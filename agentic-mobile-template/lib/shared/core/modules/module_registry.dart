import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:welltrack/shared/core/modules/module_metadata.dart';
import 'package:welltrack/shared/core/auth/supabase_service.dart';
import 'package:welltrack/shared/core/logging/app_logger.dart';

/// Repository for managing module configurations
class ModuleRegistry {
  final SupabaseService _supabaseService;
  final AppLogger _logger = AppLogger();

  ModuleRegistry(this._supabaseService);

  /// Fetch module configurations for a specific profile
  /// Falls back to defaults if no records exist
  Future<List<ModuleConfig>> getModuleConfigs(String profileId) async {
    try {
      _logger.info('Fetching module configs for profile: $profileId');

      if (profileId.isEmpty) {
        _logger.warning('Empty profileId, returning default configs');
        return _getDefaultConfigs();
      }

      final response = await _supabaseService.client
          .from('wt_profile_modules')
          .select()
          .eq('profile_id', profileId)
          .order('tile_order', ascending: true);

      if (response == null || (response as List).isEmpty) {
        _logger.info('No module configs found, returning defaults');
        return _getDefaultConfigs();
      }

      final configs = (response as List)
          .map((json) {
            try {
              return ModuleConfig.fromJson(json as Map<String, dynamic>);
            } catch (e) {
              _logger.warning('Failed to parse module config: $e');
              return null;
            }
          })
          .whereType<ModuleConfig>()
          .toList();

      // If we got configs but they're incomplete, merge with defaults
      if (configs.length < WellTrackModule.values.length) {
        _logger.info('Incomplete configs, merging with defaults');
        return _mergeWithDefaults(configs);
      }

      return configs;
    } catch (e, stackTrace) {
      _logger.error('Error fetching module configs', e, stackTrace);
      // Return defaults on error to keep app functional
      return _getDefaultConfigs();
    }
  }

  /// Get default module configurations
  List<ModuleConfig> _getDefaultConfigs() {
    return WellTrackModule.values
        .asMap()
        .entries
        .map((entry) => ModuleConfig(
              module: entry.value,
              enabled: entry.value.defaultEnabled,
              tileOrder: entry.key,
            ))
        .toList();
  }

  /// Merge existing configs with defaults for missing modules
  List<ModuleConfig> _mergeWithDefaults(List<ModuleConfig> existingConfigs) {
    final existingModules = existingConfigs.map((c) => c.module).toSet();
    final defaults = _getDefaultConfigs();

    // Add missing modules from defaults
    final missing = defaults
        .where((config) => !existingModules.contains(config.module))
        .toList();

    return [...existingConfigs, ...missing]
      ..sort((a, b) => a.tileOrder.compareTo(b.tileOrder));
  }

  /// Save or update module configuration for a profile
  Future<void> saveModuleConfig({
    required String profileId,
    required ModuleConfig config,
  }) async {
    try {
      _logger.info('Saving module config: ${config.module.name}');

      final data = {
        ...config.toJson(),
        'profile_id': profileId,
        'updated_at': DateTime.now().toIso8601String(),
      };

      await _supabaseService.client.from('wt_profile_modules').upsert(
        data,
        onConflict: 'profile_id,module_name',
      );

      _logger.info('Module config saved successfully');
    } catch (e, stackTrace) {
      _logger.error('Error saving module config', e, stackTrace);
      rethrow;
    }
  }

  /// Save multiple module configurations at once
  Future<void> saveModuleConfigs({
    required String profileId,
    required List<ModuleConfig> configs,
  }) async {
    try {
      _logger.info('Saving ${configs.length} module configs');

      final data = configs
          .map((config) => {
                ...config.toJson(),
                'profile_id': profileId,
                'updated_at': DateTime.now().toIso8601String(),
              })
          .toList();

      await _supabaseService.client.from('wt_profile_modules').upsert(
        data,
        onConflict: 'profile_id,module_name',
      );

      _logger.info('Module configs saved successfully');
    } catch (e, stackTrace) {
      _logger.error('Error saving module configs', e, stackTrace);
      rethrow;
    }
  }

