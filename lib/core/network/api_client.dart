import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:rabbit_pdv/core/auth/trusted_device_store.dart';
import 'package:rabbit_pdv/core/failures/failure.dart';
import 'package:rabbit_pdv/core/failures/failure_codes.dart';
import 'package:rabbit_pdv/core/network/arquivo_baixado.dart';
import 'package:rabbit_pdv/core/network/interceptors/auth_interceptor.dart';
import 'package:rabbit_pdv/core/network/interceptors/tenant_interceptor.dart';
import 'package:rabbit_pdv/core/network/interceptors/trusted_device_interceptor.dart';
import 'package:rabbit_pdv/core/network/relogio_servidor.dart';
import 'package:rabbit_pdv/core/network/token_store.dart';
import 'package:rabbit_pdv/core/result/result.dart';

/// Cliente HTTP central. baseUrl vem do Bootstrap (--dart-define).
/// Todo erro vira uma Failure tipada; repositórios desserializam via `decode`.
class ApiClient {
  ApiClient({
    required String baseUrl,
    required TokenStore tokens,
    required TrustedDeviceStore trustedDevices,
    required RelogioServidor relogio,
    required VoidCallback onSessionExpired,
    Duration connectTimeout = const Duration(seconds: 5),
    Duration receiveTimeout = const Duration(seconds: 15),
  }) {
    final base = BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: connectTimeout,
      receiveTimeout: receiveTimeout,
      validateStatus: (s) => s != null && s < 400,
      headers: {'Content-Type': 'application/json'},
    );

    // Dio cru só pra refresh + replay: NÃO tem AuthInterceptor
    // (evita o laço 401 → refresh → 401).
    final refreshDio = Dio(base)..interceptors.add(TenantInterceptor());

    _dio = Dio(base);
    _dio.interceptors.addAll([
      RelogioServidorInterceptor(relogio),
      TenantInterceptor(),
      TrustedDeviceInterceptor(trustedDevices, tokens),
      AuthInterceptor(
        tokens: tokens,
        refreshDio: refreshDio,
        onSessionExpired: onSessionExpired,
      ),
    ]);
  }

  late final Dio _dio;
  Dio get raw => _dio;

  /// Executa a chamada e desserializa só o corpo (`res.data`). Caso comum.
  Future<Result<T, Failure>> send<T>(
    Future<Response<dynamic>> Function(Dio dio) call, {
    required T Function(dynamic data) decode,
  }) {
    return sendRaw<T>(call, decode: (res) => decode(res.data));
  }

  /// Como [send], mas entrega a [Response] inteira ao `decode` — para quando
  /// os cabeçalhos importam (ex.: `Content-Type` de um download).
  Future<Result<T, Failure>> sendRaw<T>(
    Future<Response<dynamic>> Function(Dio dio) call, {
    required T Function(Response<dynamic> res) decode,
  }) async {
    try {
      final res = await call(_dio);
      return Ok(decode(res));
    } on DioException catch (e) {
      // Diagnóstico cru em debug: a Failure tipada (retornada abaixo) é ótima
      // para a UI, mas apaga status/método/URL/corpo — que é o que precisamos
      // ver quando algo dá "Erro inesperado.". Não altera o comportamento.
      if (kDebugMode) {
        final o = e.requestOptions;
        debugPrint(
          '[api][http-erro] ${o.method} ${o.uri} '
          '→ type=${e.type} status=${e.response?.statusCode} '
          'body=${_decodeBody(e.response?.data)}',
        );
      }
      return Err(_mapDioException(e));
    } on Object catch (e, st) {
      // Chegou 2xx mas o decode/parse estourou (corpo inesperado).
      if (kDebugMode) {
        debugPrint('[api][parse-erro] $e\n$st');
      }
      return Err(UnknownFailure('Resposta inválida do servidor.', cause: e));
    }
  }

  /// GET de arquivo binário (PDF, HTML, XML). Em erro, o corpo problem+json é
  /// decodificado normalmente — o mapeamento de falhas é o mesmo do [send].
  Future<Result<ArquivoBaixado, Failure>> download(String path) {
    return sendRaw<ArquivoBaixado>(
      (dio) => dio.get<dynamic>(
        path,
        options: Options(responseType: ResponseType.bytes),
      ),
      decode: ArquivoBaixado.fromResponse,
    );
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
    // dio 5.11+: o tempo estourou ao decodificar a resposta. O servidor pode
    // ter processado o pedido — para quem chama, é tão incerto quanto um
    // timeout de recebimento (ex.: cancelamento de nota, guia fiscal §8.4).
    case DioExceptionType.transformTimeout:
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
  final body = _decodeBody(res.data);
  final pd = _problemDetail(body);
  final status = res.statusCode ?? 0;
  final msg = pd.detail ?? pd.title ?? 'Erro inesperado.';

  switch (status) {
    case 400:
      return ValidationFailure(
        pd.detail ?? 'Dados inválidos.',
        fieldErrors: _fieldErrors(body),
      );
    case 401:
      // Sessão: token ausente/inválido/expirado — `code: nao_autenticado`
      // (problem+json desde o backend M7) ou sem corpo (legado). O
      // AuthInterceptor já tentou o refresh; a UI trata como sessão expirada.
      // Qualquer OUTRO `code` em 401 é credencial errada, não sessão:
      // `credenciais_invalidas` (login, troca de senha) ou
      // `stepup-invalid-credential` (supervisor no fechamento/anulação).
      // Preservamos o `code` para o repo rotear.
      final code401 = pd.code;
      if (code401 == null || code401 == FailureCodes.naoAutenticado) {
        return const NetworkFailure('Sessão expirada.', statusCode: 401);
      }
      return BusinessRuleFailure(msg, code: code401, details: pd.extras);
    case 403:
      return BusinessRuleFailure(
        msg,
        code: pd.code ?? _codeFromType(pd.type) ?? FailureCodes.semPermissao,
        details: pd.extras,
      );
    case 404:
      return NotFoundFailure(pd.detail ?? 'Recurso não encontrado.');
    case 409:
      // `code` do corpo → sufixo do `type`. Nunca o texto do detail: era ele
      // que transformava `expedicao-bloqueada` em CAIXA_BLOQUEADO.
      return BusinessRuleFailure(
        msg,
        code: pd.code ?? _codeFromType(pd.type) ?? FailureCodes.conflito,
        details: pd.extras,
      );
    case 422:
      return BusinessRuleFailure(
        msg,
        code: pd.code ?? _codeFromType(pd.type) ?? FailureCodes.regraNegocio,
        details: pd.extras,
      );
    case 429:
      final wait = _retryAfter(res);
      final extra = wait == null ? '' : ' Aguarde ${wait.inSeconds}s.';
      return NetworkFailure('Muitas tentativas.$extra', statusCode: 429);
    default:
      return NetworkFailure(msg, statusCode: status);
  }
}

