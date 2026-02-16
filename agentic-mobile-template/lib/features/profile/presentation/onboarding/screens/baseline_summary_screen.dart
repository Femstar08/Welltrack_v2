import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:welltrack/features/profile/presentation/onboarding/onboarding_state.dart';


class BaselineSummaryScreen extends ConsumerStatefulWidget {
  final VoidCallback onComplete;

  const BaselineSummaryScreen({super.key, required this.onComplete});

  @override
  ConsumerState<BaselineSummaryScreen> createState() =>
      _BaselineSummaryScreenState();
}

class _BaselineSummaryScreenState extends ConsumerState<BaselineSummaryScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _isLoading = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final data = ref.watch(onboardingDataProvider);

    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Building your baseline...',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    final baseline = _computeBaseline(data);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 48),
          Text(
            'Your starting point',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Based on your profile and goal selection.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 32),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _BaselineRow(
                    icon: Icons.flag_outlined,
                    label: 'Focus Priority',
                    value: baseline.focusPriority,
                  ),
                  _BaselineRow(
                    icon: Icons.analytics_outlined,
                    label: 'Key Metric',
                    value: baseline.keyMetric,
                  ),
                  _BaselineRow(
                    icon: Icons.bedtime_outlined,
                    label: 'Target Sleep',
                    value: baseline.targetSleep,
                  ),
                  _BaselineRow(
                    icon: Icons.fitness_center,
                    label: 'Weekly Load',
                    value: baseline.weeklyLoad,
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: widget.onComplete,
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Enter WellTrack',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  _BaselineResult _computeBaseline(OnboardingData data) {
    final goal = data.primaryGoal ?? 'wellness';
    final activity = data.activityLevel?.toLowerCase() ?? '';

    // Focus priority display name
    const goalNames = {
      'performance': 'Performance',
      'stress': 'Stress Reduction',
      'sleep': 'Sleep Quality',
      'strength': 'Strength Building',
      'fat_loss': 'Fat Loss',
      'wellness': 'General Wellness',
    };

    // Key metric by goal
    const keyMetrics = {
      'performance': 'VO2 Max',
      'stress': 'Stress Score',
      'sleep': 'Sleep Quality',
      'strength': 'Training Load',
      'fat_loss': 'Activity & Nutrition',
      'wellness': 'Recovery Score',
    };

    // Target sleep
    final targetSleep = goal == 'sleep' ? '8-9 hours' : '7-9 hours';

    // Weekly load based on activity level
    String weeklyLoad;
    if (activity.contains('very')) {
      weeklyLoad = '5-6 sessions';
    } else if (activity.contains('moderate')) {
      weeklyLoad = '3-4 sessions';
    } else {
      weeklyLoad = '2-3 sessions';
    }

    return _BaselineResult(
      focusPriority: goalNames[goal] ?? 'General Wellness',
      keyMetric: keyMetrics[goal] ?? 'Recovery Score',
      targetSleep: targetSleep,
      weeklyLoad: weeklyLoad,
    );
  }
}

class _BaselineResult {
  final String focusPriority;
  final String keyMetric;
  final String targetSleep;
  final String weeklyLoad;

  const _BaselineResult({
    required this.focusPriority,
    required this.keyMetric,
    required this.targetSleep,
    required this.weeklyLoad,
  });
}

class _BaselineRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _BaselineRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(icon, size: 24, color: theme.colorScheme.primary),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
