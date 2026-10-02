import 'package:rabbit_pdv/domain/enums/product_type.dart';

/// Apresentação de unidade de medida para o delivery. Mora em `presentation/`
/// porque rótulo é UI — não é tipo de domínio (o backend orientou: dicionário
/// de apresentação sobre a string crua de `unitOfMeasure`, sem ampliar o enum
/// de domínio nem colapsar valores).
///
/// Isolado do `UnidadeFormatter` (core), que só conhece `un`/`kg` e é usado pela
/// venda — aqui tratamos os 9 valores crus do catálogo real.
class UnidadeUi {
  const UnidadeUi._();

  /// Rótulos curtos dos 9 valores de `unitOfMeasure` do backend (guia §3.3).
  static const Map<String, String> _rotulos = {
    'UN': 'un',
    'KG': 'kg',
    'G': 'g',
    'L': 'L',
    'ML': 'ml',
    'M': 'm',
    'M2': 'm²',
    'CX': 'cx',
    'PCT': 'pct',
  };

  /// Rótulo curto da unidade a partir da string crua do backend
  /// ([Produto.unitOfMeasureRaw]). Valor desconhecido degrada seguro: devolve o
  /// próprio código em minúsculas (ex.: `DZ` → `dz`) — sem erro duro, porque o
  /// cálculo da linha não depende da unidade (é sempre `qtd × preço`).
  static String rotulo(String unitOfMeasureRaw) {
    final raw = unitOfMeasureRaw.trim();
    if (raw.isEmpty) return '';
    return _rotulos[raw.toUpperCase()] ?? raw.toLowerCase();
  }

  /// Passo do stepper de quantidade conforme o modo: pesável/medida usa passo
  /// fino (0.1), contável usa 1.
  static double step(ProductType productType) =>
      productType.isDecimal ? 0.1 : 1.0;

  /// Formata a quantidade conforme o modo + anexa o rótulo da unidade.
  /// Pesável: 3 casas decimais (ex.: `1,500 kg`); contável: inteiro (ex.:
  /// `2 cx`). Vírgula como separador decimal (padrão BR).
  static String formatQtd(
    double qtd,
    String unitOfMeasureRaw,
    ProductType productType,
  ) {
    final n = productType.isDecimal
        ? qtd.toStringAsFixed(3).replaceAll('.', ',')
        : qtd.toStringAsFixed(0);
    final r = rotulo(unitOfMeasureRaw);
    return r.isEmpty ? n : '$n $r';
  }

  /// Só o número formatado conforme o modo, sem rótulo (para campos editáveis
  /// de quantidade, onde o rótulo aparece à parte).
  static String formatNumero(double qtd, ProductType productType) {
    return productType.isDecimal
        ? qtd.toStringAsFixed(3).replaceAll('.', ',')
        : qtd.toStringAsFixed(0);
  }
}
