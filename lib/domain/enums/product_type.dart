/// Tipo de produto do catálogo (backend `productType`). Sinal canônico do
/// **modo de entrada de quantidade**: [weighed] usa quantidade decimal; os
/// demais, inteira.
///
/// O backend garante por constraint que `WEIGHED` só acompanha unidade de
/// medida (KG/G/L/ML/M/M2). Puro domínio: sem dependência de Flutter.
enum ProductType {
  physical('PHYSICAL'),
  weighed('WEIGHED'),
  service('SERVICE');

  const ProductType(this.wire);

  /// Valor de fio trocado com o backend (UPPER_SNAKE_CASE).
  final String wire;

  /// Default aplicado quando o campo é ausente/desconhecido: trata como
  /// contável ([physical]) — degrada seguro (quantidade inteira), sem estourar.
  static ProductType fromWire(String? value) => values.firstWhere(
    (t) => t.wire == value,
    orElse: () => ProductType.physical,
  );

  /// Quantidade decimal ⟺ vendido por peso/medida (guia §3.1).
  bool get isDecimal => this == ProductType.weighed;
}
