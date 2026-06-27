/// DTOs da anulação de item (liberação de fiscal/gerente).
/// Contrato: POST /pdv/itens/anular. `money` em double (convenção do projeto).
///
/// Idempotência é pelo [eventId] no CORPO (não por header): o backend
/// devolve 201 (gravado agora) ou 200 (retry — mesmo registro). Ambos < 400,
/// então ambos chegam como Ok no ApiClient; diferencie pelo campo
/// [AnularItemResponse.idempotent].
class AnularItemRequest {
  const AnularItemRequest({
    required this.eventId,
    required this.cashSessionId,
    required this.supervisorLoginCode,
    required this.supervisorPassword,
    required this.sku,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.reasonCategory,
    this.cartRef,
    this.productId,
    this.lineDiscountAmount = 0,
    this.reasonNote,
    this.clientReportedAt,
  });

  /// Gerado UMA vez pelo cliente e reusado em retries (garante idempotência).
  final String eventId;

  /// Id local do carrinho (atendimento ativo). Opcional, correlação.
  final String? cartRef;

  /// Sessão de caixa aberta — o servidor deriva caixa/terminal a partir dele.
  final String cashSessionId;

  final String supervisorLoginCode;
  final String supervisorPassword;

  /// UUID do produto, quando disponível. Hoje vai null (o item carrega só sku).
  final String? productId;
  final String sku;
  final String productName;
  final double quantity;
  final double unitPrice;
  final double lineDiscountAmount;

  /// Valor de fio: WRONG_SCAN | DUPLICATE_SCAN | CUSTOMER_GAVE_UP |
  /// PRICE_DISAGREEMENT | OTHER.
  final String reasonCategory;

  /// OBRIGATÓRIO quando reasonCategory == OTHER.
  final String? reasonNote;

  /// Só diagnóstico (relógio local). O servidor não confia nisso.
  final String? clientReportedAt;

  Map<String, dynamic> toJson() => {
    'eventId': eventId,
    'cartRef': cartRef,
    'cashSessionId': cashSessionId,
    'supervisorLoginCode': supervisorLoginCode,
    'supervisorPassword': supervisorPassword,
    'productId': productId,
    'sku': sku,
    'productName': productName,
    'quantity': quantity,
    'unitPrice': unitPrice,
    'lineDiscountAmount': lineDiscountAmount,
    'reasonCategory': reasonCategory,
    'reasonNote': reasonNote,
    if (clientReportedAt != null) 'clientReportedAt': clientReportedAt,
  };
}

class AnularItemResponse {
  const AnularItemResponse({
    required this.id,
    required this.eventId,
    required this.voidedAt,
    required this.authorizedByEmployeeId,
    required this.idempotent,
  });

  final String id;
  final String eventId;

  /// Carimbo autoritativo do servidor (ISO 8601).
  final String voidedAt;
  final String authorizedByEmployeeId;

  /// true quando o eventId já existia (retry → 200). false no 201.
  final bool idempotent;

  factory AnularItemResponse.fromJson(Map<String, dynamic> j) =>
      AnularItemResponse(
        id: j['id'] as String,
        eventId: j['eventId'] as String,
        voidedAt: (j['voidedAt'] as String?) ?? '',
        authorizedByEmployeeId: (j['authorizedByEmployeeId'] as String?) ?? '',
        idempotent: (j['idempotent'] as bool?) ?? false,
      );
}
