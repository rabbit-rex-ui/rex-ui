import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:rabbit_pdv/core/format/brl_formatter.dart';
import 'package:rabbit_pdv/core/theme/app_colors.dart';
import 'package:rabbit_pdv/core/theme/app_text.dart';
import 'package:rabbit_pdv/features/pagamento/presentation/controllers/payment_session_controller.dart';
import 'package:rabbit_pdv/features/pagamento/presentation/widgets/slice_card.dart';

/// Painel direito: cabeçalho + lista de slices + "adicionar forma".
class SlicesPanel extends StatelessWidget {
  final PaymentSessionController controller;
  final VoidCallback onConfirm;

  const SlicesPanel({
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
        final slices = controller.slices;
        final alocado = controller.alocado;
        final fechado = (alocado - controller.total).abs() < 0.005;
        final podeAdd = controller.podeAdicionarForma;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
              child: Row(
                children: [
                  Text(
                    'FORMAS DE PAGAMENTO',
                    style: AppText.overline.copyWith(color: c.textMute),
                  ),
                  const Spacer(),
                  Text(
                    '${slices.length} ${slices.length == 1 ? "forma" : "formas"} · ${BrlFormatter.format(alocado)}',
                    style: AppText.bodySm.copyWith(
                      color: fechado ? c.success : c.textDim,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                itemCount: slices.length + 1,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  if (i == slices.length) {
                    return _AddSliceButton(
                      enabled: podeAdd,
                      onTap: controller.addSlice,
                    );
                  }
                  final s = slices[i];
                  final ordem = s.isRestante
                      ? 0
                      : slices.where((x) => !x.isRestante).toList().indexOf(s) +
                            1;
                  return SliceCard(
                    controller: controller,
                    slice: s,
                    ordem: ordem,
                    isActive: s.id == controller.activeSliceId,
                    onConfirm: onConfirm,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AddSliceButton extends StatefulWidget {
  final bool enabled;
  final VoidCallback onTap;
  const _AddSliceButton({required this.enabled, required this.onTap});

  @override
  State<_AddSliceButton> createState() => _AddSliceButtonState();
}

class _AddSliceButtonState extends State<_AddSliceButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final enabled = widget.enabled;

    final box = Container(
      height: 48,
      decoration: BoxDecoration(
        color: enabled && _hover ? c.surface2 : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.border, width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.plus, size: 18, color: c.accent),
          const SizedBox(width: 8),
          Text(
            'Adicionar forma de pagamento',
            style: AppText.bodySm.copyWith(
              color: c.accent,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );

    if (!enabled) return Opacity(opacity: 0.4, child: box);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: box,
      ),
    );
  }
}
