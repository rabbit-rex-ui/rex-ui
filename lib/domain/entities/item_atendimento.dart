import 'package:equatable/equatable.dart';

import 'package:rabbit_pdv/domain/enums/unidade_medida.dart';
import 'package:rabbit_pdv/domain/entities/produto.dart';

class ItemAtendimento extends Equatable {
  final int id;

  /// UUID do produto no backend. Necessário para registrar a venda (§5.4).
  final String produtoId;

  final String sku;
  final String nome;
  final double qtd;
  final double preco;
  final UnidadeMedida un;
  final double? descontoLinha;
  final String? observacao;

  double get total => (qtd * preco) - (descontoLinha ?? 0);

  const ItemAtendimento({
    required this.id,
    required this.produtoId,
    required this.sku,
    required this.nome,
    required this.qtd,
    required this.preco,
    required this.un,
    this.descontoLinha,
    this.observacao,
  });

  factory ItemAtendimento.fromProduto(
    Produto produto, {
    required int id,
    double? qtdInicial,
  }) {
    final qtd = qtdInicial ?? (produto.un == UnidadeMedida.kg ? 0.5 : 1.0);
    return ItemAtendimento(
      id: id,
      produtoId: produto.id, // ⚠️ confirmar nome do campo em produto.dart
      sku: produto.sku,
      nome: produto.nome,
      qtd: qtd,
      preco: produto.preco,
      un: produto.un,
    );
  }

  ItemAtendimento copyWith({
    double? qtd,
    double? preco,
    double? descontoLinha,
    String? observacao,
  }) {
    return ItemAtendimento(
      id: id,
      produtoId: produtoId,
      sku: sku,
      nome: nome,
      qtd: qtd ?? this.qtd,
      preco: preco ?? this.preco,
      un: un,
      descontoLinha: descontoLinha ?? this.descontoLinha,
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
    descontoLinha,
  ];
}
