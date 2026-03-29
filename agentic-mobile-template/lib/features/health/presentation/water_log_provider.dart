import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// State for today's water intake.
class WaterLogState {
  const WaterLogState({
    this.totalMl = 0,
    this.glassCount = 0,
    this.isLoading = false,
    this.error,
  });
  final int totalMl;
  final int glassCount;
  final bool isLoading;
  final String? error;

  WaterLogState copyWith({
    int? totalMl,
    int? glassCount,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return WaterLogState(
      totalMl: totalMl ?? this.totalMl,
      glassCount: glassCount ?? this.glassCount,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Manages water logging via wt_health_metrics (metric_type='water').
class WaterLogNotifier extends StateNotifier<WaterLogState> {
  WaterLogNotifier(this._profileId) : super(const WaterLogState()) {
    loadTodayWater();
  }

  final String _profileId;

  static const _mlPerGlass = 250;

  Future<void> loadTodayWater() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      // Water isn't in MetricType enum — query manually.
      final client = Supabase.instance.client;
      final response = await client
          .from('wt_health_metrics')
          .select('value_num')
          .eq('profile_id', _profileId)
          .eq('metric_type', 'water')
          .gte('start_time', startOfDay.toIso8601String())
          .lte('start_time', endOfDay.toIso8601String());

      int totalMl = 0;
      for (final row in response) {
        totalMl += ((row['value_num'] as num?)?.toInt() ?? 0);
      }

      state = state.copyWith(
        totalMl: totalMl,
        glassCount: (totalMl / _mlPerGlass).round(),
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> addWater(int glasses) async {
    final ml = glasses * _mlPerGlass;
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id ?? '';
      final now = DateTime.now();

      await client.from('wt_health_metrics').insert({
        'profile_id': _profileId,
        'user_id': userId,
        'source': 'manual',
        'metric_type': 'water',
        'value_num': ml,
        'unit': 'ml',
        'start_time': now.toIso8601String(),
        'recorded_at': now.toIso8601String(),
        'validation_status': 'validated',
        'processing_status': 'processed',
      });

      // Optimistic update
      state = state.copyWith(
        totalMl: state.totalMl + ml,
        glassCount: state.glassCount + glasses,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
}

final waterLogProvider =
    StateNotifierProvider.family<WaterLogNotifier, WaterLogState, String>(
        (ref, profileId) {
  return WaterLogNotifier(profileId);
});
