import 'package:dio/dio.dart';

/// Injeta apenas o X-Terminal-Id (opcional), usado em dev/telemetria.
///
/// X-Tenant-Id NÃO é mais enviado: no modelo atual o servidor resolve a filial
/// pelo JWT (claim tenant_id) — mandar tenant fixo do cliente quebra o login
/// quando o usuário não pertence àquele tenant (guia §1.1).
///
/// X-Actor-Id também não entra aqui — só o cancelamento de venda usa, setado
/// por requisição no VendasRepository.cancelar.
class TenantInterceptor extends Interceptor {
  TenantInterceptor({this.terminalId});

  final String? terminalId;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final t = terminalId;
    if (t != null && t.isNotEmpty) {
      options.headers['X-Terminal-Id'] = t;
    }
    handler.next(options);
  }
}
