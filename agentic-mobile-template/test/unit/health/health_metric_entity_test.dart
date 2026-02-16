import 'package:flutter_test/flutter_test.dart';
import 'package:welltrack/features/health/domain/health_metric_entity.dart';

void main() {
  group('HealthMetricEntity', () {
    final baseTime = DateTime(2024, 1, 15, 10, 0);
    final endTime = DateTime(2024, 1, 15, 18, 0);
    const userId = 'test-user-123';
    const profileId = 'test-profile-456';

    group('toSupabaseJson', () {
      test('should produce correct JSON with all required fields', () {
        final entity = HealthMetricEntity(
          userId: userId,
          profileId: profileId,
          source: HealthSource.healthconnect,
          metricType: MetricType.sleep,
          valueNum: 480.0,
          unit: 'minutes',
          startTime: baseTime,
          recordedAt: baseTime,
        );

        final json = entity.toSupabaseJson();

        expect(json['user_id'], userId);
        expect(json['profile_id'], profileId);
        expect(json['source'], 'healthconnect');
        expect(json['metric_type'], 'sleep');
        expect(json['value_num'], 480.0);
        expect(json['unit'], 'minutes');
        expect(json['start_time'], baseTime.toIso8601String());
        expect(json['recorded_at'], baseTime.toIso8601String());
        expect(json['validation_status'], 'raw');
        expect(json['processing_status'], 'pending');
        expect(json['is_primary'], false);
      });

      test('should include optional fields when provided', () {
        final entity = HealthMetricEntity(
          id: 'test-id-789',
          userId: userId,
          profileId: profileId,
          source: HealthSource.garmin,
          metricType: MetricType.hr,
          valueNum: 65.0,
          valueText: 'resting',
          unit: 'bpm',
          startTime: baseTime,
          endTime: endTime,
          recordedAt: baseTime,
          rawPayload: {'test_key': 'test_value'},
          dedupeHash: 'abc123hash',
          ingestionSourceVersion: 'v1.2.3',
        );

        final json = entity.toSupabaseJson();

        expect(json['id'], 'test-id-789');
        expect(json['value_text'], 'resting');
        expect(json['end_time'], endTime.toIso8601String());
        expect(json['raw_payload_json'], {'test_key': 'test_value'});
        expect(json['dedupe_hash'], 'abc123hash');
        expect(json['ingestion_source_version'], 'v1.2.3');
      });

      test('should handle null optional fields correctly', () {
        final entity = HealthMetricEntity(
          userId: userId,
          profileId: profileId,
          source: HealthSource.manual,
          metricType: MetricType.weight,
          valueNum: 75.0,
          unit: 'kg',
          startTime: baseTime,
          recordedAt: baseTime,
        );

        final json = entity.toSupabaseJson();

        expect(json.containsKey('id'), false);
        expect(json['end_time'], null);
        expect(json['value_text'], null);
        expect(json['raw_payload_json'], null);
        expect(json['dedupe_hash'], null);
        expect(json['ingestion_source_version'], null);
      });
    });

    group('fromSupabaseJson', () {
      test('should create entity from complete JSON', () {
        final json = {
          'id': 'test-id-123',
          'user_id': userId,
          'profile_id': profileId,
          'source': 'healthconnect',
          'metric_type': 'sleep',
          'value_num': 480.0,
          'value_text': 'good quality',
          'unit': 'minutes',
          'start_time': baseTime.toIso8601String(),
          'end_time': endTime.toIso8601String(),
          'recorded_at': baseTime.toIso8601String(),
          'raw_payload_json': {'stages': {'deep': 120}},
          'dedupe_hash': 'hash456',
          'validation_status': 'validated',
          'ingestion_source_version': 'v2.0.0',
          'processing_status': 'processed',
          'is_primary': true,
        };

        final entity = HealthMetricEntity.fromSupabaseJson(json);

        expect(entity.id, 'test-id-123');
        expect(entity.userId, userId);
        expect(entity.profileId, profileId);
        expect(entity.source, HealthSource.healthconnect);
        expect(entity.metricType, MetricType.sleep);
        expect(entity.valueNum, 480.0);
        expect(entity.valueText, 'good quality');
        expect(entity.unit, 'minutes');
        expect(entity.startTime, baseTime);
        expect(entity.endTime, endTime);
        expect(entity.recordedAt, baseTime);
        expect(entity.rawPayload, {'stages': {'deep': 120}});
        expect(entity.dedupeHash, 'hash456');
        expect(entity.validationStatus, ValidationStatus.validated);
        expect(entity.ingestionSourceVersion, 'v2.0.0');
        expect(entity.processingStatus, ProcessingStatus.processed);
        expect(entity.isPrimary, true);
      });

      test('should handle missing optional fields with defaults', () {
        final json = {
          'user_id': userId,
          'profile_id': profileId,
          'source': 'manual',
          'metric_type': 'steps',
          'value_num': 10000,
          'unit': 'count',
          'start_time': baseTime.toIso8601String(),
          'recorded_at': baseTime.toIso8601String(),
        };

        final entity = HealthMetricEntity.fromSupabaseJson(json);

        expect(entity.id, null);
        expect(entity.valueText, null);
        expect(entity.endTime, null);
        expect(entity.rawPayload, null);
        expect(entity.dedupeHash, null);
        expect(entity.validationStatus, ValidationStatus.raw);
        expect(entity.ingestionSourceVersion, null);
        expect(entity.processingStatus, ProcessingStatus.pending);
        expect(entity.isPrimary, false);
      });

      test('should convert numeric valueNum to double', () {
        final json = {
          'user_id': userId,
          'profile_id': profileId,
          'source': 'healthkit',
          'metric_type': 'hr',
          'value_num': 72, // int instead of double
          'unit': 'bpm',
          'start_time': baseTime.toIso8601String(),
          'recorded_at': baseTime.toIso8601String(),
        };

        final entity = HealthMetricEntity.fromSupabaseJson(json);

        expect(entity.valueNum, 72.0);
        expect(entity.valueNum, isA<double>());
      });
    });

    group('Roundtrip Serialization', () {
      test('should maintain all data through toJson -> fromJson cycle', () {
        final original = HealthMetricEntity(
          id: 'roundtrip-id-999',
          userId: userId,
          profileId: profileId,
          source: HealthSource.strava,
          metricType: MetricType.vo2max,
          valueNum: 55.5,
          valueText: 'excellent',
          unit: 'ml/kg/min',
          startTime: baseTime,
          endTime: endTime,
          recordedAt: baseTime,
          rawPayload: {'activity': 'running', 'duration': 3600},
          dedupeHash: 'roundtrip-hash',
          validationStatus: ValidationStatus.validated,
          ingestionSourceVersion: 'v3.1.0',
          processingStatus: ProcessingStatus.processed,
          isPrimary: true,
        );

        final json = original.toSupabaseJson();
        final restored = HealthMetricEntity.fromSupabaseJson(json);

        expect(restored.id, original.id);
        expect(restored.userId, original.userId);
        expect(restored.profileId, original.profileId);
        expect(restored.source, original.source);
        expect(restored.metricType, original.metricType);
        expect(restored.valueNum, original.valueNum);
        expect(restored.valueText, original.valueText);
        expect(restored.unit, original.unit);
        expect(restored.startTime, original.startTime);
        expect(restored.endTime, original.endTime);
        expect(restored.recordedAt, original.recordedAt);
        expect(restored.rawPayload, original.rawPayload);
        expect(restored.dedupeHash, original.dedupeHash);
        expect(restored.validationStatus, original.validationStatus);
        expect(restored.ingestionSourceVersion, original.ingestionSourceVersion);
        expect(restored.processingStatus, original.processingStatus);
        expect(restored.isPrimary, original.isPrimary);
      });

      test('should maintain minimal data through roundtrip', () {
        final original = HealthMetricEntity(
          userId: userId,
          profileId: profileId,
          source: HealthSource.healthkit,
          metricType: MetricType.stress,
          valueNum: 45.0,
          unit: 'score',
          startTime: baseTime,
          recordedAt: baseTime,
        );

        final json = original.toSupabaseJson();
        final restored = HealthMetricEntity.fromSupabaseJson(json);

        expect(restored.userId, original.userId);
        expect(restored.profileId, original.profileId);
        expect(restored.source, original.source);
        expect(restored.metricType, original.metricType);
        expect(restored.valueNum, original.valueNum);
        expect(restored.unit, original.unit);
        expect(restored.startTime, original.startTime);
        expect(restored.recordedAt, original.recordedAt);
      });
    });

    group('HealthSource Enum Serialization', () {
      test('should serialize and deserialize all HealthSource values', () {
        for (final source in HealthSource.values) {
          final entity = HealthMetricEntity(
            userId: userId,
            profileId: profileId,
            source: source,
            metricType: MetricType.steps,
            valueNum: 10000.0,
            unit: 'count',
            startTime: baseTime,
            recordedAt: baseTime,
          );

          final json = entity.toSupabaseJson();
          final restored = HealthMetricEntity.fromSupabaseJson(json);

          expect(restored.source, source);
        }
      });
    });

    group('MetricType Enum Serialization', () {
      test('should serialize and deserialize all MetricType values', () {
        for (final metricType in MetricType.values) {
          final entity = HealthMetricEntity(
            userId: userId,
            profileId: profileId,
            source: HealthSource.manual,
            metricType: metricType,
            valueNum: 100.0,
            unit: 'test',
            startTime: baseTime,
            recordedAt: baseTime,
          );

          final json = entity.toSupabaseJson();
          final restored = HealthMetricEntity.fromSupabaseJson(json);

          expect(restored.metricType, metricType);
        }
      });
    });

    group('ValidationStatus Enum Serialization', () {
      test('should serialize and deserialize all ValidationStatus values', () {
        for (final status in ValidationStatus.values) {
          final entity = HealthMetricEntity(
            userId: userId,
            profileId: profileId,
            source: HealthSource.manual,
            metricType: MetricType.steps,
            valueNum: 10000.0,
            unit: 'count',
            startTime: baseTime,
            recordedAt: baseTime,
            validationStatus: status,
          );

          final json = entity.toSupabaseJson();
          final restored = HealthMetricEntity.fromSupabaseJson(json);

          expect(restored.validationStatus, status);
        }
      });
    });

    group('ProcessingStatus Enum Serialization', () {
      test('should serialize and deserialize all ProcessingStatus values', () {
        for (final status in ProcessingStatus.values) {
          final entity = HealthMetricEntity(
            userId: userId,
            profileId: profileId,
            source: HealthSource.manual,
            metricType: MetricType.steps,
            valueNum: 10000.0,
            unit: 'count',
            startTime: baseTime,
            recordedAt: baseTime,
            processingStatus: status,
          );

          final json = entity.toSupabaseJson();
          final restored = HealthMetricEntity.fromSupabaseJson(json);

          expect(restored.processingStatus, status);
        }
      });
    });
  });
}
