import 'package:flutter/widgets.dart';

/// Escala tipográfica conforme `docs/02-design-tokens.md`.
///
/// Inter para UI; JetBrainsMono para valores numéricos, SKUs e códigos.
/// Para garantir alinhamento de colunas de valores, mono usa
/// [FontFeature.tabularFigures].
///
/// Se as fontes não estiverem empacotadas, o fallback é a fonte padrão do
/// Material — visualmente próximo, mas para produção empacote os .ttf
/// (ver `pubspec.yaml`).
class AppText {
  static const _inter = 'Inter';
  static const _mono = 'JetBrainsMono';

  static const _tabular = [FontFeature.tabularFigures()];

  // ---- Inter (UI geral) -----------------------------------------------------
  static const TextStyle h1 = TextStyle(
    fontFamily: _inter,
    fontSize: 22,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );

  static const TextStyle h2 = TextStyle(
    fontFamily: _inter,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.25,
  );

  static const TextStyle h3 = TextStyle(
    fontFamily: _inter,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  static const TextStyle body = TextStyle(
    fontFamily: _inter,
    fontSize: 13.5,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );

  static const TextStyle bodySm = TextStyle(
    fontFamily: _inter,
    fontSize: 12.5,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: _inter,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 1.3,
  );

  static const TextStyle overline = TextStyle(
    fontFamily: _inter,
    fontSize: 10.5,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: 0.6,
  );

  // ---- JetBrainsMono (valores) ---------------------------------------------
  static const TextStyle display = TextStyle(
    fontFamily: _mono,
    fontSize: 36,
    fontWeight: FontWeight.w700,
    height: 1,
    letterSpacing: -0.6,
    fontFeatures: _tabular,
  );

  static const TextStyle monoLg = TextStyle(
    fontFamily: _mono,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1,
    fontFeatures: _tabular,
  );

  static const TextStyle monoMd = TextStyle(
    fontFamily: _mono,
    fontSize: 13.5,
    fontWeight: FontWeight.w600,
    height: 1,
    fontFeatures: _tabular,
  );

  static const TextStyle monoSm = TextStyle(
    fontFamily: _mono,
    fontSize: 11.5,
    fontWeight: FontWeight.w500,
    height: 1,
    fontFeatures: _tabular,
  );
}
