import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:health/health.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../logging/app_logger.dart';

/// Health platform connection status
enum HealthPlatformStatus {
  disconnected, // no permissions granted
  connected, // has permissions and ready
  needsUpgrade, // requires Health Connect app or iOS HealthKit access
}

/// Normalized health metric record from platform APIs
class HealthMetricRecord {

  HealthMetricRecord({
    required this.type,
    required this.value,
    this.stagesJson,
    required this.startTime,
    required this.endTime,
    required this.recordedAt,
    required this.source,
    required this.rawPayload,
  });
  final String type; // 'sleep', 'steps', 'resting_hr'
  final num value; // minutes, count, bpm
  final String? stagesJson; // JSON array for sleep stages
  final DateTime startTime;
  final DateTime endTime;
  final DateTime recordedAt;
  final String source; // 'health_connect' or 'healthkit'
  final Map<String, dynamic> rawPayload;

  /// Compute dedupe hash for this record
  String get dedupeHash {
    final content = '$source:$type:${startTime.toIso8601String()}:'
        '${endTime.toIso8601String()}:${value.toString()}';
    return sha256.convert(utf8.encode(content)).toString();
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'value': value,
      'stages_json': stagesJson,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
      'recorded_at': recordedAt.toIso8601String(),
      'source': source,
      'raw_payload': rawPayload,
      'dedupe_hash': dedupeHash,
    };
  }
}

/// Service for managing health data from Health Connect (Android) and HealthKit (iOS)
class HealthService {
  final Health _health = Health();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final AppLogger _logger = AppLogger();
  bool _configured = false;

  static const String _permissionsCacheKey = 'health_permissions_granted';
  static const String _lastSyncTimeKey = 'health_last_sync_time';

  /// Health data types for Android Health Connect
  /// SLEEP_IN_BED and HRV_SDNN are not available on Health Connect
  static final List<HealthDataType> _androidTypes = [
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_AWAKE,
    HealthDataType.SLEEP_DEEP,
    HealthDataType.SLEEP_LIGHT,
    HealthDataType.SLEEP_REM,
    HealthDataType.STEPS,
    HealthDataType.HEART_RATE,
    HealthDataType.WEIGHT,
    HealthDataType.BODY_FAT_PERCENTAGE,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.DISTANCE_DELTA,
  ];

  /// Health data types for iOS HealthKit (all types supported)
  static final List<HealthDataType> _iosTypes = [
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_AWAKE,
    HealthDataType.SLEEP_IN_BED,
    HealthDataType.SLEEP_DEEP,
    HealthDataType.SLEEP_LIGHT,
    HealthDataType.SLEEP_REM,
    HealthDataType.STEPS,
    HealthDataType.HEART_RATE,
    HealthDataType.WEIGHT,
    HealthDataType.BODY_FAT_PERCENTAGE,
    HealthDataType.HEART_RATE_VARIABILITY_SDNN,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.DISTANCE_DELTA,
  ];

  /// Get platform-appropriate types
  List<HealthDataType> get _types {
    if (kIsWeb) return _androidTypes;
    if (Platform.isIOS) return _iosTypes;
    return _androidTypes;
  }

  /// Initialize health platform
  Future<void> initialize() async {
    try {
      _logger.info('Initializing health service');

      // Check platform support — dart:io Platform is unavailable on web
      if (kIsWeb) {
        _logger.warning('Health data not supported on web');
        return;
      }
      if (!Platform.isAndroid && !Platform.isIOS) {
        _logger.warning('Health data not supported on this platform');
        return;
      }

      // Configure health package
      await _health.configure();
      _configured = true;

      _logger.info('Health service initialized successfully');
    } catch (e, stackTrace) {
      _logger.error('Error initializing health service', e, stackTrace);
    }
  }

  /// Ensure configured before operations
  Future<void> _ensureConfigured() async {
    if (_configured) return;
    await initialize();
  }

