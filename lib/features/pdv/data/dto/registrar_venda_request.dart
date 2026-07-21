/// Métodos aceitos pelo backend (guia §5.4).
enum PaymentMethodType {
  cash('CASH'),
  creditCard('CREDIT_CARD'),
  debitCard('DEBIT_CARD'),
  pix('PIX'),
  voucher('VOUCHER'),
  convenio('CONVENIO'),
  internalBenefit('INTERNAL_BENEFIT'),
  other('OTHER');

  const PaymentMethodType(this.wire);
  final String wire;
}

class RegistrarVendaRequest {
  const RegistrarVendaRequest({
    required this.terminalId,
    required this.cashierId,
    required this.defaultWarehouseId,
    required this.itens,
    required this.pagamentos,
    this.customerId,
    this.customerDoc,
    this.customerName,
    this.headerDiscount,
  });

  final String terminalId; // @NotBlank no backend — do caixa físico ativado
  final String cashierId; // sub do JWT
  final String defaultWarehouseId;
  final List<VendaItemDto> itens;
  final List<VendaPagamentoDto> pagamentos;
  final String? customerId;
  final String? customerDoc; // CPF/CNPJ na nota
  final String? customerName;
  final double? headerDiscount; // >= 0

  Map<String, dynamic> toJson() => _stripNulls({
    'terminalId': terminalId,
    'cashierId': cashierId,
    'defaultWarehouseId': defaultWarehouseId,
    'customerId': customerId,
    'customerDoc': customerDoc,
    'customerName': customerName,
    'headerDiscount': _money(headerDiscount),
    'itens': itens.map((e) => e.toJson()).toList(),
    'pagamentos': pagamentos.map((e) => e.toJson()).toList(),
  });
}

class VendaItemDto {
  const VendaItemDto({
    required this.produtoId,
    required this.quantidade,
    this.warehouseId,
    this.lineDiscountAmount,
    this.unitCostOverride,
    this.overrideReason,
  });

  final String produtoId;
  final num quantidade; // num: suporta venda por peso (kg)
  final String? warehouseId; // usa defaultWarehouseId se ausente
  final double? lineDiscountAmount;
  final double? unitCostOverride; // exige overrideReason
  final String? overrideReason;

  Map<String, dynamic> toJson() => _stripNulls({
    'produtoId': produtoId,
    'warehouseId': warehouseId,
    'quantidade': quantidade,
    'lineDiscountAmount': _money(lineDiscountAmount),
    'unitCostOverride': _money(unitCostOverride),
    'overrideReason': overrideReason,
  });
}

class VendaPagamentoDto {
  const VendaPagamentoDto({
    required this.methodType,
    required this.amount,
    this.cardAuthCode,
    this.cardBrand,
    this.cardLast4,
    this.tipoCartao, // 'CREDIT' | 'DEBIT'
    this.pixTxid,
    this.voucherRef,
    this.customerId,
    this.employeeBenefitId,
  });

  final PaymentMethodType methodType;
  final double amount; // > 0
  final String? cardAuthCode;
  final String? cardBrand;
  final String? cardLast4;
  final String? tipoCartao;
  final String? pixTxid;
  final String? voucherRef;
  final String? customerId;
  final String? employeeBenefitId;

  Map<String, dynamic> toJson() => _stripNulls({
    'methodType': methodType.wire,
    'amount': _money(amount),
    'cardAuthCode': cardAuthCode,
    'cardBrand': cardBrand,
    'cardLast4': cardLast4,
    'tipoCartao': tipoCartao,
    'pixTxid': pixTxid,
    'voucherRef': voucherRef,
    'customerId': customerId,
    'employeeBenefitId': employeeBenefitId,
  });
}

// ── helpers ──
// Dinheiro arredondado a 2 casas no boundary. O backend é a fonte de verdade
// de totais/troco (§3.4); aqui só transportamos o valor para a nota.
num? _money(double? v) => v == null ? null : double.parse(v.toStringAsFixed(2));

Map<String, dynamic> _stripNulls(Map<String, dynamic> m) =>
    m..removeWhere((_, v) => v == null);
