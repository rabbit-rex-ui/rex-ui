import 'package:equatable/equatable.dart';

import 'package:rabbit_pdv/domain/entities/produto.dart';
import 'package:rabbit_pdv/domain/enums/product_type.dart';
import 'package:rabbit_pdv/domain/enums/unidade_medida.dart';

/// Uma linha do carrinho enquanto o operador monta um pedido de delivery.
///
/// Espelha o formato de `ItemAtendimento` da venda (produto + quantidade para
/// exibição), mas é próprio do delivery para não arrastar campos específicos
/// da venda (desconto de linha, mapper de venda). Carrega o suficiente para a
/// UI mostrar nome/preço/subtotal e o **rótulo real da unidade** + o **modo de
/// entrada** (decimal ⟺ [ProductType.weighed]); o mapeamento para o DTO de fio
/// (`ItemPedidoDto` — só `produtoId`/`quantidade`/`observacao`) fica na camada
/// de dados, não aqui.
///
/// Sobre unidade: [un] ([UnidadeMedida], `un`/`kg`) é o modo legado;
/// [unitOfMeasureRaw] (`UN`/`CX`/`L`/…) é a base do rótulo real; [productType]
/// é o sinal canônico do modo de entrada. A UI prefere os dois últimos.
class ItemPedidoCart extends Equatable {
  final int id;
  final String produtoId;
  final String sku;
  final String nome;
  final double qtd;
  final double preco;
  final UnidadeMedida un;
  final String unitOfMeasureRaw;
  final ProductType productType;
  final String? observacao;

  /// Subtotal estimado da linha. Estimativa de UI; o backend recalcula o
  /// `valorEstimado` oficial na criação (§4.1). Invariante do backend: o total
  /// é sempre `qtd × preco`, qualquer que seja a unidade.
  double get subtotal => qtd * preco;

  const ItemPedidoCart({
    required this.id,
    required this.produtoId,
    required this.sku,
    required this.nome,
    required this.qtd,
    required this.preco,
    required this.un,
    this.unitOfMeasureRaw = '',
    this.productType = ProductType.physical,
    this.observacao,
  });

  /// Cria a linha a partir de um produto do catálogo. Quantidade inicial segue
  /// o modo de entrada: 0.5 para pesável (decimal), 1.0 para contável.
  factory ItemPedidoCart.fromProduto(
    Produto produto, {
    required int id,
    double? qtdInicial,
  }) {
    final qtd = qtdInicial ?? (produto.productType.isDecimal ? 0.5 : 1.0);
    return ItemPedidoCart(
      id: id,
      produtoId: produto.id,
      sku: produto.sku,
      nome: produto.nome,
      qtd: qtd,
      preco: produto.preco,
      un: produto.un,
      unitOfMeasureRaw: produto.unitOfMeasureRaw,
      productType: produto.productType,
    );
  }

  ItemPedidoCart copyWith({double? qtd, String? observacao}) {
    return ItemPedidoCart(
      id: id,
      produtoId: produtoId,
      sku: sku,
      nome: nome,
      qtd: qtd ?? this.qtd,
      preco: preco,
      un: un,
      unitOfMeasureRaw: unitOfMeasureRaw,
      productType: productType,
      observacao: observacao ?? this.observacao,
    );
  }

  @override
  List<Object?> get props => [
    id,
    produtoId,
    sku,
    nome,
    qtd,
    preco,
    un,
    unitOfMeasureRaw,
    productType,
    observacao,
  ];
}
