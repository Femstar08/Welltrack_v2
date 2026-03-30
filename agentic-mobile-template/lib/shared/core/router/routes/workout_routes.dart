import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../features/workouts/presentation/workout_plan_detail_screen.dart'
    as workout_plan_detail;
import '../../../../features/workouts/presentation/exercise_browser_screen.dart'
    as exercise_browser;
import '../../../../features/workouts/presentation/workout_logging_screen.dart'
    as workout_logging;
import '../../../../features/workouts/presentation/session_summary_screen.dart'
    as session_summary;
import '../../../../features/workouts/presentation/progress_screen.dart'
    as progress_screen;
import '../../../../features/workouts/presentation/body_map_screen.dart'
    as body_map;

import '../app_router.dart' show activeProfileIdProvider;

/// Nested routes under /workouts (Branch 2).
List<GoRoute> workoutChildRoutes(Ref ref) {
  return [
    GoRoute(
      path: 'plan/:planId',
      name: 'workoutPlanDetail',
      builder: (context, state) {
        final planId = state.pathParameters['planId']!;
        return workout_plan_detail.WorkoutPlanDetailScreen(planId: planId);
      },
    ),
    GoRoute(
      path: 'exercises',
      name: 'exerciseBrowser',
      builder: (context, state) {
        final selectMode =
            state.uri.queryParameters['selectMode'] == 'true';
        return exercise_browser.ExerciseBrowserScreen(
          selectMode: selectMode,
        );
      },
    ),
    GoRoute(
      path: 'log/:workoutId',
      name: 'workoutLog',
      builder: (context, state) {
        final workoutId = state.pathParameters['workoutId']!;
        final profileId = ref.read(activeProfileIdProvider) ?? '';
        final extra = state.extra as Map<String, dynamic>? ?? {};
        return workout_logging.WorkoutLoggingScreen(
          profileId: profileId,
          workoutId: workoutId,
          planId: extra['planId'] as String?,
          dayOfWeek: extra['dayOfWeek'] as int?,
          planName: extra['planName'] as String?,
        );
      },
    ),
    GoRoute(
      path: 'summary/:workoutId',
      name: 'sessionSummary',
      builder: (context, state) {
        final workoutId = state.pathParameters['workoutId']!;
        return session_summary.SessionSummaryScreen(
          workoutId: workoutId,
        );
      },
    ),
    GoRoute(
      path: 'progress',
      name: 'workoutProgress',
      builder: (context, state) =>
          const progress_screen.ProgressScreen(),
    ),
    GoRoute(
      path: 'body-map',
      name: 'bodyMap',
      builder: (context, state) => const body_map.BodyMapScreen(),
    ),
  ];
}
