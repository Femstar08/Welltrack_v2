import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../shared/core/theme/app_colors.dart';
import '../../../meals/presentation/today_nutrition_provider.dart';

/// Page 1 of NutritionSummaryCarousel — 3 macro rings for Protein, Carbs, Fat.
class MacroRingsCarouselPage extends StatelessWidget {
  const MacroRingsCarouselPage({
    super.key,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  final MacroSummary protein;
  final MacroSummary carbs;
  final MacroSummary fat;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _MacroRing(
            label: 'Protein',
            consumed: protein.consumed,
            goal: protein.goal,
            color: AppColors.primary,
          ),
          _MacroRing(
            label: 'Carbs',
            consumed: carbs.consumed,
            goal: carbs.goal,
            color: AppColors.secondary,
          ),
          _MacroRing(
            label: 'Fat',
            consumed: fat.consumed,
            goal: fat.goal,
            color: AppColors.tertiary,
          ),
        ],
      ),
    );
  }
}

class _MacroRing extends StatelessWidget {
  const _MacroRing({
    required this.label,
    required this.consumed,
    required this.goal,
    required this.color,
  });

  final String label;
  final int consumed;
  final int goal;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isOver = consumed > goal;
    final diff = (consumed - goal).abs();
    final ringColor = isOver ? Colors.amber : color;

    return Semantics(
      label: '$label: $consumed of $goal grams consumed',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 80,
            height: 80,
          child: CustomPaint(
            painter: _RingPainter(
              progress: goal > 0 ? (consumed / goal).clamp(0.0, 1.0) : 0.0,
              color: ringColor,
              backgroundColor: AppColors.surfaceContainerHighest,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${diff}g',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimaryDark,
                        ),
                  ),
                  Text(
                    isOver ? 'over' : 'left',
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
        const SizedBox(height: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.textSecondaryDark,
              ),
        ),
      ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
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
    final radius = (size.shortestSide - 8) / 2;
    const strokeWidth = 8.0;

    // Background arc
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    // Foreground arc
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
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
