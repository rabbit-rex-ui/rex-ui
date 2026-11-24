import 'package:rabbit_pdv/core/resilience/crash_record.dart';
import 'package:rabbit_pdv/core/resilience/error_reporter.dart';
import 'package:rabbit_pdv/core/result/result.dart';
import 'package:rabbit_pdv/core/failures/failure.dart';
import 'package:rabbit_pdv/core/failures/failure_codes.dart';
import 'package:rabbit_pdv/core/network/api_client.dart';
import 'package:rabbit_pdv/core/network/token_store.dart';
import 'package:rabbit_pdv/features/auth/data/dto/login_dtos.dart';
import 'package:rabbit_pdv/features/auth/domain/auth_repository.dart';
import 'package:rabbit_pdv/features/auth/domain/auth_session.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._api, this._tokens);
  final ApiClient _api;
  final TokenStore _tokens;

  @override
  Future<Result<AuthSession, Failure>> login(LoginRequest request) async {
    final result = await _api.send<LoginResponse>(
      (dio) => dio.post('/auth/login', data: request.toJson()),
      decode: (data) => LoginResponse.fromJson(data as Map<String, dynamic>),
    );

    switch (result) {
      case Ok(:final value):
        await _tokens.save(
          accessToken: value.accessToken,
          refreshToken: value.refreshToken,
        );
        return Ok(
          AuthSession.fromAccessToken(
            value.accessToken,
            refreshToken: value.refreshToken,
            tenantId: value.tenantId,
            passwordMustChange: value.passwordMustChange,
          ),
        );
      case Err(:final failure):
        return Err(_normalizarFalha(failure));
    }
  }

  @override
  Future<Result<void, Failure>> trocarSenha(TrocarSenhaRequest request) async {
    final result = await _api.send<Map<String, dynamic>?>(
      (dio) => dio.post('/auth/trocar-senha', data: request.toJson()),
      decode: (data) => data is Map<String, dynamic> ? data : null,
    );

    switch (result) {
      case Ok(:final value):
        // Se o backend rotacionar tokens após a troca, persiste os novos
        // para a sessão seguir válida; caso contrário mantém o atual.
        final novoAccess = value?['accessToken'] as String?;
        if (novoAccess != null) {
          await _tokens.save(
            accessToken: novoAccess,
            refreshToken: value?['refreshToken'] as String?,
          );
        }
        return const Ok<void, Failure>(null);
      case Err(:final failure):
        return Err(_normalizarFalha(failure));
    }
  }

  @override
  Future<Result<void, Failure>> logout() async {
    final rt = _tokens.refreshToken;
    if (rt != null) {
      try {
        await _api.raw.post<void>('/auth/logout', data: {'refreshToken': rt});
      } catch (_) {
        // best-effort: o que importa é limpar o estado local.
      }
    }
    await _tokens.clear();
    return const Ok<void, Failure>(null);
  }

  /// Refina a falha pro contexto de auth e reporta inesperadas à resiliência.
  Failure _normalizarFalha(Failure f) {
    final refined = _refineLoginFailure(f);
    if (refined is UnknownFailure) _reportar(refined);
    return refined;
  }

  /// Mensagens do login por `code` (guia fiscal v2.3 §6.4) — nunca pelo
  /// texto. O `code` é preservado para quem quiser rotear.
  Failure _refineLoginFailure(Failure f) {
    // Backend anterior ao v2.3: 401 sem corpo. No login, 401 nunca é sessão.
    if (f is NetworkFailure && f.statusCode == 401) {
      return const BusinessRuleFailure(
        'Código de login ou senha inválidos.',
        code: FailureCodes.credenciaisInvalidas,
      );
    }
    if (f is! BusinessRuleFailure) return f;
    final mensagem = switch (f.code) {
      FailureCodes.credenciaisInvalidas => 'Código de login ou senha inválidos.',
      FailureCodes.contaBloqueada =>
        'Conta bloqueada. Procure o administrador.',
      FailureCodes.contaBloqueadaTemporariamente =>
        'Conta bloqueada temporariamente por excesso de tentativas. Tente '
            'mais tarde ou redefina a senha.',
      FailureCodes.semTenantAtivo =>
        'Seu usuário não tem vínculo ativo com esta loja. Procure o '
            'administrador.',
      _ => null,
    };
    return mensagem == null
        ? f
        : BusinessRuleFailure(mensagem, code: f.code, cause: f);
  }

  void _reportar(Failure f) {
    ErrorReporter.instance.capture(
      f.cause ?? f,
      f.cause is Error ? (f.cause as Error).stackTrace : null,
      source: CrashSource.domain,
      severity: CrashSeverity.error,
      message: 'Falha inesperada no fluxo de auth: ${f.message}',
      context: {'failure': f.runtimeType.toString()},
    );
  }
}
