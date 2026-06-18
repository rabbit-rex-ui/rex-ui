import 'package:equatable/equatable.dart';

import 'package:rabbit_pdv/domain/enums/unidade_medida.dart';

/// Produto do catálogo. Vem do backend, cacheado no banco local.
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
  ];
}
