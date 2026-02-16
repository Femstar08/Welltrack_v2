import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:welltrack/features/health/presentation/health_provider.dart';

/// State for health settings UI
class HealthSettingsState {
  final bool showPermissionDetails;
  final String? lastError;

  const HealthSettingsState({
    this.showPermissionDetails = false,
    this.lastError,
  });

  HealthSettingsState copyWith({
    bool? showPermissionDetails,
    String? lastError,
  }) {
    return HealthSettingsState(
      showPermissionDetails:
          showPermissionDetails ?? this.showPermissionDetails,
      lastError: lastError,
    );
  }
}

/// Notifier for health settings screen state
class HealthSettingsNotifier extends StateNotifier<HealthSettingsState> {
  final String _profileId;
  final Ref _ref;

  HealthSettingsNotifier(this._profileId, this._ref)
      : super(const HealthSettingsState());

  void togglePermissionDetails() {
    state = state.copyWith(
      showPermissionDetails: !state.showPermissionDetails,
    );
  }

  Future<bool> connectHealthData() async {
    try {
      final granted = await _ref
          .read(healthConnectionProvider(_profileId).notifier)
          .requestPermissions();

      if (!granted) {
        state = state.copyWith(
          lastError: 'Permission denied. Please enable in system settings.',
        );
      }

      return granted;
    } catch (e) {
      state = state.copyWith(lastError: e.toString());
      return false;
    }
  }

  Future<void> disconnectHealthData() async {
    try {
      // Clear the connection state
      // Note: The actual implementation would need to clear cached permissions
      // and reset the health connection provider state

      // For now, we'll just invalidate the provider to reset its state
      _ref.invalidate(healthConnectionProvider(_profileId));

      state = state.copyWith(lastError: null);
    } catch (e) {
      state = state.copyWith(lastError: e.toString());
    }
  }

  Future<void> syncHealthData() async {
    try {
      await _ref
          .read(healthConnectionProvider(_profileId).notifier)
          .syncNow();
      state = state.copyWith(lastError: null);
    } catch (e) {
      state = state.copyWith(lastError: e.toString());
    }
  }

  void clearError() {
    state = state.copyWith(lastError: null);
  }
}

/// Provider for health settings state
final healthSettingsProvider = StateNotifierProvider.family<
    HealthSettingsNotifier,
    HealthSettingsState,
    String>((ref, profileId) {
  return HealthSettingsNotifier(profileId, ref);
});
