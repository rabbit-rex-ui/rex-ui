import 'package:flutter/material.dart';

import 'package:rabbit_pdv/core/theme/app_colors.dart';

enum StatusTone { accent, warn, success, neutral, danger }

/// Bolinha de status. Quando `pulse=true`, exibe halo animado em loop
/// (usado no atendimento ativo em status `digitando`).
class StatusDot extends StatefulWidget {
  final StatusTone tone;
  final bool pulse;
  final double size;

  const StatusDot({
    super.key,
    required this.tone,
    this.pulse = false,
    this.size = 8,
  });

  @override
  State<StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<StatusDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    if (widget.pulse) _ctrl.repeat();
  }

  @override
  void didUpdateWidget(covariant StatusDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pulse != oldWidget.pulse) {
      if (widget.pulse) {
        _ctrl.repeat();
      } else {
        _ctrl.stop();
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Color _color(BuildContext context) {
    final c = context.colors;
    return switch (widget.tone) {
      StatusTone.accent => c.accent,
      StatusTone.warn => c.warn,
      StatusTone.success => c.success,
      StatusTone.danger => c.danger,
      StatusTone.neutral => c.textMute,
    };
  }

  @override
  Widget build(BuildContext context) {
    final color = _color(context);
    final dot = Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );

    if (!widget.pulse) return dot;

    return SizedBox(
      width: widget.size * 2,
      height: widget.size * 2,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _ctrl,
            builder: (context, child) {
              final t = _ctrl.value; // 0..1
              final scale = 0.8 + (1.6 - 0.8) * t;
              final opacity = (0.6 * (1 - t)).clamp(0.0, 1.0);
              return Container(
                width: widget.size * scale,
                height: widget.size * scale,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: opacity),
                  shape: BoxShape.circle,
                ),
              );
            },
          ),
          dot,
        ],
      ),
    );
  }
}
