import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Centralized app theme configuration.
abstract final class AppTheme {
  /// Primary brand color used as the seed.
  static const seed = Color(0xFF023455);

  /// Returns the light theme used by the Proctor app.
  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seed,
      secondary: const Color(0xFF3282B8),
      brightness: Brightness.light,
    );

    final textTheme = GoogleFonts.plusJakartaSansTextTheme();

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: colorScheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: colorScheme.primary,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surfaceContainerLowest,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerLowest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.4),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.primaryContainer,
        labelStyle: textTheme.labelMedium?.copyWith(
          color: colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
