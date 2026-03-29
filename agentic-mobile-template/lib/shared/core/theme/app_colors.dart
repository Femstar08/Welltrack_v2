import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary — neon emerald (Bioluminescent Pulse)
  static const Color primary = Color(0xFF3FFF8B);
  static const Color primaryContainer = Color(0xFF13EA79);
  static const Color primaryLight = Color(0xFF3FFF8B);
  static const Color primaryDark = Color(0xFF006832);

  // Secondary — neon cyan
  static const Color secondary = Color(0xFF00E3FD);
  static const Color secondaryContainer = Color(0xFF006875);
  static const Color secondaryLight = Color(0xFF26E6FF);
  static const Color secondaryDark = Color(0xFF005964);

  // Tertiary — neon lime
  static const Color tertiary = Color(0xFFF4FFC6);
  static const Color tertiaryContainer = Color(0xFFD1FC00);

  // Recovery Score Colors (Re-mapped to neon palette where appropriate)
  static const Color recoveryExcellent = Color(0xFF3FFF8B);  // Primary emerald
  static const Color recoveryGood = Color(0xFFF4FFC6);       // Tertiary lime
  static const Color recoveryModerate = Color(0xFFFFCA28);   // Amber
  static const Color recoveryLow = Color(0xFFFF716C);        // Error dim
  static const Color recoveryCritical = Color(0xFF9F0519);   // Error container

  // Backgrounds & Surfaces (Absolute Dark Mode)
  static const Color backgroundDark = Color(0xFF0E0E0E); // Deep void
  static const Color surfaceDark = Color(0xFF0E0E0E);    // Base layer
  static const Color surfaceContainerLow = Color(0xFF131313); 
  static const Color surfaceContainer = Color(0xFF1A1919); // Secondary sectioning
  static const Color surfaceContainerHigh = Color(0xFF201F1F); // Interactive cards
  static const Color surfaceContainerHighest = Color(0xFF262626); // Raised cards
  static const Color surfaceBright = Color(0xFF2C2C2C); // Glass nav bars
  
  // Mapping standard fields to Dark for forced aesthetic
  static const Color backgroundLight = Color(0xFF0E0E0E); 
  static const Color surfaceLight = Color(0xFF0E0E0E);
  static const Color cardLight = Color(0xFF1A1919);
  static const Color cardDark = Color(0xFF1A1919);

  // Text
  static const Color textPrimaryDark = Color(0xFFFFFFFF);
  static const Color textSecondaryDark = Color(0xFFADAAAA);
  static const Color textPrimaryLight = Color(0xFFFFFFFF);
  static const Color textSecondaryLight = Color(0xFFADAAAA);
  static const Color outlineVariant = Color(0xFF494847);

  // Status
  static const Color success = Color(0xFF3FFF8B);
  static const Color warning = Color(0xFFFFCA28);
  static const Color error = Color(0xFFFF716C);
  static const Color info = Color(0xFF00E3FD);

  // Module tile accent colors
  static const Color mealsTile = Color(0xFFF4FFC6);
  static const Color workoutsTile = Color(0xFF00E3FD);
  static const Color supplementsTile = Color(0xFF3FFF8B);
  static const Color sleepTile = Color(0xFF7E57C2);
  static const Color insightsTile = Color(0xFFFFCA28);

  // Helper method to get recovery color by score
  static Color getRecoveryColor(double score) {
    if (score >= 80) return recoveryExcellent;
    if (score >= 60) return recoveryGood;
    if (score >= 40) return recoveryModerate;
    if (score >= 20) return recoveryLow;
    return recoveryCritical;
  }
}
