import 'package:equatable/equatable.dart';

/// Motivo da tomada de posse (custódia A→B).
enum CxTakeoverReason {
  suddenAbsence,
  shiftHandoverEmergency,
  operatorIncapacitated,
  other,
}

extension CxTakeoverReasonApi on CxTakeoverReason {
  String get apiValue => switch (this) {
    CxTakeoverReason.suddenAbsence => 'SUDDEN_ABSENCE',
    CxTakeoverReason.shiftHandoverEmergency => 'SHIFT_HANDOVER_EMERGENCY',
    CxTakeoverReason.operatorIncapacitated => 'OPERATOR_INCAPACITATED',
    CxTakeoverReason.other => 'OTHER',
  };

  String get label => switch (this) {
    CxTakeoverReason.suddenAbsence => 'Ausência súbita',
    CxTakeoverReason.shiftHandoverEmergency => 'Troca de turno (emergência)',
    CxTakeoverReason.operatorIncapacitated => 'Operador incapacitado',
    CxTakeoverReason.other => 'Outro',
  };
}

/// Corpo do POST /pdv/caixas/{cashSessionId}/assumir.
///
/// Regras condicionais (revalidadas no servidor — contrato §5/§8):
/// - [reasonNote] obrigatório quando [reason] == other.
/// - [countedCash] obrigatório quando [cashVerified]; deve ser nulo caso contrário.
/// - [cartRef] obrigatório quando [cartPreserved].
/// - [justificationNote] só é exigido pelo servidor (422) quando a divergência
///   excede o limiar do caixa; o frontend não conhece o limiar.
class AssumirCaixaRequest extends Equatable {
  const AssumirCaixaRequest({
    required this.eventId,
    required this.reason,
    required this.cashVerified,
    required this.cartPreserved,
    this.reasonNote,
    this.countedCash,
    this.justificationNote,
    this.cartRef,
    this.clientReportedAt,
  });

  /// UUIDv7 do cliente — um por tentativa; reusado no retry (idempotência → 200).
  final String eventId;
  final CxTakeoverReason reason;
  final bool cashVerified;
  final bool cartPreserved;

  final String? reasonNote;
  final double? countedCash;
  final String? justificationNote;
  final String? cartRef;
  final DateTime? clientReportedAt;

  /// Retry da MESMA posse após 422 de divergência: mantém [eventId] e só
  /// acrescenta a justificativa (nada foi gravado ainda no servidor).
  AssumirCaixaRequest comJustificativa(String note) => AssumirCaixaRequest(
    eventId: eventId,
    reason: reason,
    cashVerified: cashVerified,
    cartPreserved: cartPreserved,
    reasonNote: reasonNote,
    countedCash: countedCash,
    justificationNote: note,
    cartRef: cartRef,
    clientReportedAt: clientReportedAt,
  );

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'eventId': eventId,
      'reasonCategory': reason.apiValue,
      'cashVerified': cashVerified,
      'cartPreserved': cartPreserved,
    };
    // Omitimos nulos: countedCash NÃO pode ir quando cashVerified=false (400).
    if (reasonNote != null) map['reasonNote'] = reasonNote;
    if (countedCash != null) map['countedCash'] = countedCash;
    if (justificationNote != null) map['justificationNote'] = justificationNote;
    if (cartRef != null) map['cartRef'] = cartRef;
    if (clientReportedAt != null) {
      map['clientReportedAt'] = clientReportedAt!.toUtc().toIso8601String();
    }
    return map;
  }

  @override
  List<Object?> get props => [
    eventId,
    reason,
    cashVerified,
    cartPreserved,
    reasonNote,
    countedCash,
    justificationNote,
    cartRef,
    clientReportedAt,
  ];
}

/// Resposta 201/200 do POST .../assumir.
///
/// Convenção Jackson — null OMITIDO: quando [cashVerified] == false,
/// `countedCash` e `cashVariance` NÃO vêm no JSON. Tratados como
/// chave-ausente = null (não assumimos que toda chave existe).
class AssumirCaixaResponse extends Equatable {
  const AssumirCaixaResponse({
    required this.id,
    required this.eventId,
    required this.cashSessionId,
    required this.relievedEmployeeId,
    required this.assumedByEmployeeId,
    required this.assumedAt,
    required this.cashVerified,
    required this.expectedCashSnapshot,
    required this.idempotent,
    this.countedCash,
    this.cashVariance,
  });

  final String id;
  final String eventId;
  final String cashSessionId;
  final String relievedEmployeeId; // A (derivado no servidor)
  final String assumedByEmployeeId; // B
  final DateTime assumedAt; // autoritativo (servidor)
  final bool cashVerified;
  final double expectedCashSnapshot; // sempre presente
  final bool idempotent; // true = replay do eventId

  /// Presentes só quando [cashVerified] == true (senão chave ausente => null).
  final double? countedCash;
  final double? cashVariance; // countedCash − expectedCashSnapshot

  factory AssumirCaixaResponse.fromJson(Map<String, dynamic> j) {
    return AssumirCaixaResponse(
      id: j['id'] as String,
      eventId: j['eventId'] as String,
      cashSessionId: j['cashSessionId'] as String,
      relievedEmployeeId: j['relievedEmployeeId'] as String,
      assumedByEmployeeId: j['assumedByEmployeeId'] as String,
      assumedAt: DateTime.parse(j['assumedAt'] as String).toUtc().toLocal(),
      cashVerified: j['cashVerified'] as bool,
      expectedCashSnapshot: _d(j['expectedCashSnapshot']),
      idempotent: j['idempotent'] as bool,
      countedCash: (j['countedCash'] as num?)?.toDouble(),
      cashVariance: (j['cashVariance'] as num?)?.toDouble(),
    );
  }

  /// Sobra (>0) ou falta (<0) revelada após contagem cega.
  bool get temDivergencia => cashVariance != null && cashVariance != 0;

  @override
  List<Object?> get props => [
    id,
    eventId,
    cashSessionId,
    relievedEmployeeId,
    assumedByEmployeeId,
    assumedAt,
    cashVerified,
    expectedCashSnapshot,
    idempotent,
    countedCash,
    cashVariance,
  ];
}

double _d(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}
