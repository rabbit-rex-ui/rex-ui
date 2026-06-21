import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:rabbit_pdv/core/theme/app_colors.dart';
import 'package:rabbit_pdv/domain/entities/pagamento.dart';
import 'package:rabbit_pdv/features/pagamento/presentation/controllers/payment_session_controller.dart';
import 'package:rabbit_pdv/features/pagamento/presentation/widgets/payment_footer.dart';
import 'package:rabbit_pdv/features/pagamento/presentation/widgets/payment_header.dart';
import 'package:rabbit_pdv/features/pagamento/presentation/widgets/payment_items_panel.dart';
import 'package:rabbit_pdv/features/pagamento/presentation/widgets/slices_panel.dart';

/// Abre o modal de pagamento com um controller JÁ hidratado (vindo do
/// store, por atendimento). Resolve com a lista de [Pagamento]s confirmados,
/// ou `null` se cancelar.
///
/// Diferente do Passo A: o controller NÃO é descartado aqui — quem é dono é
/// o [PaymentSessionStore]. Ao cancelar, [onCancelSave] persiste o snapshot.
Future<List<Pagamento>?> showPaymentModal(
  BuildContext context, {
  required PaymentSessionController controller,
  required VoidCallback onCancelSave,
}) {
  return showGeneralDialog<List<Pagamento>>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Modal de pagamento',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (_, __, ___) {
      return _PaymentModal(controller: controller, onCancelSave: onCancelSave);
    },
    transitionBuilder: (_, anim, __, child) {
      final eased = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: eased,
        child: ScaleTransition(
          scale: Tween(begin: 0.97, end: 1.0).animate(eased),
          child: child,
        ),
      );
    },
  );
}

class _PaymentModal extends StatefulWidget {
  final PaymentSessionController controller;
  final VoidCallback onCancelSave;
  const _PaymentModal({required this.controller, required this.onCancelSave});

  @override
  State<_PaymentModal> createState() => _PaymentModalState();
}

class _PaymentModalState extends State<_PaymentModal> {
  final _focusNode = FocusNode(debugLabel: 'payment_modal_root');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _onCancel() {
    widget.onCancelSave(); // salva o snapshot antes de fechar
    Navigator.of(context).pop(null);
  }

  void _onConfirm() {
    if (!widget.controller.podeConfirmar) return;
    final pagamentos = widget.controller.buildPagamentos();
    Navigator.of(context).pop(pagamentos);
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final k = event.logicalKey;
    if (k == LogicalKeyboardKey.escape) {
      _onCancel();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.f5) {
      _onConfirm();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKey,
      child: Stack(
        children: [
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(color: Colors.black.withValues(alpha: 0.45)),
            ),
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180, maxHeight: 720),
              child: Material(
                color: c.bg,
                borderRadius: BorderRadius.circular(16),
                clipBehavior: Clip.hardEdge,
                child: Column(
                  children: [
                    PaymentHeader(
                      atendimento: widget.controller.atendimento,
                      onClose: _onCancel,
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              flex: 3,
                              child: PaymentItemsPanel(
                                controller: widget.controller,
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              flex: 2,
                              child: SlicesPanel(
                                controller: widget.controller,
                                onConfirm: _onConfirm,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    PaymentFooter(
                      controller: widget.controller,
                      onCancel: _onCancel,
                      onConfirm: _onConfirm,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
