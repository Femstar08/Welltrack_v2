import 'dart:math' as math;

import 'package:flutter/material.dart';

class TodaysStepsRing extends StatelessWidget {
  const TodaysStepsRing({
    super.key,
    this.stepsToday,
    this.stepsGoal = 10000,
    this.nudgeText,
  });

  final int? stepsToday;
  final int stepsGoal;
  final String? nudgeText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final steps = stepsToday ?? 0;
    final progress = (steps / stepsGoal).clamp(0.0, 1.0);
    final isOnTrack = _isOnTrack(steps, stepsGoal);
    final ringColor = isOnTrack ? Colors.green : Colors.amber;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.directions_walk,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Steps',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _StepsRingPainter(
                  progress: progress,
                  color: ringColor,
                  steps: steps,
                  goal: stepsGoal,
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatSteps(steps),
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: ringColor,
                        ),
                      ),
                      Text(
                        'of ${_formatSteps(stepsGoal)} steps',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${(progress * 100).toStringAsFixed(0)}% complete',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isOnTrack ? Colors.green : Colors.amber[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (nudgeText != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.directions_walk, size: 16, color: Colors.amber),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        nudgeText!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.amber[800],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// On track if current steps / elapsed day fraction ≥ goal.
  bool _isOnTrack(int steps, int goal) {
    final now = DateTime.now();
    final dayFraction = (now.hour * 60 + now.minute) / (24 * 60);
    if (dayFraction == 0) return true;
    return steps >= (goal * dayFraction);
  }

  String _formatSteps(int steps) {
    if (steps >= 1000) {
      return '${(steps / 1000).toStringAsFixed(1)}k';
    }
    return steps.toString();
  }
}

class _StepsRingPainter extends StatelessWidget {
  const _StepsRingPainter({
    required this.progress,
    required this.color,
    required this.steps,
    required this.goal,
  });

  final double progress;
  final Color color;
  final int steps;
  final int goal;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 90,
      height: 90,
      child: CustomPaint(
        painter: _RingPainter(progress: progress, color: color),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${(progress * 100).toStringAsFixed(0)}%',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 8;
    const strokeWidth = 10.0;

    final bgPaint = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fgPaint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Background ring
    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc — starts from top (−π/2)
    final sweepAngle = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color;
}
