// lib/features/bloodwork/presentation/bloodwork_provider.dart

import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/bloodwork_repository.dart';
import '../domain/bloodwork_entity.dart';
import '../../insights/presentation/insights_provider.dart';
import '../../../shared/core/ai/ai_orchestrator_service.dart';
import '../../../shared/core/ai/ai_providers.dart';
import '../../../shared/core/logging/app_logger.dart';

// ─── State ────────────────────────────────────────────────────────────────────

class BloodworkState {
  const BloodworkState({
    this.results = const [],
    this.latestByTest = const {},
    this.outOfRangeCount = 0,
    this.isLoading = false,
    this.error,
    this.aiInterpretation,
    this.isLoadingAi = false,
    this.aiError,
  });

  /// Full history ordered by test date descending.
  final List<BloodworkEntity> results;

  /// Map of testName -> most recent entity; built from [getLatestResults].
  final Map<String, BloodworkEntity> latestByTest;

  /// Derived count of flagged out-of-range results in the latest snapshot.
  final int outOfRangeCount;

  final bool isLoading;

  /// Non-null when the last CRUD operation failed.
  final String? error;

  // ─── AI interpretation state ────────────────────────────────────────────

  /// The AI (or deterministic fallback) interpretation text. Non-null after
  /// a successful [requestAiInterpretation] call.
  final String? aiInterpretation;

  /// True while an AI interpretation call is in flight.
  final bool isLoadingAi;

  /// Non-null when the AI call or consent check failed.
  final String? aiError;

