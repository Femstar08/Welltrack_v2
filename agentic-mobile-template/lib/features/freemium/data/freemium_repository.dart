import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:welltrack/features/freemium/domain/plan_tier.dart';

/// Repository for managing freemium/subscription features
class FreemiumRepository {
  final SupabaseClient _supabase;

  FreemiumRepository(this._supabase);

  /// Gets the current plan tier for a user
  Future<PlanTier> getCurrentTier(String userId) async {
    final response = await _supabase
        .from('wt_users')
        .select('plan_tier')
        .eq('id', userId)
        .single();

    final tierString = response['plan_tier'] as String? ?? 'free';
    return PlanTier.fromString(tierString);
  }

  /// Gets remaining AI calls for today
  Future<int> getRemainingAICalls(String userId) async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    // Get user's plan tier
    final tier = await getCurrentTier(userId);

    // Get today's AI usage
    final response = await _supabase
        .from('wt_ai_usage')
        .select('call_count')
        .eq('user_id', userId)
        .gte('created_at', startOfDay.toIso8601String())
        .lt('created_at', endOfDay.toIso8601String());

    final usedCalls = (response as List).fold<int>(
      0,
      (sum, record) => sum + (record['call_count'] as int? ?? 1),
    );

    final remaining = tier.dailyAICalls - usedCalls;
    return remaining > 0 ? remaining : 0;
  }

  /// Increments AI usage counter
  Future<void> incrementAIUsage(String userId, {int count = 1}) async {
    await _supabase.from('wt_ai_usage').insert({
      'user_id': userId,
      'call_count': count,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// Checks if a specific feature is available for the user
  Future<bool> isFeatureAvailable(String userId, String feature) async {
    final tier = await getCurrentTier(userId);
    return tier.isFeatureAvailable(feature);
  }

  /// Checks if user has reached their AI limit
  Future<bool> hasReachedAILimit(String userId) async {
    final remaining = await getRemainingAICalls(userId);
    return remaining <= 0;
  }

  /// Gets AI usage stats for the current month
  Future<Map<String, int>> getMonthlyAIUsage(String userId) async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 1);

    final response = await _supabase
        .from('wt_ai_usage')
        .select('call_count, created_at')
        .eq('user_id', userId)
        .gte('created_at', startOfMonth.toIso8601String())
        .lt('created_at', endOfMonth.toIso8601String());

    int totalCalls = 0;
    int daysWithUsage = 0;

    if (response is List) {
      totalCalls = response.fold<int>(
        0,
        (sum, record) => sum + (record['call_count'] as int? ?? 1),
      );

      // Count unique days
      final uniqueDays = <String>{};
      for (final record in response) {
        final date = DateTime.parse(record['created_at'] as String);
        final dayKey = '${date.year}-${date.month}-${date.day}';
        uniqueDays.add(dayKey);
      }
      daysWithUsage = uniqueDays.length;
    }

    return {
      'total_calls': totalCalls,
      'days_with_usage': daysWithUsage,
      'average_per_day': daysWithUsage > 0 ? (totalCalls / daysWithUsage).round() : 0,
    };
  }

  /// Updates user's plan tier (for testing or admin purposes)
  Future<void> updatePlanTier(String userId, PlanTier tier) async {
    await _supabase.from('wt_users').update({
      'plan_tier': tier.toDbString(),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', userId);
  }

  /// Gets the subscription expiry date (if applicable)
  Future<DateTime?> getSubscriptionExpiry(String userId) async {
    final response = await _supabase
        .from('wt_users')
        .select('subscription_expires_at')
        .eq('id', userId)
        .single();

    final expiryString = response['subscription_expires_at'] as String?;
    if (expiryString == null) return null;

    return DateTime.parse(expiryString);
  }

  /// Checks if subscription is active
  Future<bool> isSubscriptionActive(String userId) async {
    final tier = await getCurrentTier(userId);
    if (tier == PlanTier.free) return false;

    final expiry = await getSubscriptionExpiry(userId);
    if (expiry == null) return true; // Lifetime subscription

    return expiry.isAfter(DateTime.now());
  }
}

/// Provider for freemium repository
final freemiumRepositoryProvider = Provider<FreemiumRepository>((ref) {
  final supabase = Supabase.instance.client;
  return FreemiumRepository(supabase);
});

/// Provider for current user's plan tier (with caching)
final currentPlanTierProvider = FutureProvider.autoDispose<PlanTier>((ref) async {
  final supabase = Supabase.instance.client;
  final userId = supabase.auth.currentUser?.id;

  if (userId == null) {
    return PlanTier.free;
  }

  final repository = ref.watch(freemiumRepositoryProvider);
  return repository.getCurrentTier(userId);
});

/// Provider for remaining AI calls today
final remainingAICallsProvider = FutureProvider.autoDispose<int>((ref) async {
  final supabase = Supabase.instance.client;
  final userId = supabase.auth.currentUser?.id;

  if (userId == null) {
    return 0;
  }

  final repository = ref.watch(freemiumRepositoryProvider);
  return repository.getRemainingAICalls(userId);
});

/// Provider for checking feature availability
final featureAvailableProvider = FutureProvider.autoDispose.family<bool, String>(
  (ref, featureName) async {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;

    if (userId == null) {
      return false;
    }

    final repository = ref.watch(freemiumRepositoryProvider);
    return repository.isFeatureAvailable(userId, featureName);
  },
);
