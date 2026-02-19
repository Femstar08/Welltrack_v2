import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:welltrack/features/health/domain/health_metric_entity.dart';

/// Data source for reading health data from platform APIs
/// Uses Health Connect on Android and HealthKit on iOS
class HealthDataSource {
  final Health _health = Health();
  bool _configured = false;

  static const String _permissionGrantedKey = 'health_permissions_granted';

  /// Health data types for Android Health Connect
  /// Note: SLEEP_IN_BED is not available on Health Connect
  /// HEART_RATE_VARIABILITY_SDNN may not be available on all devices
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

  /// Health data types for iOS HealthKit (includes SLEEP_IN_BED + HRV)
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

  /// Get platform-appropriate types list
  List<HealthDataType> get _types {
    if (kIsWeb) return _androidTypes;
    if (Platform.isIOS) return _iosTypes;
    return _androidTypes;
  }

  /// Ensure Health plugin is configured before operations
  Future<void> _ensureConfigured() async {
    if (_configured) return;
    try {
      await _health.configure();
      _configured = true;
    } catch (e) {
      print('Error configuring health plugin: $e');
    }
  }

  /// Request permissions for reading health data
  Future<bool> requestPermissions() async {
    try {
      await _ensureConfigured();

      final types = _types;
      final permissions = types
          .map((type) => HealthDataAccess.READ)
          .toList();

      final granted = await _health.requestAuthorization(
        types,
        permissions: permissions,
      );

      // Cache permission state — hasPermissions() returns null on Health Connect
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_permissionGrantedKey, granted);

      return granted;
    } catch (e) {
      print('Error requesting health permissions: $e');
      return false;
    }
  }

  /// Check if permissions are granted
  /// On Android Health Connect, hasPermissions() may return null,
  /// so we fall back to the cached permission state from requestPermissions()
  Future<bool> hasPermissions() async {
    try {
      await _ensureConfigured();

      final types = _types;
      final granted = await _health.hasPermissions(
        types,
        permissions: types.map((type) => HealthDataAccess.READ).toList(),
      );

      // If the platform gives a definitive answer, use it
      if (granted != null) return granted;

      // Health Connect returns null — fall back to cached state
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_permissionGrantedKey) ?? false;
    } catch (e) {
      print('Error checking health permissions: $e');
      // Fall back to cached state on error
      try {
        final prefs = await SharedPreferences.getInstance();
        return prefs.getBool(_permissionGrantedKey) ?? false;
      } catch (_) {
        return false;
      }
    }
  }

  /// Fetch sleep data for the given date range
  Future<List<HealthDataPoint>> fetchSleepData(
    DateTime start,
    DateTime end,
  ) async {
    try {
      await _ensureConfigured();

      final sleepTypes = kIsWeb || (!kIsWeb && Platform.isAndroid)
          ? [
              HealthDataType.SLEEP_ASLEEP,
              HealthDataType.SLEEP_AWAKE,
              HealthDataType.SLEEP_DEEP,
              HealthDataType.SLEEP_LIGHT,
              HealthDataType.SLEEP_REM,
            ]
          : [
              HealthDataType.SLEEP_ASLEEP,
              HealthDataType.SLEEP_AWAKE,
              HealthDataType.SLEEP_IN_BED,
              HealthDataType.SLEEP_DEEP,
              HealthDataType.SLEEP_LIGHT,
              HealthDataType.SLEEP_REM,
            ];

      final data = await _health.getHealthDataFromTypes(
        startTime: start,
        endTime: end,
        types: sleepTypes,
      );

      return data;
    } catch (e) {
      print('Error fetching sleep data: $e');
      return [];
    }
  }

  /// Fetch steps data for the given date range
  Future<List<HealthDataPoint>> fetchStepsData(
    DateTime start,
    DateTime end,
  ) async {
    try {
      await _ensureConfigured();

      final data = await _health.getHealthDataFromTypes(
        startTime: start,
        endTime: end,
        types: [HealthDataType.STEPS],
      );

      return data;
    } catch (e) {
      print('Error fetching steps data: $e');
      return [];
    }
  }

  /// Fetch heart rate data for the given date range
  Future<List<HealthDataPoint>> fetchHeartRateData(
    DateTime start,
    DateTime end,
  ) async {
    try {
      await _ensureConfigured();

      final data = await _health.getHealthDataFromTypes(
        startTime: start,
        endTime: end,
        types: [HealthDataType.HEART_RATE],
      );

      return data;
    } catch (e) {
      print('Error fetching heart rate data: $e');
      return [];
    }
  }

  /// Fetch weight data for the given date range
  Future<List<HealthDataPoint>> fetchWeightData(
    DateTime start,
    DateTime end,
  ) async {
    try {
      await _ensureConfigured();

      final data = await _health.getHealthDataFromTypes(
        startTime: start,
        endTime: end,
        types: [HealthDataType.WEIGHT],
      );
      return data;
    } catch (e) {
      print('Error fetching weight data: $e');
      return [];
    }
  }

  /// Fetch body fat percentage data for the given date range
  Future<List<HealthDataPoint>> fetchBodyFatData(
    DateTime start,
    DateTime end,
  ) async {
    try {
      await _ensureConfigured();

      final data = await _health.getHealthDataFromTypes(
        startTime: start,
        endTime: end,
        types: [HealthDataType.BODY_FAT_PERCENTAGE],
      );
      return data;
    } catch (e) {
      print('Error fetching body fat data: $e');
      return [];
    }
  }

  /// Fetch HRV (SDNN) data for the given date range
  /// Only available on iOS; skipped on Android Health Connect
  Future<List<HealthDataPoint>> fetchHRVData(
    DateTime start,
    DateTime end,
  ) async {
    try {
      // HRV SDNN is not reliably available on Health Connect
      if (!kIsWeb && Platform.isAndroid) return [];

      await _ensureConfigured();

      final data = await _health.getHealthDataFromTypes(
        startTime: start,
        endTime: end,
        types: [HealthDataType.HEART_RATE_VARIABILITY_SDNN],
      );
      return data;
    } catch (e) {
      print('Error fetching HRV data: $e');
      return [];
    }
  }

  /// Fetch active energy burned data for the given date range
  Future<List<HealthDataPoint>> fetchActiveCaloriesData(
    DateTime start,
    DateTime end,
  ) async {
    try {
      await _ensureConfigured();

      final data = await _health.getHealthDataFromTypes(
        startTime: start,
        endTime: end,
        types: [HealthDataType.ACTIVE_ENERGY_BURNED],
      );
      return data;
    } catch (e) {
      print('Error fetching active calories data: $e');
      return [];
    }
  }

  /// Fetch distance data for the given date range
  Future<List<HealthDataPoint>> fetchDistanceData(
    DateTime start,
    DateTime end,
  ) async {
    try {
      await _ensureConfigured();

      final data = await _health.getHealthDataFromTypes(
        startTime: start,
        endTime: end,
        types: [HealthDataType.DISTANCE_DELTA],
      );
      return data;
    } catch (e) {
      print('Error fetching distance data: $e');
      return [];
    }
  }

  /// Get the platform-specific health source
  HealthSource getPlatformSource() {
    if (kIsWeb) return HealthSource.healthconnect;
    if (Platform.isAndroid) {
      return HealthSource.healthconnect;
    } else if (Platform.isIOS) {
      return HealthSource.healthkit;
    }
    return HealthSource.healthconnect;
  }
}
