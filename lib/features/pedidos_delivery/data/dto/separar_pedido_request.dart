// Corpo de `POST /{id}/separar` (guia §4.3): lista de itens separados. Só
// escrita (`toJson`). SEPARANDO permanece; conferir depois exige que nenhum
// item siga SOLICITADO (todo item separado ou marcado indisponível).

/// Corpo de `POST /pdv/pedidos/{id}/separar` (guia §4.3).
class SepararPedidoRequest {
  const SepararPedidoRequest({required this.itens});

  final List<SepararItemRequest> itens; // não-vazia

  Map<String, dynamic> toJson() => {
    'itens': itens.map((e) => e.toJson()).toList(),
  };
}

/// Um item na separação (guia §4.3).
/// - `indisponivel = false`: `qtySeparada` obrigatória e `> 0`.
/// - `indisponivel = true`: item sem estoque; `qtySeparada` não se aplica
///   (omitida do corpo).
class SepararItemRequest {
  const SepararItemRequest({
    required this.lineNumber,
    required this.indisponivel,
    this.qtySeparada,
  });

  final int lineNumber; // linha do item no pedido (short no backend)
  final bool indisponivel;
  final num? qtySeparada; // presente só quando disponível

  Map<String, dynamic> toJson() => _stripNulls({
    'lineNumber': lineNumber,
    'qtySeparada': indisponivel ? null : qtySeparada,
    'indisponivel': indisponivel,
  });
}

// ── helpers ──
Map<String, dynamic> _stripNulls(Map<String, dynamic> m) =>
    m..removeWhere((_, v) => v == null);
