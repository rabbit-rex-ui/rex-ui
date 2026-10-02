import 'package:rabbit_pdv/domain/entities/produto.dart';
import 'package:rabbit_pdv/domain/enums/product_type.dart';
import 'package:rabbit_pdv/domain/enums/unidade_medida.dart';

/// Mapeia a resposta de `GET /catalog/produtos?q=` (busca textual) para o
/// domínio [Produto]. É uma **projeção diferente** da do `?sku=`: traz `brand`
/// e `productType` a mais e **não** traz `categoryPath` (D1b). Por isso tem
/// mapper próprio — não reusa `produtoFromCatalogJson` (da venda), para não
/// tocar aquele fluxo em produção.
///
/// A resposta é uma **lista pura** (sem envelope de paginação).
List<Produto> catalogBuscaListFromJson(List<dynamic> data) {
  return data
      .whereType<Map<String, dynamic>>()
      .map(_produtoFromBuscaJson)
      .toList();
}

Produto _produtoFromBuscaJson(Map<String, dynamic> j) {
  final productType = ProductType.fromWire(j['productType'] as String?);
  final sku = (j['sku'] as String?) ?? '';
  return Produto(
    id: j['id'] as String,
    sku: sku,
    barcode: sku, // busca não traz barcode separado; reusa o sku (§4.1)
    nome: (j['name'] as String?) ?? 'Produto',
    categoria: '', // projeção da busca não traz categoryPath (D1b)
    preco: _d(j['currentPrice']),
    un: productType.isDecimal ? UnidadeMedida.kg : UnidadeMedida.un,
    unitOfMeasureRaw: (j['unitOfMeasure'] as String?) ?? '',
    productType: productType,
    ativo: (j['active'] as bool?) ?? true,
  );
}

double _d(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}
