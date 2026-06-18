import 'package:flutter/material.dart';

import 'package:rabbit_pdv/core/theme/app_colors.dart';
import 'package:rabbit_pdv/core/theme/app_text.dart';
import 'package:rabbit_pdv/domain/enums/metodo_pagamento.dart';
import 'package:rabbit_pdv/features/pagamento/presentation/controllers/payment_session_controller.dart';
import 'package:rabbit_pdv/features/pagamento/presentation/widgets/cash_input.dart';
import 'package:rabbit_pdv/features/pagamento/presentation/widgets/method_picker.dart';

/// Card único de pagamento (Passo A). No Passo B vira um item de uma
/// lista de slices, cada um com sua cor e atribuição de itens.
class SliceCard extends StatelessWidget {
  final PaymentSessionController controller;
  final VoidCallback onConfirm;

  const SliceCard({
    super.key,
    required this.controller,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return ListenableBuilder(
      listenable: controller,
      builder: (_, __) {
        final isCash = controller.metodo == MetodoPagamento.dinheiro;

        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'FORMA DE PAGAMENTO',
                style: AppText.overline.copyWith(color: c.textMute),
              ),
              const SizedBox(height: 12),
              MethodPicker(
                selected: controller.metodo,
                onSelect: controller.setMetodo,
              ),
              // CashInput aparece apenas em dinheiro; o resto do espaço
              // fica zerado (sem placeholder pra não sugerir interação).
              if (isCash) ...[
                const SizedBox(height: 18),
                Divider(color: c.borderSoft, height: 1),
                const SizedBox(height: 18),
                CashInput(
                  total: controller.total,
                  valorRecebido: controller.valorRecebido,
                  troco: controller.troco,
                  faltam: controller.faltam,
                  onChange: controller.setValorRecebido,
                  onSubmit: controller.podeConfirmar ? onConfirm : null,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
