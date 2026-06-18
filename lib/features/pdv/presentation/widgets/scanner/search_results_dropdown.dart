import 'package:flutter/material.dart';

import 'package:rabbit_pdv/core/format/brl_formatter.dart';
import 'package:rabbit_pdv/core/theme/app_colors.dart';
import 'package:rabbit_pdv/core/theme/app_spacing.dart';
import 'package:rabbit_pdv/core/theme/app_text.dart';
import 'package:rabbit_pdv/domain/entities/produto.dart';

class SearchResultsDropdown extends StatelessWidget {
  final List<Produto> results;
  final String query;
  final int highlightedIdx;
  final void Function(Produto) onSelect;
  final void Function(int) onHover;

  const SearchResultsDropdown({
    super.key,
    required this.results,
    required this.query,
    required this.highlightedIdx,
    required this.onSelect,
    required this.onHover,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final shown = results.take(5).toList();

    return Container(
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.border),
        boxShadow: AppShadows.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
            child: Row(
              children: [
                Text(
                  '${shown.length} ${shown.length == 1 ? "RESULTADO" : "RESULTADOS"}',
                  style: AppText.overline.copyWith(color: c.textMute),
                ),
                const Spacer(),
                Text(
                  '↑↓ · ENTER',
                  style: AppText.overline.copyWith(color: c.textDim, fontSize: 9.5),
                ),
              ],
            ),
          ),
          Divider(color: c.borderSoft, height: 1),
          for (int i = 0; i < shown.length; i++)
            _ResultRow(
              produto: shown[i],
              highlighted: i == highlightedIdx,
              onTap: () => onSelect(shown[i]),
              onHover: () => onHover(i),
            ),
        ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final Produto produto;
  final bool highlighted;
  final VoidCallback onTap;
  final VoidCallback onHover;

  const _ResultRow({
    required this.produto,
    required this.highlighted,
    required this.onTap,
    required this.onHover,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return MouseRegion(
      onEnter: (_) => onHover(),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: highlighted ? c.accentTint : Colors.transparent,
            border: Border(bottom: BorderSide(color: c.borderSoft)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      produto.nome,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body.copyWith(
                        color: c.text,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${produto.sku.substring(produto.sku.length - 7)} · ${produto.categoria}',
                      style: AppText.monoSm.copyWith(color: c.textMute),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                BrlFormatter.format(produto.preco),
                style: AppText.monoMd.copyWith(
                  color: c.accent,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
