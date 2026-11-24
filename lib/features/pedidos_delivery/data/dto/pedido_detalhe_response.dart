import 'package:rabbit_pdv/core/json/json_read.dart';
import 'package:rabbit_pdv/features/fiscal/data/dto/nota_fiscal_resumo.dart';
import 'package:rabbit_pdv/features/pedidos_delivery/domain/momento_pagamento.dart';
import 'package:rabbit_pdv/features/pedidos_delivery/domain/pedido_canal.dart';
import 'package:rabbit_pdv/features/pedidos_delivery/domain/pedido_status.dart';

/// Detalhe completo de um pedido (guia §4.13). Cabeçalho + itens + histórico.
/// É daqui que sai o `momentoPagamento` que decide se o `concluir` (§4.8) exige
/// `formaPagamento`, e o `status` que — com a permissão do operador — define as
/// ações.
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
    this.historico = const [],
    this.metodoPrevisto,
    this.notes,
    this.vendaId,
    this.notaFiscal,
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

  /// Linha do tempo das transições de status (ledger `sls_order_events`),
  /// ordenada cronologicamente pelo servidor. Leitura defensiva: ausente/vazia
  /// → a trilha do detalhe cai na versão visual (v1).
  final List<EventoPedido> historico;

  final String? metodoPrevisto;
  final String? notes;

  /// Venda materializada no faturar (guia fiscal §7, passo 5). `null` antes
  /// do faturamento. É a chave para buscar as notas fiscais do pedido.
  final String? vendaId;

  /// Situação da nota que vale para a venda (guia fiscal v2.2 §7.1). `null`
  /// antes do faturar e por ~1 s depois dele.
  final NotaFiscalResumo? notaFiscal;

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
        frete: JsonRead.decimal(json['frete']),
        valorEstimado: JsonRead.decimal(json['valorEstimado']),
        criadoEm: JsonRead.instant(json['criadoEm']),
        itens: (json['itens'] as List<dynamic>? ?? const [])
            .map((e) => ItemPedidoDetalhe.fromJson(e as Map<String, dynamic>))
            .toList(),
        historico: (json['historico'] as List<dynamic>? ?? const [])
            .map((e) => EventoPedido.fromJson(e as Map<String, dynamic>))
            .whereType<EventoPedido>()
            .toList(),
        metodoPrevisto: json['metodoPrevisto'] as String?,
        notes: json['notes'] as String?,
        vendaId: json['vendaId'] as String?,
        notaFiscal: NotaFiscalResumo.fromPedido(json),
      );
}

/// Um evento da linha do tempo do pedido (uma transição de status no ledger).
///
/// Contrato (array `historico` no detalhe): `status`, `fromStatus`,
/// `occurredAt`, `actorId`, `actorNome`, `motivo`. Os campos [recebidoPor] e
/// [formaPagamento] são extras do payload (nulos até o backend expô-los) e
/// lidos defensivamente — quando vierem, acendem sozinhos nos nós Entregue e
/// Concluído.
class EventoPedido {
  const EventoPedido({
    required this.status,
    required this.occurredAt,
    this.fromStatus,
    this.actorId,
    this.actorNome,
    this.motivo,
    this.recebidoPor,
    this.formaPagamento,
  });

  /// Status para o qual o pedido transicionou (o nó da trilha).
  final PedidoStatus status;

  /// Status de onde o pedido saiu. Em exceções, posiciona o nó na linha.
  final PedidoStatus? fromStatus;

  /// Carimbo autoritativo do servidor (convertido para o fuso local).
  final DateTime occurredAt;

  final String? actorId;
  final String? actorNome;
  final String? motivo;
  final String? recebidoPor; // extra: evento de ENTREGUE
  final String? formaPagamento; // extra: evento de CONCLUIDO

  /// Melhor rótulo do responsável: nome → id → null (UI oculta se null).
  String? get responsavel {
    if (actorNome != null && actorNome!.isNotEmpty) return actorNome;
    if (actorId != null && actorId!.isNotEmpty) return actorId;
    return null;
  }

  /// Parse tolerante: descarta o evento (retorna null) se `status` for
  /// desconhecido ou `occurredAt` ausente/inválido — um evento ruim não deve
  /// derrubar o detalhe inteiro.
  static EventoPedido? fromJson(Map<String, dynamic> json) {
    final status = PedidoStatus.tryFromWire(json['status'] as String?);
    final occ = JsonRead.instantOrNull(json['occurredAt']);
    if (status == null || occ == null) return null;
    return EventoPedido(
      status: status,
      occurredAt: occ,
      fromStatus: PedidoStatus.tryFromWire(json['fromStatus'] as String?),
      actorId: json['actorId'] as String?,
      actorNome: json['actorNome'] as String?,
      motivo: json['motivo'] as String?,
      recebidoPor: json['recebidoPor'] as String?,
      formaPagamento: json['formaPagamento'] as String?,
    );
  }
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
///
/// [produtoNome]/[produtoSku] são a identificação legível do item (adicionados
/// ao contrato). Lidos defensivamente: se ausentes, caem para string vazia — a
/// UI faz fallback (nome → sku → produtoId).
class ItemPedidoDetalhe {
  const ItemPedidoDetalhe({
    required this.lineNumber,
    required this.produtoId,
    required this.produtoNome,
    required this.produtoSku,
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
  final String produtoNome;
  final String produtoSku;
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

  /// Melhor rótulo legível disponível: nome → sku → id (fallback defensivo).
  String get displayNome {
    if (produtoNome.isNotEmpty) return produtoNome;
    if (produtoSku.isNotEmpty) return 'SKU $produtoSku';
    return produtoId;
  }

  factory ItemPedidoDetalhe.fromJson(Map<String, dynamic> json) =>
      ItemPedidoDetalhe(
        lineNumber: (json['lineNumber'] as num).toInt(),
        produtoId: json['produtoId'] as String,
        produtoNome: (json['produtoNome'] as String?) ?? '',
        produtoSku: (json['produtoSku'] as String?) ?? '',
        unitOfMeasure: json['unitOfMeasure'] as String? ?? '',
        isWeighed: json['isWeighed'] as bool? ?? false,
        itemStatus: json['itemStatus'] as String? ?? '',
        qtySolicitada: JsonRead.decimal(json['qtySolicitada']),
        unitPriceSnapshot: JsonRead.decimal(json['unitPriceSnapshot']),
        valorEstimado: JsonRead.decimal(json['valorEstimado']),
        warehouseId: json['warehouseId'] as String?,
        qtySeparada: JsonRead.decimalOrNull(json['qtySeparada']),
        qtyFaturada: JsonRead.decimalOrNull(json['qtyFaturada']),
        notes: json['notes'] as String?,
      );
}
