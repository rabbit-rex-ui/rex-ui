import 'package:flutter/material.dart';

import 'package:rabbit_pdv/core/theme/app_colors.dart';
import 'package:rabbit_pdv/core/theme/app_text.dart';

enum BrandSize { sm, md, lg }

/// Logotipo + nome + identificação da loja/caixa.
class AppBrand extends StatelessWidget {
  final BrandSize size;
  final String loja;
  final String caixa;

  const AppBrand({
    super.key,
    this.size = BrandSize.md,
    this.loja = 'Loja 01',
    this.caixa = 'Caixa 03',
  });

  double get _logoSize => switch (size) {
    BrandSize.sm => 26,
    BrandSize.md => 30,
    BrandSize.lg => 34,
  };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: _logoSize,
          height: _logoSize,
          decoration: BoxDecoration(
            color: c.accent,
            borderRadius: BorderRadius.circular(_logoSize / 4),
          ),
          alignment: Alignment.center,
          child: Text(
            'R',
            style: TextStyle(
              color: c.accentInk,
              fontFamily: 'Inter',
              fontSize: _logoSize * 0.55,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Rabbit PDV',
              style: AppText.body.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: c.text,
                height: 1.2,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
