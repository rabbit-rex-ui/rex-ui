import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:rabbit_pdv/core/widgets/app_button.dart';

class ActionRow extends StatelessWidget {
  final VoidCallback? onDesconto;
  final VoidCallback? onPausar;
  final VoidCallback? onDevolucao;
  final VoidCallback? onHistorico;

  const ActionRow({
    super.key,
    this.onDesconto,
    this.onPausar,
    this.onDevolucao,
    this.onHistorico,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AppButton(
          label: 'Desconto',
          icon: LucideIcons.percent,
          kbd: 'F6',
          onPressed: onDesconto,
        ),
        const SizedBox(width: 8),
        AppButton(
          label: 'Pausar',
          icon: LucideIcons.pause,
          kbd: 'F9',
          onPressed: onPausar,
        ),
        const Spacer(),
        AppButton(
          label: 'Devolução',
          icon: LucideIcons.undo2,
          onPressed: onDevolucao,
        ),
        const SizedBox(width: 8),
        AppButton(
          label: 'Histórico',
          icon: LucideIcons.history,
          onPressed: onHistorico,
        ),
      ],
    );
  }
}
