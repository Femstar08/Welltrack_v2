import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:welltrack/features/health/presentation/health_provider.dart';
import 'package:welltrack/features/profile/presentation/onboarding/onboarding_state.dart';

class ConnectDevicesScreen extends ConsumerWidget {
  final VoidCallback onContinue;
  final String? profileId;

  const ConnectDevicesScreen({
    super.key,
    required this.onContinue,
    this.profileId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final platformName = (!kIsWeb && Platform.isAndroid) ? 'Health Connect' : 'HealthKit';
    final platformIcon =
        (!kIsWeb && Platform.isAndroid) ? Icons.favorite : Icons.health_and_safety;

    HealthConnectionState? connectionState;
    if (profileId != null && profileId!.isNotEmpty) {
      connectionState = ref.watch(healthConnectionProvider(profileId!));
    }

    final isConnected = connectionState?.isConnected ?? false;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 48),
          Text(
            'Connect your\nhealth data',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Optional. You can always connect later in Settings.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 32),
          _DeviceConnectionTile(
            icon: platformIcon,
            title: platformName,
            subtitle: 'Sleep, steps, and heart rate',
            isConnected: isConnected,
            accent: accent,
            onConnect: profileId != null && profileId!.isNotEmpty
                ? () async {
                    await ref
                        .read(healthConnectionProvider(profileId!).notifier)
                        .requestPermissions();
                  }
                : null,
          ),
          const SizedBox(height: 12),
          _DeviceConnectionTile(
            icon: Icons.watch,
            title: 'Garmin',
            subtitle: 'Stress, VO2 max, workout metrics',
            accent: accent,
            isComingSoon: true,
          ),
          const SizedBox(height: 12),
          _DeviceConnectionTile(
            icon: Icons.directions_run,
            title: 'Strava',
            subtitle: 'Activities, routes, performance',
            accent: accent,
            isComingSoon: true,
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: onContinue,
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Continue',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: TextButton(
              onPressed: () {
                ref
                    .read(onboardingDataProvider.notifier)
                    .setSkippedDevices(true);
                onContinue();
              },
              child: Text(
                'Skip for now',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _DeviceConnectionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final bool isConnected;
  final bool isComingSoon;
  final VoidCallback? onConnect;

  const _DeviceConnectionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    this.isConnected = false,
    this.isComingSoon = false,
    this.onConnect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isConnected
              ? accent
              : theme.colorScheme.outlineVariant,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 32,
            color: isComingSoon
                ? theme.colorScheme.onSurfaceVariant
                : accent,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (isComingSoon)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Soon',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else if (isConnected)
            Icon(Icons.check_circle, color: accent, size: 24)
          else if (onConnect != null)
            OutlinedButton(
              onPressed: onConnect,
              style: OutlinedButton.styleFrom(
                foregroundColor: accent,
                side: BorderSide(color: accent),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: const Text('Connect'),
            ),
        ],
      ),
    );
  }
}
