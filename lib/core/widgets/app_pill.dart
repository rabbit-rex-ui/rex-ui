import 'package:flutter/material.dart';

import 'package:rabbit_pdv/core/theme/app_colors.dart';
import 'package:rabbit_pdv/core/theme/app_text.dart';

enum PillTone { neutral, success, warn, danger, accent }

/// Pílula pequena com bolinha à esquerda. Para indicar status (caixa aberto,
/// online/offline, etc.).
class AppPill extends StatelessWidget {
  final PillTone tone;
  final bool dot;
  final String label;

  const AppPill({
    super.key,
    this.tone = PillTone.neutral,
    this.dot = true,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    final (bg, fg, dotColor) = switch (tone) {
      PillTone.success => (c.successTint, c.success, c.success),
      PillTone.warn => (c.warnTint, c.warn, c.warn),
      PillTone.danger => (c.dangerTint, c.danger, c.danger),
      PillTone.accent => (c.accentTint, c.accent, c.accent),
      PillTone.neutral => (c.surface2, c.textMute, c.textMute),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: AppText.caption.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
