import 'package:equatable/equatable.dart';

import 'package:rabbit_pdv/domain/enums/product_type.dart';
import 'package:rabbit_pdv/domain/enums/unidade_medida.dart';

/// Produto do catálogo. Vem do backend, cacheado no banco local.
///
/// Sobre unidade, há três campos que coexistem — de propósito:
/// - [un] ([UnidadeMedida], `un`/`kg`): modo de entrada legado (contável ×
///   decimal), usado pela venda de caixa. Mantido para não mexer em produção.
/// - [unitOfMeasureRaw] (string crua do backend: `UN`/`KG`/`G`/`L`/`ML`/`M`/
///   `M2`/`CX`/`PCT`): base do **rótulo real** exibido (via mapa de
///   apresentação). `''` quando desconhecido/ausente.
/// - [productType]: sinal canônico do **modo de entrada** (decimal ⟺
///   `WEIGHED`), mais confiável que inferir pela unidade.
class Produto extends Equatable {
  /// UUID do produto no backend. É o que a venda envia como `produtoId` (§5.4).
  /// Preenchido pelo catálogo real; no mock, use um valor estável por produto.
  final String id;

  /// EAN-13 ou código interno.
  final String sku;
  final String barcode;
  final String nome;
  final String categoria;
  final double preco;
  final UnidadeMedida un;
  final int estoque;
  final String? imageUrl;
  final bool ativo;

  /// Unidade de medida crua do backend (`UN`, `KG`, `CX`, `L`, …). Base do
  /// rótulo real; `''` quando ausente. Não confundir com [un] (modo de entrada).
  final String unitOfMeasureRaw;

  /// Tipo de produto do backend. Decide o modo de entrada (decimal ⟺
  /// [ProductType.weighed]).
  final ProductType productType;

  bool get temPreco => preco > 0;

  const Produto({
    required this.id,
    required this.sku,
    required this.barcode,
    required this.nome,
    required this.categoria,
    required this.preco,
    required this.un,
    this.estoque = 0,
    this.imageUrl,
    this.ativo = true,
    this.unitOfMeasureRaw = '',
    this.productType = ProductType.physical,
  });

  @override
  List<Object?> get props => [
    id,
    sku,
    barcode,
    nome,
    categoria,
    preco,
    un,
    estoque,
    ativo,
    unitOfMeasureRaw,
    productType,
  ];
}
