/// Estado de vida de um pedido de delivery, espelhando a máquina de estados
/// do backend (módulo `sales`, `/pdv/pedidos`).
///
/// Caminho feliz:
/// ```
/// RECEBIDO → (CONFIRMANDO) → SEPARANDO → CONFERIDO → AGUARDANDO_EXPEDICAO
///          → EM_ROTA → ENTREGUE → CONCLUIDO
/// ```
/// Ramos de exceção: NAO_ENTREGUE, PAGAMENTO_RECUSADO, DEVOLVIDO, CANCELADO.
enum PedidoStatus {
  recebido('RECEBIDO'),
  confirmando('CONFIRMANDO'),
  separando('SEPARANDO'),
  conferido('CONFERIDO'),
  aguardandoExpedicao('AGUARDANDO_EXPEDICAO'),
  emRota('EM_ROTA'),
  entregue('ENTREGUE'),
  concluido('CONCLUIDO'),
  cancelado('CANCELADO'),
  naoEntregue('NAO_ENTREGUE'),
  devolvido('DEVOLVIDO'),
  pagamentoRecusado('PAGAMENTO_RECUSADO');

  const PedidoStatus(this.wire);

  /// Valor de fio trocado com o backend (UPPER_SNAKE_CASE).
  final String wire;

  /// Converte o valor recebido do backend no enum correspondente.
  ///
  /// Lança [ArgumentError] em valor desconhecido — divergência de contrato
  /// deve estourar cedo, não virar estado silencioso.
  static PedidoStatus fromWire(String value) => values.firstWhere(
    (s) => s.wire == value,
    orElse: () => throw ArgumentError.value(
      value,
      'value',
      'PedidoStatus desconhecido vindo do backend',
    ),
  );
}

/// Metadados derivados do status. Vivem perto do enum porque são informação
/// intrínseca do estado (não dependem de tema nem de tela).
extension PedidoStatusX on PedidoStatus {
  /// Rótulo legível em PT-BR para exibição na UI.
  String get label => switch (this) {
    PedidoStatus.recebido => 'Recebido',
    PedidoStatus.confirmando => 'Confirmando',
    PedidoStatus.separando => 'Separando',
    PedidoStatus.conferido => 'Conferido',
    PedidoStatus.aguardandoExpedicao => 'Aguardando expedição',
    PedidoStatus.emRota => 'Em rota',
    PedidoStatus.entregue => 'Entregue',
    PedidoStatus.concluido => 'Concluído',
    PedidoStatus.cancelado => 'Cancelado',
    PedidoStatus.naoEntregue => 'Não entregue',
    PedidoStatus.devolvido => 'Devolvido',
    PedidoStatus.pagamentoRecusado => 'Pagamento recusado',
  };

  /// Estado terminal: não há transição seguinte (guia §3).
  bool get isTerminal =>
      this == PedidoStatus.concluido ||
      this == PedidoStatus.cancelado ||
      this == PedidoStatus.devolvido;
}
