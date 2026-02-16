import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:welltrack/features/profile/presentation/onboarding/onboarding_state.dart';
import 'package:welltrack/features/profile/presentation/onboarding/widgets/goal_card.dart';


class GoalSelectionScreen extends ConsumerWidget {
  final VoidCallback onContinue;

  const GoalSelectionScreen({super.key, required this.onContinue});

  static const _goals = [
    _GoalOption(
      id: 'performance',
      label: 'Performance',
      sublabel: 'VO2 max & recovery',
      icon: Icons.speed,
    ),
    _GoalOption(
      id: 'stress',
      label: 'Reduce Stress',
      sublabel: 'Stress score & sleep',
      icon: Icons.self_improvement,
    ),
    _GoalOption(
      id: 'sleep',
      label: 'Better Sleep',
      sublabel: 'Sleep quality & consistency',
      icon: Icons.bedtime_outlined,
    ),
    _GoalOption(
      id: 'strength',
      label: 'Build Strength',
      sublabel: 'Training load & progress',
      icon: Icons.fitness_center,
    ),
    _GoalOption(
      id: 'fat_loss',
      label: 'Lose Fat',
      sublabel: 'Activity & nutrition',
      icon: Icons.local_fire_department_outlined,
    ),
    _GoalOption(
      id: 'wellness',
      label: 'General Wellness',
      sublabel: 'Recovery & balance',
      icon: Icons.spa_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final selectedGoal = ref.watch(
      onboardingDataProvider.select((d) => d.primaryGoal),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 48),
          Text(
            'What is your\nprimary goal?',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This shapes your dashboard and recommendations.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 32),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.1,
              shrinkWrap: true,
              children: _goals.map((goal) {
                return GoalCard(
                  icon: goal.icon,
                  label: goal.label,
                  sublabel: goal.sublabel,
                  isSelected: selectedGoal == goal.id,
                  onTap: () {
                    ref
                        .read(onboardingDataProvider.notifier)
                        .setPrimaryGoal(goal.id);
                  },
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: selectedGoal != null ? onContinue : null,
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                disabledBackgroundColor:
                    theme.colorScheme.surfaceContainerHighest,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Continue',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _GoalOption {
  final String id;
  final String label;
  final String sublabel;
  final IconData icon;

  const _GoalOption({
    required this.id,
    required this.label,
    required this.sublabel,
    required this.icon,
  });
}
