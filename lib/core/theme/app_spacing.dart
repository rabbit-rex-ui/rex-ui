import 'package:flutter/widgets.dart';

/// Sistema de espaçamento base 4. Use sempre estes tokens — não literais.
class AppSpacing {
  AppSpacing._();

  static const double s1 = 4;
  static const double s2 = 8;
  static const double s3 = 10;
  static const double s4 = 12;
  static const double s5 = 14;
  static const double s6 = 16;
  static const double s7 = 20;
  static const double s8 = 24;
}

class AppRadius {
  AppRadius._();

  static const double sm = 5;
  static const double md = 8;
  static const double lg = 12;
  static const double xl = 14;
  static const double full = 9999;

  static const BorderRadius brSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius brMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius brLg = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius brXl = BorderRadius.all(Radius.circular(xl));
}

class AppShadows {
  AppShadows._();

  static const List<BoxShadow> sm = [
    BoxShadow(color: Color(0x14000000), blurRadius: 2, offset: Offset(0, 1)),
  ];

  static const List<BoxShadow> md = [
    BoxShadow(color: Color(0x1F000000), blurRadius: 6, offset: Offset(0, 2)),
  ];

  static const List<BoxShadow> lg = [
    BoxShadow(color: Color(0x2E000000), blurRadius: 36, offset: Offset(0, 12)),
  ];

  static const List<BoxShadow> xl = [
    BoxShadow(color: Color(0x66000000), blurRadius: 80, offset: Offset(0, 24)),
  ];
}

/// Durações canônicas para animações da UI.
class AppDurations {
  AppDurations._();

  /// Flash de confirmação do scanner (verde / vermelho).
  static const Duration flash = Duration(milliseconds: 500);

  /// Loop do dot pulsante "em digitação".
  static const Duration pulse = Duration(milliseconds: 1400);

  /// Toggle/segmented/troca de aba.
  static const Duration swap = Duration(milliseconds: 150);

  /// Hover de cards de produto.
  static const Duration hover = Duration(milliseconds: 120);
}
