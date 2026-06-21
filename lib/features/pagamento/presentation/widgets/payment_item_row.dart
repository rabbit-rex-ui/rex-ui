import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:rabbit_pdv/core/format/brl_formatter.dart';
import 'package:rabbit_pdv/core/format/unidade_formatter.dart';
import 'package:rabbit_pdv/core/theme/app_colors.dart';
import 'package:rabbit_pdv/core/theme/app_text.dart';
import 'package:rabbit_pdv/domain/entities/item_atendimento.dart';
import 'package:rabbit_pdv/domain/enums/metodo_pagamento.dart';

/// Linha de item no painel esquerdo do modal. Stripe + check na cor do slice
/// a que pertence; chip mostra o MÉTODO da forma (vazio se a forma ainda não
/// tem método). O item SEMPRE pertence a algum slice (Restante = padrão), por
/// isso o check sempre aparece preenchido na cor da forma a que pertence.
class PaymentItemRow extends StatefulWidget {
  final ItemAtendimento item;

  /// Acento da forma a que o item pertence (inclui o Restante).
  final Color sliceColor;

  /// Método da forma a que o item pertence (null = sem método ainda).
  final MetodoPagamento? metodo;

  /// Acento da forma ATIVA; null = Restante ativo.
  final Color? activeColor;

  /// Item pertence à forma ativa?
  final bool assignedToActive;

  /// Clique habilitado (forma ativa é específica)?
  final bool selectable;

  final VoidCallback onTap;

  const PaymentItemRow({
    super.key,
    required this.item,
    required this.sliceColor,
    required this.metodo,
    required this.activeColor,
    required this.assignedToActive,
    required this.selectable,
    required this.onTap,
  });

  @override
  State<PaymentItemRow> createState() => _PaymentItemRowState();
}

class _PaymentItemRowState extends State<PaymentItemRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final it = widget.item;

    return MouseRegion(
      cursor: widget.selectable
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.selectable ? widget.onTap : null,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.fromLTRB(14, 10, 20, 10),
          color: widget.selectable && _hover ? c.surface2 : Colors.transparent,
          child: Row(
            children: [
              Container(
                width: 4,
                height: 28,
                decoration: BoxDecoration(
                  color: widget.sliceColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              _check(c),
              const SizedBox(width: 12),
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
              _chip(c),
              const SizedBox(width: 12),
              Text(
                BrlFormatter.format(it.total),
                style: AppText.monoMd.copyWith(
                  color: c.text,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _check(AppColors c) {
    // Pertence à forma ativa → preenchido na cor do ativo, check branco.
    if (widget.assignedToActive) {
      return _box(
        fill: widget.activeColor ?? widget.sliceColor,
        border: widget.activeColor ?? widget.sliceColor,
        icon: LucideIcons.check,
        iconColor: Colors.white,
      );
    }
    // Pertence a OUTRA forma → preenchido surface, borda+check na cor dela.
    // (inclui o caso Restante quando outra forma está ativa)
    return _box(
      fill: c.surface,
      border: widget.sliceColor,
      icon: LucideIcons.check,
      iconColor: widget.sliceColor,
    );
  }

  Widget _box({
    required Color fill,
    required Color border,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border, width: 1.5),
      ),
      child: Icon(icon, size: 14, color: iconColor),
    );
  }

  Widget _chip(AppColors c) {
    final label = widget.metodo?.label.toUpperCase() ?? '';
    if (label.isEmpty) {
      // Sem método ainda → chip vazio (mantém o espaço pra simetria).
      return const SizedBox(width: 0);
    }
    final cor = widget.sliceColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: AppText.overline.copyWith(color: cor, fontSize: 9.5),
      ),
    );
  }
}
