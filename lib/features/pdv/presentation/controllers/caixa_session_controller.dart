import 'package:flutter/foundation.dart';
import 'package:rabbit_pdv/core/auth/jwt_decoder.dart';
import 'package:rabbit_pdv/core/config/env.dart';
import 'package:rabbit_pdv/core/network/token_store.dart';
import 'package:rabbit_pdv/core/security/terminal_context_store.dart';
import 'package:rabbit_pdv/features/pdv/data/caixa_repository.dart';
import 'package:rabbit_pdv/features/pdv/data/dto/caixa_dtos.dart';
import 'package:rabbit_pdv/features/provisionamento/data/caixa_fisico_repository.dart';
import 'package:rabbit_pdv/features/provisionamento/data/dto/pdv_fisico.dart';

enum SessionStatus { iniciando, resolvendoTerminal, abrindoCaixa, pronto, erro }

/// Sessão de runtime do PDV: identidade do operador (claims do JWT) +
/// identidade do terminal (da ativação) + caixa aberto.
///
/// O contexto do caixa NÃO vem de Env: `cashRegisterId` vem da ativação
/// (TerminalContextStore) e `terminalId`/`defaultWarehouseId`/`name` vêm do
/// caixa físico (GET /pdv/caixas-fisicos/{id}), com cache local.
class CaixaSessionController extends ChangeNotifier {
  CaixaSessionController(
    this._caixa,
    this._tokens,
    this._terminalCtx,
    this._caixasFisicos,
  ) {
    bootstrap();
  }

  final CaixaRepository _caixa;
  final TokenStore _tokens;
  final TerminalContextStore _terminalCtx;
  final CaixaFisicoRepository _caixasFisicos;

  SessionStatus _status = SessionStatus.iniciando;
  SessionStatus get status => _status;

  String? _erro;
  String? get erro => _erro;

  String? _employeeId; // JWT.sub → cashierId / openedBy
  String? _authUserId; // JWT.auth_user_id (fallback p/ openedBy)

  String? _cashRegisterId;
  String? _terminalId;
  String? _defaultWarehouseId;
  PdvFisico? _pdv;

  CaixaSessionResponse? _caixaSessao;
  CaixaSessionResponse? get caixaSessao => _caixaSessao;

  // Contexto para a venda.
  String? get cashierId => _employeeId;
  String get terminalId => _terminalId ?? '';
  String get cashRegisterId => _cashRegisterId ?? '';
  String get defaultWarehouseId =>
      _defaultWarehouseId ?? Env.defaultWarehouseId;
  bool get pronto => _status == SessionStatus.pronto;

  /// Rótulo do caixa para a topbar (name é NOT NULL no backend).
  String get caixaLabel => _pdv?.name ?? '';

  Future<void> bootstrap() async {
    try {
      _set(SessionStatus.iniciando);
      _caixaSessao = null;
      _employeeId = null;
      _authUserId = null;

      final token = _tokens.accessToken;
      if (token == null) {
        _falhar('Sem sessão autenticada. Faça login.');
        return;
      }
      final claims = decodeJwtPayload(token);
      _employeeId = claims['sub'] as String?;
      _authUserId = claims['auth_user_id'] as String?;

      if (kDebugMode) {
        debugPrint('[caixa-session] identidade — employeeId=$_employeeId');
      }

      _set(SessionStatus.resolvendoTerminal);
      if (!await _resolverTerminal()) return;

      _set(SessionStatus.abrindoCaixa);
      await _garantirCaixaAberto();
    } catch (e) {
      _falhar('Erro no bootstrap: $e');
    }
  }

  /// Resolve o contexto do terminal: cashRegisterId vem da ativação;
  /// terminalId/defaultWarehouseId/name vêm do caixa físico (com cache local).
  Future<bool> _resolverTerminal() async {
    final ctx = await _terminalCtx.carregar();
    if (ctx == null) {
      _falhar('Terminal não ativado. Ative este terminal antes de operar.');
      return false;
    }
    _cashRegisterId = ctx.cashRegisterId;

    final r = await _caixasFisicos.buscarPorId(ctx.cashRegisterId);
    return r.fold(
      onOk: (pdv) {
        _pdv = pdv;
        _defaultWarehouseId = pdv.defaultWarehouseId;

        // §9: cx_cash_registers.terminal_id é nullable, mas pos_sales exige.
        // Falha AQUI (config) em vez de deixar a venda quebrar no fechamento.
        if (pdv.terminalId.isEmpty) {
          _falhar(
            'Caixa "${pdv.name}" sem terminal configurado. Contate o gestor.',
          );
          return false;
        }
        _terminalId = pdv.terminalId;

        // Cacheia o terminalId para boots offline/futuros.
        if (ctx.terminalId != pdv.terminalId) {
          _terminalCtx.salvar(ctx.comTerminalId(pdv.terminalId));
        }
        if (kDebugMode) {
          debugPrint(
            '[caixa-session] terminal=${pdv.terminalId} caixa=${pdv.code}',
          );
        }
        return true;
      },
      onErr: (f) {
        // Sem rede: usa o terminalId cacheado, se houver.
        if (ctx.terminalId != null && ctx.terminalId!.isNotEmpty) {
          _terminalId = ctx.terminalId;
          return true;
        }
        _falhar('Não foi possível resolver o terminal: ${f.message}');
        return false;
      },
    );
  }

  Future<void> _garantirCaixaAberto() async {
    // 1) Já existe sessão aberta? (evita 409 ao reiniciar)
    final aberta = await _caixa.sessaoAberta(cashRegisterId);
    final reusou = aberta.fold(
      onOk: (s) {
        _caixaSessao = s;
        _set(SessionStatus.pronto);
        debugPrint('[caixa] sessão já aberta: ${s.id}');
        return true;
      },
      onErr: (_) => false, // 404 → abrir
    );
    if (reusou) return;

    // 2) Abrir. openedBy = employeeId (sub).
    final openedBy = _employeeId ?? _authUserId;
    if (openedBy == null) {
      _falhar('Sem operador para abrir o caixa.');
      return;
    }
    final abriu = await _caixa.abrir(
      AbrirCaixaRequest(
        cashRegisterId: cashRegisterId,
        openedBy: openedBy,
        openingFloat: Env.openingFloat,
      ),
    );
    abriu.fold(
      onOk: (s) {
        _caixaSessao = s;
        _set(SessionStatus.pronto);
        debugPrint('[caixa] aberto: ${s.id}');
      },
      onErr: (f) => _falhar('Abrir caixa falhou: ${f.message}'),
    );
  }

  void _set(SessionStatus s) {
    _status = s;
    _erro = null;
    notifyListeners();
  }

  void _falhar(String msg) {
    _status = SessionStatus.erro;
    _erro = msg;
    debugPrint('[caixa-session][erro] $msg');
    notifyListeners();
  }
}
