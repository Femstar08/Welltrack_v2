import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/core/constants/fab_colors.dart';
import '../../freemium/data/freemium_repository.dart';
import '../../freemium/domain/plan_tier.dart';

/// Opens the enhanced FAB bottom sheet with a 2x2 action grid + list.
void showEnhancedLogSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _EnhancedLogBottomSheet(),
  );
}

class _EnhancedLogBottomSheet extends ConsumerWidget {
  const _EnhancedLogBottomSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tierAsync = ref.watch(currentPlanTierProvider);
    final isPro = tierAsync.valueOrNull == PlanTier.pro;

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.3,
      maxChildSize: 0.8,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              Text(
                'Log',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),

              // 2x2 action grid
              Row(
                children: [
                  Expanded(
                    child: _FabActionTile(
                      label: 'Log Food',
                      icon: Icons.restaurant_rounded,
                      color: kFabColorLogFood,
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/meals/food-search');
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _FabActionTile(
                      label: 'Barcode',
                      icon: Icons.qr_code_scanner_rounded,
                      color: kFabColorBarcode,
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/meals/food-barcode-scan');
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _FabActionTile(
                      label: 'Voice Log',
                      icon: Icons.mic_rounded,
                      color: kFabColorVoice,
                      locked: !isPro,
                      onTap: () {
                        Navigator.pop(context);
                        if (isPro) {
                          context.push('/meals/voice-log');
                        } else {
                          context.push('/paywall');
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _FabActionTile(
                      label: 'Meal Scan',
                      icon: Icons.camera_alt_rounded,
                      color: kFabColorMealScan,
                      locked: !isPro,
                      onTap: () {
                        Navigator.pop(context);
                        if (isPro) {
                          context.push('/meals/meal-scan');
                        } else {
                          context.push('/paywall');
                        }
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),
              Divider(color: theme.colorScheme.outlineVariant),
              const SizedBox(height: 8),

              // Quick action list
              _QuickActionItem(
                icon: Icons.water_drop_rounded,
                label: 'Water',
                subtitle: 'Log hydration',
                onTap: () {
                  Navigator.pop(context);
                  _showWaterStepper(context);
                },
              ),
              _QuickActionItem(
                icon: Icons.monitor_weight_rounded,
                label: 'Weight',
                subtitle: 'Log weight',
                onTap: () {
                  Navigator.pop(context);
                  context.push('/weight/log');
                },
              ),
              _QuickActionItem(
                icon: Icons.fitness_center_rounded,
                label: 'Exercise',
                subtitle: 'Start a workout',
                onTap: () {
                  Navigator.pop(context);
                  context.push('/workouts');
                },
              ),
              _QuickActionItem(
                icon: Icons.auto_awesome_rounded,
                label: 'AI Suggestions',
                subtitle: 'Coming Soon',
                enabled: false,
                onTap: () {},
              ),
              _QuickActionItem(
                icon: Icons.menu_book_rounded,
                label: 'Recipes',
                subtitle: 'Browse recipes',
                onTap: () {
                  Navigator.pop(context);
                  context.push('/recipes');
                },
              ),
              _QuickActionItem(
                icon: Icons.add_circle_outline_rounded,
                label: 'Quick Add',
                subtitle: 'Add calories manually',
                onTap: () {
                  Navigator.pop(context);
                  context.push('/meals/log');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showWaterStepper(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => const _WaterStepperSubSheet(),
    );
  }
}

/// 2x2 grid tile for the FAB bottom sheet.
class _FabActionTile extends StatelessWidget {
  const _FabActionTile({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.locked = false,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
          child: Column(
            children: [
              Stack(
                children: [
                  Icon(icon, size: 32, color: color),
                  if (locked)
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.lock,
                          size: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// List item for quick actions.
class _QuickActionItem extends StatelessWidget {
  const _QuickActionItem({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final opacity = enabled ? 1.0 : 0.4;

    return ListTile(
      leading: Icon(
        icon,
        color: theme.colorScheme.primary.withValues(alpha: opacity),
      ),
      title: Text(
        label,
        style: theme.textTheme.bodyLarge?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: opacity),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: opacity),
        ),
      ),
      trailing: enabled
          ? Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant)
          : null,
      onTap: enabled ? onTap : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}

/// Inline water stepper sub-sheet.
class _WaterStepperSubSheet extends StatefulWidget {
  const _WaterStepperSubSheet();

  @override
  State<_WaterStepperSubSheet> createState() => _WaterStepperSubSheetState();
}

class _WaterStepperSubSheetState extends State<_WaterStepperSubSheet> {
  int _glasses = 1;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Log Water',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.filled(
                onPressed: _glasses > 1
                    ? () => setState(() => _glasses--)
                    : null,
                icon: const Icon(Icons.remove),
              ),
              const SizedBox(width: 24),
              Column(
                children: [
                  Text(
                    '$_glasses',
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${_glasses * 250} ml',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 24),
              IconButton.filled(
                onPressed: _glasses < 20
                    ? () => setState(() => _glasses++)
                    : null,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '1 glass = 250ml',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                // Water logging will be wired in P14-013
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Logged $_glasses glass${_glasses > 1 ? 'es' : ''} of water'),
                  ),
                );
              },
              child: const Text('Save'),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
