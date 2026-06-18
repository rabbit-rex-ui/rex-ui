import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:rabbit_pdv/core/format/brl_formatter.dart';
import 'package:rabbit_pdv/core/format/unidade_formatter.dart';
import 'package:rabbit_pdv/core/theme/app_colors.dart';
import 'package:rabbit_pdv/core/theme/app_text.dart';
import 'package:rabbit_pdv/domain/entities/atendimento.dart';

/// Cabeçalho do modal: identificação do atendimento à esquerda + total
/// destacado à direita + botão de fechar.
class PaymentHeader extends StatelessWidget {
  final Atendimento atendimento;
  final VoidCallback onClose;

  const PaymentHeader({
    super.key,
    required this.atendimento,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ordem = atendimento.ordem.toString().padLeft(2, '0');

    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: Row(
        children: [
          // ---- Identificação ----
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PAGAMENTO · ATD #$ordem',
                  style: AppText.overline.copyWith(color: c.textMute),
                ),
                const SizedBox(height: 4),
                Text(
                  atendimento.cliente.nome,
                  style: AppText.h3.copyWith(
                    color: c.text,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // ---- Total da venda ----
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'TOTAL DA VENDA',
                style: AppText.overline.copyWith(color: c.textMute),
              ),
              const SizedBox(height: 4),
              Text(
                BrlFormatter.format(atendimento.total),
                style: AppText.monoLg.copyWith(
                  color: c.text,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          _CloseButton(onTap: onClose),
        ],
      ),
    );
  }
}

class _CloseButton extends StatefulWidget {
  final VoidCallback onTap;
  const _CloseButton({required this.onTap});

  @override
  State<_CloseButton> createState() => _CloseButtonState();
}

class _CloseButtonState extends State<_CloseButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Tooltip(
      message: 'Fechar (Esc)',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _hover ? c.surface3 : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              LucideIcons.x,
              size: 22,
              color: _hover ? c.danger : c.textMute,
            ),
          ),
        ),
      ),
    );
  }
}

/// Lista de itens da venda à esquerda. No Passo A é informativa apenas
/// (não dá pra clicar pra atribuir). No Passo B, cada row será tocável
/// pra atribuir ao slice ativo.
class PaymentItemsList extends StatelessWidget {
  final Atendimento atendimento;

  const PaymentItemsList({super.key, required this.atendimento});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final itens = atendimento.itens;

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 16),
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
                  '${atendimento.numItens} ${atendimento.numItens == 1 ? "item" : "itens"}',
                  style: AppText.bodySm.copyWith(
                    color: c.textDim,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 6),
              itemCount: itens.length,
              separatorBuilder: (_, __) =>
                  Divider(color: c.borderSoft, height: 1),
              itemBuilder: (_, i) {
                final it = itens[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              it.nome,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.body.copyWith(
                                color: c.text,
                                fontSize: 13.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${UnidadeFormatter.format(it.qtd, it.un)} × ${BrlFormatter.format(it.preco)}',
                              style: AppText.monoSm.copyWith(
                                color: c.textDim,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        BrlFormatter.format(it.total),
                        style: AppText.monoMd.copyWith(
                          color: c.text,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
