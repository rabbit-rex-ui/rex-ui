class AbrirCaixaRequest {
  const AbrirCaixaRequest({
    required this.cashRegisterId,
    required this.openedBy,
    required this.openingFloat,
  });
  final String cashRegisterId;
  final String openedBy;
  final double openingFloat;

  Map<String, dynamic> toJson() => {
    'cashRegisterId': cashRegisterId,
    'openedBy': openedBy,
    'openingFloat': double.parse(openingFloat.toStringAsFixed(2)),
  };
}

class CaixaSessionResponse {
  const CaixaSessionResponse({
    required this.id,
    required this.cashRegisterId,
    required this.status,
    required this.openedAt,
    required this.openingFloat,
    required this.expectedCash,
    this.openedBy,
    this.currentCustodianId,
    this.salesCashTotal = 0,
    this.reinforcementsTotal = 0,
    this.withdrawalsTotal = 0,
    this.blindClose = false,
  });

  final String id;
  final String cashRegisterId;
  final String status;
  final DateTime openedAt;
  final double openingFloat;
  final double expectedCash;
  final String? openedBy;

  /// Custodiante corrente (contrato §6.2): último `assumed_by`, ou `openedBy`
  /// se nunca houve posse. É ESTE — não `openedBy` — que decide Desbloquear vs
  /// Assumir. Pode vir null em backends antigos; tratamos como "sem posse".
  final String? currentCustodianId;

  final double salesCashTotal;
  final double reinforcementsTotal;
  final double withdrawalsTotal;
  final bool blindClose;

  bool get isOpen => status.toUpperCase() == 'OPEN';

  /// Quem está no comando agora: o custodiante corrente, com fallback no abridor.
  String? get custodianEfetivo => currentCustodianId ?? openedBy;

  factory CaixaSessionResponse.fromJson(Map<String, dynamic> j) =>
      CaixaSessionResponse(
        id: j['id'] as String,
        cashRegisterId: (j['cashRegisterId'] as String?) ?? '',
        status: (j['status'] as String?) ?? 'UNKNOWN',
        openedAt: DateTime.parse(j['openedAt'] as String).toLocal(),
        openingFloat: _d(j['openingFloat']),
        expectedCash: _d(j['expectedCash']),
        openedBy: j['openedBy'] as String?,
        currentCustodianId: j['currentCustodianId'] as String?,
        salesCashTotal: _d(j['salesCashTotal']),
        reinforcementsTotal: _d(j['reinforcementsTotal']),
        withdrawalsTotal: _d(j['withdrawalsTotal']),
        blindClose: (j['blindClose'] as bool?) ?? false,
      );
}

double _d(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}
