import 'package:flutter/material.dart';

import 'package:rabbit_pdv/core/format/brl_formatter.dart';
import 'package:rabbit_pdv/core/format/unidade_formatter.dart';
import 'package:rabbit_pdv/core/theme/app_colors.dart';
import 'package:rabbit_pdv/core/theme/app_text.dart';
import 'package:rabbit_pdv/domain/entities/produto.dart';
import 'package:rabbit_pdv/domain/enums/unidade_medida.dart';

class CategoryChips extends StatelessWidget {
  final List<String> categorias;
  final String? value;
  final ValueChanged<String> onChange;
  final Map<String, int> countsByCat;

  const CategoryChips({
    super.key,
    required this.categorias,
    required this.value,
    required this.onChange,
    this.countsByCat = const {},
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.borderSoft)),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categorias.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final cat = categorias[i];
          final selected = cat == value;
          final count = countsByCat[cat];
          return _Chip(
            label: cat,
            count: count,
            selected: selected,
            onTap: () => onChange(cat),
          );
        },
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final int? count;
  final bool selected;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: selected ? c.accent : c.surface2,
            border: Border.all(color: selected ? c.accent : c.border),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: AppText.body.copyWith(
                  color: selected ? c.accentInk : c.text,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  fontSize: 12.5,
                ),
              ),
              if (count != null) ...[
                const SizedBox(width: 6),
                Text(
                  '$count',
                  style: AppText.monoSm.copyWith(
                    color: selected
                        ? c.accentInk.withValues(alpha: 0.65)
                        : c.textMute,
                    fontSize: 10,
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

class CategoryGrid extends StatelessWidget {
  final List<String> categorias;
  final String? categoriaSelecionada;
  final List<Produto> produtos;
  final Map<String, double> qtdPorSku;
  final ValueChanged<String> onCategoryChange;
  final ValueChanged<Produto> onProductTap;

  const CategoryGrid({
    super.key,
    required this.categorias,
    required this.categoriaSelecionada,
    required this.produtos,
    required this.qtdPorSku,
    required this.onCategoryChange,
    required this.onProductTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CategoryChips(
          categorias: categorias,
          value: categoriaSelecionada,
          onChange: onCategoryChange,
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.4,
            ),
            itemCount: produtos.length,
            itemBuilder: (_, i) {
              final p = produtos[i];
              final qtd = qtdPorSku[p.sku];
              return ProductCard(
                produto: p,
                qtyInCart: qtd != null ? UnidadeFormatter.format(qtd, p.un) : null,
                onTap: () => onProductTap(p),
              );
            },
          ),
        ),
      ],
    );
  }
}

class ProductCard extends StatefulWidget {
  final Produto produto;
  final String? qtyInCart;
  final VoidCallback onTap;

  const ProductCard({
    super.key,
    required this.produto,
    required this.onTap,
    this.qtyInCart,
  });

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final p = widget.produto;
    final pesavel = p.un == UnidadeMedida.kg;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _hover ? c.surface3 : c.surface2,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: c.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          p.categoria.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.overline.copyWith(
                            color: c.textMute,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      if (pesavel)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: c.warnTint,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'PESÁVEL',
                            style: TextStyle(
                              color: c.warn,
                              fontFamily: 'Inter',
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    p.nome,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.bodySm.copyWith(
                      color: c.text,
                      fontWeight: FontWeight.w500,
                      height: 1.25,
                    ),
                  ),
                  const Spacer(),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        BrlFormatter.format(p.preco),
                        style: AppText.monoMd.copyWith(
                          color: c.accent,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 1),
                        child: Text(
                          pesavel ? '/kg' : 'est. ${p.estoque}',
                          style: AppText.monoSm.copyWith(
                            color: c.textDim,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (widget.qtyInCart != null)
              Positioned(
                left: -6,
                bottom: -6,
                child: Container(
                  height: 22,
                  padding: const EdgeInsets.symmetric(horizontal: 7),
                  decoration: BoxDecoration(
                    color: c.success,
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: c.surface, width: 2),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check, size: 10, color: c.successInk),
                      const SizedBox(width: 4),
                      Text(
                        widget.qtyInCart!,
                        style: AppText.monoSm.copyWith(
                          color: c.successInk,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
