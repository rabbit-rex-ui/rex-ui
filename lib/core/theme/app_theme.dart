import 'package:flutter/material.dart';

import 'package:rabbit_pdv/core/theme/app_colors.dart';
import 'package:rabbit_pdv/core/theme/app_text.dart';

/// Constrói o [ThemeData] a partir do conjunto semântico [AppColors].
///
/// Os ThemeData do Material são deixados sóbrios — o app não usa o sistema
/// de cores padrão do Material. Toda a UI consome `context.colors`.
ThemeData buildTheme({required bool dark}) {
  final colors = dark ? AppColors.dark : AppColors.light;

  return ThemeData(
    useMaterial3: true,
    brightness: dark ? Brightness.dark : Brightness.light,
    scaffoldBackgroundColor: colors.bg,
    canvasColor: colors.bg,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    hoverColor: colors.surface3.withValues(alpha: 0.4),
    dividerColor: colors.borderSoft,
    extensions: [colors],
    textTheme: _buildTextTheme(colors),
    iconTheme: IconThemeData(color: colors.text, size: 18),
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    colorScheme: ColorScheme(
      brightness: dark ? Brightness.dark : Brightness.light,
      primary: colors.accent,
      onPrimary: colors.accentInk,
      secondary: colors.accent,
      onSecondary: colors.accentInk,
      surface: colors.surface,
      onSurface: colors.text,
      error: colors.danger,
      onError: colors.accentInk,
    ),
  );
}

TextTheme _buildTextTheme(AppColors colors) {
  // Cada estilo recebe a cor padrão de texto. Componentes específicos
  // sobreescrevem quando precisam (ex: valor monetário em accent).
  TextStyle c(TextStyle s) => s.copyWith(color: colors.text);

  return TextTheme(
    displayLarge: c(AppText.display),
    headlineLarge: c(AppText.h1),
    headlineMedium: c(AppText.h2),
    titleLarge: c(AppText.h3),
    bodyLarge: c(AppText.body),
    bodyMedium: c(AppText.bodySm),
    bodySmall: c(AppText.caption),
    labelSmall: c(AppText.overline),
  );
}
