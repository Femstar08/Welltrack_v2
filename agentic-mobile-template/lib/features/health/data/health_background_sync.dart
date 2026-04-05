import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workmanager/workmanager.dart';
import 'baseline_calibration.dart';
import 'health_repository.dart';
import '../../reminders/data/notification_service.dart';
import '../../reminders/domain/reminder_entity.dart';
import '../../insights/data/insights_repository.dart';
import '../../insights/domain/training_load_entity.dart';
import '../../insights/data/performance_engine.dart';
import '../../goals/data/goal_repository.dart';
import '../../../shared/core/logging/app_logger.dart';

final _logger = AppLogger();

/// Background sync service for health data using Workmanager
///
/// Features:
/// - Periodic sync every 6 hours
/// - Network-connected constraint
/// - Auto-triggers baseline calibration after sync
/// - Logs sync timestamps to SharedPreferences
class HealthBackgroundSync {

  HealthBackgroundSync({
    required SharedPreferences preferences,
  }) : _prefs = preferences;
  static const String syncTaskName = 'welltrack_health_sync';
  static const String periodicTaskName = 'welltrack_health_periodic_sync';
  static const String _lastSyncKey = 'health_last_sync_time';
  static const String _lastSyncProfileKey = 'health_last_sync_profile_id';

  final SharedPreferences _prefs;

  /// Initialize workmanager and register periodic sync
  ///
  /// Must be called during app initialization (e.g., main.dart)
  /// Registers the background task callback dispatcher
  Future<void> initialize() async {
    try {
      await Workmanager().initialize(
        callbackDispatcher,
      );
      _logger.info('HealthBackgroundSync: Workmanager initialized');
    } catch (e) {
      _logger.error('HealthBackgroundSync: Failed to initialize workmanager: $e');
      // Don't rethrow — workmanager init failure is non-fatal
    }
  }

  /// Registers periodic sync task
  ///
  /// Frequency: Every 6 hours
  /// Constraints: Network connected
  /// Existing work policy: Keep (don't replace if already registered)
  Future<void> registerPeriodicSync() async {
    try {
      await Workmanager().registerPeriodicTask(
        periodicTaskName,
        periodicTaskName,
        frequency: const Duration(hours: 6),
        constraints: Constraints(
          networkType: NetworkType.connected,
        ),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
        backoffPolicy: BackoffPolicy.exponential,
        backoffPolicyDelay: const Duration(minutes: 15),
      );
      _logger.info('HealthBackgroundSync: Periodic sync registered (every 6 hours)');
    } catch (e) {
      _logger.error('HealthBackgroundSync: Failed to register periodic sync: $e');
      // Don't rethrow — periodic sync registration failure is non-fatal
    }
  }

  /// Cancels all registered sync tasks
  Future<void> cancelSync() async {
    try {
      await Workmanager().cancelAll();
      _logger.info('HealthBackgroundSync: All sync tasks cancelled');
    } catch (e) {
      _logger.error('HealthBackgroundSync: Failed to cancel sync tasks: $e');
      rethrow;
    }
  }