  /// Request runtime permissions for health data
  /// Returns true if all permissions granted
  Future<bool> requestHealthPermissions() async {
    try {
      await _ensureConfigured();
      _logger.info('Requesting health permissions');

      final types = _types;
      final permissions = types.map((type) => HealthDataAccess.READ).toList();

      final granted = await _health.requestAuthorization(
        types,
        permissions: permissions,
      );

      if (granted == true) {
        // Cache permission state
        await _storage.write(key: _permissionsCacheKey, value: 'true');
        // Also save to SharedPreferences for HealthDataSource consistency
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('health_permissions_granted', true);
        _logger.info('Health permissions granted');
      } else {
        await _storage.write(key: _permissionsCacheKey, value: 'false');
        _logger.warning('Health permissions denied');
      }

      return granted;
    } catch (e, stackTrace) {
      _logger.error('Error requesting health permissions', e, stackTrace);
      await _storage.write(key: _permissionsCacheKey, value: 'false');
      return false;
    }
  }

  /// Check if health permissions are granted
  Future<bool> isHealthConnected() async {
    try {
      await _ensureConfigured();

      // Check cached permission state first
      final cached = await _storage.read(key: _permissionsCacheKey);
      if (cached == 'false') {
        return false;
      }

      // Verify with platform
      final types = _types;
      final granted = await _health.hasPermissions(
        types,
        permissions: types.map((type) => HealthDataAccess.READ).toList(),
      );

      // If platform gives a definitive answer, use it
      if (granted != null) return granted;

      // Health Connect returns null — fall back to cached state
      return cached == 'true';
    } catch (e, stackTrace) {
      _logger.error('Error checking health permissions', e, stackTrace);
      // Fall back to cached state
      final cached = await _storage.read(key: _permissionsCacheKey);
      return cached == 'true';
    }
  }

