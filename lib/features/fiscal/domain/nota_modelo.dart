/// Modelo do documento fiscal (guia fiscal §1).
///
/// Cliente com CNPJ → NF-e (55), DANFE em PDF A4. CPF ou sem documento →
/// NFC-e (65), DANFE em HTML para térmica de 80 mm.
enum NotaModelo {
  nfe('NFE', 'NF-e'),
  nfce('NFCE', 'NFC-e');

  const NotaModelo(this.wire, this.label);

  /// Valor de fio trocado com o backend.
  final String wire;

  /// Rótulo para a tela.
  final String label;

  /// Converte o valor do backend. Lança [ArgumentError] em valor desconhecido.
  static NotaModelo fromWire(String value) => values.firstWhere(
    (m) => m.wire == value,
    orElse: () => throw ArgumentError.value(
      value,
      'value',
      'NotaModelo desconhecido vindo do backend',
    ),
  );
}