  /// Triggers immediate one-time sync (for manual refresh from UI)
  ///
  /// Steps:
  /// 1. Sync health data for the last 24 hours
  /// 2. Apply source priority: skip Health Connect metrics already covered by Garmin
  /// 3. Check baseline calibration status
  /// 4. Compute baselines if ready
  /// 5. Update last sync timestamp
  Future<void> syncNow(String profileId) async {
    try {
      _logger.info('HealthBackgroundSync: Starting manual sync for profile $profileId');

      // Check if user is authenticated
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        _logger.warning('HealthBackgroundSync: User not authenticated, skipping sync');
        return;
      }

      // Create repository instances
      final healthRepo = HealthRepository();
      final calibration = BaselineCalibration();

      // Sync health data (last 24h)
      final syncResult = await healthRepo.syncHealthData(profileId);
      _logger.debug('HealthBackgroundSync: Synced ${syncResult['sleep']} sleep, '
          '${syncResult['steps']} steps, ${syncResult['hr']} HR records');

      // Phase 11: enforce Garmin > Health Connect source priority.
      // If Garmin is connected and already wrote today's stress or VO2 max,
      // remove the lower-fidelity Health Connect duplicates for those metrics.
      await _enforceGarminSourcePriority(profileId);

      // Check if baselines are complete
      final allComplete = await calibration.hasAllBaselinesComplete(profileId);

      if (!allComplete) {
        _logger.info('HealthBackgroundSync: Baselines incomplete, computing...');
        final baselines = await calibration.computeAllBaselines(profileId);
        _logger.info('HealthBackgroundSync: Computed ${baselines.length} baselines');
      } else {
        _logger.info('HealthBackgroundSync: All baselines already complete');
      }

      // Calculate training loads from recent workout logs (US-002)
      await _syncTrainingLoads(profileId);

      // Auto-calculate today's recovery score if not yet done (US-001)
      await _calculateDailyRecoveryIfNeeded(profileId);

      // Auto-refresh goal progress from latest health data.
      // recalculateForecast() pulls the latest value from wt_health_metrics
      // and updates goal.currentValue so progress tracking stays current.
      await _refreshGoalProgress(profileId);

      // Update last sync timestamp
      await _updateLastSyncTime(profileId);

      _logger.info('HealthBackgroundSync: Manual sync completed successfully');
    } catch (e) {
      _logger.error('HealthBackgroundSync: Error during manual sync: $e');
      rethrow;
    }
  }

  /// Calculate training loads from recent workout logs not yet recorded.
  Future<void> _syncTrainingLoads(String profileId) async {
    try {
      final supabase = Supabase.instance.client;
      final insightsRepo = InsightsRepository(supabase);

      // Fetch workout logs from last 28 days that have duration and intensity
      final since = DateTime.now().subtract(const Duration(days: 28));
      final response = await supabase
          .from('wt_workout_logs')
          .select('id, workout_id, started_at, duration_seconds, intensity, avg_hr_bpm')
          .eq('profile_id', profileId)
          .gte('started_at', since.toIso8601String())
          .not('duration_seconds', 'is', null);

      for (final row in (response as List)) {
        final durationSec = (row['duration_seconds'] as num?)?.toDouble() ?? 0;
        if (durationSec < 60) continue; // skip sub-minute sessions

        final durationMin = durationSec / 60.0;
        final intensityStr = (row['intensity'] as String?) ?? 'moderate';
        final factor = PerformanceEngine.intensityFactorFromString(intensityStr);
        final load = PerformanceEngine.calculateTrainingLoad(durationMin, factor);
        final loadDate = DateTime.parse(row['started_at'] as String);

        final entity = TrainingLoadEntity(
          id: '',
          profileId: profileId,
          workoutId: row['workout_id'] as String?,
          loadDate: loadDate,
          durationMinutes: durationMin,
          intensityFactor: factor,
          trainingLoad: load,
          loadType: TrainingLoadType.mixed,
          avgHrBpm: (row['avg_hr_bpm'] as num?)?.toDouble(),
        );

        await insightsRepo.saveTrainingLoad(entity);
      }
      _logger.info('HealthBackgroundSync: Training loads synced');
    } catch (e) {
      _logger.warning('HealthBackgroundSync: Training load sync failed: $e');
      // Non-fatal
    }
  }

  /// Enforce Garmin > Health Connect source priority for overlapping metrics.
  ///
  /// Metrics where Garmin provides higher fidelity than Health Connect:
  ///   - stress (continuous wrist measurement vs HRV-derived estimate)
  ///   - vo2max (Garmin's proprietary FitStar algorithm vs HC approximation)
  ///
  /// When Garmin rows exist for today's date, any Health Connect rows for the
  /// same metric_type on the same day are deleted. This prevents the performance
  /// engine from accidentally picking up the lower-fidelity HC reading.
  ///
  /// The body_battery metric type is Garmin-exclusive — no HC equivalent exists,
  /// so no deduplication is needed for it.
  Future<void> _enforceGarminSourcePriority(String profileId) async {
    // Metric types where Garmin wins over Health Connect
    const garminPriorityMetrics = ['stress', 'vo2max'];

    final supabase = Supabase.instance.client;
    final today = DateTime.now();
    final startOfDay =
        DateTime.utc(today.year, today.month, today.day).toIso8601String();
    final startOfNextDay = DateTime.utc(today.year, today.month, today.day)
        .add(const Duration(days: 1))
        .toIso8601String();

    for (final metricType in garminPriorityMetrics) {
      try {
        // Check if a Garmin row exists for this metric today
        final garminCheck = await supabase
            .from('wt_health_metrics')
            .select('id')
            .eq('profile_id', profileId)
            .eq('metric_type', metricType)
            .eq('source', 'garmin')
            .gte('start_time', startOfDay)
            .lt('start_time', startOfNextDay)
            .limit(1);

        if ((garminCheck as List).isEmpty) continue; // Garmin not connected / no data

        // Garmin data found — remove Health Connect rows for the same metric + day
        await supabase
            .from('wt_health_metrics')
            .delete()
            .eq('profile_id', profileId)
            .eq('metric_type', metricType)
            .eq('source', 'healthconnect')
            .gte('start_time', startOfDay)
            .lt('start_time', startOfNextDay);

        _logger.info(
            'HealthBackgroundSync: Removed HC duplicates for $metricType (Garmin priority)');
      } catch (e) {
        _logger.warning(
            'HealthBackgroundSync: Source priority enforcement failed for $metricType: $e');
        // Non-fatal — continue to next metric
      }
    }
  }

  /// Refresh all active goals by recalculating forecasts from latest health data.
  /// This ensures goal.currentValue stays in sync after every health sync.
  Future<void> _refreshGoalProgress(String profileId) async {
    try {
      final supabase = Supabase.instance.client;
      final goalsRepo = GoalsRepository(supabase);
      final insightsRepo = InsightsRepository(supabase);

      final goals = await goalsRepo.getGoals(profileId);
      int updated = 0;
      for (final goal in goals) {
        try {
          await goalsRepo.recalculateForecast(goal.id, insightsRepo);
          updated++;
        } catch (_) {
          // Individual goal failure shouldn't stop others
        }
      }
      if (updated > 0) {
        _logger.info('HealthBackgroundSync: Refreshed $updated goal(s)');
      }
    } catch (e) {
      _logger.warning('HealthBackgroundSync: Goal refresh failed (non-fatal): $e');
    }
  }

  /// Auto-calculate today's recovery score if not yet calculated.
  Future<void> _calculateDailyRecoveryIfNeeded(String profileId) async {
    try {
      final insightsRepo = InsightsRepository(Supabase.instance.client);
      await insightsRepo.calculateAndSaveDailyRecovery(profileId: profileId);
      _logger.info('HealthBackgroundSync: Daily recovery score ensured');
    } catch (e) {
      _logger.warning('HealthBackgroundSync: Recovery score calculation failed: $e');
      // Non-fatal
    }
  }

  /// Gets the last sync timestamp for a profile
  Future<DateTime?> getLastSyncTime() async {
    try {
      final timestamp = _prefs.getString(_lastSyncKey);
      if (timestamp == null) return null;
      return DateTime.parse(timestamp);
    } catch (e) {
      _logger.error('HealthBackgroundSync: Error getting last sync time: $e');
      return null;
    }
  }

  /// Gets the profile ID from last sync
  Future<String?> getLastSyncProfileId() async {
    return _prefs.getString(_lastSyncProfileKey);
  }

  /// Updates the last sync timestamp
  Future<void> _updateLastSyncTime(String profileId) async {
    try {
      final now = DateTime.now();
      await _prefs.setString(_lastSyncKey, now.toIso8601String());
      await _prefs.setString(_lastSyncProfileKey, profileId);
      _logger.debug('HealthBackgroundSync: Updated last sync time to $now');
    } catch (e) {
      _logger.error('HealthBackgroundSync: Error updating last sync time: $e');
    }
  }

  /// Checks if sync is due (last sync was more than 6 hours ago)
  Future<bool> isSyncDue() async {
    final lastSync = await getLastSyncTime();
    if (lastSync == null) return true;

    final now = DateTime.now();
    final difference = now.difference(lastSync);
    return difference.inHours >= 6;
  }
}

