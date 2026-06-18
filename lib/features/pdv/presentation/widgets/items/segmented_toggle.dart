import 'package:flutter/material.dart';

import 'package:rabbit_pdv/core/theme/app_colors.dart';
import 'package:rabbit_pdv/core/theme/app_spacing.dart';
import 'package:rabbit_pdv/core/theme/app_text.dart';
import 'package:rabbit_pdv/features/pdv/presentation/controllers/ui_controllers.dart';

class ToggleOption {
  final ItemsView value;
  final String label;
  final IconData icon;
  final int? count;

  const ToggleOption({
    required this.value,
    required this.label,
    required this.icon,
    this.count,
  });
}

class SegmentedToggle extends StatelessWidget {
  final List<ToggleOption> options;
  final ItemsView value;
  final ValueChanged<ItemsView> onChange;

  const SegmentedToggle({
    super.key,
    required this.options,
    required this.value,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: c.surface3,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: c.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final o in options) ...[
            _ToggleButton(
              option: o,
              active: o.value == value,
              onTap: () => onChange(o.value),
            ),
          ],
        ],
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  final ToggleOption option;
  final bool active;
  final VoidCallback onTap;

  const _ToggleButton({
    required this.option,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = active ? c.text : c.textMute;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: active ? c.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            boxShadow: active ? AppShadows.sm : const [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(option.icon, size: 14, color: fg),
              const SizedBox(width: 6),
              Text(
                option.label,
                style: AppText.body.copyWith(
                  color: fg,
                  fontSize: 12.5,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
              if (option.count != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: active ? c.accent : c.surface3,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    option.count!.toString(),
                    style: AppText.monoSm.copyWith(
                      color: active ? c.accentInk : c.textMute,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
