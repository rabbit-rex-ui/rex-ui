import 'package:rabbit_pdv/features/pedidos_delivery/domain/pedido_status.dart';

/// Resposta de `POST /pdv/pedidos/{id}/faturar` (guia fiscal v2.2 §7, passo
/// 4) — era 204 sem corpo até a v2.0.
///
/// O `notaId` não vem de propósito: a emissão é disparada depois que o
/// faturamento é gravado, então a nota pode ainda não existir. Com o
/// [vendaId], busque as notas em `GET /fis/notas?vendaId=`.
class FaturarPedidoResponse {
  const FaturarPedidoResponse({
    required this.pedidoId,
    required this.vendaId,
    required this.status,
  });

  final String pedidoId;
  final String vendaId;
  final PedidoStatus status;

  factory FaturarPedidoResponse.fromJson(Map<String, dynamic> json) =>
      FaturarPedidoResponse(
        pedidoId: json['pedidoId'] as String,
        vendaId: json['vendaId'] as String,
        status: PedidoStatus.fromWire(json['status'] as String),
      );
}
