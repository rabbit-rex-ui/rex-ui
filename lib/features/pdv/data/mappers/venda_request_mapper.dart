import 'package:rabbit_pdv/domain/entities/item_atendimento.dart';
import 'package:rabbit_pdv/domain/entities/pagamento.dart';
import 'package:rabbit_pdv/domain/enums/metodo_pagamento.dart';
import 'package:rabbit_pdv/features/pdv/data/dto/registrar_venda_request.dart';

/// Traduz o estado de domínio (itens + pagamentos do atendimento) para o
/// contrato do backend (§5.4). NÃO recalcula totais — o backend é a verdade.
RegistrarVendaRequest montarVendaRequest({
  required String terminalId,
  required String cashierId, // employeeId (sub do JWT)
  required String defaultWarehouseId,
  required List<ItemAtendimento> itens,
  required List<Pagamento> pagamentos,
  String? customerId,
  String? customerDoc,
  String? customerName,
  double? headerDiscount,
}) {
  final itensDto = itens
      .map(
        (i) => VendaItemDto(
          produtoId: i.produtoId,
          quantidade: i.qtd, // kg pode ter 3 casas; un é inteiro
          lineDiscountAmount: i.descontoLinha,
        ),
      )
      .toList();

  final pagamentosDto = pagamentos.map((p) {
    final metodo = _mapMetodo(p.metodo);
    final isCash = metodo == PaymentMethodType.cash;

    // CASH → envia o valor RECEBIDO (backend calcula o troco).
    // Demais → valor exato (não-CASH não pode exceder o total).
    final amount = isCash ? (p.valorRecebido ?? p.valor) : p.valor;

    return VendaPagamentoDto(
      methodType: metodo,
      amount: amount,
      cardBrand: p.bandeira,
      cardAuthCode:
          p.nsu, // ⚠️ NSU mapeado no campo de auth; confirmar com backend
      tipoCartao: _tipoCartao(p.metodo),
      // CONVENIO exige cliente único (§5.4); herda do atendimento.
      customerId: metodo == PaymentMethodType.convenio ? customerId : null,
    );
  }).toList();

  return RegistrarVendaRequest(
    terminalId: terminalId,
    cashierId: cashierId,
    defaultWarehouseId: defaultWarehouseId,
    itens: itensDto,
    pagamentos: pagamentosDto,
    customerId: customerId,
    customerDoc: customerDoc,
    customerName: customerName,
    headerDiscount: headerDiscount,
  );
}

PaymentMethodType _mapMetodo(MetodoPagamento m) => switch (m) {
  MetodoPagamento.dinheiro => PaymentMethodType.cash,
  MetodoPagamento.pix => PaymentMethodType.pix,
  MetodoPagamento.debito => PaymentMethodType.debitCard,
  MetodoPagamento.credito => PaymentMethodType.creditCard,
  MetodoPagamento.vale => PaymentMethodType.voucher,
  // ⚠️ "Crediário" não tem tipo dedicado no backend. CONVENIO é o mais
  // próximo (conta atrelada a cliente). Confirmar a semântica com o backend;
  // se for outra coisa, troque para OTHER.
  MetodoPagamento.crediario => PaymentMethodType.convenio,
};

String? _tipoCartao(MetodoPagamento m) => switch (m) {
  MetodoPagamento.credito => 'CREDIT',
  MetodoPagamento.debito => 'DEBIT',
  _ => null,
};
