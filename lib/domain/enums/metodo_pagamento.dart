import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Métodos de pagamento aceitos pelo PDV. Cada um vira um [Pagamento]
/// no backend ao finalizar a venda.
enum MetodoPagamento {
  dinheiro,
  pix,
  debito,
  credito,
  vale,
  crediario,
}

/// Metadados visuais e legíveis de cada método. Vive perto do enum porque
/// é informação intrínseca do método (não tema dependente).
extension MetodoPagamentoX on MetodoPagamento {
  String get label => switch (this) {
        MetodoPagamento.dinheiro => 'Dinheiro',
        MetodoPagamento.pix => 'PIX',
        MetodoPagamento.debito => 'Débito',
        MetodoPagamento.credito => 'Crédito',
        MetodoPagamento.vale => 'Vale',
        MetodoPagamento.crediario => 'Crediário',
      };

  IconData get icon => switch (this) {
        MetodoPagamento.dinheiro => LucideIcons.banknote,
        MetodoPagamento.pix => LucideIcons.qrCode,
        MetodoPagamento.debito => LucideIcons.creditCard,
        MetodoPagamento.credito => LucideIcons.creditCard,
        MetodoPagamento.vale => LucideIcons.ticket,
        MetodoPagamento.crediario => LucideIcons.fileClock,
      };

  /// Indica se este método requer captura de "valor recebido" + cálculo
  /// de troco (apenas dinheiro, no MVP).
  bool get exigeValorRecebido => this == MetodoPagamento.dinheiro;
}
