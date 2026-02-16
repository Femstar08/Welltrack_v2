import 'dart:io';
import 'package:health/health.dart';
import 'package:welltrack/features/health/domain/health_metric_entity.dart';

/// Data source for reading health data from platform APIs
/// Uses Health Connect on Android and HealthKit on iOS
class HealthDataSource {
  final Health _health = Health();

  /// Health data types we need permissions for
  static final List<HealthDataType> _types = [
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_AWAKE,
    HealthDataType.SLEEP_IN_BED,
    HealthDataType.SLEEP_DEEP,
    HealthDataType.SLEEP_LIGHT,
    HealthDataType.SLEEP_REM,
    HealthDataType.STEPS,
    HealthDataType.HEART_RATE,
  ];

  /// Request permissions for reading health data
  Future<bool> requestPermissions() async {
    try {
      final permissions = _types
          .map((type) => HealthDataAccess.READ)
          .toList();

      final granted = await _health.requestAuthorization(
        _types,
        permissions: permissions,
      );

      return granted;
    } catch (e) {
      print('Error requesting health permissions: $e');
      return false;
    }
  }

  /// Check if permissions are granted
  Future<bool> hasPermissions() async {
    try {
      final granted = await _health.hasPermissions(
        _types,
        permissions: _types.map((type) => HealthDataAccess.READ).toList(),
      );
      return granted ?? false;
    } catch (e) {
      print('Error checking health permissions: $e');
      return false;
    }
  }

  /// Fetch sleep data for the given date range
  /// Returns raw HealthDataPoint list containing sleep sessions and stages
  Future<List<HealthDataPoint>> fetchSleepData(
    DateTime start,
    DateTime end,
  ) async {
    try {
      final sleepTypes = [
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
  /// Returns daily step counts
  Future<List<HealthDataPoint>> fetchStepsData(
    DateTime start,
    DateTime end,
  ) async {
    try {
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
  /// Returns HR samples
  Future<List<HealthDataPoint>> fetchHeartRateData(
    DateTime start,
    DateTime end,
  ) async {
    try {
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

  /// Get the platform-specific health source
  /// Returns healthconnect for Android, healthkit for iOS
  HealthSource getPlatformSource() {
    if (Platform.isAndroid) {
      return HealthSource.healthconnect;
    } else if (Platform.isIOS) {
      return HealthSource.healthkit;
    }
    throw UnsupportedError('Platform not supported for health data');
  }
}
