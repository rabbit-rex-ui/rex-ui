import 'package:flutter/material.dart';

import 'package:rabbit_pdv/core/theme/app_colors.dart';
import 'package:rabbit_pdv/core/theme/app_text.dart';
import 'package:rabbit_pdv/core/widgets/app_kbd.dart';

enum BtnVariant { primary, secondary, ghost, danger, success }

enum BtnSize { sm, md, lg, xl }

/// Botão padrão do PDV.
///
/// Não usa `ElevatedButton`/`TextButton` do Material para ter controle total
/// sobre cor, raio, tipografia e gap. Hit-area mínima é forçada para 44px
/// mesmo em sizes menores (acessibilidade).
class AppButton extends StatefulWidget {
  final BtnVariant variant;
  final BtnSize size;
  final IconData? icon;
  final String? kbd;
  final bool full;
  final VoidCallback? onPressed;
  final String label;
  final String? tooltip;

  const AppButton({
    super.key,
    required this.label,
    this.variant = BtnVariant.secondary,
    this.size = BtnSize.md,
    this.icon,
    this.kbd,
    this.full = false,
    this.onPressed,
    this.tooltip,
  });

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _hover = false;

  ({double h, double padH, double font, double gap, double radius}) get _sz =>
      switch (widget.size) {
        BtnSize.sm => (h: 32, padH: 10, font: 13, gap: 6, radius: 7),
        BtnSize.md => (h: 40, padH: 14, font: 14, gap: 8, radius: 8),
        BtnSize.lg => (h: 52, padH: 18, font: 15, gap: 10, radius: 10),
        BtnSize.xl => (h: 64, padH: 22, font: 17, gap: 12, radius: 12),
      };

  ({Color bg, Color fg, Color? border}) _styleFor(BuildContext context) {
    final c = context.colors;
    return switch (widget.variant) {
      BtnVariant.primary => (bg: c.accent, fg: c.accentInk, border: null),
      BtnVariant.secondary => (bg: c.surface, fg: c.text, border: c.border),
      BtnVariant.ghost => (bg: Colors.transparent, fg: c.text, border: null),
      BtnVariant.danger => (bg: Colors.transparent, fg: c.danger, border: c.border),
      BtnVariant.success => (bg: c.success, fg: c.successInk, border: null),
    };
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final s = _sz;
    final style = _styleFor(context);

    final hoverTint = widget.variant == BtnVariant.ghost
        ? context.colors.surface3.withValues(alpha: 0.6)
        : null;

    final bg = !enabled
        ? style.bg.withValues(alpha: 0.5)
        : (_hover && hoverTint != null ? hoverTint : style.bg);

    final content = ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: s.h,
        minWidth: widget.full ? double.infinity : 0,
      ),
      child: Container(
        height: s.h,
        padding: EdgeInsets.symmetric(horizontal: s.padH),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(s.radius),
          border: style.border != null
              ? Border.all(color: style.border!, width: 1)
              : null,
        ),
        child: Row(
          mainAxisAlignment: widget.full ? MainAxisAlignment.center : MainAxisAlignment.start,
          mainAxisSize: widget.full ? MainAxisSize.max : MainAxisSize.min,
          children: [
            if (widget.icon != null) ...[
              Icon(
                widget.icon,
                size: s.font + 3,
                color: style.fg,
              ),
              SizedBox(width: s.gap),
            ],
            Flexible(
              child: Text(
                widget.label,
                overflow: TextOverflow.ellipsis,
                style: AppText.body.copyWith(
                  color: style.fg,
                  fontSize: s.font,
                  fontWeight: FontWeight.w600,
                  height: 1.1,
                ),
              ),
            ),
            if (widget.kbd != null) ...[
              SizedBox(width: s.gap + 2),
              AppKbd(
                widget.kbd!,
                onPrimary: widget.variant == BtnVariant.primary ||
                    widget.variant == BtnVariant.success,
              ),
            ],
          ],
        ),
      ),
    );

    final wrapped = MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? widget.onPressed : null,
        child: ConstrainedBox(
          // Hit target mínimo 44 mesmo em sm/md baixinhos.
          constraints: const BoxConstraints(minHeight: 44),
          child: Center(child: content),
        ),
      ),
    );

    if (widget.tooltip != null) {
      return Tooltip(message: widget.tooltip!, child: wrapped);
    }
    return wrapped;
  }
}
