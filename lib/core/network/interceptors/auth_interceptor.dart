import 'package:dio/dio.dart';
import 'package:rabbit_pdv/core/network/token_store.dart';

/// Injeta `Authorization: Bearer <token>` em tudo, exceto nos endpoints de auth.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._tokens);
  final TokenStore _tokens;

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
}
