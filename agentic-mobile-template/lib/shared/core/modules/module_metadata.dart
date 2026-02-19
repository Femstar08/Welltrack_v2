import 'package:flutter/material.dart';

/// Enum representing all available modules in WellTrack
enum WellTrackModule {
  meals('Meals & Recipes', Icons.restaurant, true),
  nutrients('Nutrient Tracking', Icons.pie_chart, true),
  supplements('Supplements', Icons.medication, true),
  workouts('Workouts', Icons.fitness_center, true),
  health('Activity & Sleep', Icons.monitor_heart, true),
  insights('Insights', Icons.insights, true),
  reminders('Reminders', Icons.notifications, true),
  dailyView('Daily View', Icons.today, true),
  moduleToggles('Module Settings', Icons.tune, true);

  const WellTrackModule(this.displayName, this.icon, this.defaultEnabled);

  final String displayName;
  final IconData icon;
  final bool defaultEnabled;

  /// Get module-specific color from AppColors
  Color getAccentColor() {
    // Import is circular, so we'll define colors inline
    // These match AppColors module tile colors
    switch (this) {
      case WellTrackModule.meals:
        return const Color(0xFFFF7043); // mealsTile
      case WellTrackModule.nutrients:
        return const Color(0xFF66BB6A); // supplementsTile (green for nutrients)
      case WellTrackModule.supplements:
        return const Color(0xFF66BB6A); // supplementsTile
      case WellTrackModule.workouts:
        return const Color(0xFF42A5F5); // workoutsTile
      case WellTrackModule.health:
        return const Color(0xFF7E57C2); // sleepTile (purple for health)
      case WellTrackModule.insights:
        return const Color(0xFFFFCA28); // insightsTile
      case WellTrackModule.reminders:
        return const Color(0xFF2196F3); // info color
      case WellTrackModule.dailyView:
        return const Color(0xFF00BFA5); // secondary (teal)
      case WellTrackModule.moduleToggles:
        return const Color(0xFF757575); // textSecondaryLight
    }
  }

  /// Convert to database value (lowercase with underscore)
  String toDatabaseValue() {
    return name.toLowerCase();
  }

  /// Parse from database value
  static WellTrackModule? fromDatabaseValue(String value) {
    try {
      return WellTrackModule.values.firstWhere(
        (module) => module.name.toLowerCase() == value.toLowerCase(),
      );
    } catch (e) {
      return null;
    }
  }
}

/// Configuration for a module including its enabled state and tile settings
class ModuleConfig {

  const ModuleConfig({
    required this.module,
    this.enabled = true,
    this.tileOrder = 0,
    this.tileConfig = const {},
  });

  /// Create from JSON from database
  factory ModuleConfig.fromJson(Map<String, dynamic> json) {
    final moduleName = json['module_name'] as String?;
    final module = moduleName != null
        ? WellTrackModule.fromDatabaseValue(moduleName)
        : null;

    if (module == null) {
      throw ArgumentError('Invalid module name: $moduleName');
    }

    return ModuleConfig(
      module: module,
      enabled: json['enabled'] as bool? ?? true,
      tileOrder: json['tile_order'] as int? ?? 0,
      tileConfig: json['tile_config'] as Map<String, dynamic>? ?? {},
    );
  }
  final WellTrackModule module;
  final bool enabled;
  final int tileOrder;
  final Map<String, dynamic> tileConfig;

  /// Create a copy with updated fields
  ModuleConfig copyWith({
    bool? enabled,
    int? tileOrder,
    Map<String, dynamic>? tileConfig,
  }) {
    return ModuleConfig(
      module: module,
      enabled: enabled ?? this.enabled,
      tileOrder: tileOrder ?? this.tileOrder,
      tileConfig: tileConfig ?? this.tileConfig,
    );
  }

  /// Convert to JSON for database storage
  Map<String, dynamic> toJson() {
    return {
      'module_name': module.toDatabaseValue(),
      'enabled': enabled,
      'tile_order': tileOrder,
      'tile_config': tileConfig,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ModuleConfig &&
          runtimeType == other.runtimeType &&
          module == other.module &&
          enabled == other.enabled &&
          tileOrder == other.tileOrder;

  @override
  int get hashCode => module.hashCode ^ enabled.hashCode ^ tileOrder.hashCode;
}
