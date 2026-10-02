/// Corpo `{ motivo }` compartilhado pelas transições de exceção do pedido
/// (guia §4.9 nao-entregue, §4.10 pagamento-recusado, §4.11 devolver,
/// §4.14 cancelar). Só escrita.
///
/// `motivo` é obrigatório em cancelar/nao-entregue/devolver; para
/// pagamento-recusado o corpo é opcional — nesse caso, passe `null` como
/// request ao repositório em vez de instanciar esta classe.
class MotivoPedidoRequest {
  const MotivoPedidoRequest({required this.motivo});

  final String motivo;

  Map<String, dynamic> toJson() => {'motivo': motivo};
}
