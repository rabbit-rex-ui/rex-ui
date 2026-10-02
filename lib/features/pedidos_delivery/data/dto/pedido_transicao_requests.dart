// Corpos das transições de pedido de delivery que exigem dados (guia §4).
// Cada um é só escrita (`toJson`). Os corpos pequenos ficam reunidos aqui; a
// separação (lista de itens, §4.3) terá arquivo próprio.

/// Corpo de `POST /{id}/entregar` (guia §4.7). `recebidoPor` é a prova de
/// entrega — quem recebeu — e é obrigatório.
class EntregarPedidoRequest {
  const EntregarPedidoRequest({required this.recebidoPor});

  final String recebidoPor;

  Map<String, dynamic> toJson() => {'recebidoPor': recebidoPor};
}

/// Corpo de `POST /{id}/concluir` (guia §4.8). Enviado apenas quando há forma
/// de pagamento a registrar:
/// - NA_ENTREGA (COD): `formaPagamento` obrigatória → instancie esta classe.
/// - ANTECIPADO: corpo omitido → passe `null` como request ao repositório.
class ConcluirPedidoRequest {
  const ConcluirPedidoRequest({required this.formaPagamento});

  final String formaPagamento;

  Map<String, dynamic> toJson() => {'formaPagamento': formaPagamento};
}