  BloodworkState copyWith({
    List<BloodworkEntity>? results,
    Map<String, BloodworkEntity>? latestByTest,
    int? outOfRangeCount,
    bool? isLoading,
    String? error,
    bool clearError = false,
    String? aiInterpretation,
    bool? isLoadingAi,
    String? aiError,
    bool clearAiError = false,
  }) {
    return BloodworkState(
      results: results ?? this.results,
      latestByTest: latestByTest ?? this.latestByTest,
      outOfRangeCount: outOfRangeCount ?? this.outOfRangeCount,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      aiInterpretation: aiInterpretation ?? this.aiInterpretation,
      isLoadingAi: isLoadingAi ?? this.isLoadingAi,
      aiError: clearAiError ? null : (aiError ?? this.aiError),
    );
  }
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class BloodworkNotifier extends StateNotifier<BloodworkState> {
  BloodworkNotifier(
    this._repository,
    this._aiService,
    this._ref,
    this._profileId,
  ) : super(const BloodworkState());

  final BloodworkRepository _repository;
  final AiOrchestratorService _aiService;
  final Ref _ref;
  final String _profileId;
  final AppLogger _logger = AppLogger();

  // ── Load ──────────────────────────────────────────────────────────────────

  /// Fetches full history + latest-per-test snapshot.
  Future<void> loadResults() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final results = await _repository.getResults(_profileId);
      final latestList = await _repository.getLatestResults(_profileId);

      final latestByTest = <String, BloodworkEntity>{
        for (final e in latestList) e.testName: e,
      };

      final outOfRangeCount =
          latestList.where((e) => e.isOutOfRange).length;

      state = state.copyWith(
        results: results,
        latestByTest: latestByTest,
        outOfRangeCount: outOfRangeCount,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  // ── Add ───────────────────────────────────────────────────────────────────

  /// Persists a new result and refreshes all derived state.
  Future<void> addResult(BloodworkEntity entity) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final saved = await _repository.addResult(entity);

      // Prepend to history (list is date-desc) and rebuild latest map.
      final results = [saved, ...state.results];
      final latestByTest = Map<String, BloodworkEntity>.from(state.latestByTest)
        ..[saved.testName] = _pickLatest(
          existing: state.latestByTest[saved.testName],
          candidate: saved,
        );

      final outOfRangeCount =
          latestByTest.values.where((e) => e.isOutOfRange).length;

      state = state.copyWith(
        results: results,
        latestByTest: latestByTest,
        outOfRangeCount: outOfRangeCount,
        isLoading: false,
      );

      // Invalidate insights so recovery and trend data reflect the new result.
      _ref.invalidate(insightsProvider);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  // ── Update ────────────────────────────────────────────────────────────────

  /// Updates an existing result in both the history list and the latest map.
  Future<void> updateResult(BloodworkEntity entity) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final updated = await _repository.updateResult(entity);

      final results = state.results
          .map((r) => r.id == updated.id ? updated : r)
          .toList();

      // Rebuild latest map by re-scanning the updated history list.
      final latestByTest = _buildLatestMap(results);
      final outOfRangeCount =
          latestByTest.values.where((e) => e.isOutOfRange).length;

      state = state.copyWith(
        results: results,
        latestByTest: latestByTest,
        outOfRangeCount: outOfRangeCount,
        isLoading: false,
      );

      // Invalidate insights so downstream views reflect the updated result.
      _ref.invalidate(insightsProvider);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  // ── Delete ────────────────────────────────────────────────────────────────

  /// Removes a result and refreshes derived state.
  Future<void> deleteResult(String id) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _repository.deleteResult(id);

      final results = state.results.where((r) => r.id != id).toList();
      final latestByTest = _buildLatestMap(results);
      final outOfRangeCount =
          latestByTest.values.where((e) => e.isOutOfRange).length;

      state = state.copyWith(
        results: results,
        latestByTest: latestByTest,
        outOfRangeCount: outOfRangeCount,
        isLoading: false,
      );

      // Invalidate insights so downstream views no longer reference the deleted result.
      _ref.invalidate(insightsProvider);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  // ── AI interpretation ─────────────────────────────────────────────────────

  /// Requests an AI interpretation of the most recent bloodwork results.
  ///
  /// Flow:
  /// 1. Check `ai_consent_bloodwork` on the profile — abort with error if false.
  /// 2. Build a context payload from out-of-range and borderline results.
  /// 3. Call the AI orchestrator with tool `interpret_bloodwork`.
  /// 4. Parse the response and store it in [BloodworkState.aiInterpretation].
  /// 5. On any AI failure, build a deterministic fallback from the results and
  ///    store that instead — the user always sees something useful.
  Future<void> requestAiInterpretation() async {
    state = state.copyWith(isLoadingAi: true, clearAiError: true);

    // ── 1. Consent check ────────────────────────────────────────────────────
    try {
      final profileRow = await Supabase.instance.client
          .from('wt_profiles')
          .select('ai_consent_bloodwork')
          .eq('id', _profileId)
          .maybeSingle();

      final consentGranted =
          profileRow?['ai_consent_bloodwork'] as bool? ?? false;

      if (!consentGranted) {
        state = state.copyWith(
          isLoadingAi: false,
          aiError: 'consent_required',
        );
        return;
      }
    } catch (e) {
      _logger.error('Bloodwork consent check failed', e, null);
      state = state.copyWith(
        isLoadingAi: false,
        aiError: 'Could not verify AI consent. Please try again.',
      );
      return;
    }

    // ── 2. Build results context ─────────────────────────────────────────────
    final latest = state.latestByTest.values.toList();
    final outOfRange = latest.where((e) => e.isOutOfRange).toList();
    final borderline = latest.where((e) => e.isBorderline && !e.isOutOfRange).toList();

    // ── 3. Deterministic fallback builder (runs without AI) ──────────────────
    String buildDeterministicFallback() {
      if (latest.isEmpty) {
        return 'No bloodwork results logged yet. Add your lab results to '
            'receive a personalised summary.';
      }

      final parts = <String>[];

      for (final e in outOfRange) {
        final direction =
            e.referenceRangeLow != null && e.valueNum < e.referenceRangeLow!
                ? 'below'
                : 'above';
        final rangeText = _formatRange(e);
        parts.add(
          'Your ${e.testName} (${_formatVal(e.valueNum)} ${e.unit}) is '
          '$direction the reference range ($rangeText). '
          'Consider discussing this with your healthcare provider.',
        );
      }

      for (final e in borderline) {
        final rangeText = _formatRange(e);
        parts.add(
          'Your ${e.testName} (${_formatVal(e.valueNum)} ${e.unit}) is '
          'borderline (reference: $rangeText). '
          'You may find it helpful to keep an eye on this value.',
        );
      }

      if (parts.isEmpty) {
        return 'All logged results are currently within normal reference '
            'ranges. Continue monitoring regularly and discuss any concerns '
            'with your healthcare provider.';
      }

      return parts.join('\n\n');
    }

    // ── 4. AI call ──────────────────────────────────────────────────────────
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      state = state.copyWith(
        isLoadingAi: false,
        aiInterpretation: buildDeterministicFallback(),
      );
      return;
    }

    final contextPayload = <String, dynamic>{
      'bloodwork_context': {
        'out_of_range_count': outOfRange.length,
        'borderline_count': borderline.length,
        'total_tests_logged': latest.length,
        'results': latest.map((e) => {
          'test_name': e.testName,
          'value': e.valueNum,
          'unit': e.unit,
          if (e.referenceRangeLow != null)
            'reference_low': e.referenceRangeLow,
          if (e.referenceRangeHigh != null)
            'reference_high': e.referenceRangeHigh,
          'is_out_of_range': e.isOutOfRange,
          'is_borderline': e.isBorderline,
          'test_date': e.testDate.toIso8601String().substring(0, 10),
        }).toList(),
      },
      'narrative_instructions':
          'Respond in 3-5 sentences using suggestive language only. '
          'Never diagnose, never use: you must, you should, you need to. '
          'Use language like: consider discussing, you might find it helpful, '
          'many people notice that. Always recommend consulting a healthcare '
          'provider for anything outside the normal range.',
    };

    try {
      final response = await _aiService.orchestrate(
        userId: userId,
        profileId: _profileId,
        workflowType: 'interpret_bloodwork',
        message: 'Provide a suggestive wellness summary of my bloodwork results.',
        contextOverride: contextPayload,
      );

      _ref.read(aiUsageProvider.notifier).state = response.usage;

      // Parse structured JSON if available; fall back to raw text
      String interpretation = response.assistantMessage.trim();
      try {
        final parsed = jsonDecode(interpretation) as Map<String, dynamic>;
        // New schema: { interpretation, possible_considerations[], professional_consultation_note }
        final interp = parsed['interpretation'] as String?;
        final considerations = (parsed['possible_considerations'] as List?)
            ?.map((c) => c.toString())
            .toList();
        final note = parsed['professional_consultation_note'] as String?;
        if (interp != null && interp.isNotEmpty) {
          final buffer = StringBuffer(interp);
          if (considerations != null && considerations.isNotEmpty) {
            buffer.writeln('\n');
            for (final c in considerations) {
              buffer.writeln('- $c');
            }
          }
          if (note != null) {
            buffer.writeln('\n$note');
          }
          interpretation = buffer.toString().trim();
        }
      } catch (_) {
        // Not JSON — use raw text as-is
      }
      if (interpretation.isEmpty) {
        interpretation = buildDeterministicFallback();
      }

      state = state.copyWith(
        isLoadingAi: false,
        aiInterpretation: interpretation,
      );
    } catch (e) {
      _logger.error('Bloodwork AI interpretation failed', e, null);
      // AI unavailable — always surface the deterministic fallback so the
      // user still gets actionable information.
      state = state.copyWith(
        isLoadingAi: false,
        aiInterpretation: buildDeterministicFallback(),
      );
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void clearError() => state = state.copyWith(clearError: true);

  void clearAiInterpretation() =>
      state = state.copyWith(aiInterpretation: null, clearAiError: true);

  /// Picks the more recent of two entities for the latest-by-test map.
  BloodworkEntity _pickLatest({
    required BloodworkEntity? existing,
    required BloodworkEntity candidate,
  }) {
    if (existing == null) return candidate;
    return candidate.testDate.isAfter(existing.testDate) ? candidate : existing;
  }

  /// Rebuilds the full latest-by-test map by scanning a date-desc list.
  Map<String, BloodworkEntity> _buildLatestMap(List<BloodworkEntity> results) {
    final map = <String, BloodworkEntity>{};
    for (final e in results) {
      // Because [results] is ordered date-desc, the first occurrence of each
      // testName is already the most recent.
      map.putIfAbsent(e.testName, () => e);
    }
    return map;
  }

  /// Formats a numeric lab value — strips trailing zeros after two decimals.
  String _formatVal(double v) =>
      v.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');

  /// Builds a human-readable reference range string for fallback text.
  String _formatRange(BloodworkEntity e) {
    final low = e.referenceRangeLow;
    final high = e.referenceRangeHigh;
    if (low != null && high != null) {
      return '${_formatVal(low)}-${_formatVal(high)} ${e.unit}';
    }
    if (low != null) return '>${_formatVal(low)} ${e.unit}';
    if (high != null) return '<${_formatVal(high)} ${e.unit}';
    return e.unit;
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────

/// Family provider keyed by profileId — matches the pattern used by
/// [supplementProvider] and [mealPlanProvider].
final bloodworkProvider =
    StateNotifierProvider.family<BloodworkNotifier, BloodworkState, String>(
  (ref, profileId) {
    final repository = ref.watch(bloodworkRepositoryProvider);
    final aiService = ref.watch(aiOrchestratorServiceProvider);
    return BloodworkNotifier(repository, aiService, ref, profileId);
  },
);
