import 'package:rabbit_pdv/core/json/json_read.dart';
import 'package:rabbit_pdv/features/pedidos_delivery/domain/pedido_status.dart';

/// Resposta de `POST /pdv/pedidos` (guia §4.1). Vale tanto para criação nova
/// (201) quanto para replay idempotente (200) — o corpo é o mesmo.
class CriarPedidoResponse {
  const CriarPedidoResponse({
    required this.pedidoId,
    required this.orderNumber,
    required this.status,
    required this.valorEstimado,
    required this.criadoEm,
  });

  final String pedidoId; // UUID
  final int orderNumber; // número sequencial legível do pedido
  final PedidoStatus status; // RECEBIDO na criação
  final double valorEstimado; // calculado no servidor (fonte de verdade)
  final DateTime criadoEm;

  factory CriarPedidoResponse.fromJson(Map<String, dynamic> json) =>
      CriarPedidoResponse(
        pedidoId: json['pedidoId'] as String,
        orderNumber: (json['orderNumber'] as num).toInt(),
        status: PedidoStatus.fromWire(json['status'] as String),
        valorEstimado: JsonRead.decimal(json['valorEstimado']),
        criadoEm: JsonRead.instant(json['criadoEm']),
      );
}
