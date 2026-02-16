import 'package:flutter/material.dart';

/// Material 3 type scale using system fonts for optimal performance
class AppTypography {
  AppTypography._();

  // Font family fallbacks
  static const String _fontFamily = 'Roboto';

  // Display styles (large, prominent text)
  static const TextStyle displayLarge = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 57,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.25,
    height: 64 / 57,
  );

  static const TextStyle displayMedium = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 45,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 52 / 45,
  );

  static const TextStyle displaySmall = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 36,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 44 / 36,
  );

  // Headline styles (titles, headings)
  static const TextStyle headlineLarge = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 32,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 40 / 32,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 28,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 36 / 28,
  );

  static const TextStyle headlineSmall = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 32 / 24,
  );

  // Title styles (smaller headings, list items)
  static const TextStyle titleLarge = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
    height: 28 / 22,
  );

  static const TextStyle titleMedium = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.15,
    height: 24 / 16,
  );

  static const TextStyle titleSmall = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
    height: 20 / 14,
  );

  // Body styles (main content)
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.5,
    height: 24 / 16,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.25,
    height: 20 / 14,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.4,
    height: 16 / 12,
  );

  // Label styles (buttons, tabs, chips)
  static const TextStyle labelLarge = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
    height: 20 / 14,
  );

  static const TextStyle labelMedium = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    height: 16 / 12,
  );

  static const TextStyle labelSmall = TextStyle(
    fontFamily: _fontFamily,
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
