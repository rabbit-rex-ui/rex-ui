/// Momento em que o pedido de delivery é pago (guia §6).
///
/// - [antecipado]: pago na criação/antecipadamente; o `concluir` dispensa
///   `formaPagamento`.
/// - [naEntrega]: COD — pago na entrega; o `concluir` **exige**
///   `formaPagamento` (guia §4.8).
enum MomentoPagamento {
  antecipado('ANTECIPADO'),
  naEntrega('NA_ENTREGA');

  const MomentoPagamento(this.wire);

  /// Valor de fio trocado com o backend (UPPER_SNAKE_CASE).
  final String wire;

  /// Default aplicado pelo backend quando o campo é omitido na criação
  /// (guia §4.1).
  static const MomentoPagamento padrao = MomentoPagamento.naEntrega;

  /// Converte o valor recebido do backend no enum correspondente.
  ///
  /// Lança [ArgumentError] em valor desconhecido — divergência de contrato
  /// deve estourar cedo, não virar estado silencioso.
  static MomentoPagamento fromWire(String value) => values.firstWhere(
    (m) => m.wire == value,
    orElse: () => throw ArgumentError.value(
      value,
      'value',
      'MomentoPagamento desconhecido vindo do backend',
    ),
  );
}

/// Metadados derivados do momento de pagamento.
extension MomentoPagamentoX on MomentoPagamento {
  /// Rótulo legível em PT-BR para exibição na UI.
  String get label => switch (this) {
    MomentoPagamento.antecipado => 'Antecipado',
    MomentoPagamento.naEntrega => 'Na entrega',
  };

  /// Se a conclusão do pedido exige `formaPagamento` (COD). Guia §4.8:
  /// NA_ENTREGA exige; ANTECIPADO dispensa.
  bool get exigeFormaNaConclusao => this == MomentoPagamento.naEntrega;
}