/// Top-level callback dispatcher for Workmanager
///
/// REQUIRED: This must be a top-level function (not in a class)
/// Workmanager invokes this in a separate isolate
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    _logger.info('HealthBackgroundSync: Background task started: $task');

    try {
      // Initialize Supabase in the background isolate
      await Supabase.initialize(
        url: const String.fromEnvironment('SUPABASE_URL'),
        anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
      );

      // Route to appropriate handler
      if (task == 'reschedule_notifications') {
        return await _rescheduleNotificationsBackground();
      }

      // Default: health sync task
      return await _runHealthSyncBackground();
    } catch (e) {
      _logger.error('HealthBackgroundSync: Background task failed: $e');
      // Return false to trigger backoff retry
      return Future.value(false);
    }
  });
}

/// Reschedules all active notifications after device reboot.
/// Called from BootReceiver via WorkManager.
@pragma('vm:entry-point')
Future<bool> _rescheduleNotificationsBackground() async {
  try {
    // Check authentication
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      _logger.warning('HealthBackgroundSync: Not authenticated, skipping notification reschedule');
      return true; // Not a failure — user may not be logged in yet
    }

    // Get profile ID stored at last sync
    final prefs = await SharedPreferences.getInstance();
    final profileId = prefs.getString('health_last_sync_profile_id');
    if (profileId == null) {
      _logger.warning('HealthBackgroundSync: No profile ID stored, skipping reschedule');
      return true;
    }

    // Fetch active reminders directly from Supabase
    final supabase = Supabase.instance.client;
    final response = await supabase
        .from('wt_reminders')
        .select()
        .eq('profile_id', profileId)
        .eq('is_active', true)
        .order('remind_at');

    final reminders = (response as List)
        .map((json) => ReminderEntity.fromJson(json as Map<String, dynamic>))
        .toList();

    if (reminders.isEmpty) {
      _logger.info('HealthBackgroundSync: No active reminders to reschedule after boot');
      return true;
    }

    // Initialize flutter_local_notifications in this isolate
    final plugin = FlutterLocalNotificationsPlugin();
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await plugin.initialize(initSettings, onDidReceiveNotificationResponse: (_) {});

    // Create notification channel
    final androidImpl = plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    const channel = AndroidNotificationChannel(
      'welltrack_reminders',
      'WellTrack Reminders',
      description: 'Notifications for meals, supplements, workouts, and other reminders',
      importance: Importance.high,
    );
    await androidImpl?.createNotificationChannel(channel);

    // Clear stale scheduled notifications and reschedule active ones
    await plugin.cancelAll();
    final notifService = NotificationService(plugin);

    int rescheduled = 0;
    for (final reminder in reminders) {
      try {
        await notifService.scheduleRepeatingNotification(reminder);
        rescheduled++;
      } catch (e) {
        _logger.warning('HealthBackgroundSync: Failed to reschedule reminder ${reminder.id}: $e');
      }
    }

    _logger.info('HealthBackgroundSync: Rescheduled $rescheduled/${reminders.length} notifications after boot');
    return true;
  } catch (e) {
    _logger.error('HealthBackgroundSync: Notification reschedule failed: $e');
    return false;
  }
}

