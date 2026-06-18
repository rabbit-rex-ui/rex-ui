class RegistrarVendaResponse {
  const RegistrarVendaResponse({
    required this.vendaId,
    required this.saleNumber,
    required this.subtotal,
    required this.discountAmount,
    required this.total,
    required this.paidAmount,
    required this.change,
    required this.finalizedAt,
    this.cashCeilingStatus,
  });

  final String vendaId;
  final int saleNumber;
  final double subtotal;
  final double discountAmount;
  final double total;
  final double paidAmount;
  final double change;
  final DateTime finalizedAt;
  final CashCeilingStatus? cashCeilingStatus;

  factory RegistrarVendaResponse.fromJson(Map<String, dynamic> json) =>
      RegistrarVendaResponse(
        vendaId: json['vendaId'] as String,
        saleNumber: (json['saleNumber'] as num).toInt(),
        subtotal: _money(json['subtotal']),
        discountAmount: _money(json['discountAmount']),
        total: _money(json['total']),
        paidAmount: _money(json['paidAmount']),
        change: _money(json['change']),
        finalizedAt: _date(json['finalizedAt']),
        cashCeilingStatus: CashCeilingStatus.tryParse(
          json['cashCeilingStatus'],
        ),
      );
}

enum NivelTeto { verde, amarelo, vermelho, desconhecido }

class CashCeilingStatus {
  const CashCeilingStatus({
    required this.nivel,
    this.mode,
    this.ceiling,
    this.currentCash,
  });

  final NivelTeto nivel;
  final String? mode; // EXPRESS / IMMEDIATE (string livre — não bloqueia)
  final double? ceiling;
  final double? currentCash;

  /// Exibir indicador a partir do amarelo (decisão de UX, §6.1).
  bool get exibeAlerta =>
      nivel == NivelTeto.amarelo || nivel == NivelTeto.vermelho;

  /// Aceita objeto `{nivel,...}` OU string `"VERDE"` OU null. As fontes
  /// (Swagger vs doc) divergem; toleramos ambos.
  static CashCeilingStatus? tryParse(dynamic v) {
    if (v == null) return null;
    if (v is String) return CashCeilingStatus(nivel: _nivel(v));
    if (v is Map<String, dynamic>) {
      return CashCeilingStatus(
        nivel: _nivel(v['nivel']),
        mode: v['mode'] as String?,
        ceiling: _moneyOrNull(v['ceiling']),
        currentCash: _moneyOrNull(v['currentCash']),
      );
    }
    return null;
  }
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

NivelTeto _nivel(dynamic v) => switch ((v ?? '').toString().toUpperCase()) {
  'VERDE' => NivelTeto.verde,
  'AMARELO' => NivelTeto.amarelo,
  'VERMELHO' => NivelTeto.vermelho,
  _ => NivelTeto.desconhecido,
};
