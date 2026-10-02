/// Canal de origem de um pedido de delivery (guia §6).
enum PedidoCanal {
  pdv('PDV'),
  telefone('TELEFONE'),
  whatsapp('WHATSAPP'),
  balcao('BALCAO'),
  app('APP');

  const PedidoCanal(this.wire);

  /// Valor de fio trocado com o backend (UPPER_SNAKE_CASE).
  final String wire;

  /// Converte o valor recebido do backend no enum correspondente.
  ///
  /// Lança [ArgumentError] em valor desconhecido — divergência de contrato
  /// deve estourar cedo, não virar estado silencioso.
  static PedidoCanal fromWire(String value) => values.firstWhere(
    (c) => c.wire == value,
    orElse: () => throw ArgumentError.value(
      value,
      'value',
      'PedidoCanal desconhecido vindo do backend',
    ),
  );
}

/// Metadados derivados do canal.
extension PedidoCanalX on PedidoCanal {
  /// Rótulo legível em PT-BR para exibição na UI.
  String get label => switch (this) {
    PedidoCanal.pdv => 'PDV',
    PedidoCanal.telefone => 'Telefone',
    PedidoCanal.whatsapp => 'WhatsApp',
    PedidoCanal.balcao => 'Balcão',
    PedidoCanal.app => 'App',
  };
}
