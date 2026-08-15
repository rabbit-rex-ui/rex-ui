import 'package:rabbit_pdv/features/pdv/data/dto/registrar_venda_response.dart';

/// Tipos de movimento de caixa criáveis pelo PDV (contrato v3 §3.1).
/// Saída = sangria (`WITHDRAWAL`); entradas = reforço/suprimento (exigem
/// `cx.reforco`). Os tipos administrativos (`CASH_OUT`, `CORRECTION_*`) não são
/// operações do terminal e por isso não entram aqui.
enum MovimentoTipo {
  withdrawal('WITHDRAWAL'),
  reinforcement('REINFORCEMENT'),
  supply('SUPPLY');

  const MovimentoTipo(this.wire);

  /// Valor literal enviado no corpo (`tipo`).
  final String wire;

  bool get isSaida => this == MovimentoTipo.withdrawal;
  bool get isEntrada => !isSaida;
}

/// Destino do dinheiro numa sangria (contrato v3 §3.3). Só válido em
/// `WITHDRAWAL`. Apenas `COFRE` é elegível a malote; os demais são terminais
/// (informativos). `COFRE` só deve ser oferecido quando `maloteHabilitado`
/// (cx-config, §5).
enum MovimentoDestino {
  cofre('COFRE'),
  banco('BANCO'),
  tesouraria('TESOURARIA'),
  outro('OUTRO');

  const MovimentoDestino(this.wire);

  /// Valor literal enviado no corpo (`destino`).
  final String wire;

  /// Único destino que entra no ciclo de malote (web).
  bool get elegivelMalote => this == MovimentoDestino.cofre;
}

/// Corpo de `POST /pdv/caixas/{sessionId}/movimentos` (contrato v3 §3.1).
///
/// Espelha [FecharCaixaRequest] no mecanismo de step-up: credenciais de
/// supervisor no corpo em caixa Imediata, com [temStepUp] sinalizando ao
/// repositório que deve pular o refresh automático (um 401 aqui é credencial
/// inválida, não token do operador expirado).
///
/// `employeeId` **não** é enviado: o backend deriva o operador do token (§3.2).
class MovimentoCaixaRequest {
  const MovimentoCaixaRequest({
    required this.tipo,
    required this.amount,
    this.reason,
    this.destino,
    this.supervisorLoginCode,
    this.supervisorPassword,
  });

  final MovimentoTipo tipo;
  final double amount; // > 0 (validado no controller)
  final String? reason; // obrigatório em WITHDRAWAL (validado no controller)
  final MovimentoDestino? destino; // só faz sentido em WITHDRAWAL
  final String? supervisorLoginCode; // step-up (credencial avulsa)
  final String? supervisorPassword; // step-up (credencial avulsa)

  /// True quando o corpo carrega credenciais de supervisor. Nesse caso um 401 é
  /// credencial inválida (stepup), não token expirado — o repo usa isso para
  /// pular o refresh automático.
  bool get temStepUp =>
      (supervisorLoginCode?.isNotEmpty ?? false) &&
      (supervisorPassword?.isNotEmpty ?? false);

  Map<String, dynamic> toJson() => {
    'tipo': tipo.wire,
    'amount': double.parse(amount.toStringAsFixed(2)),
    if (reason != null && reason!.isNotEmpty) 'reason': reason,
    // `destino` só é serializado em WITHDRAWAL: enviá-lo numa entrada retorna
    // 422 invalid-argument (§3.8). Guarda defensiva, além do controller.
    if (tipo == MovimentoTipo.withdrawal && destino != null)
      'destino': destino!.wire,
    if (supervisorLoginCode != null) 'supervisorLoginCode': supervisorLoginCode,
    if (supervisorPassword != null) 'supervisorPassword': supervisorPassword,
  };
}

/// Resposta de `POST /pdv/caixas/{sessionId}/movimentos` (contrato v3 §3.4).
/// Leitura tolerante — o backend (Jackson) omite nulos, então campos ausentes
/// viram `null` e nunca quebram o parse.
class MovimentoCaixaResponse {
  const MovimentoCaixaResponse({
    required this.id,
    required this.sessionId,
    required this.tipo,
    required this.amount,
    this.reason,
    this.authorizedBy,
    this.referenceType,
    this.referenceId,
    this.idempotencyKey,
    this.occurredAt,
    this.createdAt,
    this.cashCeilingStatus,
  });

  /// `movementId` numérico (Long) — é a chave que o malote (web) usa para
  /// vincular a sangria.
  final int id;
  final String sessionId;

  /// Eco do tipo enviado. String livre para tolerância (o backend pode devolver
  /// tipos que o PDV não cria).
  final String tipo;