/// Downloads (`ResponseType.bytes`) entregam o corpo de erro como bytes. Tenta
/// ler como JSON (problem+json); se não der, devolve o texto ou o original.
dynamic _decodeBody(dynamic data) {
  if (data is! List<int>) return data;
  try {
    final text = utf8.decode(data);
    try {
      return jsonDecode(text);
    } on FormatException {
      return text;
    }
  } on FormatException {
    return data;
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

/// `https://errors.rabbit-rex.com/nota-nao-cancelavel` → `NOTA_NAO_CANCELAVEL`.
///
/// Devolve `null` quando o `type` não identifica o erro: ausente, sem caminho,
/// ou com esquema mas sem host — caso do `about:blank`, o padrão do Spring, que
/// antes virava o code `ABOUT:BLANK` e escondia os fallbacks
/// (`SEM_PERMISSAO`, `REGRA_NEGOCIO`).
String? _codeFromType(String? type) {
  if (type == null || type.isEmpty) return null;
  final uri = Uri.tryParse(type);
  if (uri == null || (uri.hasScheme && uri.host.isEmpty)) return null;
  final seg = uri.pathSegments.lastWhere(
    (s) => s.isNotEmpty,
    orElse: () => '',
  );
  if (seg.isEmpty || seg.contains('.')) return null;
  return seg.toUpperCase().replaceAll('-', '_');
}

Duration? _retryAfter(Response<dynamic> res) {
  final s = int.tryParse(res.headers.value('retry-after') ?? '');
  return s == null ? null : Duration(seconds: s);
}

/// Membros padrão do ProblemDetail; o resto vai para `extras`.
const _membrosPadrao = {
  'type',
  'title',
  'status',
  'detail',
  'instance',
  'code',
};

typedef _ProblemDetail = ({
  String? type,
  String? title,
  String? detail,
  String? code,
  Map<String, Object?> extras,
});

_ProblemDetail _problemDetail(dynamic data) {
  if (data is Map<String, dynamic>) {
    return (
      type: data['type'] as String?,
      title: data['title'] as String?,
      detail: data['detail'] as String?,
      code: data['code'] as String?, // ProblemDetail estendido (contrato §8)
      extras: {
        for (final e in data.entries)
          if (!_membrosPadrao.contains(e.key)) e.key: e.value,
      },
    );
  }
  if (data is String && data.isNotEmpty) {
    return (
      type: null,
      title: null,
      detail: data,
      code: null,
      extras: const {},
    );
  }
  return (
    type: null,
    title: null,
    detail: null,
    code: null,
    extras: const {},
  );
}
