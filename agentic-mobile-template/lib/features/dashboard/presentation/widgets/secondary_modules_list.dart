import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:welltrack/features/dashboard/presentation/module_tile_widget.dart';
import 'package:welltrack/shared/core/modules/module_metadata.dart';

/// Section 5: Compact module tiles list.
class SecondaryModulesList extends StatelessWidget {
  final List<ModuleConfig> tiles;

  const SecondaryModulesList({super.key, required this.tiles});

  @override
  Widget build(BuildContext context) {
    if (tiles.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Modules',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextButton(
                onPressed: () => context.push('/settings'),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Customize',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Module tiles
          ...tiles.map(
            (config) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: CompactModuleTile(config: config),
            ),
          ),
        ],
      ),
    );
  }
}
