import 'package:flutter/foundation.dart';
import 'package:rabbit_pdv/core/failures/failure.dart';
import 'package:rabbit_pdv/core/failures/failure_codes.dart';
import 'package:rabbit_pdv/features/pdv/data/caixa_repository.dart';
import 'package:rabbit_pdv/features/pdv/data/dto/movimento_caixa_dtos.dart';
import 'package:uuid/uuid.dart';

/// Orquestra UMA operação de movimento de caixa (sangria ou reforço).
///
/// O [_eventId] é um **UUIDv7** gerado UMA vez no construtor e reusado em todo
/// retry — inclusive no reenvio pós-403 do step-up (a MESMA chave; o 403 não
/// persiste nada no backend). É o que garante idempotência (201 grava agora /
/// 200 devolve o mesmo registro). Descartável: um controller por operação.
///
/// Identidade e permissões vivem no [CaixaSessionController]; este controller só
/// cuida da operação em si. O `sessionId` é passado pronto pelo chamador.
class SangriaController extends ChangeNotifier {
  SangriaController(this._repo, {required this.sessionId, required this.tipo})
    : _eventId = const Uuid().v7();

  final CaixaRepository _repo;
  final String sessionId;
  final MovimentoTipo tipo;

  final String _eventId;

  // ── Estado do formulário ──
  double _amount = 0;
  double get amount => _amount;

  String _reason = '';
  String get reason => _reason;

  MovimentoDestino? _destino;
  MovimentoDestino? get destino => _destino;

  // ── Estado operacional ──
  bool _loading = false;
  bool get loading => _loading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  /// `true` quando a sangria exige o passo do fiscal/supervisor. Ligado por
  /// [exigirFiscal] (antecipação: 4 olhos ou IMMEDIATE conhecido) OU pelo
  /// `403 movement-supervisor-required` reativo. O diálogo usa isto para
  /// revelar os campos de credencial — um caminho só para os dois gatilhos.
  bool _requerSupervisor = false;
  bool get requerSupervisor => _requerSupervisor;

  bool _obscurePassword = true;
  bool get obscurePassword => _obscurePassword;

  // ── Sugestão de sangria (só WITHDRAWAL) ──
  SugestaoSangriaResponse? _sugestao;
  SugestaoSangriaResponse? get sugestao => _sugestao;

  bool _carregandoSugestao = false;
  bool get carregandoSugestao => _carregandoSugestao;

  /// Habilita a CTA. Valor positivo e, em sangria, motivo preenchido.
  /// Credenciais de supervisor são validadas no submit.
  bool get podeRegistrar =>
      !_loading &&
      _amount > 0 &&
      (tipo != MovimentoTipo.withdrawal || _reason.trim().isNotEmpty);

  // ── Setters do formulário ──
  void setAmount(double v) {
    _amount = v;
    _clearErrorSilencioso();
    notifyListeners();
  }

  void setReason(String v) {
    _reason = v;
    _clearErrorSilencioso();
    notifyListeners();
  }

  void setDestino(MovimentoDestino? v) {
    _destino = v;
    _clearErrorSilencioso();
    notifyListeners();
  }

