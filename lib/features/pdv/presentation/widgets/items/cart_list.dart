import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:rabbit_pdv/core/format/brl_formatter.dart';
import 'package:rabbit_pdv/core/format/unidade_formatter.dart';
import 'package:rabbit_pdv/core/theme/app_colors.dart';
import 'package:rabbit_pdv/core/theme/app_text.dart';
import 'package:rabbit_pdv/domain/entities/item_atendimento.dart';

class CartList extends StatelessWidget {
  final List<ItemAtendimento> items;
  final void Function(ItemAtendimento, double delta) onAdjustQty;
  final void Function(ItemAtendimento) onRemove;

  const CartList({
    super.key,
    required this.items,
    required this.onAdjustQty,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const _EmptyState();

    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: items.length,
      itemBuilder: (_, i) {
        return CartItemRow(
          item: items[i],
          onAdjustQty: (d) => onAdjustQty(items[i], d),
          onRemove: () => onRemove(items[i]),
        );
      },
    );
  }
}

class CartItemRow extends StatelessWidget {
  final ItemAtendimento item;
  final void Function(double delta) onAdjustQty;
  final VoidCallback onRemove;

  const CartItemRow({
    super.key,
    required this.item,
    required this.onAdjustQty,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final skuTail = item.sku.length > 7
        ? item.sku.substring(item.sku.length - 7)
        : item.sku;
    final precoSuffix = UnidadeFormatter.suffix(item.un);

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.borderSoft)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: c.surface2,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(LucideIcons.shoppingBag, size: 18, color: c.textMute),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.nome,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body.copyWith(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: c.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$skuTail · ${BrlFormatter.format(item.preco)}$precoSuffix',
                  style: AppText.monoSm.copyWith(
                    color: c.textMute,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _Stepper(
            qtdLabel: UnidadeFormatter.format(item.qtd, item.un),
            onMinus: () => onAdjustQty(-UnidadeFormatter.step(item.un)),
            onPlus: () => onAdjustQty(UnidadeFormatter.step(item.un)),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 80,
            child: Text(
              BrlFormatter.format(item.total),
              textAlign: TextAlign.right,
              style: AppText.monoMd.copyWith(
                color: c.text,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 4),
          _IconBtn(
            icon: LucideIcons.trash2,
            tooltip: 'Remover item',
            color: c.textDim,
            onTap: onRemove,
          ),
        ],
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  final String qtdLabel;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  const _Stepper({
    required this.qtdLabel,
    required this.onMinus,
    required this.onPlus,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      height: 26,
      decoration: BoxDecoration(
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepperBtn(icon: LucideIcons.minus, onTap: onMinus),
          SizedBox(
            width: 56,
            child: Center(
              child: Text(
                qtdLabel,
                style: AppText.monoSm.copyWith(
                  color: c.text,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          _StepperBtn(icon: LucideIcons.plus, onTap: onPlus),
        ],
      ),
    );
  }
}

class _StepperBtn extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _StepperBtn({required this.icon, required this.onTap});

  @override
  State<_StepperBtn> createState() => _StepperBtnState();
}

class _StepperBtnState extends State<_StepperBtn> {
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
          height: 24,
          color: _hover ? c.surface3 : Colors.transparent,
          child: Icon(widget.icon, size: 12, color: c.text),
        ),
      ),
    );
  }
}

class _IconBtn extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;

  const _IconBtn({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });

  @override
  State<_IconBtn> createState() => _IconBtnState();
}

class _IconBtnState extends State<_IconBtn> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: _hover ? c.dangerTint : Colors.transparent,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Icon(
              widget.icon,
              size: 14,
              color: _hover ? c.danger : widget.color,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: c.surface2,
              shape: BoxShape.circle,
            ),
            child: Icon(LucideIcons.shoppingCart, size: 26, color: c.textMute),
          ),
          const SizedBox(height: 14),
          Text(
            'Nenhum item ainda',
            style: AppText.h3.copyWith(color: c.text),
          ),
          const SizedBox(height: 4),
          Text(
            "Leia o código ou troque para a aba 'Atalhos'",
            style: AppText.bodySm.copyWith(color: c.textMute),
          ),
        ],
      ),
    );
  }
}
