import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Arquivo binário baixado da API (ex.: DANFE em PDF/HTML, XML da nota).
///
/// Guarda só o que a UI precisa: os bytes e o tipo de mídia. O nome sugerido
/// pelo servidor (`Content-Disposition`) é ignorado de propósito — quem grava o
/// arquivo em disco escolhe o próprio nome (evita depender do formato do
/// cabeçalho e qualquer risco de path traversal).
class ArquivoBaixado {
  const ArquivoBaixado({required this.bytes, required this.mimeType});

  final Uint8List bytes;

  /// Tipo de mídia sem parâmetros, em minúsculas. Ex.: `text/html` para
  /// `text/html;charset=UTF-8`. Vazio se o servidor não informou.
  final String mimeType;

  /// Monta a partir de uma resposta pedida com `ResponseType.bytes`.
  factory ArquivoBaixado.fromResponse(Response<dynamic> res) {
    final contentType = res.headers.value(Headers.contentTypeHeader) ?? '';
    return ArquivoBaixado(
      bytes: Uint8List.fromList(res.data as List<int>),
      mimeType: contentType.split(';').first.trim().toLowerCase(),
    );
  }
}
