import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:rabbit_pdv/core/format/brl_formatter.dart';
import 'package:rabbit_pdv/core/theme/app_colors.dart';
import 'package:rabbit_pdv/core/theme/app_text.dart';
import 'package:rabbit_pdv/core/widgets/status_dot.dart';
import 'package:rabbit_pdv/domain/entities/atendimento.dart';
import 'package:rabbit_pdv/domain/enums/atendimento_status.dart';
import 'package:rabbit_pdv/features/pdv/presentation/controllers/sessions_controller.dart';

class TabsBar extends StatelessWidget {
  final SessionsController sessions;

  const TabsBar({super.key, required this.sessions});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: c.surface2,
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: ListenableBuilder(
        listenable: sessions,
        builder: (_, __) {
          final list = sessions.sessions;
          final activeId = sessions.activeId;
          final canClose = list.length > 1;

          return Row(
            children: [
              Expanded(
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final s = list[i];
                    return Padding(
                      padding: const EdgeInsets.only(right: 4, top: 4),
                      child: SessionTab(
                        session: s,
                        isActive: s.id == activeId,
                        onTap: () => sessions.alternarPara(s.id),
                        onClose: canClose
                            ? () => sessions.fechar(s.id)
                            : null,
                      ),
                    );
                  },
                ),
              ),
              _NewSessionButton(onTap: () => sessions.novoAtendimento()),
            ],
          );
        },
      ),
    );
  }
}

class SessionTab extends StatefulWidget {
  final Atendimento session;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback? onClose;

  const SessionTab({
    super.key,
    required this.session,
    required this.isActive,
    required this.onTap,
    this.onClose,
  });

  @override
  State<SessionTab> createState() => _SessionTabState();
}

class _SessionTabState extends State<SessionTab> {
  bool _hover = false;

  StatusTone _toneFor(AtendimentoStatus s) => switch (s) {
        AtendimentoStatus.digitando => StatusTone.accent,
        AtendimentoStatus.aguardando => StatusTone.warn,
        AtendimentoStatus.pronto => StatusTone.success,
        AtendimentoStatus.pago => StatusTone.success,
        AtendimentoStatus.cancelado => StatusTone.danger,
      };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = widget.session;
    final ordem = s.ordem.toString().padLeft(2, '0');
    final bg = widget.isActive
        ? c.bg
        : (_hover ? c.surface3 : c.surface2);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              constraints: const BoxConstraints(minWidth: 180, maxWidth: 240),
              height: 42,
              padding: const EdgeInsets.fromLTRB(14, 0, 4, 0),
              // Border uniforme (cor única) é requisito do framework para
              // permitir borderRadius. A faixa accent do tab ativo vem como
              // indicator sobreposto via Stack (abaixo).
              decoration: BoxDecoration(
                color: bg,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
                border: Border.all(
                  color: c.border.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  StatusDot(
                    tone: _toneFor(s.status),
                    pulse: widget.isActive && s.status == AtendimentoStatus.digitando,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '#$ordem · ${s.cliente.nome}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.bodySm.copyWith(
                            color: c.text,
                            fontSize: 12,
                            fontWeight: widget.isActive ? FontWeight.w600 : FontWeight.w500,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${s.numItens} ${s.numItens == 1 ? "item" : "itens"} · ${BrlFormatter.format(s.total)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.monoSm.copyWith(
                            color: c.textDim,
                            fontSize: 10.5,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.onClose != null)
                    _TabCloseButton(onTap: widget.onClose!),
                ],
              ),
            ),
            // Indicator accent no topo da aba ativa. Posicionado fora do
            // BoxDecoration porque cores não-uniformes em Border + borderRadius
            // não são suportadas pelo Flutter.
            if (widget.isActive)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: Container(
                    height: 2,
                    decoration: BoxDecoration(
                      color: c.accent,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(8),
                        topRight: Radius.circular(8),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TabCloseButton extends StatefulWidget {
  final VoidCallback onTap;
  const _TabCloseButton({required this.onTap});

  @override
  State<_TabCloseButton> createState() => _TabCloseButtonState();
}

class _TabCloseButtonState extends State<_TabCloseButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: _hover ? c.surface3 : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(
            LucideIcons.x,
            size: 14,
            color: _hover ? c.danger : c.textDim,
          ),
        ),
      ),
    );
  }
}

class _NewSessionButton extends StatefulWidget {
  final VoidCallback onTap;
  const _NewSessionButton({required this.onTap});

  @override
  State<_NewSessionButton> createState() => _NewSessionButtonState();
}

class _NewSessionButtonState extends State<_NewSessionButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Tooltip(
          message: 'Novo atendimento (Ctrl+N)',
          child: Container(
            width: 44,
            height: 44,
            margin: const EdgeInsets.only(right: 8, left: 4),
            decoration: BoxDecoration(
              color: _hover ? c.surface3 : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              LucideIcons.plus,
              size: 20,
              color: c.text,
            ),
          ),
        ),
      ),
    );
  }
}