/// Enforce Garmin > Health Connect source priority in the background isolate.
/// Top-level function — mirrors [HealthBackgroundSync._enforceGarminSourcePriority].
Future<void> _enforceGarminSourcePriorityBackground(String profileId) async {
  const garminPriorityMetrics = ['stress', 'vo2max'];
  final supabase = Supabase.instance.client;
  final today = DateTime.now();
  final startOfDay =
      DateTime.utc(today.year, today.month, today.day).toIso8601String();
  final startOfNextDay = DateTime.utc(today.year, today.month, today.day)
      .add(const Duration(days: 1))
      .toIso8601String();

  for (final metricType in garminPriorityMetrics) {
    try {
      final garminCheck = await supabase
          .from('wt_health_metrics')
          .select('id')
          .eq('profile_id', profileId)
          .eq('metric_type', metricType)
          .eq('source', 'garmin')
          .gte('start_time', startOfDay)
          .lt('start_time', startOfNextDay)
          .limit(1);

      if ((garminCheck as List).isEmpty) continue;

      await supabase
          .from('wt_health_metrics')
          .delete()
          .eq('profile_id', profileId)
          .eq('metric_type', metricType)
          .eq('source', 'healthconnect')
          .gte('start_time', startOfDay)
          .lt('start_time', startOfNextDay);

      _logger.info(
          'HealthBackgroundSync [bg]: Removed HC duplicates for $metricType (Garmin priority)');
    } catch (e) {
      _logger.warning(
          'HealthBackgroundSync [bg]: Source priority enforcement failed for $metricType: $e');
    }
  }
}

