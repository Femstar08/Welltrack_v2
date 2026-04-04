import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Obsidian Vitality Type Scale (Manrope for headers, Inter for body)
class AppTypography {
  AppTypography._();

  // Display styles - Manrope (large, prominent text)
  static TextStyle get displayLarge => GoogleFonts.manrope(
    fontSize: 56, // 3.5rem equivalent
    fontWeight: FontWeight.w400,
    letterSpacing: -0.25,
    height: 64 / 56,
  );

  static TextStyle get displayMedium => GoogleFonts.manrope(
    fontSize: 45,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 52 / 45,
  );

  static TextStyle get displaySmall => GoogleFonts.manrope(
    fontSize: 36,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 44 / 36,
  );

  // Headline styles - Manrope
  static TextStyle get headlineLarge => GoogleFonts.manrope(
    fontSize: 32,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 40 / 32,
  );

  static TextStyle get headlineMedium => GoogleFonts.manrope(
    fontSize: 28, // 1.75rem
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 36 / 28,
  );

  static TextStyle get headlineSmall => GoogleFonts.manrope(
    fontSize: 24,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 32 / 24,
  );

  // Title styles - Inter
  static TextStyle get titleLarge => GoogleFonts.inter(
    fontSize: 22,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
    height: 28 / 22,
  );

  static TextStyle get titleMedium => GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.15,
    height: 24 / 16,
  );

  static TextStyle get titleSmall => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
    height: 20 / 14,
  );

  // Body styles - Inter
  static TextStyle get bodyLarge => GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.5,
    height: 24 / 16,
  );

  static TextStyle get bodyMedium => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.25,
    height: 20 / 14,
  );

  static TextStyle get bodySmall => GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.4,
    height: 16 / 12,
  );

  // Label styles - Inter
  static TextStyle get labelLarge => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
    height: 20 / 14,
  );

  static TextStyle get labelMedium => GoogleFonts.inter(
    fontSize: 12, // 0.75rem
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    height: 16 / 12,
  );

  static TextStyle get labelSmall => GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    height: 16 / 11,
  );

  /// Create a TextTheme from the type scale
  static TextTheme getTextTheme([Color? color]) {
    return TextTheme(
      displayLarge: displayLarge.apply(color: color),
      displayMedium: displayMedium.apply(color: color),
      displaySmall: displaySmall.apply(color: color),
      headlineLarge: headlineLarge.apply(color: color),
      headlineMedium: headlineMedium.apply(color: color),
      headlineSmall: headlineSmall.apply(color: color),
      titleLarge: titleLarge.apply(color: color),
      titleMedium: titleMedium.apply(color: color),
      titleSmall: titleSmall.apply(color: color),
      bodyLarge: bodyLarge.apply(color: color),
      bodyMedium: bodyMedium.apply(color: color),
      bodySmall: bodySmall.apply(color: color),
      labelLarge: labelLarge.apply(color: color),
      labelMedium: labelMedium.apply(color: color),
      labelSmall: labelSmall.apply(color: color),
    );
  }
}
