import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../onboarding_state.dart';


class FocusIntroductionScreen extends ConsumerWidget {

  const FocusIntroductionScreen({super.key, required this.onContinue});
  final VoidCallback onContinue;

  static const _goalDisplayNames = {
    'performance': 'Improve Performance',
    'stress': 'Reduce Stress',
    'sleep': 'Better Sleep',
    'strength': 'Build Strength',
    'fat_loss': 'Lose Fat',
    'wellness': 'General Wellness',
  };

  static const _goalIcons = {
    'performance': Icons.speed,
    'stress': Icons.self_improvement,
    'sleep': Icons.bedtime_outlined,
    'strength': Icons.fitness_center,
    'fat_loss': Icons.local_fire_department_outlined,
    'wellness': Icons.spa_outlined,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final data = ref.watch(onboardingDataProvider);
    final goalName =
        _goalDisplayNames[data.primaryGoal] ?? 'Your Goal';
    final goalIcon =
        _goalIcons[data.primaryGoal] ?? Icons.flag_outlined;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          const Spacer(flex: 2),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              goalIcon,
              size: 40,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Your 21-Day Focus',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            goalName,
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'For the next 21 days, WellTrack will prioritize '
            'this goal across your dashboard, insights, and '
            'recommendations.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'You can change your focus anytime in Settings.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const Spacer(flex: 3),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: onContinue,
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Begin',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }
}
