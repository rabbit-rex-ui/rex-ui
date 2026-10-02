import 'package:rabbit_pdv/features/pedidos_delivery/domain/momento_pagamento.dart';
import 'package:rabbit_pdv/features/pedidos_delivery/domain/pedido_canal.dart';

/// Corpo de `POST /pdv/pedidos` (guia §4.1). Cria um pedido de delivery no
/// estado inicial RECEBIDO.
///
/// Identidade do operador e tenant vêm do JWT/contexto — nunca do corpo
/// (guia §2). A idempotência é via header `Idempotency-Key`, tratada no
/// repository, não neste DTO.
class CriarPedidoRequest {
  const CriarPedidoRequest({
    required this.canal,
    required this.defaultWarehouseId,
    required this.customerName,
    required this.endereco,
    required this.itens,
    this.customerId,
    this.customerDoc,
    this.customerPhone,
    this.momentoPagamento,
    this.frete,
    this.notes,
  });

  final PedidoCanal canal;
  final String defaultWarehouseId; // UUID do depósito padrão dos itens
  final String customerName; // não-vazio (validado no backend)
  final EnderecoDto endereco;
  final List<ItemPedidoDto> itens; // não-vazia
  final String? customerId; // UUID de cliente cadastrado, se houver
  final String? customerDoc; // CPF/CNPJ
  final String? customerPhone;
  final MomentoPagamento? momentoPagamento; // omitido = NA_ENTREGA (backend)
  final double? frete; // >= 0
  final String? notes;

  Map<String, dynamic> toJson() => _stripNulls({
    'canal': canal.wire,
    'defaultWarehouseId': defaultWarehouseId,
    'customerId': customerId,
    'customerName': customerName,
    'customerDoc': customerDoc,
    'customerPhone': customerPhone,
    'endereco': endereco.toJson(),
    'momentoPagamento': momentoPagamento?.wire,
    'frete': _money(frete),
    'itens': itens.map((e) => e.toJson()).toList(),
    'notes': notes,
  });
}

/// Endereço de entrega (guia §4.1). Apenas `line` é obrigatório.
class EnderecoDto {
  const EnderecoDto({
    required this.line,
    this.number,
    this.complement,
    this.district,
    this.cityIbge,
    this.zip,
  });

  final String line;
  final String? number;
  final String? complement;
  final String? district;
  final String? cityIbge; // código IBGE do município
  final String? zip; // CEP

  Map<String, dynamic> toJson() => _stripNulls({
    'line': line,
    'number': number,
    'complement': complement,
    'district': district,
    'cityIbge': cityIbge,
    'zip': zip,
  });
}

/// Item do pedido na criação (guia §4.1).
class ItemPedidoDto {
  const ItemPedidoDto({
    required this.produtoId,
    required this.quantidade,
    this.warehouseId,
    this.observacao,
  });

  final String produtoId; // UUID
  final num quantidade; // > 0; num suporta venda por peso (kg)
  final String? warehouseId; // usa defaultWarehouseId se ausente
  final String? observacao;

  Map<String, dynamic> toJson() => _stripNulls({
    'produtoId': produtoId,
    'warehouseId': warehouseId,
    'quantidade': quantidade,
    'observacao': observacao,
  });
}

// ── helpers ──
// Dinheiro arredondado a 2 casas no boundary; o backend é a fonte de verdade
// de totais (a criação devolve `valorEstimado` calculado no servidor).
num? _money(double? v) => v == null ? null : double.parse(v.toStringAsFixed(2));

Map<String, dynamic> _stripNulls(Map<String, dynamic> m) =>
    m..removeWhere((_, v) => v == null);
