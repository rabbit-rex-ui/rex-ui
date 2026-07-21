import 'package:dio/dio.dart';

import 'package:rabbit_pdv/core/auth/jwt_decoder.dart';
import 'package:rabbit_pdv/core/auth/trusted_device_store.dart';
import 'package:rabbit_pdv/core/network/token_store.dart';

/// Injeta X-Device-Id/Secret nas rotas que exigem estação confiável:
/// `/admin/*` (EXCETO `/admin/trusted-devices`, que é o bootstrap isento) e
/// `POST /auth/trocar-senha` (guia §3.1). Em nenhuma outra rota.
///
/// O device é escolhido pelo tenant ativo (claim tenant_id do access token),
/// porque o backend casa id+secret+tenant_id.
class TrustedDeviceInterceptor extends Interceptor {
  TrustedDeviceInterceptor(this._devices, this._tokens);

  final TrustedDeviceStore _devices;
  final TokenStore _tokens;

  static bool _exigeDevice(RequestOptions o) {
    final p = o.path;
    if (p.contains('/admin/trusted-devices')) return false; // bootstrap isento
    if (p.contains('/admin/')) return true;
    if (p.contains('/auth/trocar-senha')) return true;
    return false;
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (!_exigeDevice(options)) {
      handler.next(options);
      return;
    }
    final token = _tokens.accessToken;
    final tenantId = token == null
        ? null
        : decodeJwtPayload(token)['tenant_id'] as String?;
    final cred = tenantId == null ? null : _devices.peek(tenantId);
    if (cred != null) {
      options.headers['X-Device-Id'] = cred.deviceId;
      options.headers['X-Device-Secret'] = cred.secret;
    }
    // Sem credencial → segue sem os headers; o backend responde 403 e a
    // camada de repositório traduz para "estação não confiável".
    handler.next(options);
  }
}
