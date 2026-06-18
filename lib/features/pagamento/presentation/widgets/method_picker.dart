import 'package:flutter/material.dart';

import 'package:rabbit_pdv/core/theme/app_colors.dart';
import 'package:rabbit_pdv/core/theme/app_text.dart';
import 'package:rabbit_pdv/domain/enums/metodo_pagamento.dart';

/// Grid 3×2 dos métodos de pagamento. O botão selecionado fica em accent.
class MethodPicker extends StatelessWidget {
  final MetodoPagamento? selected;
  final ValueChanged<MetodoPagamento> onSelect;

  const MethodPicker({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    const methods = MetodoPagamento.values;
    return LayoutBuilder(
      builder: (context, constraints) {
        // Grid manual em vez de GridView pra controlar gap e altura exata.
        const cols = 3;
        const gap = 10.0;
        final cellWidth = (constraints.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final m in methods)
              SizedBox(
                width: cellWidth,
                child: _MethodButton(
                  method: m,
                  selected: m == selected,
                  onTap: () => onSelect(m),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _MethodButton extends StatefulWidget {
  final MetodoPagamento method;
  final bool selected;
  final VoidCallback onTap;

  const _MethodButton({
    required this.method,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_MethodButton> createState() => _MethodButtonState();
}

class _MethodButtonState extends State<_MethodButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final selected = widget.selected;

    final bg = selected
        ? c.accent
        : (_hover ? c.surface3 : c.surface2);
    final fg = selected ? c.accentInk : c.text;
    final border = selected ? c.accent : c.border;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 64,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: border, width: selected ? 2 : 1),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.method.icon, size: 22, color: fg),
              const SizedBox(height: 4),
              Text(
                widget.method.label,
                style: AppText.bodySm.copyWith(
                  color: fg,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
