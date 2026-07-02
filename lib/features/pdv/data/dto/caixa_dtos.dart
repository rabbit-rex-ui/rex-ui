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

/// Corpo de fechamento (contrato §7). NÃO existe `closedBy` — quem fecha é o
/// principal do token. Campos condicionais só vão quando fazem sentido.
class FecharCaixaRequest {
  const FecharCaixaRequest({
    this.countedCash,
    this.blindClose = false,
    this.notes,
    this.justificationNote,
    this.supervisorLoginCode,
    this.supervisorPassword,
  });

  final double? countedCash; // obrigatório quando blindClose=false
  final bool blindClose;
  final String? notes;
  final String? justificationNote; // só na divergência acima da tolerância
  final String? supervisorLoginCode; // step-up (credencial avulsa)
  final String? supervisorPassword; // step-up (credencial avulsa)

  /// True quando o corpo carrega credenciais de supervisor. Nesse caso um 401 é
  /// credencial inválida (stepup), não token do operador expirado — o repo usa
  /// isso para pular o refresh automático.
  bool get temStepUp =>
      (supervisorLoginCode?.isNotEmpty ?? false) &&
      (supervisorPassword?.isNotEmpty ?? false);

  Map<String, dynamic> toJson() => {
    if (countedCash != null)
      'countedCash': double.parse(countedCash!.toStringAsFixed(2)),
    'blindClose': blindClose,
    if (notes != null && notes!.isNotEmpty) 'notes': notes,
    if (justificationNote != null && justificationNote!.isNotEmpty)
      'justificationNote': justificationNote,
    if (supervisorLoginCode != null) 'supervisorLoginCode': supervisorLoginCode,
    if (supervisorPassword != null) 'supervisorPassword': supervisorPassword,
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
    this.closedAt,
    this.closedBy,
    this.countedCash,
    this.cashDifference,
    this.notes,
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

  // Preenchidos no fechamento (§8). Omitidos enquanto OPEN e em cego.
  final DateTime? closedAt;
  final String? closedBy;
  final double? countedCash;
  final double? cashDifference; // countedCash − expectedCash (±)
  final String? notes;

  final double salesCashTotal;
  final double reinforcementsTotal;
  final double withdrawalsTotal;
  final bool blindClose;

  bool get isOpen => status.toUpperCase() == 'OPEN';
  bool get fechouComDivergencia =>
      status.toUpperCase() == 'CLOSED_WITH_DIFFERENCE';

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
        closedAt: _dtOpt(j['closedAt']),
        closedBy: j['closedBy'] as String?,
        countedCash: _dOpt(j['countedCash']),
        cashDifference: _dOpt(j['cashDifference']),
        notes: j['notes'] as String?,
        salesCashTotal: _d(j['salesCashTotal']),
        reinforcementsTotal: _d(j['reinforcementsTotal']),
        withdrawalsTotal: _d(j['withdrawalsTotal']),
        blindClose: (j['blindClose'] as bool?) ?? false,
      );
}

// ─── Relatório de conferência (GET /pdv/caixas/{id}/relatorio) ───
// Estrutura marcada com ✱ no guia (confirmar campos exatos na 1ª integração).
// Leitura tolerante: campo ausente → null / default, nunca quebra.

class RelatorioCaixaResponse {
  const RelatorioCaixaResponse({
    required this.sessao,
    required this.conferencia,
    required this.pagamentos,
    required this.resumoVendas,
    required this.movimentos,
  });

  final RelatorioSessao sessao;
  final RelatorioConferencia conferencia;
  final List<RelatorioPagamento> pagamentos;
  final RelatorioResumoVendas resumoVendas;
  final List<RelatorioMovimento> movimentos;

