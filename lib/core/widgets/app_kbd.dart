import 'package:flutter/material.dart';

import 'package:rabbit_pdv/core/theme/app_colors.dart';
import 'package:rabbit_pdv/core/theme/app_text.dart';

/// Badge tipográfico que representa uma tecla de atalho (F5, Esc, Ctrl+N).
class AppKbd extends StatelessWidget {
  final String label;

  /// Quando o kbd vive dentro de um botão `primary`, o background é semi-
  /// transparente sobre a cor accent (em vez de surface3).
  final bool onPrimary;

  const AppKbd(this.label, {super.key, this.onPrimary = false});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bg = onPrimary
        ? Colors.black.withValues(alpha: 0.18)
        : c.surface3;
    final fg = onPrimary
        ? c.accentInk.withValues(alpha: 0.7)
        : c.textMute;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: AppText.monoSm.copyWith(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
