import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Brand constants for the "Oxford & Kirtipur Academic Editorial" system.
abstract final class Brand {
  static const navy = Color(0xFF0F172A);
  static const slate = Color(0xFF1E293B);
  static const ivory = Color(0xFFFAF8F5);
  static const night = Color(0xFF0B0F19);
  static const crimson = Color(0xFF8B1E24);
  static const crimsonLight = Color(0xFFE07A80);
  static const gold = Color(0xFFC59B27);
  static const goldLight = Color(0xFFE2BE5A);
}

/// Semantic colours that Material's ColorScheme doesn't cover.
@immutable
class Palette extends ThemeExtension<Palette> {
  const Palette({
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.ink,
    required this.muted,
    required this.border,
    required this.accent,
    required this.gold,
    required this.glass,
  });

  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color ink;
  final Color muted;
  final Color border;
  final Color accent; // crimson, tuned per mode for contrast
  final Color gold;
  final Color glass;

  static const light = Palette(
    background: Brand.ivory,
    surface: Colors.white,
    surfaceAlt: Color(0xFFF2EEE7),
    ink: Brand.navy,
    muted: Color(0xFF55607A),
    border: Color(0xFFE4DED3),
    accent: Brand.crimson,
    gold: Color(0xFF9E7A16),
    glass: Color(0xCCFAF8F5),
  );

  static const dark = Palette(
    background: Brand.night,
    surface: Color(0xFF131A2A),
    surfaceAlt: Brand.slate,
    ink: Color(0xFFF1EDE6),
    muted: Color(0xFF9CA6BA),
    border: Color(0xFF263149),
    accent: Brand.crimsonLight,
    gold: Brand.goldLight,
    glass: Color(0xB30B0F19),
  );

  @override
  Palette copyWith() => this;

  @override
  Palette lerp(ThemeExtension<Palette>? other, double t) {
    if (other is! Palette) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return Palette(
      background: l(background, other.background),
      surface: l(surface, other.surface),
      surfaceAlt: l(surfaceAlt, other.surfaceAlt),
      ink: l(ink, other.ink),
      muted: l(muted, other.muted),
      border: l(border, other.border),
      accent: l(accent, other.accent),
      gold: l(gold, other.gold),
      glass: l(glass, other.glass),
    );
  }
}

extension ThemeX on BuildContext {
  Palette get palette => Theme.of(this).extension<Palette>()!;
  TextTheme get text => Theme.of(this).textTheme;

  /// JetBrains Mono, for formulas, DOIs, ORCID iDs and metrics.
  TextStyle mono({double size = 13, FontWeight weight = FontWeight.w500, Color? color}) =>
      GoogleFonts.jetBrainsMono(fontSize: size, fontWeight: weight, color: color ?? palette.ink);
}

ThemeData buildTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final p = isDark ? Palette.dark : Palette.light;

  final scheme = ColorScheme.fromSeed(
    seedColor: Brand.navy,
    brightness: brightness,
  ).copyWith(
    primary: isDark ? Brand.goldLight : Brand.navy,
    onPrimary: isDark ? Brand.night : Colors.white,
    secondary: p.accent,
    onSecondary: Colors.white,
    tertiary: p.gold,
    surface: p.surface,
    onSurface: p.ink,
    outline: p.border,
  );

  final body = GoogleFonts.plusJakartaSansTextTheme(
    ThemeData(brightness: brightness).textTheme,
  ).apply(bodyColor: p.ink, displayColor: p.ink);

  TextStyle serif(TextStyle? base, {FontWeight w = FontWeight.w700}) =>
      GoogleFonts.playfairDisplay(textStyle: base, fontWeight: w, color: p.ink, height: 1.15);

  final textTheme = body.copyWith(
    displayLarge: serif(body.displayLarge),
    displayMedium: serif(body.displayMedium),
    displaySmall: serif(body.displaySmall),
    headlineLarge: serif(body.headlineLarge),
    headlineMedium: serif(body.headlineMedium),
    headlineSmall: serif(body.headlineSmall, w: FontWeight.w600),
    titleLarge: serif(body.titleLarge, w: FontWeight.w600),
    bodyLarge: body.bodyLarge?.copyWith(height: 1.65),
    bodyMedium: body.bodyMedium?.copyWith(height: 1.6, color: p.muted),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: p.background,
    textTheme: textTheme,
    extensions: [p],
    dividerColor: p.border,
    cardTheme: CardThemeData(
      color: p.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: p.border),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: p.surface,
      selectedColor: isDark ? Brand.goldLight.withValues(alpha: 0.18) : Brand.navy,
      side: BorderSide(color: p.border),
      labelStyle: body.labelLarge?.copyWith(color: p.ink),
      secondaryLabelStyle: body.labelLarge?.copyWith(color: isDark ? Brand.goldLight : Colors.white),
      checkmarkColor: isDark ? Brand.goldLight : Colors.white,
      shape: const StadiumBorder(),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.surface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: p.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: p.border)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: scheme.primary, width: 1.6),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: body.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: p.ink,
        side: BorderSide(color: p.border),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: body.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(color: Brand.slate, borderRadius: BorderRadius.circular(6)),
      textStyle: const TextStyle(color: Colors.white, fontSize: 12),
    ),
  );
}
