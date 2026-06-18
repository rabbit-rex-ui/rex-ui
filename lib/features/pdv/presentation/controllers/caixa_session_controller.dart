import 'package:flutter/foundation.dart';
import 'package:rabbit_pdv/core/auth/jwt_decoder.dart';
import 'package:rabbit_pdv/core/config/env.dart';
import 'package:rabbit_pdv/core/network/token_store.dart';
import 'package:rabbit_pdv/features/auth/data/auth_repository.dart';
import 'package:rabbit_pdv/features/auth/data/dto/login_dtos.dart';
import 'package:rabbit_pdv/features/pdv/data/caixa_repository.dart';
import 'package:rabbit_pdv/features/pdv/data/dto/caixa_dtos.dart';

enum SessionStatus { iniciando, autenticando, abrindoCaixa, pronto, erro }

/// Sessão de runtime do PDV: identidade (login) + caixa aberto + contexto fixo
/// de dev (terminal/warehouse/caixa). É o que alimenta a venda com
/// terminalId / cashierId / defaultWarehouseId.
///
/// Auto-bootstrap em dev: ao ser instanciado, loga e garante o caixa aberto.
/// Quando a tela de login existir, troque o bootstrap automático por um fluxo
/// disparado pela UI.
class CaixaSessionController extends ChangeNotifier {
  CaixaSessionController(this._auth, this._caixa, this._tokens) {
    bootstrap();
  }

  final AuthRepository _auth;
  final CaixaRepository _caixa;
  final TokenStore _tokens;

  SessionStatus _status = SessionStatus.iniciando;
  SessionStatus get status => _status;

  String? _erro;
  String? get erro => _erro;

  String? _employeeId; // JWT.sub → cashierId / openedBy
  String? _authUserId; // JWT.auth_user_id (alternativa para openedBy)

  CaixaSessionResponse? _caixaSessao;
  CaixaSessionResponse? get caixaSessao => _caixaSessao;

  // Contexto para a venda.
  String? get cashierId => _employeeId;
  String get terminalId => Env.terminalId;
  String get defaultWarehouseId => Env.defaultWarehouseId;
  String get cashRegisterId => Env.cashRegisterId;
  bool get pronto => _status == SessionStatus.pronto;

  Future<void> bootstrap() async {
    try {
      _set(SessionStatus.autenticando);
      final login = await _auth.login(
        const LoginRequest(
          loginCode: Env.devLoginCode,
          password: Env.devPassword,
          tenantId: Env.tenantId,
        ),
      );

      final autenticou = login.fold(
        onOk: (r) {
          _aplicarLogin(r);
          return true;
        },
        onErr: (f) {
          _falhar('Login falhou: ${f.message}');
          return false;
        },
      );
      if (!autenticou) return;

      _set(SessionStatus.abrindoCaixa);
      await _garantirCaixaAberto();
    } catch (e) {
      _falhar('Erro no bootstrap: $e');
    }
  }

  void _aplicarLogin(LoginResponse r) {
    _tokens.save(accessToken: r.accessToken, refreshToken: r.refreshToken);
    final claims = decodeJwtPayload(r.accessToken);
    _employeeId = claims['sub'] as String?;
    _authUserId = claims['auth_user_id'] as String?;
    debugPrint('[auth] login ok — employeeId=$_employeeId');
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

    // 2) Abrir. openedBy = employeeId (sub) — é o que a resposta do backend
    //    normaliza. ⚠️ Se der 400 em openedBy, troque para `_authUserId`.
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
