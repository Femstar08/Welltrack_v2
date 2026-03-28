import 'package:flutter/material.dart';
import '../../../../shared/core/theme/app_colors.dart';

/// Shared reusable progress bar for nutrient tracking (Heart Healthy / Low Carb pages).
class NutrientProgressBar extends StatelessWidget {
  const NutrientProgressBar({
    super.key,
    required this.label,
    required this.consumed,
    required this.goal,
    this.isNull = false,
    this.color,
    this.overGoalColor,
  });

  final String label;
  final double consumed;
  final double goal;

  /// When true, renders '--' instead of the progress bar (untracked nutrient).
  final bool isNull;
  final Color? color;
  final Color? overGoalColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (isNull) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            SizedBox(
              width: 90,
              child: Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondaryDark,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '--',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondaryDark,
              ),
            ),
          ],
        ),
      );
    }

    final isOver = consumed > goal;
    final progress = goal > 0 ? (consumed / goal).clamp(0.0, 1.0) : 0.0;
    final barColor = isOver
        ? (overGoalColor ?? Colors.amber)
        : (color ?? AppColors.primary);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondaryDark,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: AppColors.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 60,
            child: Text(
              isOver
                  ? '${consumed.toInt()}/${goal.toInt()}'
                  : '${consumed.toInt()}/${goal.toInt()}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: isOver ? Colors.amber : AppColors.textSecondaryDark,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
