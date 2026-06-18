import 'package:rabbit_pdv/domain/entities/produto.dart';
import 'package:rabbit_pdv/domain/enums/unidade_medida.dart';

/// Mapeia a resposta de /catalog/produtos (Swagger) para o domínio Produto.
/// O campo central é `id` (UUID) — é ele que a venda manda como `produtoId`.
Produto produtoFromCatalogJson(Map<String, dynamic> j) {
  return Produto(
    id: j['id'] as String,
    sku: (j['sku'] as String?) ?? '',
    barcode:
        (j['sku'] as String?) ?? '', // catálogo não traz barcode; usa o sku
    nome: (j['name'] as String?) ?? 'Produto',
    categoria: (j['categoryPath'] as String?) ?? '',
    preco: _d(j['currentPrice']),
    un: _un(j['unitOfMeasure'] as String?),
    estoque: 0, // resposta não traz estoque atual
    ativo: (j['active'] as bool?) ?? true,
  );
}

double _d(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

/// ⚠️ Confirme os valores reais de `unitOfMeasure` do backend.
/// "KG" → pesável; qualquer outro → unitário.
UnidadeMedida _un(String? s) {
  final v = (s ?? '').toUpperCase();
  if (v == 'KG' || v == 'KGM' || v.contains('KILO')) return UnidadeMedida.kg;
  return UnidadeMedida.un;
}
