import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../habits/presentation/habit_provider.dart';
import '../../insights/presentation/today_recovery_score_provider.dart';

/// Data class for a contextual habit/recovery prompt.
class HabitPromptData {
  const HabitPromptData({
    required this.message,
    required this.icon,
    this.actionLabel,
    this.actionRoute,
  });

  final String message;

  /// Icon name key — caller maps to IconData.
  final String icon;
  final String? actionLabel;
  final String? actionRoute;
}

/// Dismissed state — resets daily (in-memory only).
final habitPromptDismissedProvider = StateProvider<bool>((ref) => false);

/// Generates a contextual nudge based on logging streak and recovery state.
/// Returns `null` when no relevant prompt or dismissed.
final habitPromptProvider =
    Provider.family<HabitPromptData?, String>((ref, profileId) {
  if (ref.watch(habitPromptDismissedProvider)) return null;

  final habitState = ref.watch(habitProvider(profileId));
  final recoveryScore = ref.watch(todayRecoveryScoreProvider(profileId));

  final now = DateTime.now();
  final hour = now.hour;

  // Rule 1: Low recovery warning (highest priority)
  if (recoveryScore != null && recoveryScore < 40) {
    return const HabitPromptData(
      message: 'Recovery is low — prioritise rest and hydration today',
      icon: 'recovery',
      actionLabel: 'View Recovery',
      actionRoute: '/recovery-detail',
    );
  }

  // Rule 2: Meal logging streak celebration
  // Check habits for any with long streaks
  final activeHabits = habitState.habits.where((h) => h.isActive).toList();
  for (final habit in activeHabits) {
    if (habit.currentStreakDays >= 7 && habit.currentStreakDays % 7 == 0) {
      final label = habit.habitLabel ?? habit.habitType.replaceAll('_', ' ');
      return HabitPromptData(
        message: '$label: ${habit.currentStreakDays}-day streak! Keep it up',
        icon: 'streak',
      );
    }
  }

  // Rule 3: Habits not yet logged today
  final unloggedToday = activeHabits.where((h) {
    return habitState.todayLogs[h.habitType] != true;
  }).toList();

  if (unloggedToday.isNotEmpty && hour >= 18) {
    return HabitPromptData(
      message:
          '${unloggedToday.length} habit${unloggedToday.length > 1 ? 's' : ''} not logged today — still time!',
      icon: 'habits',
      actionLabel: 'Log Habits',
      actionRoute: '/habits',
    );
  }

  // Rule 4: High recovery encouragement
  if (recoveryScore != null && recoveryScore >= 80) {
    return const HabitPromptData(
      message: 'Recovery is high — great day for a push workout',
      icon: 'recovery_high',
      actionLabel: 'Start Workout',
      actionRoute: '/workouts/new',
    );
  }

  // Rule 5: Morning habit reminder
  if (hour < 10 && unloggedToday.isNotEmpty) {
    return const HabitPromptData(
      message: 'Good morning! Start your day by checking off a habit',
      icon: 'morning',
      actionLabel: 'View Habits',
      actionRoute: '/habits',
    );
  }

  return null;
});
