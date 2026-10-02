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
  });

  final String pedidoId; // UUID
  final int orderNumber;
  final PedidoStatus status;
  final PedidoCanal canal;
  final String customerName;
  final double valorEstimado;
  final DateTime criadoEm;

  factory PedidoResumoResponse.fromJson(Map<String, dynamic> json) =>
      PedidoResumoResponse(
        pedidoId: json['pedidoId'] as String,
        orderNumber: (json['orderNumber'] as num).toInt(),
        status: PedidoStatus.fromWire(json['status'] as String),
        canal: PedidoCanal.fromWire(json['canal'] as String),
        customerName: json['customerName'] as String? ?? '',
        valorEstimado: _money(json['valorEstimado']),
        criadoEm: _date(json['criadoEm']),
      );
}

/// Envelope de paginação do backend (guia §4.12): `conteudo` + metadados.
///
/// Genérico e reusável. Não há um envelope de paginação em `core` hoje; se
/// outra feature passar a paginar, promover esta classe para `core` em vez de
/// duplicá-la.
class PaginaResponse<T> {
  const PaginaResponse({
    required this.conteudo,
    required this.pagina,
    required this.tamanho,
    required this.total,
  });

  final List<T> conteudo;
  final int pagina;
  final int tamanho;
  final int total;

  factory PaginaResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) itemFromJson,
  ) => PaginaResponse(
    conteudo: (json['conteudo'] as List<dynamic>? ?? const [])
        .map((e) => itemFromJson(e as Map<String, dynamic>))
        .toList(),
    pagina: (json['pagina'] as num?)?.toInt() ?? 0,
    tamanho: (json['tamanho'] as num?)?.toInt() ?? 0,
    total: (json['total'] as num?)?.toInt() ?? 0,
  );
}

// ── helpers ──
double _money(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

DateTime _date(dynamic v) => DateTime.parse(v as String).toLocal();
