import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppPalette {
  // Light — warm paper
  static const lightBg = Color(0xFFF6F1E7);
  static const lightSurface = Color(0xFFFBF7EE);
  static const lightInk = Color(0xFF1F1B16);
  static const lightInkSoft = Color(0xFF5B5246);
  static const lightAccent = Color(0xFF8A5A2B);
  static const lightDivider = Color(0xFFE6DDCB);

  // Dark — warm charcoal
  static const darkBg = Color(0xFF14110E);
  static const darkSurface = Color(0xFF1B1814);
  static const darkInk = Color(0xFFEDE3D2);
  static const darkInkSoft = Color(0xFF9C907D);
  static const darkAccent = Color(0xFFD4A574);
  static const darkDivider = Color(0xFF2C261F);
}

/// Paletas de acento elegibles (el fondo papel/charcoal no cambia, solo el
/// color de acento — así sigue siendo coherente y poco invasivo).
class AccentPalette {
  final String name;
  final Color light;
  final Color dark;
  const AccentPalette(this.name, this.light, this.dark);
}

const List<AccentPalette> accentPalettes = [
  AccentPalette('Cobre', Color(0xFF8A5A2B), Color(0xFFD4A574)),
  AccentPalette('Índigo', Color(0xFF45489B), Color(0xFF9DA0E8)),
  AccentPalette('Oliva', Color(0xFF5E6B33), Color(0xFFB7C47A)),
  AccentPalette('Borgoña', Color(0xFF8C2F39), Color(0xFFE08C95)),
  AccentPalette('Pizarra', Color(0xFF3E6470), Color(0xFF8FBDCB)),
  AccentPalette('Ciruela', Color(0xFF6D3F73), Color(0xFFC79BCC)),
];

/// Colores de resaltado de versículos. El índice se guarda en la base de
/// datos; el color real se elige según el tema claro/oscuro.
class HighlightSwatch {
  final String name;
  final Color light;
  final Color dark;
  const HighlightSwatch(this.name, this.light, this.dark);
}

const List<HighlightSwatch> highlightSwatches = [
  HighlightSwatch('Amarillo', Color(0xFFF2D34E), Color(0xFFB89A1F)),
  HighlightSwatch('Verde', Color(0xFF8BC58A), Color(0xFF4E7E4D)),
  HighlightSwatch('Azul', Color(0xFF85B6E0), Color(0xFF3E6E99)),
  HighlightSwatch('Rosa', Color(0xFFE79BB8), Color(0xFF9C4F6C)),
  HighlightSwatch('Naranja', Color(0xFFE9A86A), Color(0xFFA9692E)),
  HighlightSwatch('Lila', Color(0xFFB79BDB), Color(0xFF6B4E96)),
];

Color highlightColorFor(int index, bool isDark) {
  if (index < 0 || index >= highlightSwatches.length) {
    return highlightSwatches.first.light;
  }
  final s = highlightSwatches[index];
  return isDark ? s.dark : s.light;
}

ThemeData buildLightTheme(AccentPalette palette) =>
    _buildTheme(brightness: Brightness.light, palette: palette);
ThemeData buildDarkTheme(AccentPalette palette) =>
    _buildTheme(brightness: Brightness.dark, palette: palette);

