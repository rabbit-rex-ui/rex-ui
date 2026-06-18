import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:rabbit_pdv/core/format/time_formatter.dart';
import 'package:rabbit_pdv/core/theme/app_colors.dart';
import 'package:rabbit_pdv/core/theme/app_text.dart';
import 'package:rabbit_pdv/core/widgets/app_brand.dart';
import 'package:rabbit_pdv/core/widgets/app_pill.dart';
import 'package:rabbit_pdv/features/pdv/presentation/controllers/ui_controllers.dart';

class Topbar extends StatelessWidget {
  final ClockController clock;
  final ThemeController theme;

  const Topbar({
    super.key,
    required this.clock,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: Row(
        children: [
          const AppBrand(),
          const Spacer(),
          const AppPill(
            tone: PillTone.success,
            label: 'Caixa aberto',
          ),
          const SizedBox(width: 14),
          ListenableBuilder(
            listenable: clock,
            builder: (_, __) {
              return Text(
                TimeFormatter.hms(clock.now),
                style: AppText.monoMd.copyWith(
                  color: c.text,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              );
            },
          ),
          const SizedBox(width: 14),
          _ThemeToggleButton(theme: theme),
        ],
      ),
    );
  }
}

class _ThemeToggleButton extends StatelessWidget {
  final ThemeController theme;

  const _ThemeToggleButton({required this.theme});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ListenableBuilder(
      listenable: theme,
      builder: (_, __) {
        return Tooltip(
          message: theme.dark ? 'Modo claro' : 'Modo escuro',
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: theme.toggle,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: c.surface2,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: c.border),
              ),
              child: Icon(
                theme.dark ? LucideIcons.sun : LucideIcons.moon,
                size: 18,
                color: c.text,
              ),
            ),
          ),
        );
      },
    );
  }
}
