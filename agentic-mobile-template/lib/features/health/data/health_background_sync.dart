import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workmanager/workmanager.dart';
import 'baseline_calibration.dart';
import 'health_repository.dart';
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
  /// 2. Check baseline calibration status
  /// 3. Compute baselines if ready
  /// 4. Update last sync timestamp
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

      // Check if baselines are complete
      final allComplete = await calibration.hasAllBaselinesComplete(profileId);

      if (!allComplete) {
        _logger.info('HealthBackgroundSync: Baselines incomplete, computing...');
        final baselines = await calibration.computeAllBaselines(profileId);
        _logger.info('HealthBackgroundSync: Computed ${baselines.length} baselines');
      } else {
        _logger.info('HealthBackgroundSync: All baselines already complete');
      }

      // Update last sync timestamp
      await _updateLastSyncTime(profileId);

      _logger.info('HealthBackgroundSync: Manual sync completed successfully');
    } catch (e) {
      _logger.error('HealthBackgroundSync: Error during manual sync: $e');
      rethrow;
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

      // Initialize SharedPreferences
      final prefs = await SharedPreferences.getInstance();

      // Get profile ID from last sync
      final profileId = prefs.getString('health_last_sync_profile_id');

      if (profileId == null) {
        _logger.warning('HealthBackgroundSync: No profile ID found, skipping sync');
        return Future.value(true);
      }

      // Check if user is authenticated
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        _logger.warning('HealthBackgroundSync: User not authenticated in background, skipping sync');
        return Future.value(true);
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

      // Update last sync timestamp
      await prefs.setString(
        'health_last_sync_time',
        DateTime.now().toIso8601String(),
      );

      _logger.info('HealthBackgroundSync: Background sync completed successfully');
      return Future.value(true);
    } catch (e) {
      _logger.error('HealthBackgroundSync: Background sync failed: $e');
      // Return false to trigger backoff retry
      return Future.value(false);
    }
  });
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
