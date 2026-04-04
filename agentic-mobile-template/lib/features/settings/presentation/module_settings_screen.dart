import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/core/modules/module_metadata.dart';
import '../../../shared/core/modules/module_registry.dart';
import '../../../shared/core/router/app_router.dart' show activeProfileIdProvider;
import '../../../shared/core/theme/app_colors.dart';

/// Screen for toggling modules on/off and reordering dashboard tiles.
class ModuleSettingsScreen extends ConsumerWidget {
  const ModuleSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final configsAsync = ref.watch(moduleConfigsProvider);

    // Ensure configs are loaded for current profile
    if (configsAsync is AsyncData && (configsAsync as AsyncData).value.isEmpty) {
      final profileId = ref.read(activeProfileIdProvider) ?? '';
      if (profileId.isNotEmpty) {
        Future.microtask(() =>
            ref.read(moduleConfigsProvider.notifier).loadForProfile(profileId));
      }
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () => context.pop(),
        ),
        title: const Text('Module Settings'),
      ),
      body: configsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Failed to load modules: $e'),
        ),
        data: (configs) {
          // Filter out meta modules that shouldn't be togglable
          final toggleable = configs.where((c) =>
              c.module != WellTrackModule.moduleToggles &&
              c.module != WellTrackModule.dailyView).toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text(
                  'Choose which modules appear on your dashboard',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondaryDark,
                  ),
                ),
              ),
              Expanded(
                child: ReorderableListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: toggleable.length,
                  onReorder: (oldIndex, newIndex) {
                    if (newIndex > oldIndex) newIndex--;
                    final reordered = List<ModuleConfig>.from(toggleable);
                    final item = reordered.removeAt(oldIndex);
                    reordered.insert(newIndex, item);
                    ref
                        .read(moduleConfigsProvider.notifier)
                        .updateTileOrder(reordered);
                  },
                  itemBuilder: (context, index) {
                    final config = toggleable[index];
                    final module = config.module;
                    final accentColor = module.getAccentColor();

                    return Card(
                      key: ValueKey(module.name),
                      margin: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 4),
                      child: ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(module.icon,
                              color: accentColor, size: 22),
                        ),
                        title: Text(
                          module.displayName,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Switch(
                              value: config.enabled,
                              onChanged: (enabled) {
                                ref
                                    .read(moduleConfigsProvider.notifier)
                                    .toggleModule(module, enabled);
                              },
                            ),
                            ReorderableDragStartListener(
                              index: index,
                              child: const Icon(Icons.drag_handle,
                                  color: AppColors.textSecondaryDark),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
