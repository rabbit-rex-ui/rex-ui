import 'package:rabbit_pdv/features/pedidos_delivery/domain/momento_pagamento.dart';
import 'package:rabbit_pdv/features/pedidos_delivery/domain/pedido_canal.dart';
import 'package:rabbit_pdv/features/pedidos_delivery/domain/pedido_status.dart';

/// Detalhe completo de um pedido (guia §4.13). Cabeçalho + itens. É daqui que
/// sai o `momentoPagamento` que decide se o `concluir` exige `formaPagamento`
/// (§4.8), e o `status` que — com a permissão do operador — define as ações.
class PedidoDetalheResponse {
  const PedidoDetalheResponse({
    required this.pedidoId,
    required this.orderNumber,
    required this.status,
    required this.canal,
    required this.cliente,
    required this.endereco,
    required this.momentoPagamento,
    required this.frete,
    required this.valorEstimado,
    required this.criadoEm,
    required this.itens,
    this.metodoPrevisto,
    this.notes,
  });

  final String pedidoId;
  final int orderNumber;
  final PedidoStatus status;
  final PedidoCanal canal;
  final ClienteDetalhe cliente;
  final EnderecoDetalhe endereco;
  final MomentoPagamento momentoPagamento;
  final double frete;
  final double valorEstimado;
  final DateTime criadoEm;
  final List<ItemPedidoDetalhe> itens;
  final String? metodoPrevisto;
  final String? notes;

  factory PedidoDetalheResponse.fromJson(Map<String, dynamic> json) =>
      PedidoDetalheResponse(
        pedidoId: json['pedidoId'] as String,
        orderNumber: (json['orderNumber'] as num).toInt(),
        status: PedidoStatus.fromWire(json['status'] as String),
        canal: PedidoCanal.fromWire(json['canal'] as String),
        cliente: ClienteDetalhe.fromJson(
          json['cliente'] as Map<String, dynamic>? ?? const {},
        ),
        endereco: EnderecoDetalhe.fromJson(
          json['endereco'] as Map<String, dynamic>? ?? const {},
        ),
        momentoPagamento: MomentoPagamento.fromWire(
          json['momentoPagamento'] as String,
        ),
        frete: _money(json['frete']),
        valorEstimado: _money(json['valorEstimado']),
        criadoEm: _date(json['criadoEm']),
        itens: (json['itens'] as List<dynamic>? ?? const [])
            .map((e) => ItemPedidoDetalhe.fromJson(e as Map<String, dynamic>))
            .toList(),
        metodoPrevisto: json['metodoPrevisto'] as String?,
        notes: json['notes'] as String?,
      );
}

/// Dados do cliente no detalhe (guia §4.13). Todos opcionais — o pedido pode
/// ter só o nome, sem cadastro/documento.
class ClienteDetalhe {
  const ClienteDetalhe({this.id, this.doc, this.nome, this.telefone});

  final String? id;
  final String? doc;
  final String? nome;
  final String? telefone;

  factory ClienteDetalhe.fromJson(Map<String, dynamic> json) => ClienteDetalhe(
    id: json['id'] as String?,
    doc: json['doc'] as String?,
    nome: json['nome'] as String?,
    telefone: json['telefone'] as String?,
  );
}

/// Endereço de entrega no detalhe (guia §4.13). Só leitura — separado do
/// `EnderecoDto` (request), que é só escrita.
class EnderecoDetalhe {
  const EnderecoDetalhe({
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
  final String? cityIbge;
  final String? zip;

  factory EnderecoDetalhe.fromJson(Map<String, dynamic> json) =>
      EnderecoDetalhe(
        line: json['line'] as String? ?? '',
        number: json['number'] as String?,
        complement: json['complement'] as String?,
        district: json['district'] as String?,
        cityIbge: json['cityIbge'] as String?,
        zip: json['zip'] as String?,
      );
}

/// Item no detalhe do pedido (guia §4.13). Além do produto e quantidades por
/// etapa, carrega o `itemStatus` e o snapshot de preço da estimativa.
class ItemPedidoDetalhe {
  const ItemPedidoDetalhe({
    required this.lineNumber,
    required this.produtoId,
    required this.unitOfMeasure,
    required this.isWeighed,
    required this.itemStatus,
    required this.qtySolicitada,
    required this.unitPriceSnapshot,
    required this.valorEstimado,
    this.warehouseId,
    this.qtySeparada,
    this.qtyFaturada,
    this.notes,
  });

  final int lineNumber;
  final String produtoId;
  final String unitOfMeasure; // valor de fio cru (ex.: "UN"/"KG")
  final bool isWeighed;
  final String itemStatus; // status por item (sem enum fechado no contrato)
  final double qtySolicitada;
  final double unitPriceSnapshot;
  final double valorEstimado;
  final String? warehouseId;
  final double? qtySeparada; // null = ainda não separado
  final double? qtyFaturada; // null = ainda não faturado
  final String? notes;

  factory ItemPedidoDetalhe.fromJson(Map<String, dynamic> json) =>
      ItemPedidoDetalhe(
        lineNumber: (json['lineNumber'] as num).toInt(),
        produtoId: json['produtoId'] as String,
        unitOfMeasure: json['unitOfMeasure'] as String? ?? '',
        isWeighed: json['isWeighed'] as bool? ?? false,
        itemStatus: json['itemStatus'] as String? ?? '',
        qtySolicitada: _money(json['qtySolicitada']),
        unitPriceSnapshot: _money(json['unitPriceSnapshot']),
        valorEstimado: _money(json['valorEstimado']),
        warehouseId: json['warehouseId'] as String?,
        qtySeparada: _moneyOrNull(json['qtySeparada']),
        qtyFaturada: _moneyOrNull(json['qtyFaturada']),
        notes: json['notes'] as String?,
      );
}

// ── helpers ──
double _money(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

double? _moneyOrNull(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

DateTime _date(dynamic v) => DateTime.parse(v as String).toLocal();
