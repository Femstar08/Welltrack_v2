import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/core/theme/app_colors.dart';
import '../../../meals/presentation/today_nutrition_provider.dart';

/// Dashboard tile showing today's exercise calories and duration
/// from completed workouts and Health Connect active calories.
class ExerciseSummaryTile extends ConsumerWidget {
  const ExerciseSummaryTile({super.key, required this.profileId});
  final String profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exerciseAsync = ref.watch(todayExerciseProvider(profileId));

    return GestureDetector(
      onTap: () => context.push('/workouts'),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(24),
        ),
        child: exerciseAsync.when(
          loading: () => _buildContent(context, null, isLoading: true),
          error: (_, __) => _buildContent(context, null),
          data: (exercise) => _buildContent(context, exercise),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, ExerciseSummary? exercise,
      {bool isLoading = false}) {
    final cals = exercise?.caloriesBurned ?? 0;
    final mins = exercise?.durationMinutes ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.local_fire_department,
              color: AppColors.primary, size: 24),
        ),
        const SizedBox(height: 16),
        if (isLoading)
          const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else ...[
          Text(
            '$cals',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          Text(
            mins > 0 ? 'kcal \u00b7 ${mins}min' : 'Exercise kcal',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondaryDark,
                ),
          ),
        ],
      ],
    );
  }
}
