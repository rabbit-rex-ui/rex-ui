import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:rabbit_pdv/core/format/brl_formatter.dart';
import 'package:rabbit_pdv/core/theme/app_colors.dart';
import 'package:rabbit_pdv/core/theme/app_text.dart';
import 'package:rabbit_pdv/core/widgets/app_button.dart';
import 'package:rabbit_pdv/features/pagamento/presentation/controllers/payment_session_controller.dart';

/// Footer do modal: blocos Total/Alocado à esquerda, aviso opcional no
/// meio, CTA de confirmação à direita.
class PaymentFooter extends StatelessWidget {
  final PaymentSessionController controller;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  const PaymentFooter({
    super.key,
    required this.controller,
    required this.onCancel,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return ListenableBuilder(
      listenable: controller,
      builder: (_, __) {
        final podeConfirmar = controller.podeConfirmar;
        final bloqueio = controller.motivoBloqueio;
        // No Passo A, "alocado" = total quando há método; senão 0.
        final alocado = controller.alocado;

        return Container(
          height: 88,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: c.surface,
            border: Border(top: BorderSide(color: c.border)),
          ),
          child: Row(
            children: [
              _SummaryBlock(
                label: 'TOTAL',
                value: controller.total,
                valueColor: c.text,
              ),
              Container(
                width: 1,
                height: 36,
                margin: const EdgeInsets.symmetric(horizontal: 24),
                color: c.border,
              ),
              _SummaryBlock(
                label: 'ALOCADO',
                value: alocado,
                valueColor: alocado == controller.total ? c.success : c.warn,
              ),
              const SizedBox(width: 20),
              if (bloqueio != null) Expanded(child: _Warn(message: bloqueio)),
              if (bloqueio == null) const Spacer(),
              AppButton(
                label: 'Cancelar',
                variant: BtnVariant.ghost,
                size: BtnSize.lg,
                onPressed: onCancel,
              ),
              const SizedBox(width: 10),
              AppButton(
                label: 'Confirmar pagamento',
                variant: BtnVariant.primary,
                size: BtnSize.xl,
                icon: LucideIcons.check,
                kbd: 'F5',
                onPressed: podeConfirmar ? onConfirm : null,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SummaryBlock extends StatelessWidget {
  final String label;
  final double value;
  final Color valueColor;

  const _SummaryBlock({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.overline.copyWith(color: c.textMute)),
        const SizedBox(height: 4),
        Text(
          BrlFormatter.format(value),
          style: AppText.monoLg.copyWith(
            color: valueColor,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _Warn extends StatelessWidget {
  final String message;
  const _Warn({required this.message});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: c.warnTint,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.warn.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.triangleAlert, size: 16, color: c.warn),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              message,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.bodySm.copyWith(
                color: c.warn,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
