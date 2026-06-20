import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:rabbit_pdv/core/network/token_store.dart';
import 'package:rabbit_pdv/features/auth/data/dto/login_dtos.dart';

/// Anexa `Authorization: Bearer <token>` em tudo (exceto endpoints de auth)
/// e, em 401, tenta UM refresh (single-flight) e refaz a requisição original.
/// Se o refresh falhar, dispara [onSessionExpired] (bloqueio → login).
class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor({
    required TokenStore tokens,
    required Dio refreshDio,
    required VoidCallback onSessionExpired,
  }) : _tokens = tokens,
       _refreshDio = refreshDio,
       _onSessionExpired = onSessionExpired;

  final TokenStore _tokens;
  final Dio _refreshDio;
  final VoidCallback _onSessionExpired;

  Future<bool>? _inFlight;

  static bool _isAuthEndpoint(String path) =>
      path.contains('/auth/login') || path.contains('/auth/refresh');

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (!_isAuthEndpoint(options.path)) {
      final t = _tokens.accessToken;
      if (t != null && t.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $t';
      }
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final is401 = err.response?.statusCode == 401;
    final isAuth = _isAuthEndpoint(err.requestOptions.path);
    final jaTentou = err.requestOptions.extra['__retried'] == true;

    if (!is401 || isAuth || jaTentou || _semRefreshToken()) {
      return handler.next(err);
    }

    final ok = await _refresh();
    if (!ok) {
      _onSessionExpired(); // refresh morto → bloqueia e volta pro login
      return handler.next(err);
    }

    // Refaz a original com o novo token, pelo dio cru (sem este interceptor).
    try {
      final o = err.requestOptions;
      o.extra['__retried'] = true;
      o.headers['Authorization'] = 'Bearer ${_tokens.accessToken}';
      final res = await _refreshDio.fetch<dynamic>(o);
      return handler.resolve(res);
    } on DioException catch (e) {
      return handler.next(e);
    }
  }

  bool _semRefreshToken() {
    final rt = _tokens.refreshToken;
    return rt == null || rt.isEmpty;
  }

  Future<bool> _refresh() =>
      _inFlight ??= _doRefresh().whenComplete(() => _inFlight = null);

  Future<bool> _doRefresh() async {
    final rt = _tokens.refreshToken;
    if (rt == null || rt.isEmpty) return false;
    try {
      final res = await _refreshDio.post<dynamic>(
        '/auth/refresh',
        data: {'refreshToken': rt},
      );
      if (res.data is! Map<String, dynamic>) return false;
      final body = LoginResponse.fromJson(res.data as Map<String, dynamic>);
      if (body.accessToken.isEmpty) return false;
      await _tokens.save(
        accessToken: body.accessToken,
        refreshToken: body.refreshToken ?? rt,
      );
      return true;
    } catch (_) {
      return false; // refresh token expirado/inválido → sessão morta
    }
  }
}
