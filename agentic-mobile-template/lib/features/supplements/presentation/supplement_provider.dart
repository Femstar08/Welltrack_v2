// lib/features/supplements/presentation/supplement_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:welltrack/features/supplements/data/supplement_repository.dart';
import 'package:welltrack/features/supplements/domain/supplement_entity.dart';
import 'package:welltrack/features/supplements/domain/supplement_protocol_entity.dart';
import 'package:welltrack/features/supplements/domain/supplement_log_entity.dart';

// State classes
class SupplementState {
  final List<SupplementEntity> supplements;
  final List<SupplementProtocolEntity> protocols;
  final List<SupplementLogEntity> todayLogs;
  final bool isLoading;
  final String? error;

  const SupplementState({
    this.supplements = const [],
    this.protocols = const [],
    this.todayLogs = const [],
    this.isLoading = false,
    this.error,
  });

  SupplementState copyWith({
    List<SupplementEntity>? supplements,
    List<SupplementProtocolEntity>? protocols,
    List<SupplementLogEntity>? todayLogs,
    bool? isLoading,
    String? error,
  }) {
    return SupplementState(
      supplements: supplements ?? this.supplements,
      protocols: protocols ?? this.protocols,
      todayLogs: todayLogs ?? this.todayLogs,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  List<SupplementProtocolEntity> get activeProtocols =>
      protocols.where((p) => p.isActive).toList();

  Map<String, SupplementLogEntity?> get todayLogsByProtocol {
    final Map<String, SupplementLogEntity?> logMap = {};
    for (final protocol in activeProtocols) {
      final log = todayLogs
          .where((l) =>
              l.supplementId == protocol.supplementId &&
              l.protocolTime == protocol.timeOfDay)
          .firstOrNull;
      logMap[protocol.id] = log;
    }
    return logMap;
  }

  double get completionPercentage {
    if (activeProtocols.isEmpty) return 0.0;
    final takenCount = todayLogs.where((l) => l.isTaken).length;
    return (takenCount / activeProtocols.length) * 100;
  }
}

// StateNotifier
class SupplementNotifier extends StateNotifier<SupplementState> {
  final SupplementRepository _repository;
  final String _profileId;

  SupplementNotifier(this._repository, this._profileId)
      : super(const SupplementState());

  Future<void> loadData() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final supplements = await _repository.getSupplements(_profileId);
      final protocols = await _repository.getProtocols(_profileId);
      final todayLogs = await _repository.getLogsForDate(
        _profileId,
        DateTime.now(),
      );

      state = state.copyWith(
        supplements: supplements,
        protocols: protocols,
        todayLogs: todayLogs,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> addSupplement({
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
      final supplement = await _repository.createSupplement(
        profileId: _profileId,
        name: name,
        brand: brand,
        description: description,
        dosage: dosage,
        unit: unit,
        servingSize: servingSize,
        barcode: barcode,
        notes: notes,
      );

      state = state.copyWith(
        supplements: [...state.supplements, supplement],
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> updateSupplement(SupplementEntity supplement) async {
    try {
      final updated = await _repository.updateSupplement(supplement);
      final supplements = state.supplements
          .map((s) => s.id == updated.id ? updated : s)
          .toList();

      state = state.copyWith(supplements: supplements);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> deleteSupplement(String supplementId) async {
    try {
      await _repository.deleteSupplement(supplementId);
      final supplements = state.supplements
          .where((s) => s.id != supplementId)
          .toList();

      state = state.copyWith(supplements: supplements);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> addProtocol({
    required String supplementId,
    required String supplementName,
    required ProtocolTimeOfDay timeOfDay,
    required double dosage,
    required String unit,
    String? linkedGoalId,
  }) async {
    try {
      final protocol = await _repository.saveProtocol(
        profileId: _profileId,
        supplementId: supplementId,
        supplementName: supplementName,
        timeOfDay: timeOfDay,
        dosage: dosage,
        unit: unit,
        linkedGoalId: linkedGoalId,
      );

      state = state.copyWith(
        protocols: [...state.protocols, protocol],
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> toggleProtocol(String protocolId) async {
    try {
      final protocol = state.protocols.firstWhere((p) => p.id == protocolId);
      final updated = protocol.copyWith(isActive: !protocol.isActive);
      final result = await _repository.updateProtocol(updated);

      final protocols = state.protocols
          .map((p) => p.id == result.id ? result : p)
          .toList();

      state = state.copyWith(protocols: protocols);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> deleteProtocol(String protocolId) async {
    try {
      await _repository.deleteProtocol(protocolId);
      final protocols = state.protocols
          .where((p) => p.id != protocolId)
          .toList();

      state = state.copyWith(protocols: protocols);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> logSupplement({
    required String supplementId,
    required String supplementName,
    required ProtocolTimeOfDay protocolTime,
    required double dosage,
    required String unit,
    required SupplementLogStatus status,
    String? notes,
  }) async {
    try {
      final log = await _repository.logIntake(
        profileId: _profileId,
        supplementId: supplementId,
        supplementName: supplementName,
        protocolTime: protocolTime,
        dosageTaken: dosage,
        unit: unit,
        status: status,
        notes: notes,
      );

      state = state.copyWith(
        todayLogs: [...state.todayLogs, log],
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> updateLog(SupplementLogEntity log) async {
    try {
      final updated = await _repository.updateLog(log);
      final todayLogs = state.todayLogs
          .map((l) => l.id == updated.id ? updated : l)
          .toList();

      state = state.copyWith(todayLogs: todayLogs);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

// Provider
final supplementProvider =
    StateNotifierProvider.family<SupplementNotifier, SupplementState, String>(
  (ref, profileId) {
    final repository = ref.watch(supplementRepositoryProvider);
    return SupplementNotifier(repository, profileId);
  },
);
