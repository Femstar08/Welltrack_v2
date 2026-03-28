import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/core/theme/app_colors.dart';
import '../../../freemium/data/freemium_repository.dart';
import '../../../freemium/domain/plan_tier.dart';
import '../../../meals/presentation/today_nutrition_provider.dart';

/// Page 2 of NutritionSummaryCarousel — calorie budget ring with breakdown.
class CaloriesBudgetCarouselPage extends ConsumerWidget {
  const CaloriesBudgetCarouselPage({
    super.key,
    required this.calories,
    this.exerciseCalories = 0,
  });

  final CalorieSummary calories;
  final int exerciseCalories;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tier = ref.watch(currentPlanTierProvider).valueOrNull;
    final isPro = tier == PlanTier.pro;
    final remaining = calories.adjustedGoal - calories.consumed + exerciseCalories;
    final isOver = remaining < 0;
    final progress = calories.adjustedGoal > 0
        ? (calories.consumed / calories.adjustedGoal).clamp(0.0, 1.0)
        : 0.0;
    final ringColor = isOver ? Colors.amber : AppColors.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Large ring
          SizedBox(
            width: 120,
            height: 120,
            child: CustomPaint(
              painter: _CalorieRingPainter(
                progress: progress,
                color: ringColor,
                backgroundColor: AppColors.surfaceContainerHighest,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${remaining.abs()}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimaryDark,
                          ),
                    ),
                    Text(
                      isOver ? 'kcal over' : 'kcal left',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: isOver ? Colors.amber : AppColors.textSecondaryDark,
                            fontSize: 10,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Breakdown column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _BreakdownRow(
                  label: 'Base Goal',
                  value: '${calories.adjustedGoal} kcal',
                ),
                const SizedBox(height: 4),
                _BreakdownRow(
                  label: 'Food',
                  value: '${calories.consumed} kcal',
                ),
                const SizedBox(height: 4),
                _BreakdownRow(
                  label: 'Exercise',
                  value: '+$exerciseCalories kcal',
                ),
                if (calories.recoveryBadge != null) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () {
                      if (isPro) {
                        context.push('/recovery-detail');
                      } else {
                        context.push('/paywall');
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        calories.recoveryBadge!,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  isPro ? '(Recovery-Adjusted)' : '(Estimated)',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.textSecondaryDark,
                        fontSize: 10,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondaryDark,
              ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textPrimaryDark,
                fontWeight: FontWeight.w500,
              ),
        ),
      ],
    );
  }
}

class _CalorieRingPainter extends CustomPainter {
  _CalorieRingPainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
  });

  final double progress;
  final Color color;
  final Color backgroundColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - 10) / 2;
    const strokeWidth = 10.0;

    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    final fgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final sweepAngle = 2 * pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      sweepAngle,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(_CalorieRingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
