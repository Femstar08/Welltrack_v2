import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../daily_coach/domain/daily_prescription_entity.dart';

class TodaysWorkoutCard extends StatelessWidget {
  const TodaysWorkoutCard({
    super.key,
    required this.prescription,
    required this.profileId,
    this.activePlanId,
    this.planName,
    this.exerciseCount,
    this.estimatedDurationMinutes,
    this.muscleGroups = const [],
  });

  final DailyPrescriptionEntity prescription;
  final String profileId;
  final String? activePlanId;
  final String? planName;
  final int? exerciseCount;
  final int? estimatedDurationMinutes;
  final List<String> muscleGroups;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final directive = prescription.workoutDirective;
    final isRestOrRecovery = directive == WorkoutDirective.rest ||
        directive == WorkoutDirective.activeRecovery;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _cardTapRoute(directive) != null
            ? () => context.push(_cardTapRoute(directive)!)
            : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _directiveIcon(directive),
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Workout',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  if (prescription.workoutVolumeModifier != 1.0 &&
                      !isRestOrRecovery)
                    _VolumeBadge(modifier: prescription.workoutVolumeModifier),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                _directiveLabel(directive),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (!isRestOrRecovery && planName != null) ...[
                const SizedBox(height: 4),
                Text(
                  _buildSubtitle(),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (!isRestOrRecovery && muscleGroups.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  muscleGroups.join(', '),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (prescription.workoutNote != null) ...[
                const SizedBox(height: 8),
                Text(
                  prescription.workoutNote!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              _buildActionButton(context, directive),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, WorkoutDirective directive) {
    if (directive == WorkoutDirective.rest) {
      return FilledButton.tonal(
        onPressed: () => context.push('/workouts'),
        child: const Text('View Workouts'),
      );
    }

    if (directive == WorkoutDirective.activeRecovery) {
      return FilledButton.tonal(
        onPressed: () => context.push('/workouts'),
        child: const Text('View Recovery Options'),
      );
    }

    if (activePlanId == null) {
      return OutlinedButton.icon(
        icon: const Icon(Icons.add, size: 16),
        label: const Text('Set Up Workout Plan'),
        onPressed: () => context.push('/workouts'),
      );
    }

    return FilledButton.icon(
      icon: const Icon(Icons.play_arrow, size: 18),
      label: const Text('Start Workout'),
      onPressed: () => context.push('/workouts/plan/$activePlanId'),
    );
  }

  String _buildSubtitle() {
    final parts = <String>[];
    if (planName != null) parts.add(planName!);
    if (estimatedDurationMinutes != null) parts.add('~$estimatedDurationMinutes min');
    if (exerciseCount != null) parts.add('$exerciseCount exercises');
    return parts.join(' · ');
  }

  /// Route for tapping the card. Opens live workout session when a plan exists.
  String? _cardTapRoute(WorkoutDirective directive) {
    if (directive == WorkoutDirective.rest) return null;
    if (activePlanId != null) return '/workouts/plan/$activePlanId';
    return '/workouts';
  }

  IconData _directiveIcon(WorkoutDirective directive) {
    switch (directive) {
      case WorkoutDirective.fullSession:
        return Icons.fitness_center;
      case WorkoutDirective.reducedVolume:
        return Icons.fitness_center;
      case WorkoutDirective.quickSession:
        return Icons.timer;
      case WorkoutDirective.activeRecovery:
        return Icons.self_improvement;
      case WorkoutDirective.rest:
        return Icons.hotel;
    }
  }

  String _directiveLabel(WorkoutDirective directive) {
    switch (directive) {
      case WorkoutDirective.fullSession:
        return 'Full Session';
      case WorkoutDirective.reducedVolume:
        return 'Light Session';
      case WorkoutDirective.quickSession:
        return 'Express Session';
      case WorkoutDirective.activeRecovery:
        return 'Active Recovery';
      case WorkoutDirective.rest:
        return 'Rest Day';
    }
  }
}

class _VolumeBadge extends StatelessWidget {
  const _VolumeBadge({required this.modifier});
  final double modifier;

  @override
  Widget build(BuildContext context) {
    final pct = (modifier * 100).round();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'Volume: $pct%',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSecondaryContainer,
            ),
      ),
    );
  }
}