  /// Get current health platform status
  Future<HealthPlatformStatus> getHealthStatus() async {
    try {
      if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
        return HealthPlatformStatus.disconnected;
      }

      final hasPermissions = await isHealthConnected();

      if (hasPermissions) {
        return HealthPlatformStatus.connected;
      }

      // Check if Health Connect app is available (Android)
      if (Platform.isAndroid) {
        // On Android 14+, Health Connect is built-in
        // On Android 13, user needs to install HC app
        return HealthPlatformStatus.needsUpgrade;
      }

      return HealthPlatformStatus.disconnected;
    } catch (e, stackTrace) {
      _logger.error('Error getting health status', e, stackTrace);
      return HealthPlatformStatus.disconnected;
    }
  }

  /// Sleep types for the current platform
  List<HealthDataType> get _sleepTypes {
    if (!kIsWeb && Platform.isIOS) {
      return [
        HealthDataType.SLEEP_ASLEEP,
        HealthDataType.SLEEP_AWAKE,
        HealthDataType.SLEEP_IN_BED,
        HealthDataType.SLEEP_DEEP,
        HealthDataType.SLEEP_LIGHT,
        HealthDataType.SLEEP_REM,
      ];
    }
    return [
      HealthDataType.SLEEP_ASLEEP,
      HealthDataType.SLEEP_AWAKE,
      HealthDataType.SLEEP_DEEP,
      HealthDataType.SLEEP_LIGHT,
      HealthDataType.SLEEP_REM,
    ];
  }

  /// Fetch sleep data for date range
  Future<List<HealthMetricRecord>> fetchSleep(
    DateTime start,
    DateTime end,
  ) async {
    try {
      await _ensureConfigured();
      _logger.info('Fetching sleep data from ${start.toIso8601String()} to ${end.toIso8601String()}');

      final data = await _health.getHealthDataFromTypes(
        startTime: start,
        endTime: end,
        types: _sleepTypes,
      );

      if (data.isEmpty) {
        _logger.info('No sleep data found');
        return [];
      }

      // Group by sleep session (same start/end times)
      final sessions = <String, List<HealthDataPoint>>{};
      for (final point in data) {
        final key = '${point.dateFrom.toIso8601String()}_${point.dateTo.toIso8601String()}';
        sessions.putIfAbsent(key, () => []).add(point);
      }

      // Convert to normalized records
      final records = <HealthMetricRecord>[];
      for (final session in sessions.values) {
        records.add(_normalizeSleepSession(session));
      }

      _logger.info('Fetched ${records.length} sleep records');
      return records;
    } catch (e, stackTrace) {
      _logger.error('Error fetching sleep data', e, stackTrace);
      return [];
    }
  }

  /// Fetch steps data for date range
  Future<List<HealthMetricRecord>> fetchSteps(
    DateTime start,
    DateTime end,
  ) async {
    try {
      await _ensureConfigured();
      _logger.info('Fetching steps data from ${start.toIso8601String()} to ${end.toIso8601String()}');

      final data = await _health.getHealthDataFromTypes(
        startTime: start,
        endTime: end,
        types: [HealthDataType.STEPS],
      );

      if (data.isEmpty) {
        _logger.info('No steps data found');
        return [];
      }

      final records = data.map(_normalizeSteps).toList();
      _logger.info('Fetched ${records.length} step records');
      return records;
    } catch (e, stackTrace) {
      _logger.error('Error fetching steps data', e, stackTrace);
      return [];
    }
  }

  /// Fetch resting heart rate data for date range
  Future<List<HealthMetricRecord>> fetchRestingHeartRate(
    DateTime start,
    DateTime end,
  ) async {
    try {
      await _ensureConfigured();
      _logger.info('Fetching heart rate data from ${start.toIso8601String()} to ${end.toIso8601String()}');

      final data = await _health.getHealthDataFromTypes(
        startTime: start,
        endTime: end,
        types: [HealthDataType.HEART_RATE],
      );

      if (data.isEmpty) {
        _logger.info('No heart rate data found');
        return [];
      }

      // Filter for resting HR (typically lowest morning reading)
      final records = data
          .where((point) => point.value is NumericHealthValue)
          .map(_normalizeHeartRate)
          .toList();

      _logger.info('Fetched ${records.length} heart rate records');
      return records;
    } catch (e, stackTrace) {
      _logger.error('Error fetching heart rate data', e, stackTrace);
      return [];
    }
  }

  /// Get today's sleep data
  Future<HealthMetricRecord?> getTodaysSleep() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day - 1, 18, 0); // 6 PM yesterday
    final end = DateTime(now.year, now.month, now.day, 12, 0); // 12 PM today

    final records = await fetchSleep(start, end);
    return records.isNotEmpty ? records.first : null;
  }

  /// Get today's steps
  Future<HealthMetricRecord?> getTodaysSteps() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day, 0, 0);
    final end = DateTime(now.year, now.month, now.day, 23, 59);

    final records = await fetchSteps(start, end);

    // Sum all step counts for today
    if (records.isEmpty) return null;

    final totalSteps = records.fold<num>(
      0,
      (sum, record) => sum + record.value,
    );

    return HealthMetricRecord(
      type: 'steps',
      value: totalSteps,
      startTime: start,
      endTime: end,
      recordedAt: DateTime.now(),
      source: _getPlatformSource(),
      rawPayload: {'total_steps': totalSteps, 'records_count': records.length},
    );
  }

  /// Get today's resting heart rate
  Future<HealthMetricRecord?> getTodaysRestingHR() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day, 0, 0);
    final end = DateTime(now.year, now.month, now.day, 23, 59);

    final records = await fetchRestingHeartRate(start, end);

    // Return lowest HR reading (likely resting)
    if (records.isEmpty) return null;

    records.sort((a, b) => a.value.compareTo(b.value));
    return records.first;
  }

  /// Fetch weight data for date range
  Future<List<HealthMetricRecord>> fetchWeight(DateTime start, DateTime end) async {
    try {
      await _ensureConfigured();
      final data = await _health.getHealthDataFromTypes(
        startTime: start, endTime: end,
        types: [HealthDataType.WEIGHT],
      );
      if (data.isEmpty) return [];
      return data
          .where((p) => p.value is NumericHealthValue)
          .map((p) => HealthMetricRecord(
                type: 'weight',
                value: (p.value as NumericHealthValue).numericValue.toDouble(),
                startTime: p.dateFrom,
                endTime: p.dateTo,
                recordedAt: DateTime.now(),
                source: _getPlatformSource(),
                rawPayload: {'unit': p.unit.name, 'source_name': p.sourceName},
              ))
          .toList();
    } catch (e, st) {
      _logger.error('Error fetching weight data', e, st);
      return [];
    }
  }

  /// Fetch HRV (SDNN) data for date range
  /// Only available on iOS; skipped on Android Health Connect
  Future<List<HealthMetricRecord>> fetchHRV(DateTime start, DateTime end) async {
    try {
      // HRV SDNN is not reliably available on Health Connect
      if (!kIsWeb && Platform.isAndroid) return [];

      await _ensureConfigured();
      final data = await _health.getHealthDataFromTypes(
        startTime: start, endTime: end,
        types: [HealthDataType.HEART_RATE_VARIABILITY_SDNN],
      );
      if (data.isEmpty) return [];
      return data
          .where((p) => p.value is NumericHealthValue)
          .map((p) => HealthMetricRecord(
                type: 'hrv',
                value: (p.value as NumericHealthValue).numericValue.toDouble(),
                startTime: p.dateFrom,
                endTime: p.dateTo,
                recordedAt: DateTime.now(),
                source: _getPlatformSource(),
                rawPayload: {'unit': 'ms', 'source_name': p.sourceName},
              ))
          .toList();
    } catch (e, st) {
      _logger.error('Error fetching HRV data', e, st);
      return [];
    }
  }

  /// Fetch active calories data for date range
  Future<List<HealthMetricRecord>> fetchActiveCalories(DateTime start, DateTime end) async {
    try {
      await _ensureConfigured();
      final data = await _health.getHealthDataFromTypes(
        startTime: start, endTime: end,
        types: [HealthDataType.ACTIVE_ENERGY_BURNED],
      );
      if (data.isEmpty) return [];
      return data
          .where((p) => p.value is NumericHealthValue)
          .map((p) => HealthMetricRecord(
                type: 'active_calories',
                value: (p.value as NumericHealthValue).numericValue.toDouble(),
                startTime: p.dateFrom,
                endTime: p.dateTo,
                recordedAt: DateTime.now(),
                source: _getPlatformSource(),
                rawPayload: {'unit': 'kcal', 'source_name': p.sourceName},
              ))
          .toList();
    } catch (e, st) {
      _logger.error('Error fetching active calories data', e, st);
      return [];
    }
  }

  /// Fetch distance data for date range
  Future<List<HealthMetricRecord>> fetchDistance(DateTime start, DateTime end) async {
    try {
      await _ensureConfigured();
      final data = await _health.getHealthDataFromTypes(
        startTime: start, endTime: end,
        types: [HealthDataType.DISTANCE_DELTA],
      );
      if (data.isEmpty) return [];
      return data
          .where((p) => p.value is NumericHealthValue)
          .map((p) => HealthMetricRecord(
                type: 'distance',
                value: (p.value as NumericHealthValue).numericValue.toDouble(),
                startTime: p.dateFrom,
                endTime: p.dateTo,
                recordedAt: DateTime.now(),
                source: _getPlatformSource(),
                rawPayload: {'unit': 'm', 'source_name': p.sourceName},
              ))
          .toList();
    } catch (e, st) {
      _logger.error('Error fetching distance data', e, st);
      return [];
    }
  }

  /// Sync health data for user profile
  /// Fetches last 7 days of data, normalizes, and returns records
  Future<List<HealthMetricRecord>> syncHealthData(
    String userId,
    String profileId,
  ) async {
    try {
      _logger.info('Syncing health data for profile: $profileId');

      // Check permissions
      final hasPermissions = await isHealthConnected();
      if (!hasPermissions) {
        _logger.warning('Health permissions not granted, skipping sync');
        return [];
      }

      final now = DateTime.now();
      final sevenDaysAgo = now.subtract(const Duration(days: 7));

      // Fetch all metric types
      final sleep = await fetchSleep(sevenDaysAgo, now);
      final steps = await fetchSteps(sevenDaysAgo, now);
      final heartRate = await fetchRestingHeartRate(sevenDaysAgo, now);
      final weight = await fetchWeight(sevenDaysAgo, now);
      final hrv = await fetchHRV(sevenDaysAgo, now);
      final activeCals = await fetchActiveCalories(sevenDaysAgo, now);
      final distance = await fetchDistance(sevenDaysAgo, now);

      final allRecords = [
        ...sleep,
        ...steps,
        ...heartRate,
        ...weight,
        ...hrv,
        ...activeCals,
        ...distance,
      ];

      // Update last sync time
      await _storage.write(
        key: _lastSyncTimeKey,
        value: now.toIso8601String(),
      );

      _logger.info('Health sync complete: ${allRecords.length} records');
      return allRecords;
    } catch (e, stackTrace) {
      _logger.error('Error syncing health data', e, stackTrace);
      return [];
    }
  }

  /// Get last sync timestamp
  Future<DateTime?> getLastSyncTime() async {
    try {
      final value = await _storage.read(key: _lastSyncTimeKey);
      return value != null ? DateTime.parse(value) : null;
    } catch (e) {
      _logger.error('Error getting last sync time', e);
      return null;
    }
  }

  // Private helper methods

  HealthMetricRecord _normalizeSleepSession(List<HealthDataPoint> session) {
    // Calculate total sleep time and extract stages
    final stages = <Map<String, dynamic>>[];
    num totalMinutes = 0;

    for (final point in session) {
      final duration = point.dateTo.difference(point.dateFrom);
      final minutes = duration.inMinutes;
      totalMinutes += minutes;

      String? stage;
      if (point.type == HealthDataType.SLEEP_DEEP) {
        stage = 'deep';
      } else if (point.type == HealthDataType.SLEEP_LIGHT) {
        stage = 'light';
      } else if (point.type == HealthDataType.SLEEP_REM) {
        stage = 'rem';
      } else if (point.type == HealthDataType.SLEEP_AWAKE) {
        stage = 'awake';
      }

      if (stage != null) {
        stages.add({'stage': stage, 'minutes': minutes});
      }
    }

    final firstPoint = session.first;

    return HealthMetricRecord(
      type: 'sleep',
      value: totalMinutes,
      stagesJson: stages.isNotEmpty ? jsonEncode(stages) : null,
      startTime: firstPoint.dateFrom,
      endTime: firstPoint.dateTo,
      recordedAt: DateTime.now(),
      source: _getPlatformSource(),
      rawPayload: {
        'session_count': session.length,
        'stages': stages,
      },
    );
  }

  HealthMetricRecord _normalizeSteps(HealthDataPoint point) {
    final value = point.value as NumericHealthValue;

    return HealthMetricRecord(
      type: 'steps',
      value: value.numericValue.toInt(),
      startTime: point.dateFrom,
      endTime: point.dateTo,
      recordedAt: DateTime.now(),
      source: _getPlatformSource(),
      rawPayload: {
        'unit': point.unit.name,
        'source_name': point.sourceName,
      },
    );
  }

  HealthMetricRecord _normalizeHeartRate(HealthDataPoint point) {
    final value = point.value as NumericHealthValue;

    return HealthMetricRecord(
      type: 'resting_hr',
      value: value.numericValue.toInt(),
      startTime: point.dateFrom,
      endTime: point.dateTo,
      recordedAt: DateTime.now(),
      source: _getPlatformSource(),
      rawPayload: {
        'unit': point.unit.name,
        'source_name': point.sourceName,
      },
    );
  }

  String _getPlatformSource() {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) {
      return 'health_connect';
    } else if (Platform.isIOS) {
      return 'healthkit';
    }
    return 'unknown';
  }
}

/// Riverpod provider for HealthService
final healthServiceProvider = Provider<HealthService>((ref) {
  return HealthService();
});

/// Provider for health connection status
final healthConnectionStatusProvider = FutureProvider<HealthPlatformStatus>((ref) async {
  final service = ref.watch(healthServiceProvider);
  return await service.getHealthStatus();
});

/// Provider for last health sync time
final lastHealthSyncTimeProvider = FutureProvider<DateTime?>((ref) async {
  final service = ref.watch(healthServiceProvider);
  return await service.getLastSyncTime();
});
