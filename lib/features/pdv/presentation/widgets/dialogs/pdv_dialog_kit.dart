import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:rabbit_pdv/core/theme/app_colors.dart';

/// Primitivos visuais compartilhados dos diálogos do PDV (liberação de
/// supervisor, sangria, etc.). Centraliza a identidade visual — tipografia,
/// espaçamentos, cores e formas — para novos diálogos ficarem consistentes sem
/// duplicar estilo. O `anular_item_dialog` pode migrar para cá depois.

/// Rótulo de campo (overline): 11px, peso 600, tracking leve, cor mute.
class PdvFieldLabel extends StatelessWidget {
  const PdvFieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.6,
      color: context.colors.textMute,
    ),
  );
}

/// Decoração padrão de input dos diálogos (fundo surface2, borda accent no
/// foco).
InputDecoration pdvInputDecoration(
  BuildContext context, {
  required String hint,
  Widget? suffix,
}) {
  final colors = context.colors;
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: colors.textDim),
    suffixIcon: suffix,
    filled: true,
    fillColor: colors.surface2,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: colors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: colors.accent, width: 1.5),
    ),
    disabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: colors.borderSoft),
    ),
  );
}

/// Banner de erro (vermelho): ícone + mensagem.
class PdvErrorBanner extends StatelessWidget {
  const PdvErrorBanner(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.danger.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.danger.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.circleAlert, size: 16, color: colors.danger),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 12.5, color: colors.danger),
            ),
          ),
        ],
      ),
    );
  }
}

/// Banner informativo (accent): para prompts que NÃO são erro, como "liberação
/// de supervisor necessária".
class PdvInfoBanner extends StatelessWidget {
  const PdvInfoBanner(this.message, {super.key, this.icon = LucideIcons.info});

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: colors.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 12.5, color: colors.accent),
            ),
          ),
        ],
      ),
    );
  }
}

/// Botão secundário (ghost).
class PdvGhostButton extends StatelessWidget {
  const PdvGhostButton(this.label, {super.key, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: colors.surface2,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 48,
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: colors.textMute,
            ),
          ),
        ),
      ),
    );
  }
}

/// Botão primário (accent) com estado de loading e ícone opcional.
class PdvPrimaryButton extends StatelessWidget {
  const PdvPrimaryButton({
    super.key,
    required this.label,
    this.icon,
    this.loading = false,
    this.enabled = true,
    this.onTap,
  });

  final String label;
  final IconData? icon;
  final bool loading;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final active = enabled && !loading;
    return Opacity(
      opacity: active ? 1 : 0.6,
      child: Material(
        color: colors.accent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: active ? onTap : null,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 48,
            alignment: Alignment.center,
            child: loading
                ? SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(colors.accentInk),
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, size: 17, color: colors.accentInk),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: colors.accentInk,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
