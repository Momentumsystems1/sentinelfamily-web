// THEME LOCK: light — source: domain signal (family safety, outdoor use, trust)
// Scaffold.backgroundColor = AppTheme.backgroundLight — ALL screens

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand colors
  static const Color primary = Color(0xFF1B5E52);
  static const Color primaryLight = Color(0xFF2E7D6E);
  static const Color primaryContainer = Color(0xFFB2DFDB);
  static const Color secondary = Color(0xFF4A7C6F);
  static const Color secondaryContainer = Color(0xFFCCE8E3);

  // Semantic colors
  static const Color success = Color(0xFF2E7D5E);
  static const Color successContainer = Color(0xFFB8F0D4);
  static const Color warning = Color(0xFFB45309);
  static const Color warningContainer = Color(0xFFFEF3C7);
  static const Color error = Color(0xFFB91C1C);
  static const Color errorContainer = Color(0xFFFFE4E4);
  static const Color sos = Color(0xFFD32F2F);
  static const Color sosContainer = Color(0xFFFFCDD2);

  // Status colors
  static const Color statusOnline = Color(0xFF2E7D5E);
  static const Color statusGhost = Color(0xFF9E9E9E);
  static const Color statusOffline = Color(0xFFBDBDBD);

  // Light surfaces
  static const Color backgroundLight = Color(0xFFF7F8F7);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceVariantLight = Color(0xFFF4F6F5);

  // Dark surfaces
  static const Color backgroundDark = Color(0xFF0F1A18);
  static const Color surfaceDark = Color(0xFF1C2826);
  static const Color surfaceVariantDark = Color(0xFF243330);

  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.light(
      primary: primary,
      onPrimary: Colors.white,
      primaryContainer: primaryContainer,
      onPrimaryContainer: Color(0xFF0D2E28),
      secondary: secondary,
      onSecondary: Colors.white,
      secondaryContainer: secondaryContainer,
      onSecondaryContainer: Color(0xFF0D2E28),
      error: error,
      onError: Colors.white,
      errorContainer: errorContainer,
      onErrorContainer: Color(0xFF7A0000),
      surface: surfaceLight,
      onSurface: Color(0xFF1A1A1A),
      surfaceContainerHighest: surfaceVariantLight,
      onSurfaceVariant: Color(0xFF5A6E6A),
      outline: Color(0xFFCCCCCC),
      outlineVariant: Color(0xFFEEEEEE),
      shadow: Colors.black,
      scrim: Colors.black54,
      inverseSurface: Color(0xFF1A1A1A),
      onInverseSurface: Color(0xFFF5F5F5),
      inversePrimary: Color(0xFF80CBC4),
    ),
    scaffoldBackgroundColor: backgroundLight,
    textTheme: GoogleFonts.plusJakartaSansTextTheme(
      TextTheme(
        displayLarge: TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        displayMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        displaySmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
        headlineLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        headlineSmall: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        titleLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
        bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
        bodySmall: TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
        labelMedium: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
        labelSmall: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.3,
        ),
      ),
    ),
    appBarTheme: AppBarThemeData(
      backgroundColor: surfaceLight,
      elevation: 0,
      scrolledUnderElevation: 1,
      surfaceTintColor: primaryContainer,
      titleTextStyle: GoogleFonts.plusJakartaSans(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: Color(0xFF1A1A1A),
      ),
      iconTheme: IconThemeData(color: primary),
    ),
    cardTheme: CardThemeData(
      color: surfaceLight,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: surfaceVariantLight,
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Color(0xFFE0E0E0), width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: error, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: error, width: 2),
      ),
      labelStyle: TextStyle(color: Color(0xFF5A6E6A), fontSize: 14),
      hintStyle: TextStyle(color: Color(0xFF9E9E9E), fontSize: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.plusJakartaSans(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.plusJakartaSans(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: surfaceVariantLight,
      selectedColor: primaryContainer,
      labelStyle: GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surfaceLight,
      indicatorColor: primaryContainer,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: primary,
          );
        }
        return GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: Color(0xFF9E9E9E),
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return IconThemeData(color: primary, size: 24);
        }
        return IconThemeData(color: Color(0xFF9E9E9E), size: 24);
      }),
      height: 68,
      elevation: 2,
    ),
    dividerTheme: DividerThemeData(
      color: Color(0xFFEEEEEE),
      thickness: 1,
      space: 1,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: surfaceLight,
      modalBackgroundColor: surfaceLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      elevation: 8,
    ),
  );

  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.dark(
      primary: Color(0xFF80CBC4),
      onPrimary: Color(0xFF0D2E28),
      primaryContainer: Color(0xFF1B5E52),
      onPrimaryContainer: Color(0xFFB2DFDB),
      secondary: Color(0xFF80CBC4),
      onSecondary: Color(0xFF0D2E28),
      secondaryContainer: Color(0xFF2E4E4A),
      onSecondaryContainer: Color(0xFFCCE8E3),
      error: Color(0xFFCF6679),
      onError: Colors.white,
      surface: surfaceDark,
      onSurface: Color(0xFFE6E6E6),
      surfaceContainerHighest: surfaceVariantDark,
      onSurfaceVariant: Color(0xFFAABBB8),
      outline: Color(0xFF4A5A57),
      outlineVariant: Color(0xFF2E3E3B),
      inverseSurface: Color(0xFFE6E6E6),
      onInverseSurface: Color(0xFF1A1A1A),
      inversePrimary: primary,
    ),
    scaffoldBackgroundColor: backgroundDark,
    textTheme: GoogleFonts.plusJakartaSansTextTheme(
      TextTheme(
        displayLarge: TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.w700,
          color: Color(0xFFE6E6E6),
        ),
        headlineMedium: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Color(0xFFE6E6E6),
        ),
        titleMedium: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Color(0xFFE6E6E6),
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: Color(0xFFCCCCCC),
        ),
        labelMedium: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFFAABBB8),
        ),
      ),
    ),
    appBarTheme: AppBarThemeData(
      backgroundColor: surfaceDark,
      elevation: 0,
      scrolledUnderElevation: 1,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surfaceDark,
      indicatorColor: Color(0xFF1B5E52),
      height: 68,
    ),
  );
}
