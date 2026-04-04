import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'insights_provider.dart';
import '../../../shared/core/auth/session_manager.dart';

/// Convenience provider that extracts today's recovery score from
/// [insightsProvider] so widgets don't need the full insights state.
///
/// Returns `null` during baseline calibration or when no health data exists.
final todayRecoveryScoreProvider =
    Provider.family<double?, String>((ref, profileId) {
  final userId = ref.watch(currentUserIdProvider) ?? '';
  if (userId.isEmpty) return null;

  final insightsState =
      ref.watch(insightsProvider((profileId: profileId, userId: userId)));
  return insightsState.latestRecoveryScore?.recoveryScore;
});
