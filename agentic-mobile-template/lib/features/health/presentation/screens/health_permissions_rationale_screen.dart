import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/core/health/health_service.dart';

/// Google Play required screen: explains WHY each health permission is needed.
/// Shown BEFORE requesting Health Connect permissions.
class HealthPermissionsRationaleScreen extends ConsumerWidget {
  const HealthPermissionsRationaleScreen({super.key});

  static const _permissions = <_PermissionInfo>[
    _PermissionInfo(
      icon: Icons.directions_walk_rounded,
      name: 'Steps',
      reason: 'Track daily activity and set movement goals',
    ),
    _PermissionInfo(
      icon: Icons.monitor_heart_rounded,
      name: 'Heart Rate',
      reason: 'Monitor recovery and calculate training readiness',
    ),
    _PermissionInfo(
      icon: Icons.bedtime_rounded,
      name: 'Sleep',
      reason: 'Optimise rest and adjust tomorrow\'s plan',
    ),
    _PermissionInfo(
      icon: Icons.monitor_weight_rounded,
      name: 'Weight',
      reason: 'Track body composition progress toward your goals',
    ),
    _PermissionInfo(
      icon: Icons.fitness_center_rounded,
      name: 'Exercise & Calories',
      reason: 'Personalise workout plans and calorie targets',
    ),
    _PermissionInfo(
      icon: Icons.straighten_rounded,
      name: 'Distance',
      reason: 'Measure running and walking activity accurately',
    ),
    _PermissionInfo(
      icon: Icons.percent_rounded,
      name: 'Body Fat',
      reason: 'Fine-tune nutrition recommendations',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () => context.pop(),
        ),
        title: const Text('Health Data Access'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.health_and_safety_rounded,
                size: 48,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Why WellTrack needs your health data',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'We use Health Connect to personalise your recovery plan and training recommendations. Your data stays private and secure.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Expanded(
                child: ListView.separated(
                  itemCount: _permissions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final perm = _permissions[index];
                    return Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            perm.icon,
                            size: 24,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                perm.name,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                perm.reason,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  // Request actual Health Connect permissions
                  try {
                    final healthService =
                        ref.read(healthServiceProvider);
                    await healthService.requestHealthPermissions();
                  } catch (_) {
                    // Permission request handled by system
                  }
                  if (context.mounted) context.pop();
                },
                child: const Text('Continue'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  // Show explanation that limited features still work
                  showDialog<void>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Limited features'),
                      content: const Text(
                        'WellTrack will still work without health data access. '
                        'You can manually log meals, workouts, and habits. '
                        'However, automatic recovery scoring and personalised '
                        'plans require health data from Health Connect.\n\n'
                        'You can grant permissions later in Settings.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            context.pop();
                          },
                          child: const Text('Continue without'),
                        ),
                      ],
                    ),
                  );
                },
                child: Text(
                  'Not now',
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermissionInfo {
  const _PermissionInfo({
    required this.icon,
    required this.name,
    required this.reason,
  });
  final IconData icon;
  final String name;
  final String reason;
}
