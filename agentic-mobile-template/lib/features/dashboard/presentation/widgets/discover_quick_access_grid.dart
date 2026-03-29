import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../freemium/data/freemium_repository.dart';
import '../../../freemium/domain/plan_tier.dart';

/// 2x2 grid of quick-access feature tiles replacing SecondaryModulesList.
class DiscoverQuickAccessGrid extends ConsumerWidget {
  const DiscoverQuickAccessGrid({super.key});

  static const _tiles = <_DiscoverTileData>[
    _DiscoverTileData(
      label: 'Sleep',
      icon: Icons.bedtime_rounded,
      route: '/health/sleep',
      color: Color(0xFF5C6BC0),
      requiresPro: false,
    ),
    _DiscoverTileData(
      label: 'Recipes',
      icon: Icons.restaurant_rounded,
      route: '/recipes',
      color: Color(0xFFFF7043),
      requiresPro: false,
    ),
    _DiscoverTileData(
      label: 'Workouts',
      icon: Icons.fitness_center_rounded,
      route: '/workouts',
      color: Color(0xFF26A69A),
      requiresPro: false,
    ),
    _DiscoverTileData(
      label: 'Recovery',
      icon: Icons.favorite_rounded,
      route: '/recovery-detail',
      color: Color(0xFFEF5350),
      requiresPro: true,
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tierAsync = ref.watch(currentPlanTierProvider);
    final isPro = tierAsync.valueOrNull == PlanTier.pro;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Discover',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 2.2,
            children: _tiles.map((tile) {
              return _DiscoverTile(
                data: tile,
                isPro: isPro,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _DiscoverTileData {
  const _DiscoverTileData({
    required this.label,
    required this.icon,
    required this.route,
    required this.color,
    required this.requiresPro,
  });

  final String label;
  final IconData icon;
  final String route;
  final Color color;
  final bool requiresPro;
}

class _DiscoverTile extends StatelessWidget {
  const _DiscoverTile({
    required this.data,
    required this.isPro,
  });

  final _DiscoverTileData data;
  final bool isPro;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locked = data.requiresPro && !isPro;

    return Material(
      color: data.color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (locked) {
            context.push('/paywall');
          } else {
            context.push(data.route);
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(data.icon, size: 24, color: data.color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  data.label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (locked)
                Icon(
                  Icons.lock_outline_rounded,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
