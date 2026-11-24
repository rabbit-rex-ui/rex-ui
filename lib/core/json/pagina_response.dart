/// Envelope de paginação do backend: `conteudo` + metadados. Usado pela fila
/// de pedidos (`/pdv/pedidos`) e pelo painel de atenção fiscal
/// (`/fis/notas/atencao`).
class PaginaResponse<T> {
  const PaginaResponse({
    required this.conteudo,
    required this.pagina,
    required this.tamanho,
    required this.total,
  });

  final List<T> conteudo;
  final int pagina;
  final int tamanho;
  final int total;

  factory PaginaResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) itemFromJson,
  ) => PaginaResponse(
    conteudo: (json['conteudo'] as List<dynamic>? ?? const [])
        .map((e) => itemFromJson(e as Map<String, dynamic>))
        .toList(),
    pagina: (json['pagina'] as num?)?.toInt() ?? 0,
    tamanho: (json['tamanho'] as num?)?.toInt() ?? 0,
    total: (json['total'] as num?)?.toInt() ?? 0,
  );
}