  final double amount;
  final String? reason;

  /// Supervisor que liberou a saída Imediata (§3.5); `null` quando não houve
  /// step-up (operador com `cx.sangria.supervise`, ou caixa Expresso).
  final String? authorizedBy;

  /// Carrega o destino (`COFRE`/`BANCO`/…) ou `null` se sem destino.
  final String? referenceType;

  /// Sempre `null` na sangria — ignore (§3.4).
  final String? referenceId;

  final String? idempotencyKey;

  /// Momento de negócio da sangria — exiba ESTE como "momento da sangria".
  final DateTime? occurredAt;

  /// Momento físico do registro (igual a [occurredAt] na criação normal).
  final DateTime? createdAt;

  /// Estado do teto APÓS o movimento. Vem na criação (`201`) **e** no replay
  /// (`200`); omitido só quando a sessão não tem teto.
  ///
  /// Regra de consumo (crítica, aplicada no controller): **ausência (`null`) =
  /// NÃO atualizar o semáforo** — nunca interprete como "sem teto/zerar alerta".
  final CashCeilingStatus? cashCeilingStatus;

  /// Momento a exibir: negócio, com fallback no registro.
  DateTime? get momento => occurredAt ?? createdAt;

  /// Se a saída foi liberada por um supervisor via step-up.
  bool get autorizadoPorSupervisor => authorizedBy != null;

  factory MovimentoCaixaResponse.fromJson(Map<String, dynamic> j) =>
      MovimentoCaixaResponse(
        id: _intOf(j['id']),
        sessionId: (j['sessionId'] as String?) ?? '',
        tipo: (j['tipo'] as String?) ?? '',
        amount: _money(j['amount']),
        reason: j['reason'] as String?,
        authorizedBy: j['authorizedBy'] as String?,
        referenceType: j['referenceType'] as String?,
        referenceId: j['referenceId']?.toString(),
        idempotencyKey: j['idempotencyKey'] as String?,
        occurredAt: _dateOpt(j['occurredAt']),
        createdAt: _dateOpt(j['createdAt']),
        cashCeilingStatus: CashCeilingStatus.tryParse(j['cashCeilingStatus']),
      );
}

/// Resposta de `GET /pdv/caixas/{sessionId}/sugestao-sangria` (contrato v3 §4).
///
/// O backend calcula, por-tenant, quanto sangrar para trazer a gaveta a um
/// patamar saudável — regra 100% no servidor; o PDV só exibe. Endpoint
/// **opcional** de consumir: a sangria funciona sem ele (entrada manual).
/// `404` (Err(NotFoundFailure)) = sessão inexistente/não aberta → o controller
/// cai em entrada manual. Leitura tolerante.
class SugestaoSangriaResponse {
  const SugestaoSangriaResponse({
    required this.sessionId,
    required this.cashLive,
    required this.alvo,
    required this.suggestedRaw,
    required this.suggestedRounded,
    required this.sangriaRecomendada,
    this.ceiling,
    this.ceilingMode,
  });

  final String sessionId;

  /// Dinheiro vivo atual na gaveta.
  final double cashLive;

  /// Quanto deve SOBRAR após a sangria (fração do teto, ou o fundo de abertura
  /// se sem teto).
  final double alvo;

  /// Sugestão crua (`cashLive − alvo`, nunca negativa).
  final double suggestedRaw;

  /// Sugestão arredondada para baixo a um múltiplo prático — **o valor a
  /// exibir/pré-preencher**.
  final double suggestedRounded;

  /// `true` quando há algo a sangrar (`suggestedRaw > 0`).
  final bool sangriaRecomendada;

  /// Teto configurado (`null` se a sessão não tem teto).
  final double? ceiling;

  /// `EXPRESS` / `IMMEDIATE` (`null` se sem teto).
  final String? ceilingMode;

  factory SugestaoSangriaResponse.fromJson(Map<String, dynamic> j) =>
      SugestaoSangriaResponse(
        sessionId: (j['sessionId'] as String?) ?? '',
        cashLive: _money(j['cashLive']),
        alvo: _money(j['alvo']),
        suggestedRaw: _money(j['suggestedRaw']),
        suggestedRounded: _money(j['suggestedRounded']),
        sangriaRecomendada: (j['sangriaRecomendada'] as bool?) ?? false,
        ceiling: _moneyOrNull(j['ceiling']),
        ceilingMode: j['ceilingMode'] as String?,
      );
}

// ─── Helpers de parse ───

int _intOf(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v?.toString() ?? '') ?? 0;
}

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

DateTime? _dateOpt(dynamic v) {
  if (v is String && v.isNotEmpty) return DateTime.parse(v).toLocal();
  return null;
}
