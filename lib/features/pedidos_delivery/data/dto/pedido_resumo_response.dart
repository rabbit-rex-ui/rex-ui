import 'package:rabbit_pdv/core/json/json_read.dart';
import 'package:rabbit_pdv/features/fiscal/data/dto/nota_fiscal_resumo.dart';
import 'package:rabbit_pdv/features/pedidos_delivery/domain/pedido_canal.dart';
import 'package:rabbit_pdv/features/pedidos_delivery/domain/pedido_status.dart';

/// Item da fila de pedidos (guia §4.12). Resumo exibido na listagem por status
/// (ex.: SEPARANDO = fila de separação, EM_ROTA = fila de entrega).
class PedidoResumoResponse {
  const PedidoResumoResponse({
    required this.pedidoId,
    required this.orderNumber,
    required this.status,
    required this.canal,
    required this.customerName,
    required this.valorEstimado,
    required this.criadoEm,
    this.vendaId,
    this.notaFiscal,
  });

  final String pedidoId; // UUID
  final int orderNumber;
  final PedidoStatus status;
  final PedidoCanal canal;
  final String customerName;
  final double valorEstimado;
  final DateTime criadoEm;

  /// Preenchidos depois do faturar (guia fiscal v2.2 §7.1): a fila de
  /// expedição decide imprimir/expedir sem consultar nota por nota.
  final String? vendaId;
  final NotaFiscalResumo? notaFiscal;

  factory PedidoResumoResponse.fromJson(Map<String, dynamic> json) =>
      PedidoResumoResponse(
        pedidoId: json['pedidoId'] as String,
        orderNumber: (json['orderNumber'] as num).toInt(),
        status: PedidoStatus.fromWire(json['status'] as String),
        canal: PedidoCanal.fromWire(json['canal'] as String),
        customerName: json['customerName'] as String? ?? '',
        valorEstimado: JsonRead.decimal(json['valorEstimado']),
        criadoEm: JsonRead.instant(json['criadoEm']),
        vendaId: json['vendaId'] as String?,
        notaFiscal: NotaFiscalResumo.fromPedido(json),
      );
}
