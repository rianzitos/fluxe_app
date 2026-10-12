import 'package:flutter/material.dart';

/// Cores fixas da identidade SICAPDA / Fluxe (iguais às do painel web).
class AppColors {
  static const Color black = Color(0xFF0D0D0D);
  static const Color blackSoft = Color(0xFF17171A);
  static const Color accent = Color(0xFFFFC107);
  static const Color accentText = Color(0xFF8A6500);
  static const Color purple = Color(0xFF7C3AED);
  static const Color red = Color(0xFFEF4444);
  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFD97706);
  static const Color info = Color(0xFF2563EB);

  // Tela de login (sempre escura)
  static const Color loginField = Color(0xFF1A1A1A);
  static const Color loginBorder = Color(0xFF2A2A2A);
  static const Color loginMuted = Color(0xFFB0B0B0);
  static const Color loginHint = Color(0xFF6E6E6E);
}

/// Cores que mudam entre tema claro e escuro (variáveis CSS do painel web).
class AppPalette extends ThemeExtension<AppPalette> {
  final Color background;
  final Color card;
  final Color text;
  final Color textMuted;
  final Color border;
  final Color accentSoft;
  final Color successBg;
  final Color warningBg;
  final Color infoBg;
  final Color chip;

  const AppPalette({
    required this.background,
    required this.card,
    required this.text,
    required this.textMuted,
    required this.border,
    required this.accentSoft,
    required this.successBg,
    required this.warningBg,
    required this.infoBg,
    required this.chip,
  });

  static const light = AppPalette(
    background: Color(0xFFF4F5F9),
    card: Color(0xFFFFFFFF),
    text: Color(0xFF16171B),
    textMuted: Color(0xFF6B7280),
    border: Color(0xFFE7E8EE),
    accentSoft: Color(0xFFFFF4CC),
    successBg: Color(0xFFEAF9EF),
    warningBg: Color(0xFFFFF6E5),
    infoBg: Color(0xFFEAF1FF),
    chip: Color(0xFFF4F5F9),
  );

  static const dark = AppPalette(
    background: Color(0xFF121214),
    card: Color(0xFF1B1B1F),
    text: Color(0xFFF4F4F6),
    textMuted: Color(0xFF9A9AA3),
    border: Color(0xFF2C2C31),
    accentSoft: Color(0x24FFC107),
    successBg: Color(0x2916A34A),
    warningBg: Color(0x29D97706),
    infoBg: Color(0x292563EB),
    chip: Color(0xFF26262B),
  );

  @override
  AppPalette copyWith() => this;

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppPalette(
      background: l(background, other.background),
      card: l(card, other.card),
      text: l(text, other.text),
      textMuted: l(textMuted, other.textMuted),
      border: l(border, other.border),
      accentSoft: l(accentSoft, other.accentSoft),
      successBg: l(successBg, other.successBg),
      warningBg: l(warningBg, other.warningBg),
      infoBg: l(infoBg, other.infoBg),
      chip: l(chip, other.chip),
    );
  }
}

extension PaletteContext on BuildContext {
  AppPalette get pal => Theme.of(this).extension<AppPalette>()!;
}

/// Estilos de texto: Sora nos títulos e Inter no resto, como na web.
class AppText {
  static const String body = 'Inter';
  static const String heading = 'Sora';

  static TextStyle title(BuildContext c, {double size = 22}) => TextStyle(
        fontFamily: heading,
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: c.pal.text,
        height: 1.2,
      );

  static TextStyle value(BuildContext c, {double size = 30}) => TextStyle(
        fontFamily: heading,
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: c.pal.text,
        height: 1.1,
      );

  static TextStyle muted(BuildContext c, {double size = 13}) =>
      TextStyle(fontSize: size, color: c.pal.textMuted, height: 1.35);

  static TextStyle strong(BuildContext c, {double size = 14}) => TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w600,
        color: c.pal.text,
        height: 1.3,
      );
}

ThemeData buildTheme(Brightness brightness) {
  final pal = brightness == Brightness.dark ? AppPalette.dark : AppPalette.light;
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.accent,
    brightness: brightness,
  ).copyWith(
    primary: AppColors.accent,
    onPrimary: Colors.black,
    surface: pal.card,
    onSurface: pal.text,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    fontFamily: AppText.body,
    colorScheme: scheme,
    scaffoldBackgroundColor: pal.background,
    canvasColor: pal.background,
    dividerColor: pal.border,
    extensions: [pal],
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.blackSoft,
      contentTextStyle: const TextStyle(color: Colors.white, fontFamily: AppText.body),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: pal.card,
      indicatorColor: AppColors.accent,
      surfaceTintColor: Colors.transparent,
      iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
            color: s.contains(WidgetState.selected) ? Colors.black : pal.textMuted,
          )),
      labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: s.contains(WidgetState.selected) ? pal.text : pal.textMuted,
          )),
    ),
  );
}
