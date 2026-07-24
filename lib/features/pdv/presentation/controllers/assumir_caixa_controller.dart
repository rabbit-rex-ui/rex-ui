import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'package:rabbit_pdv/core/failures/failure.dart';
import 'package:rabbit_pdv/core/failures/failure_codes.dart';
import 'package:rabbit_pdv/core/result/result.dart';
import 'package:rabbit_pdv/features/auth/presentation/login_controller.dart';
import 'package:rabbit_pdv/features/pdv/data/assumir_caixa_repository.dart';
import 'package:rabbit_pdv/features/pdv/data/caixa_repository.dart';
import 'package:rabbit_pdv/features/pdv/data/dto/assumir_caixa_dtos.dart';

/// Orquestra UMA tomada de posse (custódia A→B). Descartável: o [_eventId] é
/// gerado uma vez na construção e REUSADO em todos os reenvios — inclusive o
/// retry após 422 `justification-required` (idempotência).
///
/// Atribuição é por token (contrato §1.2): após o login de B, todas as chamadas
/// saem com o bearer de B. Não há rebind.
///
/// Quando construído com `jaAutenticado: true` (ex.: pelo LockOverlay, que já
/// autenticou B para rotear por custódia), o login interno é pulado e as
/// credenciais não são exigidas.
class AssumirCaixaController extends ChangeNotifier {
  AssumirCaixaController({
    required AssumirCaixaRepository assumirRepo,
    required CaixaRepository caixaRepo,
    required LoginController login,
    String? cashSessionId, // sessão já em memória (preferido)
    String? cashRegisterId, // fallback: resolve via GET
    bool jaAutenticado = false, // chamador já logou B; não reautenticar
  }) : assert(
         cashSessionId != null || cashRegisterId != null,
         'Forneça cashSessionId (sessão em memória) ou cashRegisterId (GET).',
       ),
       _assumir = assumirRepo,
       _caixa = caixaRepo,
       _login = login,
       _cashSessionId = cashSessionId,
       _cashRegisterId = cashRegisterId,
       _autenticado = jaAutenticado,
       _eventId = const Uuid().v7();

  final AssumirCaixaRepository _assumir;
  final CaixaRepository _caixa;
  final LoginController _login;
  final String? _cashRegisterId;
  final String _eventId;

  String? _cashSessionId; // resolvido on-demand se vier null

  bool _loading = false;
  bool get loading => _loading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool _precisaJustificativa = false;
  bool get precisaJustificativa => _precisaJustificativa;

  /// True quando o backend rejeitou por `segregation`: B já é o custodiante.
  /// A UI usa isso para sugerir "Desbloquear" em vez de insistir em assumir.
  bool _jaEhCustodiante = false;
  bool get jaEhCustodiante => _jaEhCustodiante;

  bool _autenticado;

  /// True quando quem abriu o fluxo já autenticou B. A UI usa isso para não
  /// pedir credenciais novamente.
  bool get jaAutenticado => _autenticado;

  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }

  /// Executa (ou reexecuta) a posse. Retorna a resposta em 2xx; null em falha.
  ///
  /// [loginCode]/[password] só são necessários quando o controller NÃO foi
  /// construído com `jaAutenticado: true`.
  Future<AssumirCaixaResponse?> assumir({
    String? loginCode,
    String? password,
    required CxTakeoverReason reason,
    String? reasonNote,
    required bool cashVerified,
    double? countedCash,
    required bool cartPreserved,
    String? cartRef,
    String? justificationNote,
  }) async {
    _loading = true;
    _errorMessage = null;
    notifyListeners();

    // 1) Login de B — só quando ainda não autenticado. O bearer de B passa a
    //    valer em todas as chamadas seguintes (atribuição por token).
    if (!_autenticado) {
      if (loginCode == null || password == null) {
        _fail('Informe o código de login e a senha de quem assume.');
        return null;
      }
      final ok = await _login.submit(loginCode: loginCode, password: password);
      if (!ok) {
        _fail(_login.errorMessage ?? 'Falha na autenticação.');
        return null;
      }
      final session = _login.session;
      if (session != null && !session.hasPermission('cx.takeover')) {
        _fail('Você não tem permissão para assumir o caixa (cx.takeover).');
        return null;
      }
      _autenticado = true;
    }

    // 2) Resolve a sessão aberta SÓ se não a temos em memória.
    if (_cashSessionId == null) {
      final r = await _caixa.sessaoAberta(_cashRegisterId!);
      switch (r) {
        case Ok(:final value):
          if (!value.isOpen) {
            _fail('Nenhuma sessão de caixa aberta neste terminal.');
            return null;
          }
          _cashSessionId = value.id;
        case Err(:final failure):
          _fail(
            failure is NotFoundFailure
                ? 'Nenhuma sessão de caixa aberta neste terminal.'
                : failure.message,
          );
          return null;
      }
    }

    // 3) POST .../assumir — eventId reusado entre tentativas.
    final req = AssumirCaixaRequest(
      eventId: _eventId,
      reason: reason,
      reasonNote: reasonNote,
      cashVerified: cashVerified,
      countedCash: cashVerified ? countedCash : null,
      cartPreserved: cartPreserved,
      cartRef: cartPreserved ? cartRef : null,
      justificationNote: justificationNote,
      clientReportedAt: DateTime.now(),
    );

    final res = await _assumir.assumir(
      cashSessionId: _cashSessionId!,
      request: req,
    );

    return res.fold(
      onOk: (r) {
        _loading = false;
        _precisaJustificativa = false;
        _jaEhCustodiante = false;
        _errorMessage = null;
        notifyListeners();
        return r;
      },
      onErr: (f) {
        final code = f is BusinessRuleFailure ? f.code : '';
        _precisaJustificativa =
            code == FailureCodes.cxTakeoverJustificationRequired;
        _jaEhCustodiante = code == FailureCodes.cxTakeoverSegregation;
        _fail(_mensagem(f));
        return null;
      },
    );
  }

  String _mensagem(Failure f) {
    if (f is BusinessRuleFailure) {
      return switch (f.code) {
        FailureCodes.cxTakeoverJustificationRequired =>
          'Divergência acima do limite. Informe uma justificativa para prosseguir.',
        FailureCodes.cxTakeoverSegregation =>
          'Este caixa já está sob sua responsabilidade. Use "Desbloquear".',
        FailureCodes.cxTakeoverSessionInvalid =>
          'A sessão do caixa não está mais aberta. Recarregue e tente de novo.',
        FailureCodes.cxTakeoverReasonNoteRequired =>
          'Descreva o motivo (obrigatório para "Outro").',
        _ => f.message,
      };
    }
    return f.message;
  }

  void _fail(String msg) {
    _errorMessage = msg;
    _loading = false;
    notifyListeners();
  }
}
