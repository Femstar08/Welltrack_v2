import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary — deep blue (performance/trust)
  static const Color primary = Color(0xFF1A73E8);
  static const Color primaryLight = Color(0xFF4DA3FF);
  static const Color primaryDark = Color(0xFF0D47A1);

  // Secondary — teal (health/vitality)
  static const Color secondary = Color(0xFF00BFA5);
  static const Color secondaryLight = Color(0xFF5DF2D6);
  static const Color secondaryDark = Color(0xFF008E76);

  // Recovery Score Colors
  static const Color recoveryExcellent = Color(0xFF4CAF50);  // 80-100
  static const Color recoveryGood = Color(0xFF8BC34A);       // 60-79
  static const Color recoveryModerate = Color(0xFFFFCA28);   // 40-59
  static const Color recoveryLow = Color(0xFFFF9800);        // 20-39
  static const Color recoveryCritical = Color(0xFFF44336);   // 0-19

  // Backgrounds
  static const Color backgroundLight = Color(0xFFF8F9FA);
  static const Color backgroundDark = Color(0xFF121212);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF1E1E1E);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color cardDark = Color(0xFF2C2C2C);

  // Text
  static const Color textPrimaryLight = Color(0xFF212121);
  static const Color textSecondaryLight = Color(0xFF757575);
  static const Color textPrimaryDark = Color(0xFFE0E0E0);
  static const Color textSecondaryDark = Color(0xFF9E9E9E);

  // Status
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFF44336);
  static const Color info = Color(0xFF2196F3);

  // Module tile accent colors
  static const Color mealsTile = Color(0xFFFF7043);
  static const Color workoutsTile = Color(0xFF42A5F5);
  static const Color supplementsTile = Color(0xFF66BB6A);
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
