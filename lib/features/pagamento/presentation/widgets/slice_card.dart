import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:rabbit_pdv/core/format/brl_formatter.dart';
import 'package:rabbit_pdv/core/theme/app_colors.dart';
import 'package:rabbit_pdv/core/theme/app_text.dart';
import 'package:rabbit_pdv/domain/enums/metodo_pagamento.dart';
import 'package:rabbit_pdv/features/pagamento/domain/payment_slice.dart';
import 'package:rabbit_pdv/features/pagamento/presentation/controllers/payment_session_controller.dart';
import 'package:rabbit_pdv/features/pagamento/presentation/widgets/cash_input.dart';
import 'package:rabbit_pdv/features/pagamento/presentation/widgets/method_picker.dart';

/// Card de uma forma de pagamento (slice). Fundo neutro preenchido pela cor
/// do slice; borda padrão; realce sutil quando ativo. Clicar ativa o slice.
class SliceCard extends StatelessWidget {
  final PaymentSessionController controller;
  final PaymentSlice slice;
  final int ordem; // 0 = Restante, 1+ = Forma N
  final bool isActive;
  final VoidCallback onConfirm;

  const SliceCard({
    super.key,
    required this.controller,
    required this.slice,
    required this.ordem,
    required this.isActive,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = SliceColors.bg(slice.colorIndex, dark: dark);
    final acento = SliceColors.accent(slice.colorIndex, dark: dark);

    final valor = controller.valorSlice(slice.id);
    final itens = controller.itemCountOfSlice(slice.id);
    final isCash = slice.metodo == MetodoPagamento.dinheiro;
    final vazio = itens == 0;

    return GestureDetector(
      onTap: () => controller.setActiveSlice(slice.id),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? acento : c.border,
            width: isActive ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          children: [
            // Stripe lateral em altura cheia (sem IntrinsicHeight).
            Positioned(
              top: 0,
              bottom: 0,
              left: 0,
              child: Container(width: 4, color: acento),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _topRow(c, acento, itens, vazio),
                  const SizedBox(height: 12),
                  MethodPicker(
                    selected: slice.metodo,
                    onSelect: (m) => controller.setMetodo(slice.id, m),
                    isEnabled: (m) => m == MetodoPagamento.dinheiro
                        ? controller.dinheiroDisponivelPara(slice.id)
                        : true,
                  ),
                  if (isCash) ...[
                    const SizedBox(height: 14),
                    Divider(color: c.borderSoft, height: 1),
                    const SizedBox(height: 14),
                    CashInput(
                      total: valor,
                      valorRecebido: slice.valorRecebido,
                      troco: controller.trocoDoSlice(slice.id),
                      faltam: controller.faltamNoSlice(slice.id),
                      onChange: (v) => controller.setValorRecebido(slice.id, v),
                      onSubmit: controller.podeConfirmar ? onConfirm : null,
                    ),
                  ],
                  const SizedBox(height: 12),
                  _bottomRow(c, acento, valor),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topRow(AppColors c, Color acento, int itens, bool vazio) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: c.surface.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            slice.isRestante ? 'RESTANTE' : 'FORMA $ordem',
            style: AppText.overline.copyWith(color: acento, fontSize: 10),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            slice.isRestante
                ? '$itens ${itens == 1 ? "item" : "itens"}'
                : (vazio
                      ? 'Selecione itens à esquerda'
                      : '$itens ${itens == 1 ? "item" : "itens"} específicos'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.bodySm.copyWith(
              color: vazio && !slice.isRestante ? c.warn : c.textMute,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        if (!slice.isRestante)
          _RemoveButton(onTap: () => controller.removeSlice(slice.id)),
      ],
    );
  }

  Widget _bottomRow(AppColors c, Color acento, double valor) {
    return Row(
      children: [
        Text(
          slice.metodo?.label.toUpperCase() ?? 'ESCOLHA O MÉTODO',
          style: AppText.overline.copyWith(
            color: slice.metodo == null ? c.textDim : c.textMute,
          ),
        ),
        const Spacer(),
        Text(
          BrlFormatter.format(valor),
          style: AppText.monoLg.copyWith(
            color: acento,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _RemoveButton extends StatefulWidget {
  final VoidCallback onTap;
  const _RemoveButton({required this.onTap});

  @override
  State<_RemoveButton> createState() => _RemoveButtonState();
}

class _RemoveButtonState extends State<_RemoveButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: _hover ? c.surface3 : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            LucideIcons.x,
            size: 15,
            color: _hover ? c.danger : c.textDim,
          ),
        ),
      ),
    );
  }
}
