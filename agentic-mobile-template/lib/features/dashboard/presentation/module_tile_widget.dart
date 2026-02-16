import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:welltrack/shared/core/modules/module_metadata.dart';
import 'package:welltrack/shared/core/theme/app_colors.dart';
import 'package:welltrack/shared/core/theme/app_typography.dart';

/// Reusable dashboard tile widget for module display
class ModuleTileWidget extends StatelessWidget {
  final ModuleConfig config;
  final VoidCallback? onTap;
  final bool isDraggable;

  const ModuleTileWidget({
    super.key,
    required this.config,
    this.onTap,
    this.isDraggable = false,
  });

  @override
  Widget build(BuildContext context) {
    final module = config.module;
    final accentColor = module.getAccentColor();

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap ?? () => _handleTap(context),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                accentColor.withOpacity(0.1),
                accentColor.withOpacity(0.05),
              ],
            ),
          ),
          child: Row(
            children: [
              // Module icon
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  module.icon,
                  color: accentColor,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),

              // Module info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      module.displayName,
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getModuleSummary(),
                      style: AppTypography.bodySmall.copyWith(
                        color: Theme.of(context).brightness == Brightness.light
                            ? AppColors.textSecondaryLight
                            : AppColors.textSecondaryDark,
                      ),
                    ),
                  ],
                ),
              ),

              // Drag handle or chevron
              if (isDraggable)
                Icon(
                  Icons.drag_handle,
                  color: Theme.of(context).brightness == Brightness.light
                      ? AppColors.textSecondaryLight
                      : AppColors.textSecondaryDark,
                )
              else
                Icon(
                  Icons.chevron_right,
                  color: accentColor,
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Get module-specific summary text
  String _getModuleSummary() {
    switch (config.module) {
      case WellTrackModule.meals:
        return 'Track meals and discover recipes';
      case WellTrackModule.nutrients:
        return 'Monitor your nutrition goals';
      case WellTrackModule.supplements:
        return 'Manage your supplement protocol';
      case WellTrackModule.workouts:
        return 'Log workouts and track progress';
      case WellTrackModule.health:
        return 'View activity and sleep data';
      case WellTrackModule.insights:
        return 'AI-powered health insights';
      case WellTrackModule.reminders:
        return 'Manage your notifications';
      case WellTrackModule.dailyView:
        return 'Today\'s tasks and progress';
      case WellTrackModule.moduleToggles:
        return 'Customize your dashboard';
    }
  }

  /// Handle tile tap - navigate to module screen
  void _handleTap(BuildContext context) {
    final route = _getModuleRoute(config.module);
    if (route != null) {
      context.push(route);
    }
  }

  /// Map each module to its route path
  static String? _getModuleRoute(WellTrackModule module) {
    switch (module) {
      case WellTrackModule.meals:
        return '/pantry';
      case WellTrackModule.nutrients:
        return '/insights';
      case WellTrackModule.supplements:
        return '/supplements';
      case WellTrackModule.workouts:
        return '/workouts';
      case WellTrackModule.health:
        return '/health/connections';
      case WellTrackModule.insights:
        return '/insights';
      case WellTrackModule.reminders:
        return '/reminders';
      case WellTrackModule.dailyView:
        return '/daily-view';
      case WellTrackModule.moduleToggles:
        return '/settings';
    }
  }
}

/// Compact version of module tile for grid layout
class CompactModuleTile extends StatelessWidget {
  final ModuleConfig config;
  final VoidCallback? onTap;

  const CompactModuleTile({
    super.key,
    required this.config,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final module = config.module;
    final accentColor = module.getAccentColor();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap ?? () => _handleTap(context),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                accentColor.withOpacity(0.15),
                accentColor.withOpacity(0.05),
              ],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                module.icon,
                color: accentColor,
                size: 36,
              ),
              const SizedBox(height: 8),
              Text(
                module.displayName,
                style: AppTypography.labelMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleTap(BuildContext context) {
    final route = ModuleTileWidget._getModuleRoute(config.module);
    if (route != null) {
      context.push(route);
    }
  }
}
