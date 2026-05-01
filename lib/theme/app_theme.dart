import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── Brand Palette ──────────────────────────────────────────────────────────
  // Deep editorial dark with warm amber accent
  static const Color primary = Color(0xFFD4A853); // Warm amber gold
  static const Color primaryLight = Color(0xFF2A2318); // Dark amber tint
  static const Color primaryMuted = Color(0xFF8A6D35); // Muted gold
  static const Color secondary = Color(0xFF4CAF82); // Sage green
  static const Color secondaryLight = Color(0xFF1A2E24); // Dark sage tint
  static const Color warning = Color(0xFFE8A020); // Amber warning
  static const Color warningLight = Color(0xFF2A2010); // Dark warning tint
  static const Color error = Color(0xFFE05252); // Warm red
  static const Color errorLight = Color(0xFF2A1515); // Dark error tint

  // Surfaces — layered dark editorial
  static const Color surface = Color(0xFF1C1C1E); // Card surface
  static const Color surfaceVariant = Color(0xFF242426); // Elevated surface
  static const Color surfaceElevated = Color(0xFF2C2C2E); // Higher elevation
  static const Color background = Color(0xFF111113); // Deep background
  static const Color backgroundAlt = Color(0xFF161618); // Slightly lighter bg

  // Borders
  static const Color outline = Color(0xFF3A3A3C);
  static const Color outlineVariant = Color(0xFF2C2C2E);

  // Text
  static const Color onSurface = Color(0xFFF5F0E8); // Warm cream
  static const Color onSurfaceSecondary = Color(0xFFB0A898); // Muted cream
  static const Color onSurfaceMuted = Color(0xFF6B6560); // Dimmed

  // Accent chips
  static const Color accentBlue = Color(0xFF5B8DEF);
  static const Color accentPurple = Color(0xFF9B72CF);

  static ThemeData get lightTheme => _buildTheme();
  static ThemeData get darkTheme => _buildTheme();

  static ThemeData _buildTheme() => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: primary,
      primaryContainer: primaryLight,
      secondary: secondary,
      secondaryContainer: secondaryLight,
      error: error,
      errorContainer: errorLight,
      surface: surface,
      surfaceContainerHighest: surfaceVariant,
      outline: outline,
      outlineVariant: outlineVariant,
      onPrimary: Color(0xFF111113),
      onSecondary: Color(0xFF111113),
      onSurface: onSurface,
      onSurfaceVariant: onSurfaceSecondary,
    ),
    scaffoldBackgroundColor: background,
    textTheme: _buildTextTheme(),
    appBarTheme: AppBarThemeData(
      backgroundColor: background,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.dmSans(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: onSurface,
        letterSpacing: -0.3,
      ),
      iconTheme: const IconThemeData(color: onSurface),
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: outlineVariant, width: 1),
      ),
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: surfaceVariant,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: error, width: 1.5),
      ),
      labelStyle: GoogleFonts.dmSans(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: onSurfaceMuted,
      ),
      floatingLabelStyle: GoogleFonts.dmSans(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      hintStyle: GoogleFonts.dmSans(fontSize: 14, color: onSurfaceMuted),
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: const Color(0xFF111113),
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.dmSans(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primary,
        side: const BorderSide(color: primary),
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.dmSans(
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primary,
        textStyle: GoogleFonts.dmSans(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: primary,
      foregroundColor: Color(0xFF111113),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: surfaceVariant,
      selectedColor: primaryLight,
      labelStyle: GoogleFonts.dmSans(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: onSurface,
      ),
      side: const BorderSide(color: outline),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surface,
      elevation: 0,
      indicatorColor: Colors.transparent,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return GoogleFonts.dmSans(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: primary,
          );
        }
        return GoogleFonts.dmSans(
          fontSize: 10,
          fontWeight: FontWeight.w400,
          color: onSurfaceMuted,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: primary, size: 22);
        }
        return const IconThemeData(color: onSurfaceMuted, size: 22);
      }),
    ),
    dividerTheme: const DividerThemeData(
      color: outlineVariant,
      thickness: 1,
      space: 0,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: surfaceVariant,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surfaceVariant,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titleTextStyle: GoogleFonts.dmSans(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: onSurface,
      ),
      contentTextStyle: GoogleFonts.dmSans(
        fontSize: 14,
        color: onSurfaceSecondary,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: surfaceElevated,
      contentTextStyle: GoogleFonts.dmSans(fontSize: 13, color: onSurface),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      behavior: SnackBarBehavior.floating,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return primary;
        return onSurfaceMuted;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return primaryLight;
        return outlineVariant;
      }),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: primary),
  );

  static TextTheme _buildTextTheme() {
    return TextTheme(
      displayLarge: GoogleFonts.fraunces(
        fontSize: 36,
        fontWeight: FontWeight.w700,
        color: onSurface,
        letterSpacing: -1.0,
        height: 1.1,
      ),
      displayMedium: GoogleFonts.fraunces(
        fontSize: 30,
        fontWeight: FontWeight.w700,
        color: onSurface,
        letterSpacing: -0.8,
        height: 1.15,
      ),
      headlineLarge: GoogleFonts.fraunces(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        color: onSurface,
        letterSpacing: -0.5,
        height: 1.2,
      ),
      headlineMedium: GoogleFonts.dmSans(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: onSurface,
        letterSpacing: -0.4,
      ),
      headlineSmall: GoogleFonts.dmSans(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: onSurface,
        letterSpacing: -0.3,
      ),
      titleLarge: GoogleFonts.dmSans(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: onSurface,
        letterSpacing: -0.2,
      ),
      titleMedium: GoogleFonts.dmSans(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
      titleSmall: GoogleFonts.dmSans(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
      bodyLarge: GoogleFonts.dmSans(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: onSurface,
        height: 1.5,
      ),
      bodyMedium: GoogleFonts.dmSans(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: onSurface,
        height: 1.5,
      ),
      bodySmall: GoogleFonts.dmSans(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: onSurfaceSecondary,
        height: 1.4,
      ),
      labelLarge: GoogleFonts.dmSans(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
        color: onSurface,
      ),
      labelMedium: GoogleFonts.dmSans(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        color: onSurface,
      ),
      labelSmall: GoogleFonts.dmSans(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.3,
        color: onSurfaceMuted,
      ),
    );
  }
}
