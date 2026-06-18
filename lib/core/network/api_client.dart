import 'package:dio/dio.dart';
import 'package:rabbit_pdv/core/failures/failure.dart';
import 'package:rabbit_pdv/core/failures/failure_codes.dart';
import 'package:rabbit_pdv/core/result/result.dart';
import 'package:rabbit_pdv/core/network/token_store.dart';
import 'package:rabbit_pdv/core/network/interceptors/auth_interceptor.dart';
import 'package:rabbit_pdv/core/network/interceptors/tenant_interceptor.dart';

/// Cliente HTTP central. baseUrl vem do Bootstrap (--dart-define).
/// Todo erro vira uma Failure tipada; repositórios desserializam via `decode`.
class ApiClient {
  ApiClient({
    required String baseUrl,
    required String tenantId,
    required TokenStore tokens,
    String? terminalId,
    Duration connectTimeout = const Duration(seconds: 5),
    Duration receiveTimeout = const Duration(seconds: 15),
  }) {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: connectTimeout,
        receiveTimeout: receiveTimeout,
        validateStatus: (s) => s != null && s < 400,
        headers: {'Content-Type': 'application/json'},
      ),
    );
    _dio.interceptors.addAll([
      TenantInterceptor(tenantId: tenantId, terminalId: terminalId),
      AuthInterceptor(tokens),
    ]);
  }

  late final Dio _dio;
  Dio get raw => _dio;

  Future<Result<T, Failure>> send<T>(
    Future<Response<dynamic>> Function(Dio dio) call, {
    required T Function(dynamic data) decode,
  }) async {
    try {
      final res = await call(_dio);
      return Ok(decode(res.data));
    } on DioException catch (e) {
      return Err(_mapDioException(e));
    } on Object catch (e) {
      return Err(UnknownFailure('Resposta inválida do servidor.', cause: e));
    }
  }

  static Options idempotent(String key) =>
      Options(headers: {'Idempotency-Key': key});
}

// ─── Mapeamento DioException → Failure ───

Failure _mapDioException(DioException e) {
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return NetworkFailure('Tempo de conexão esgotado.', cause: e);
    case DioExceptionType.connectionError:
      return NetworkFailure('Sem conexão com o servidor.', cause: e);
    case DioExceptionType.badCertificate:
      return NetworkFailure('Certificado do servidor inválido.', cause: e);
    case DioExceptionType.cancel:
      return NetworkFailure('Requisição cancelada.', cause: e);
    case DioExceptionType.badResponse:
    case DioExceptionType.unknown:
      final res = e.response;
      return res == null
          ? NetworkFailure('Sem conexão com o servidor.', cause: e)
          : _mapStatus(res);
  }
}

Failure _mapStatus(Response<dynamic> res) {
  final pd = _problemDetail(res.data);
  final status = res.statusCode ?? 0;
  final msg = pd.detail ?? pd.title ?? 'Erro inesperado.';

  switch (status) {
    case 400:
      return ValidationFailure(
        pd.detail ?? 'Dados inválidos.',
        fieldErrors: _fieldErrors(res.data),
      );
    case 401:
      return const NetworkFailure('Sessão expirada.', statusCode: 401);
    case 403:
      return BusinessRuleFailure(msg, code: _code403(msg, pd.type));
    case 404:
      return NotFoundFailure(pd.detail ?? 'Recurso não encontrado.');
    case 409:
      return BusinessRuleFailure(msg, code: _code409(msg));
    case 422:
      return BusinessRuleFailure(
        msg,
        code: _codeFromType(pd.type) ?? FailureCodes.regraNegocio,
      );
    case 429:
      final wait = _retryAfter(res);
      final extra = wait == null ? '' : ' Aguarde ${wait.inSeconds}s.';
      return NetworkFailure('Muitas tentativas.$extra', statusCode: 429);
    default:
      return NetworkFailure(msg, statusCode: status);
  }
}

Map<String, String> _fieldErrors(dynamic data) {
  if (data is! Map || data['erros'] is! List) return const {};
  final out = <String, String>{};
  for (final e in data['erros'] as List) {
    if (e is Map && e['campo'] != null) {
      out[e['campo'].toString()] = (e['mensagem'] ?? '').toString();
    }
  }
  return out;
}

String _code403(String detail, String? type) {
  if (_mentions(detail, ['supervisor', 'supervise'])) {
    return FailureCodes.exigeSupervisor;
  }
  if (_mentions(detail, ['bloquead', 'locked'])) {
    return FailureCodes.contaBloqueada;
  }
  return _codeFromType(type) ?? FailureCodes.semPermissao;
}

String _code409(String detail) {
  if (_mentions(detail, ['bloquead'])) return FailureCodes.caixaBloqueado;
  if (_mentions(detail, ['fechad'])) return FailureCodes.caixaFechado;
  if (_mentions(detail, ['idempotency', 'idempotência'])) {
    return FailureCodes.idempotenciaConflito;
  }
  return 'CONFLITO';
}

String? _codeFromType(String? type) {
  if (type == null) return null;
  final seg = type.split('/').lastWhere((s) => s.isNotEmpty, orElse: () => '');
  if (seg.isEmpty || seg.contains('.')) return null;
  return seg.toUpperCase().replaceAll('-', '_');
}

bool _mentions(String h, List<String> needles) {
  final s = h.toLowerCase();
  return needles.any((n) => s.contains(n.toLowerCase()));
}

Duration? _retryAfter(Response<dynamic> res) {
  final s = int.tryParse(res.headers.value('retry-after') ?? '');
  return s == null ? null : Duration(seconds: s);
}

({String? type, String? title, String? detail}) _problemDetail(dynamic data) {
  if (data is Map<String, dynamic>) {
    return (
      type: data['type'] as String?,
      title: data['title'] as String?,
      detail: data['detail'] as String?,
    );
  }
  if (data is String && data.isNotEmpty) {
    return (type: null, title: null, detail: data);
  }
  return (type: null, title: null, detail: null);
}
