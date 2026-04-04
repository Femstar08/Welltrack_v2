import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/core/theme/app_colors.dart';
import '../../../meals/presentation/today_nutrition_provider.dart';

/// Dashboard tile showing today's step count from Health Connect / Garmin.
/// When no health data source is connected, shows a Connect prompt.
class StepsSummaryTile extends ConsumerWidget {
  const StepsSummaryTile({super.key, required this.profileId});
  final String profileId;

  static const int _defaultStepTarget = 10000;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stepsAsync = ref.watch(todayStepsProvider(profileId));

    return GestureDetector(
      onTap: () => context.push('/health/steps'),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(24),
        ),
        child: stepsAsync.when(
          loading: () => _buildContent(context, null, isLoading: true),
          error: (_, __) => _buildContent(context, null),
          data: (steps) => _buildContent(context, steps),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, int? steps,
      {bool isLoading = false}) {
    final hasData = steps != null;
    final progress = hasData ? (steps / _defaultStepTarget).clamp(0.0, 1.0) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.directions_walk,
                  color: AppColors.secondary, size: 24),
            ),
            if (hasData) ...[
              const Spacer(),
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 3,
                  backgroundColor:
                      AppColors.secondary.withValues(alpha: 0.15),
                  color: AppColors.secondary,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),
        if (isLoading)
          const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else if (!hasData) ...[
          Text(
            '-- steps',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () => context.push('/health/connections'),
            child: Text(
              'Connect',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ] else ...[
          Text(
            _formatSteps(steps),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          Text(
            'Steps',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondaryDark,
                ),
          ),
        ],
      ],
    );
  }

  String _formatSteps(int steps) {
    if (steps >= 1000) {
      final thousands = steps ~/ 1000;
      final remainder = (steps % 1000) ~/ 100;
      if (remainder == 0) return '${thousands}k';
      return '$thousands,${(steps % 1000).toString().padLeft(3, '0')}';
    }
    return steps.toString();
  }
}
