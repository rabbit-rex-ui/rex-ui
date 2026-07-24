import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:rabbit_pdv/core/auth/lock_controller.dart';
import 'package:rabbit_pdv/core/format/time_formatter.dart';
import 'package:rabbit_pdv/core/theme/app_colors.dart';
import 'package:rabbit_pdv/core/theme/app_text.dart';
import 'package:rabbit_pdv/core/widgets/app_brand.dart';
import 'package:rabbit_pdv/core/widgets/app_pill.dart';
import 'package:rabbit_pdv/features/auth/domain/sessao_atual.dart';
import 'package:rabbit_pdv/features/pdv/presentation/controllers/caixa_session_controller.dart';
import 'package:rabbit_pdv/features/pdv/presentation/controllers/ui_controllers.dart';

class Topbar extends StatelessWidget {
  final ClockController clock;
  final ThemeController theme;

  const Topbar({super.key, required this.clock, required this.theme});

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
          const SizedBox(width: 14),
          const _ContextoPosto(),
          const Spacer(),
          const AppPill(tone: PillTone.success, label: 'Caixa aberto'),
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
          const _LockButton(),
          const SizedBox(width: 10),
          _ThemeToggleButton(theme: theme),
        ],
      ),
    );
  }
}

/// Identificação do posto: Loja · Caixa · Operador. Degrada com elegância —
/// mostra só o que está disponível, nunca placeholder.
class _ContextoPosto extends StatelessWidget {
  const _ContextoPosto();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final sessao = Modular.get<SessaoAtual>();
    final caixaSession = Modular.get<CaixaSessionController>();

    return ListenableBuilder(
      listenable: Listenable.merge([sessao, caixaSession]),
      builder: (_, __) {
        final me = sessao.me;
        final loja = me?.tenantName ?? '';
        final caixa = caixaSession.caixaLabel;
        final operador = me?.nomeAbreviado ?? '';
        final operadorFull = me?.employeeName ?? '';

        final partes = [loja, caixa, operador].where((s) => s.isNotEmpty);
        if (partes.isEmpty) return const SizedBox.shrink();

        return Row(
          children: [
            Container(width: 1, height: 18, color: c.border),
            const SizedBox(width: 14),
            Icon(LucideIcons.store, size: 14, color: c.textMute),
            const SizedBox(width: 6),
            Tooltip(
              message: operadorFull.isEmpty ? '' : 'Operador: $operadorFull',
              child: Text(
                partes.join(' · '),
                style: AppText.bodySm.copyWith(
                  color: c.textMute,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        );
      },
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

class _LockButton extends StatelessWidget {
  const _LockButton();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Tooltip(
      message: 'Bloquear terminal',
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => Modular.get<LockController>().lock(),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: c.surface2,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: c.border),
          ),
          child: Icon(LucideIcons.lock, size: 18, color: c.text),
        ),
      ),
    );
  }
}
