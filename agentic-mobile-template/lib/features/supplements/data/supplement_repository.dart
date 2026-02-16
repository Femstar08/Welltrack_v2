// lib/features/supplements/data/supplement_repository.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:welltrack/features/supplements/domain/supplement_entity.dart';
import 'package:welltrack/features/supplements/domain/supplement_protocol_entity.dart';
import 'package:welltrack/features/supplements/domain/supplement_log_entity.dart';

final supplementRepositoryProvider = Provider<SupplementRepository>((ref) {
  return SupplementRepository(Supabase.instance.client);
});

class SupplementRepository {
  final SupabaseClient _supabase;
  final _uuid = const Uuid();

  SupplementRepository(this._supabase);

  // CRUD for supplements
  Future<List<SupplementEntity>> getSupplements(String profileId) async {
    try {
      final response = await _supabase
          .from('wt_supplements')
          .select()
          .eq('profile_id', profileId)
          .order('name');

      return (response as List)
          .map((json) => SupplementEntity.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch supplements: $e');
    }
  }

  Future<SupplementEntity> getSupplement(String supplementId) async {
    try {
      final response = await _supabase
          .from('wt_supplements')
          .select()
          .eq('id', supplementId)
          .single();

      return SupplementEntity.fromJson(response);
    } catch (e) {
      throw Exception('Failed to fetch supplement: $e');
    }
  }

  Future<SupplementEntity> createSupplement({
    required String profileId,
    required String name,
    String? brand,
    String? description,
    required double dosage,
    required String unit,
    double? servingSize,
    String? barcode,
    String? notes,
  }) async {
    try {
      final now = DateTime.now();
      final data = {
        'id': _uuid.v4(),
        'profile_id': profileId,
        'name': name,
        'brand': brand,
        'description': description,
        'dosage': dosage,
        'unit': unit,
        'serving_size': servingSize,
        'barcode': barcode,
        'notes': notes,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };

      final response = await _supabase
          .from('wt_supplements')
          .insert(data)
          .select()
          .single();

      return SupplementEntity.fromJson(response);
    } catch (e) {
      throw Exception('Failed to create supplement: $e');
    }
  }

  Future<SupplementEntity> updateSupplement(SupplementEntity supplement) async {
    try {
      final data = supplement.toJson();
      data['updated_at'] = DateTime.now().toIso8601String();

      final response = await _supabase
          .from('wt_supplements')
          .update(data)
          .eq('id', supplement.id)
          .select()
          .single();

      return SupplementEntity.fromJson(response);
    } catch (e) {
      throw Exception('Failed to update supplement: $e');
    }
  }

  Future<void> deleteSupplement(String supplementId) async {
    try {
      await _supabase.from('wt_supplements').delete().eq('id', supplementId);
    } catch (e) {
      throw Exception('Failed to delete supplement: $e');
    }
  }

  // CRUD for protocols
  Future<List<SupplementProtocolEntity>> getProtocols(String profileId) async {
    try {
      final response = await _supabase
          .from('wt_supplement_protocols')
          .select()
          .eq('profile_id', profileId)
          .order('time_of_day');

      return (response as List)
          .map((json) => SupplementProtocolEntity.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch protocols: $e');
    }
  }

  Future<List<SupplementProtocolEntity>> getActiveProtocols(String profileId) async {
    try {
      final response = await _supabase
          .from('wt_supplement_protocols')
          .select()
          .eq('profile_id', profileId)
          .eq('is_active', true)
          .order('time_of_day');

      return (response as List)
          .map((json) => SupplementProtocolEntity.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch active protocols: $e');
    }
  }

  Future<SupplementProtocolEntity> saveProtocol({
    required String profileId,
    required String supplementId,
    required String supplementName,
    required ProtocolTimeOfDay timeOfDay,
    required double dosage,
    required String unit,
    String? linkedGoalId,
    bool isActive = true,
  }) async {
    try {
      final now = DateTime.now();
      final data = {
        'id': _uuid.v4(),
        'profile_id': profileId,
        'supplement_id': supplementId,
        'supplement_name': supplementName,
        'time_of_day': timeOfDay.toJson(),
        'dosage': dosage,
        'unit': unit,
        'linked_goal_id': linkedGoalId,
        'is_active': isActive,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };

      final response = await _supabase
          .from('wt_supplement_protocols')
          .insert(data)
          .select()
          .single();

      return SupplementProtocolEntity.fromJson(response);
    } catch (e) {
      throw Exception('Failed to save protocol: $e');
    }
  }

  Future<SupplementProtocolEntity> updateProtocol(SupplementProtocolEntity protocol) async {
    try {
      final data = protocol.toJson();
      data['updated_at'] = DateTime.now().toIso8601String();

      final response = await _supabase
          .from('wt_supplement_protocols')
          .update(data)
          .eq('id', protocol.id)
          .select()
          .single();

      return SupplementProtocolEntity.fromJson(response);
    } catch (e) {
      throw Exception('Failed to update protocol: $e');
    }
  }

  Future<void> deleteProtocol(String protocolId) async {
    try {
      await _supabase.from('wt_supplement_protocols').delete().eq('id', protocolId);
    } catch (e) {
      throw Exception('Failed to delete protocol: $e');
    }
  }

  // CRUD for logs
  Future<List<SupplementLogEntity>> getLogsForDate(
    String profileId,
    DateTime date,
  ) async {
    try {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final response = await _supabase
          .from('wt_supplement_logs')
          .select()
          .eq('profile_id', profileId)
          .gte('taken_at', startOfDay.toIso8601String())
          .lt('taken_at', endOfDay.toIso8601String())
          .order('taken_at');

      return (response as List)
          .map((json) => SupplementLogEntity.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch logs: $e');
    }
  }

  Future<List<SupplementLogEntity>> getLogsForDateRange(
    String profileId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final response = await _supabase
          .from('wt_supplement_logs')
          .select()
          .eq('profile_id', profileId)
          .gte('taken_at', startDate.toIso8601String())
          .lte('taken_at', endDate.toIso8601String())
          .order('taken_at', ascending: false);

      return (response as List)
          .map((json) => SupplementLogEntity.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch logs for date range: $e');
    }
  }

  Future<SupplementLogEntity> logIntake({
    required String profileId,
    required String supplementId,
    required String supplementName,
    required ProtocolTimeOfDay protocolTime,
    required double dosageTaken,
    required String unit,
    required SupplementLogStatus status,
    DateTime? takenAt,
    String? notes,
  }) async {
    try {
      final now = DateTime.now();
      final data = {
        'id': _uuid.v4(),
        'profile_id': profileId,
        'supplement_id': supplementId,
        'supplement_name': supplementName,
        'taken_at': (takenAt ?? now).toIso8601String(),
        'protocol_time': protocolTime.toJson(),
        'dosage_taken': dosageTaken,
        'unit': unit,
        'status': status.toJson(),
        'notes': notes,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };

      final response = await _supabase
          .from('wt_supplement_logs')
          .insert(data)
          .select()
          .single();

      return SupplementLogEntity.fromJson(response);
    } catch (e) {
      throw Exception('Failed to log intake: $e');
    }
  }

  Future<SupplementLogEntity> updateLog(SupplementLogEntity log) async {
    try {
      final data = log.toJson();
      data['updated_at'] = DateTime.now().toIso8601String();

      final response = await _supabase
          .from('wt_supplement_logs')
          .update(data)
          .eq('id', log.id)
          .select()
          .single();

      return SupplementLogEntity.fromJson(response);
    } catch (e) {
      throw Exception('Failed to update log: $e');
    }
  }

  Future<void> deleteLog(String logId) async {
    try {
      await _supabase.from('wt_supplement_logs').delete().eq('id', logId);
    } catch (e) {
      throw Exception('Failed to delete log: $e');
    }
  }
}