/// Runs the health data sync in the background isolate.
Future<bool> _runHealthSyncBackground() async {
  try {
    // Initialize SharedPreferences
    final prefs = await SharedPreferences.getInstance();

    // Get profile ID from last sync
    final profileId = prefs.getString('health_last_sync_profile_id');

    if (profileId == null) {
      _logger.warning('HealthBackgroundSync: No profile ID found, skipping sync');
      return true;
    }

    // Check if user is authenticated
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      _logger.warning('HealthBackgroundSync: User not authenticated in background, skipping sync');
      return true;
    }

    // Create repository instances
    final healthRepo = HealthRepository();
    final calibration = BaselineCalibration();

    // Sync health data (last 24h)
    final syncResult = await healthRepo.syncHealthData(profileId);
    _logger.debug('HealthBackgroundSync: Background synced ${syncResult['sleep']} sleep, '
        '${syncResult['steps']} steps, ${syncResult['hr']} HR records');

    // Check if baselines are complete
    final allComplete = await calibration.hasAllBaselinesComplete(profileId);

    if (!allComplete) {
      _logger.info('HealthBackgroundSync: Baselines incomplete, computing in background...');
      final baselines = await calibration.computeAllBaselines(profileId);
      _logger.info('HealthBackgroundSync: Computed ${baselines.length} baselines in background');
    }

    // Phase 11: enforce Garmin > Health Connect source priority in background too
    await _enforceGarminSourcePriorityBackground(profileId);

    // Sync training loads from workout logs
    try {
      final insightsRepo = InsightsRepository(Supabase.instance.client);
      final since = DateTime.now().subtract(const Duration(days: 28));
      final response = await Supabase.instance.client
          .from('wt_workout_logs')
          .select('id, workout_id, started_at, duration_seconds, intensity, avg_hr_bpm')
          .eq('profile_id', profileId)
          .gte('started_at', since.toIso8601String())
          .not('duration_seconds', 'is', null);

      for (final row in (response as List)) {
        final durationSec = (row['duration_seconds'] as num?)?.toDouble() ?? 0;
        if (durationSec < 60) continue;
        final durationMin = durationSec / 60.0;
        final factor = PerformanceEngine.intensityFactorFromString(
            (row['intensity'] as String?) ?? 'moderate');
        final entity = TrainingLoadEntity(
          id: '',
          profileId: profileId,
          workoutId: row['workout_id'] as String?,
          loadDate: DateTime.parse(row['started_at'] as String),
          durationMinutes: durationMin,
          intensityFactor: factor,
          trainingLoad: PerformanceEngine.calculateTrainingLoad(durationMin, factor),
          loadType: TrainingLoadType.mixed,
          avgHrBpm: (row['avg_hr_bpm'] as num?)?.toDouble(),
        );
        await insightsRepo.saveTrainingLoad(entity);
      }

      // Auto-calculate today's recovery score
      await insightsRepo.calculateAndSaveDailyRecovery(profileId: profileId);
    } catch (e) {
      _logger.warning('HealthBackgroundSync: Post-sync calculations failed: $e');
    }

    // Update last sync timestamp
    await prefs.setString(
      'health_last_sync_time',
      DateTime.now().toIso8601String(),
    );

    _logger.info('HealthBackgroundSync: Background sync completed successfully');
    return true;
  } catch (e) {
    _logger.error('HealthBackgroundSync: Health sync failed: $e');
    return false;
  }
}

/// Override state provider — set during app init with SharedPreferences instance
final healthBackgroundSyncOverrideProvider =
    StateProvider<HealthBackgroundSync?>((ref) => null);

/// Riverpod provider for HealthBackgroundSync
/// Reads from the override; returns null-safe instance
final healthBackgroundSyncProvider = Provider<HealthBackgroundSync>((ref) {
  final override = ref.watch(healthBackgroundSyncOverrideProvider);
  if (override == null) {
    throw StateError(
      'healthBackgroundSyncProvider accessed before SharedPreferences init',
    );
  }
  return override;
});

/// Provider for last sync time
final lastSyncTimeProvider = FutureProvider<DateTime?>((ref) async {
  final override = ref.watch(healthBackgroundSyncOverrideProvider);
  if (override == null) return null;
  return await override.getLastSyncTime();
});

/// Provider to check if sync is due
final isSyncDueProvider = FutureProvider<bool>((ref) async {
  final override = ref.watch(healthBackgroundSyncOverrideProvider);
  if (override == null) return true;
  return await override.isSyncDue();
});

/// Provider for last synced profile ID
final lastSyncProfileIdProvider = FutureProvider<String?>((ref) async {
  final override = ref.watch(healthBackgroundSyncOverrideProvider);
  if (override == null) return null;
  return await override.getLastSyncProfileId();
});
