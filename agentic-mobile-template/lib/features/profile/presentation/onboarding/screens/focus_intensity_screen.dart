import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:welltrack/features/profile/presentation/onboarding/onboarding_state.dart';


class FocusIntensityScreen extends ConsumerWidget {
  final VoidCallback onContinue;

  const FocusIntensityScreen({super.key, required this.onContinue});

  static const _intensityLabels = ['Low', 'Moderate', 'High', 'Top Priority'];
  static const _intensityDescriptions = [
    'Light tracking, gentle nudges',
    'Balanced tracking and suggestions',
    'Detailed tracking with active coaching',
    'Maximum focus, aggressive targets',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final currentIntensity = ref.watch(
      onboardingDataProvider.select((d) => d.goalIntensity),
    );

    final intensityIndex = _intensityLabels.indexWhere(
      (l) => l.toLowerCase() == currentIntensity?.toLowerCase(),
    );
    final sliderValue = intensityIndex >= 0 ? intensityIndex.toDouble() : 1.0;
    final activeLabel = _intensityLabels[sliderValue.toInt()];
    final activeDescription = _intensityDescriptions[sliderValue.toInt()];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 48),
          Text(
            'How intensely do you\nwant to focus?',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You can change this anytime in settings.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          Center(
            child: Column(
              children: [
                Text(
                  activeLabel,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  activeDescription,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 48),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: theme.colorScheme.primary,
              inactiveTrackColor:
                  theme.colorScheme.surfaceContainerHighest,
              thumbColor: theme.colorScheme.primary,
              overlayColor: theme.colorScheme.primary.withValues(alpha: 0.12),
              trackHeight: 6,
            ),
            child: Slider(
              value: sliderValue,
              min: 0,
              max: 3,
              divisions: 3,
              onChanged: (value) {
                HapticFeedback.selectionClick();
                ref
                    .read(onboardingDataProvider.notifier)
                    .setGoalIntensity(
                      _intensityLabels[value.toInt()].toLowerCase(),
                    );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: _intensityLabels.map((label) {
                return Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 10,
                  ),
                );
              }).toList(),
            ),
          ),
          const Spacer(flex: 2),
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