  factory RelatorioCaixaResponse.fromJson(Map<String, dynamic> j) =>
      RelatorioCaixaResponse(
        sessao: RelatorioSessao.fromJson(
          (j['sessao'] as Map<String, dynamic>?) ?? const {},
        ),
        conferencia: RelatorioConferencia.fromJson(
          (j['conferencia'] as Map<String, dynamic>?) ?? const {},
        ),
        pagamentos: ((j['pagamentos'] as List<dynamic>?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(RelatorioPagamento.fromJson)
            .toList(growable: false),
        resumoVendas: RelatorioResumoVendas.fromJson(
          (j['resumoVendas'] as Map<String, dynamic>?) ?? const {},
        ),
        movimentos: ((j['movimentos'] as List<dynamic>?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(RelatorioMovimento.fromJson)
            .toList(growable: false),
      );
}

class RelatorioSessao {
  const RelatorioSessao({
    required this.sessionId,
    required this.cashRegisterId,
    required this.status,
    this.cashRegisterCode,
    this.cashRegisterName,
    this.openedAt,
    this.openedBy,
    this.closedAt,
    this.closedBy,
    this.duracaoMin,
  });

  final String sessionId;
  final String cashRegisterId;
  final String status;
  final String? cashRegisterCode;
  final String? cashRegisterName;
  final DateTime? openedAt;
  final String? openedBy;
  final DateTime? closedAt;
  final String? closedBy;
  final int? duracaoMin;

  bool get fechado => status.toUpperCase() != 'OPEN';

  factory RelatorioSessao.fromJson(Map<String, dynamic> j) => RelatorioSessao(
    sessionId: (j['sessionId'] as String?) ?? '',
    cashRegisterId: (j['cashRegisterId'] as String?) ?? '',
    status: (j['status'] as String?) ?? 'UNKNOWN',
    cashRegisterCode: j['cashRegisterCode'] as String?,
    cashRegisterName: j['cashRegisterName'] as String?,
    openedAt: _dtOpt(j['openedAt']),
    openedBy: j['openedBy'] as String?,
    closedAt: _dtOpt(j['closedAt']),
    closedBy: j['closedBy'] as String?,
    duracaoMin: (j['duracaoMin'] as num?)?.toInt(),
  );
}

class RelatorioConferencia {
  const RelatorioConferencia({
    required this.openingFloat,
    required this.salesCash,
    required this.reinforcementsTotal,
    required this.withdrawalsTotal,
    required this.expectedCash,
    this.countedCash,
    this.cashDifference,
    this.isBlindClose = false,
  });

  final double openingFloat;
  final double salesCash;
  final double reinforcementsTotal;
  final double withdrawalsTotal;
  final double expectedCash;
  final double? countedCash; // ausente em cego
  final double? cashDifference; // ausente em cego
  final bool isBlindClose;

  factory RelatorioConferencia.fromJson(Map<String, dynamic> j) =>
      RelatorioConferencia(
        openingFloat: _d(j['openingFloat']),
        salesCash: _d(j['salesCash']),
        reinforcementsTotal: _d(j['reinforcementsTotal']),
        withdrawalsTotal: _d(j['withdrawalsTotal']),
        expectedCash: _d(j['expectedCash']),
        countedCash: _dOpt(j['countedCash']),
        cashDifference: _dOpt(j['cashDifference']),
        isBlindClose: (j['isBlindClose'] as bool?) ?? false,
      );
}

class RelatorioPagamento {
  const RelatorioPagamento({
    required this.methodType,
    required this.totalRecebido,
    required this.totalTroco,
    required this.qtdVendas,
  });

  final String methodType;
  final double totalRecebido;
  final double totalTroco;
  final int qtdVendas;

  factory RelatorioPagamento.fromJson(Map<String, dynamic> j) =>
      RelatorioPagamento(
        methodType: (j['methodType'] as String?) ?? '',
        totalRecebido: _d(j['totalRecebido']),
        totalTroco: _d(j['totalTroco']),
        qtdVendas: (j['qtdVendas'] as num?)?.toInt() ?? 0,
      );
}

class RelatorioResumoVendas {
  const RelatorioResumoVendas({
    required this.qtd,
    required this.totalGeral,
    required this.ticketMedio,
  });

  final int qtd;
  final double totalGeral;
  final double ticketMedio;

  factory RelatorioResumoVendas.fromJson(Map<String, dynamic> j) =>
      RelatorioResumoVendas(
        qtd: (j['qtd'] as num?)?.toInt() ?? 0,
        totalGeral: _d(j['totalGeral']),
        ticketMedio: _d(j['ticketMedio']),
      );
}

class RelatorioMovimento {
  const RelatorioMovimento({
    required this.id,
    required this.movementType,
    required this.amount,
    this.reason,
    this.employeeId,
    this.occurredAt,
  });

  final String id; // backend pode mandar int; guardamos como String
  final String movementType;
  final double amount;
  final String? reason;
  final String? employeeId;
  final DateTime? occurredAt;

  factory RelatorioMovimento.fromJson(Map<String, dynamic> j) =>
      RelatorioMovimento(
        id: j['id']?.toString() ?? '',
        movementType: (j['movementType'] as String?) ?? '',
        amount: _d(j['amount']),
        reason: j['reason'] as String?,
        employeeId: j['employeeId'] as String?,
        occurredAt: _dtOpt(j['occurredAt']),
      );
}

// ─── Helpers de parse ───

double _d(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

double? _dOpt(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

DateTime? _dtOpt(dynamic v) {
  if (v is String && v.isNotEmpty) return DateTime.parse(v).toLocal();
  return null;
}