ThemeData _buildTheme({
  required Brightness brightness,
  required AccentPalette palette,
}) {
  final isDark = brightness == Brightness.dark;
  final bg = isDark ? AppPalette.darkBg : AppPalette.lightBg;
  final surface = isDark ? AppPalette.darkSurface : AppPalette.lightSurface;
  final ink = isDark ? AppPalette.darkInk : AppPalette.lightInk;
  final inkSoft = isDark ? AppPalette.darkInkSoft : AppPalette.lightInkSoft;
  final accent = isDark ? palette.dark : palette.light;
  final divider = isDark ? AppPalette.darkDivider : AppPalette.lightDivider;

  final scheme = ColorScheme(
    brightness: brightness,
    primary: accent,
    onPrimary: isDark ? AppPalette.darkBg : Colors.white,
    secondary: accent,
    onSecondary: isDark ? AppPalette.darkBg : Colors.white,
    error: const Color(0xFFB3261E),
    onError: Colors.white,
    surface: surface,
    onSurface: ink,
    surfaceContainerHighest: isDark
        ? AppPalette.darkSurface
        : AppPalette.lightSurface,
    outline: divider,
    outlineVariant: divider,
  );

  final sansBase = GoogleFonts.interTextTheme(
    isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme,
  );

  final serif = GoogleFonts.crimsonPro;

  final textTheme = sansBase.copyWith(
    displayLarge: serif(
      textStyle: TextStyle(
        color: ink,
        fontSize: 36,
        fontWeight: FontWeight.w500,
        height: 1.15,
        letterSpacing: -0.5,
      ),
    ),
    displayMedium: serif(
      textStyle: TextStyle(
        color: ink,
        fontSize: 28,
        fontWeight: FontWeight.w500,
        height: 1.2,
      ),
    ),
    headlineSmall: serif(
      textStyle: TextStyle(
        color: ink,
        fontSize: 22,
        fontWeight: FontWeight.w600,
        height: 1.3,
      ),
    ),
    titleLarge: GoogleFonts.inter(
      textStyle: TextStyle(
        color: ink,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
    ),
    titleMedium: GoogleFonts.inter(
      textStyle: TextStyle(
        color: ink,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    ),
    bodyLarge: serif(
      textStyle: TextStyle(
        color: ink,
        fontSize: 19,
        height: 1.65,
        fontWeight: FontWeight.w400,
      ),
    ),
    bodyMedium: GoogleFonts.inter(
      textStyle: TextStyle(color: ink, fontSize: 15, height: 1.45),
    ),
    bodySmall: GoogleFonts.inter(
      textStyle: TextStyle(color: inkSoft, fontSize: 13, height: 1.4),
    ),
    labelLarge: GoogleFonts.inter(
      textStyle: TextStyle(
        color: ink,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
    ),
    labelSmall: GoogleFonts.inter(
      textStyle: TextStyle(
        color: inkSoft,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.0,
      ),
    ),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: bg,
    canvasColor: bg,
    dividerColor: divider,
    dividerTheme: DividerThemeData(color: divider, thickness: 1, space: 1),
    splashColor: accent.withValues(alpha: 0.08),
    highlightColor: accent.withValues(alpha: 0.05),
    // El fondo viene del tema (no se pasa fijo al abrir el sheet), así se
    // actualiza en vivo al cambiar de tema.
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: surface,
      modalBackgroundColor: surface,
      surfaceTintColor: Colors.transparent,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      iconTheme: IconThemeData(color: ink),
      titleTextStyle: GoogleFonts.inter(
        color: ink,
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
      centerTitle: false,
    ),
    listTileTheme: ListTileThemeData(
      iconColor: inkSoft,
      titleTextStyle: textTheme.titleMedium,
      subtitleTextStyle: textTheme.bodySmall,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      hintStyle: GoogleFonts.inter(color: inkSoft, fontSize: 15),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: accent, width: 1.5),
      ),
    ),
    iconTheme: IconThemeData(color: inkSoft),
    textTheme: textTheme,
    extensions: [
      AppColors(
        ink: ink,
        inkSoft: inkSoft,
        accent: accent,
        bg: bg,
        surface: surface,
        divider: divider,
      ),
    ],
  );
}

class AppColors extends ThemeExtension<AppColors> {
  final Color ink;
  final Color inkSoft;
  final Color accent;
  final Color bg;
  final Color surface;
  final Color divider;

  const AppColors({
    required this.ink,
    required this.inkSoft,
    required this.accent,
    required this.bg,
    required this.surface,
    required this.divider,
  });

  @override
  AppColors copyWith({
    Color? ink,
    Color? inkSoft,
    Color? accent,
    Color? bg,
    Color? surface,
    Color? divider,
  }) => AppColors(
    ink: ink ?? this.ink,
    inkSoft: inkSoft ?? this.inkSoft,
    accent: accent ?? this.accent,
    bg: bg ?? this.bg,
    surface: surface ?? this.surface,
    divider: divider ?? this.divider,
  );

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      ink: Color.lerp(ink, other.ink, t)!,
      inkSoft: Color.lerp(inkSoft, other.inkSoft, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
    );
  }
}

extension AppColorsContext on BuildContext {
  AppColors get appColors => Theme.of(this).extension<AppColors>()!;
}
