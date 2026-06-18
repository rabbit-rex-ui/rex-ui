/// Estado de vida de um [Atendimento].
///
/// Transições normais:
/// ```
/// digitando ⇄ aguardando
///   ↓
/// pronto → pago
///   ↓
/// cancelado
/// ```
enum AtendimentoStatus {
  /// Aba ativa onde o operador adiciona itens. Apenas UM por vez.
  digitando,

  /// Pausado/suspenso. Operador atendendo outro cliente.
  aguardando,

  /// Fechado, aguardando pagamento (modal aberto ou voltado).
  pronto,

  /// Finalizado com sucesso. Sai da lista de abertos.
  pago,

  /// Cancelado. Sai da lista.
  cancelado,
}
