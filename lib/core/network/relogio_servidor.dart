import 'dart:io' show HttpDate, HttpHeaders;

import 'package:dio/dio.dart';

/// Hora do servidor vista do terminal (guia fiscal v2.2 §8.3).
///
/// Prazos que o backend calcula — como o `cancelavelAte` da nota — devem ser
/// comparados com o relógio do SERVIDOR: um terminal com o relógio errado
/// mostraria o botão "Cancelar" fora de hora. Toda resposta HTTP traz o header
/// padrão `Date`; guardamos o desvio `Date(servidor) − agora(terminal)` da
/// última resposta e o aplicamos em [agora]. A precisão de 1 s do header basta.
class RelogioServidor {
  Duration _desvio = Duration.zero;

  /// Desvio da última resposta (positivo = servidor adiantado).
  Duration get desvio => _desvio;

  /// "Agora" no relógio do servidor. Sem nenhuma resposta ainda, é o relógio
  /// do terminal.
  DateTime agora() => DateTime.now().add(_desvio);

  /// Registra o header `Date` de uma resposta. Ausente ou inválido: ignora.
  void registrar(String? headerDate) {
    if (headerDate == null || headerDate.isEmpty) return;
    try {
      _desvio = HttpDate.parse(headerDate).difference(DateTime.now());
    } on Exception {
      // Header fora do formato RFC 1123: mantém o desvio anterior.
    }
  }
}

/// Alimenta o [RelogioServidor] com o header `Date` de toda resposta,
/// inclusive as de erro.
class RelogioServidorInterceptor extends Interceptor {
  RelogioServidorInterceptor(this._relogio);
  final RelogioServidor _relogio;

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    _relogio.registrar(response.headers.value(HttpHeaders.dateHeader));
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _relogio.registrar(err.response?.headers.value(HttpHeaders.dateHeader));
    handler.next(err);
  }
}