  /// Toggle a module's enabled state
  Future<void> toggleModule({
    required String profileId,
    required WellTrackModule module,
    required bool enabled,
  }) async {
    try {
      _logger.info('Toggling module ${module.name} to $enabled');

      final configs = await getModuleConfigs(profileId);
      final config = configs.firstWhere(
        (c) => c.module == module,
        orElse: () => ModuleConfig(module: module),
      );

      await saveModuleConfig(
        profileId: profileId,
        config: config.copyWith(enabled: enabled),
      );
    } catch (e, stackTrace) {
      _logger.error('Error toggling module', e, stackTrace);
      rethrow;
    }
  }

  /// Update tile order for modules
  Future<void> updateTileOrder({
    required String profileId,
    required List<ModuleConfig> orderedConfigs,
  }) async {
    try {
      _logger.info('Updating tile order');

      // Reassign tile orders based on list position
      final reordered = orderedConfigs
          .asMap()
          .entries
          .map((entry) => entry.value.copyWith(tileOrder: entry.key))
          .toList();

      await saveModuleConfigs(profileId: profileId, configs: reordered);
    } catch (e, stackTrace) {
      _logger.error('Error updating tile order', e, stackTrace);
      rethrow;
    }
  }
}

/// State notifier for managing module configurations
class ModuleConfigsNotifier extends AsyncNotifier<List<ModuleConfig>> {
  late ModuleRegistry _registry;
  String? _currentProfileId;

  @override
  Future<List<ModuleConfig>> build() async {
    _registry = ModuleRegistry(ref.read(supabaseServiceProvider));
    // We'll set profile ID from outside, start with empty list
    return [];
  }

  /// Load module configs for a specific profile
  Future<void> loadForProfile(String profileId) async {
    _currentProfileId = profileId;
    state = const AsyncValue.loading();

    state = await AsyncValue.guard(() async {
      return await _registry.getModuleConfigs(profileId);
    });
  }

  /// Toggle a module's enabled state
  Future<void> toggleModule(WellTrackModule module, bool enabled) async {
    if (_currentProfileId == null) return;

    final previousState = state;

    // Optimistic update
    state = state.whenData((configs) {
      return configs.map((config) {
        if (config.module == module) {
          return config.copyWith(enabled: enabled);
        }
        return config;
      }).toList();
    });

    try {
      await _registry.toggleModule(
        profileId: _currentProfileId!,
        module: module,
        enabled: enabled,
      );
    } catch (e) {
      // Revert on error
      state = previousState;
      rethrow;
    }
  }

  /// Update tile order after drag-and-drop
  Future<void> updateTileOrder(List<ModuleConfig> orderedConfigs) async {
    if (_currentProfileId == null) return;

    final previousState = state;

    // Optimistic update
    state = AsyncValue.data(orderedConfigs);

    try {
      await _registry.updateTileOrder(
        profileId: _currentProfileId!,
        orderedConfigs: orderedConfigs,
      );
    } catch (e) {
      // Revert on error
      state = previousState;
      rethrow;
    }
  }

  /// Refresh module configs from server
  Future<void> refresh() async {
    if (_currentProfileId != null) {
      await loadForProfile(_currentProfileId!);
    }
  }
}

/// Provider for module configurations
final moduleConfigsProvider =
    AsyncNotifierProvider<ModuleConfigsNotifier, List<ModuleConfig>>(
  () => ModuleConfigsNotifier(),
);

/// Provider for enabled modules only, sorted by tile order
final enabledModulesProvider = Provider<List<ModuleConfig>>((ref) {
  final asyncConfigs = ref.watch(moduleConfigsProvider);

  return asyncConfigs.when(
    data: (configs) =>
        configs.where((config) => config.enabled).toList()
          ..sort((a, b) => a.tileOrder.compareTo(b.tileOrder)),
    loading: () => [],
    error: (_, __) => [],
  );
});
