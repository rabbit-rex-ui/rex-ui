import 'package:flutter/material.dart';

/// Paleta semântica do PDV. Vive como [ThemeExtension] no [ThemeData].
///
/// Use sempre via `context.colors` (ver [AppColorsX] abaixo). Não pegue cores
/// hard-coded em widgets — toda cor passa por este token.
///
/// As cores aqui são derivadas de oklch (ver `docs/02-design-tokens.md`).
/// Os hex aproximados podem ter pequena divergência perceptual; é aceitável.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  final Color bg;
  final Color surface;
  final Color surface2;
  final Color surface3;
  final Color border;
  final Color borderSoft;
  final Color text;
  final Color textMute;
  final Color textDim;
  final Color accent;
  final Color accentInk;
  final Color success;
  final Color successInk;
  final Color warn;
  final Color danger;
  final Color focusRing;

  /// Tintes leves de cada cor semântica — usados em backgrounds de pílulas,
  /// chips e badges (ex: success com alpha em torno de 0.18).
  final Color successTint;
  final Color warnTint;
  final Color dangerTint;
  final Color accentTint;

  const AppColors({
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.surface3,
    required this.border,
    required this.borderSoft,
    required this.text,
    required this.textMute,
    required this.textDim,
    required this.accent,
    required this.accentInk,
    required this.success,
    required this.successInk,
    required this.warn,
    required this.danger,
    required this.focusRing,
    required this.successTint,
    required this.warnTint,
    required this.dangerTint,
    required this.accentTint,
  });

  // ---------------------------------------------------------------------------
  // Tema claro
  // ---------------------------------------------------------------------------
  static const light = AppColors(
    bg: Color(0xFFF4F5F7),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFEFF1F4),
    surface3: Color(0xFFE5E8EC),
    border: Color(0xFFDCE0E6),
    borderSoft: Color(0xFFEAEDF1),
    text: Color(0xFF1F232A),
    textMute: Color(0xFF5C6470),
    textDim: Color(0xFF838995),
    accent: Color(0xFF3D6FA8),
    accentInk: Color(0xFFFBFCFD),
    success: Color(0xFF1E9D6F),
    successInk: Color(0xFF0A2A1F),
    warn: Color(0xFFC18A2C),
    danger: Color(0xFFC84A2F),
    focusRing: Color(0x403D6FA8),
    successTint: Color(0x2E1E9D6F), // ~18% alpha
    warnTint: Color(0x2EC18A2C),
    dangerTint: Color(0x2EC84A2F),
    accentTint: Color(0x1F3D6FA8), // ~12% alpha
  );

  // ---------------------------------------------------------------------------
  // Tema escuro
  // ---------------------------------------------------------------------------
  static const dark = AppColors(
    bg: Color(0xFF1F2329),
    surface: Color(0xFF272C33),
    surface2: Color(0xFF30353D),
    surface3: Color(0xFF383E47),
    border: Color(0xFF414751),
    borderSoft: Color(0xFF353A42),
    text: Color(0xFFF0F1F3),
    textMute: Color(0xFFA6ACB6),
    textDim: Color(0xFF73797F),
    accent: Color(0xFF7AA3CF),
    accentInk: Color(0xFF1B1F25),
    success: Color(0xFF5BC796),
    successInk: Color(0xFF0F1F18),
    warn: Color(0xFFDAB561),
    danger: Color(0xFFE27D5F),
    focusRing: Color(0x597AA3CF),
    successTint: Color(0x2E5BC796),
    warnTint: Color(0x2EDAB561),
    dangerTint: Color(0x2EE27D5F),
    accentTint: Color(0x297AA3CF),
  );

  @override
  AppColors copyWith({
    Color? bg,
    Color? surface,
    Color? surface2,
    Color? surface3,
    Color? border,
    Color? borderSoft,
    Color? text,
    Color? textMute,
    Color? textDim,
    Color? accent,
    Color? accentInk,
    Color? success,
    Color? successInk,
    Color? warn,
    Color? danger,
    Color? focusRing,
    Color? successTint,
    Color? warnTint,
    Color? dangerTint,
    Color? accentTint,
  }) {
    return AppColors(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surface2: surface2 ?? this.surface2,
      surface3: surface3 ?? this.surface3,
      border: border ?? this.border,
      borderSoft: borderSoft ?? this.borderSoft,
      text: text ?? this.text,
      textMute: textMute ?? this.textMute,
      textDim: textDim ?? this.textDim,
      accent: accent ?? this.accent,
      accentInk: accentInk ?? this.accentInk,
      success: success ?? this.success,
      successInk: successInk ?? this.successInk,
      warn: warn ?? this.warn,
      danger: danger ?? this.danger,
      focusRing: focusRing ?? this.focusRing,
      successTint: successTint ?? this.successTint,
      warnTint: warnTint ?? this.warnTint,
      dangerTint: dangerTint ?? this.dangerTint,
      accentTint: accentTint ?? this.accentTint,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surface2: Color.lerp(surface2, other.surface2, t)!,
      surface3: Color.lerp(surface3, other.surface3, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderSoft: Color.lerp(borderSoft, other.borderSoft, t)!,
      text: Color.lerp(text, other.text, t)!,
      textMute: Color.lerp(textMute, other.textMute, t)!,
      textDim: Color.lerp(textDim, other.textDim, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentInk: Color.lerp(accentInk, other.accentInk, t)!,
      success: Color.lerp(success, other.success, t)!,
      successInk: Color.lerp(successInk, other.successInk, t)!,
      warn: Color.lerp(warn, other.warn, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      focusRing: Color.lerp(focusRing, other.focusRing, t)!,
      successTint: Color.lerp(successTint, other.successTint, t)!,
      warnTint: Color.lerp(warnTint, other.warnTint, t)!,
      dangerTint: Color.lerp(dangerTint, other.dangerTint, t)!,
      accentTint: Color.lerp(accentTint, other.accentTint, t)!,
    );
  }
}

/// Atalho ergonômico para acessar as cores semânticas do contexto.
extension AppColorsX on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}