  void toggleObscure() {
    _obscurePassword = !_obscurePassword;
    notifyListeners();
  }

  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }

  void _clearErrorSilencioso() => _errorMessage = null;

  /// Liga o passo do fiscal **de forma antecipada** — antes do primeiro POST —
  /// quando o diálogo já sabe que ele será exigido (4 olhos, ou caixa IMMEDIATE
  /// conhecido, e o operador não tem `cx.sangria.supervise`). Idempotente.
  ///
  /// Reusa o mesmo `_requerSupervisor` do caminho reativo: a partir daqui, a
  /// primeira tentativa já envia as credenciais, sem o roundtrip que levaria 403.
  void exigirFiscal() {
    if (_requerSupervisor) return;
    _requerSupervisor = true;
    notifyListeners();
  }

  /// Busca a sugestão de valor (§4). Só faz sentido em sangria. Silenciosa: um
  /// 404 (sessão não aberta) ou qualquer erro cai em entrada manual, sem ruído.
  /// Pré-preenche o valor só quando há algo a sangrar e o operador ainda não
  /// digitou nada.
  Future<void> carregarSugestao() async {
    if (tipo != MovimentoTipo.withdrawal) return;
    _carregandoSugestao = true;
    notifyListeners();
    final r = await _repo.sugestaoSangria(sessionId);
    r.fold(
      onOk: (s) {
        _sugestao = s;
        if (s.sangriaRecomendada && _amount <= 0) {
          _amount = s.suggestedRounded;
        }
      },
      onErr: (_) {
        _sugestao = null;
      },
    );
    _carregandoSugestao = false;
    notifyListeners();
  }

  /// Registra o movimento. Devolve a resposta (201/200) em sucesso; `null` em
  /// falha (com [errorMessage] preenchido, ou [requerSupervisor] ligado no caso
  /// do 403). Reusa o MESMO [_eventId] em cada tentativa, inclusive no reenvio
  /// com credenciais de supervisor.
  Future<MovimentoCaixaResponse?> registrar({
    String supervisorLoginCode = '',
    String supervisorPassword = '',
  }) async {
    final loginCode = supervisorLoginCode.trim();
    final password = supervisorPassword;

    // Validação client-side (o backend é a autoridade, mas evitamos idas óbvias).
    if (_amount <= 0) {
      _errorMessage = 'Informe um valor maior que zero.';
      notifyListeners();
      return null;
    }
    if (tipo == MovimentoTipo.withdrawal && _reason.trim().isEmpty) {
      _errorMessage = 'Informe o motivo da sangria.';
      notifyListeners();
      return null;
    }
    if (_requerSupervisor && (loginCode.isEmpty || password.isEmpty)) {
      _errorMessage = 'Informe o código e a senha do fiscal.';
      notifyListeners();
      return null;
    }

    _loading = true;
    _errorMessage = null;
    notifyListeners();

    final req = MovimentoCaixaRequest(
      tipo: tipo,
      amount: _amount,
      reason: _reason.trim().isEmpty ? null : _reason.trim(),
      destino: tipo == MovimentoTipo.withdrawal ? _destino : null,
      supervisorLoginCode: loginCode.isEmpty ? null : loginCode,
      supervisorPassword: password.isEmpty ? null : password,
    );

    final result = await _repo.registrarMovimento(
      sessionId,
      req,
      idempotencyKey: _eventId,
    );

    return result.fold<MovimentoCaixaResponse?>(
      onOk: (resp) {
        _loading = false;
        notifyListeners();
        return resp;
      },
      onErr: (f) {
        _loading = false;
        _rotearErro(f);
        notifyListeners();
        return null;
      },
    );
  }

  /// Traduz a falha em UX. `movement-supervisor-required` não é "erro": liga o
  /// modo step-up para o diálogo revelar os campos de credencial. Roteia SEMPRE
  /// pelo `code` (contrato v3 §3.8), nunca pelo texto de `detail`.
  void _rotearErro(Failure f) {
    if (f is! BusinessRuleFailure) {
      _errorMessage = f.message;
      return;
    }
    switch (f.code) {
      case FailureCodes.movementSupervisorRequired:
        _requerSupervisor = true;
        _errorMessage = null;
      case FailureCodes.stepupInvalidCredential:
        _errorMessage = 'Código ou senha do fiscal inválidos.';
      case FailureCodes.stepupLocked:
        _errorMessage =
            'Fiscal bloqueado por tentativas. Tente novamente mais tarde.';
      case FailureCodes.stepupDenied:
        _errorMessage = 'Este fiscal não tem permissão para liberar.';
      case FailureCodes.movementSegregation:
        _errorMessage = 'O fiscal precisa ser diferente do operador do caixa.';
      case FailureCodes.movementExceedsCash:
        _errorMessage = 'Valor acima do dinheiro disponível no caixa.';
      case FailureCodes.movementReasonRequired:
        _errorMessage = 'Informe o motivo da sangria.';
      case FailureCodes.destinoNaoHabilitado:
        _errorMessage = 'Este destino não está habilitado para esta loja.';
      case FailureCodes.sessionClosed:
        _errorMessage = 'O caixa está fechado. Não é possível registrar.';
      case FailureCodes.movementIdempotencyConflict:
        _errorMessage = 'Conflito ao reenviar. Feche e refaça a operação.';
      case FailureCodes.validationFailed:
        _errorMessage = 'Dados inválidos. Confira o valor e tente de novo.';
      case FailureCodes.invalidArgument:
        _errorMessage = 'Destino inválido para este tipo de movimento.';
      default:
        _errorMessage = f.message;
    }
  }
}
