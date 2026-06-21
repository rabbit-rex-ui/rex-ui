import 'package:flutter/material.dart';

import 'package:rabbit_pdv/core/theme/app_colors.dart';
import 'package:rabbit_pdv/core/theme/app_text.dart';
import 'package:rabbit_pdv/features/pagamento/domain/payment_slice.dart';
import 'package:rabbit_pdv/features/pagamento/presentation/controllers/payment_session_controller.dart';
import 'package:rabbit_pdv/features/pagamento/presentation/widgets/payment_item_row.dart';

/// Painel esquerdo do modal: lista de itens com atribuição por slice.
/// Todo item pertence a alguma forma (Restante = padrão), então sempre mostra
/// check preenchido na cor da forma a que pertence.
class PaymentItemsPanel extends StatelessWidget {
  final PaymentSessionController controller;

  const PaymentItemsPanel({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
      clipBehavior: Clip.hardEdge,
      child: ListenableBuilder(
        listenable: controller,
        builder: (_, __) {
          final itens = controller.atendimento.itens;
          final ativo = controller.activeSlice;
          final n = itens.length;
          final restante = controller.slices.firstWhere((s) => s.isRestante);
          final ativoAcento = ativo.isRestante
              ? null
              : SliceColors.accent(ativo.colorIndex, dark: dark);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 16, 12),
                decoration: BoxDecoration(
                  color: c.surface2,
                  border: Border(bottom: BorderSide(color: c.border)),
                ),
                child: Row(
                  children: [
                    Text(
                      'ITENS DA VENDA',
                      style: AppText.overline.copyWith(color: c.textMute),
                    ),
                    const Spacer(),
                    Text(
                      '$n ${n == 1 ? "item" : "itens"}',
                      style: AppText.bodySm.copyWith(
                        color: c.textDim,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              _statusBar(c, ativo.isRestante, ativoAcento),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: itens.length,
                  separatorBuilder: (_, __) =>
                      Divider(color: c.borderSoft, height: 1),
                  itemBuilder: (_, i) {
                    final it = itens[i];
                    final sliceId = controller.sliceDoItem(it.id);
                    // Forma a que o item pertence: a específica, ou o Restante.
                    final slice = sliceId == null
                        ? restante
                        : controller.slices.firstWhere((s) => s.id == sliceId);
                    final pertenceAoAtivo = slice.id == ativo.id;
                    return PaymentItemRow(
                      item: it,
                      sliceColor: SliceColors.accent(
                        slice.colorIndex,
                        dark: dark,
                      ),
                      metodo: slice.metodo,
                      activeColor: ativoAcento,
                      assignedToActive: pertenceAoAtivo,
                      selectable: !ativo.isRestante,
                      onTap: () => controller.toggleItem(it.id),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _statusBar(AppColors c, bool restanteAtivo, Color? acento) {
    final bg = restanteAtivo
        ? c.surface2
        : (acento ?? c.accent).withValues(alpha: 0.10);
    final fg = restanteAtivo ? c.textMute : (acento ?? c.accent);
    final msg = restanteAtivo
        ? 'Forma padrão — adicione outra forma para dividir os itens'
        : 'Clique nos itens para atribuir a esta forma';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        border: Border(bottom: BorderSide(color: c.borderSoft)),
      ),
      child: Text(
        msg,
        style: AppText.bodySm.copyWith(color: fg, fontWeight: FontWeight.w500),
      ),
    );
  }
}
