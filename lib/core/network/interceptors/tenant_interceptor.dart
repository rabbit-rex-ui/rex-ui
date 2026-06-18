import 'package:dio/dio.dart';

/// Injeta os headers de identidade exigidos em dev (§2):
/// X-Tenant-Id (obrigatório) e X-Terminal-Id (opcional).
///
/// X-Actor-Id NÃO entra aqui — só o cancelamento de venda usa, e é setado
/// por requisição no VendasRepository.cancelar.
class TenantInterceptor extends Interceptor {
  TenantInterceptor({required this.tenantId, this.terminalId});

  final String tenantId;
  final String? terminalId;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers['X-Tenant-Id'] = tenantId;
    final t = terminalId;
    if (t != null && t.isNotEmpty) {
      options.headers['X-Terminal-Id'] = t;
    }
    handler.next(options);
  }
}
