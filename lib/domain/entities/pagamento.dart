import 'package:equatable/equatable.dart';

import 'package:rabbit_pdv/domain/enums/metodo_pagamento.dart';

/// Uma forma de pagamento processada dentro de uma venda. Pode haver
/// múltiplos por atendimento (pagamento misto), mas no MVP atual há um
/// por venda.
///
/// Imutável. Criada pelo modal de pagamento e enviada ao backend via
/// outbox de sincronização.
class Pagamento extends Equatable {
  final String id;
  final MetodoPagamento metodo;

  /// Valor cobrado nesta forma. Sempre positivo.
  final double valor;

  /// Quando dinheiro: valor que o operador efetivamente recebeu (notas
  /// e moedas). `null` para outros métodos.
  final double? valorRecebido;

  /// Troco devolvido ao cliente em espécie. `null` ou `0` para não-dinheiro.
  /// Sempre `valorRecebido - valor` quando aplicável.
  final double? troco;

  /// Bandeira do cartão (Visa, Master, Elo…). Preenchido pelo TEF.
  /// `null` enquanto não há integração.
  final String? bandeira;

  /// Identificador de transação retornado pelo TEF / PSP.
  final String? nsu;

  final DateTime processadoEm;

  const Pagamento({
    required this.id,
    required this.metodo,
    required this.valor,
    required this.processadoEm,
    this.valorRecebido,
    this.troco,
    this.bandeira,
    this.nsu,
  });

  @override
  List<Object?> get props =>
      [id, metodo, valor, valorRecebido, troco, bandeira, nsu, processadoEm];
}
