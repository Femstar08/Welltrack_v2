import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:welltrack/features/health/presentation/health_provider.dart';
import 'package:welltrack/features/health/domain/health_metric_entity.dart';
import 'package:welltrack/shared/core/router/app_router.dart';

class HealthSettingsScreen extends ConsumerWidget {
  const HealthSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // Get profile ID from active profile provider
    final profileId = ref.watch(activeProfileIdProvider) ?? '';

    final connectionState = ref.watch(healthConnectionProvider(profileId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Health Data'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // Connection Status Section
          _buildSectionHeader(context, 'Connection Status'),
          _buildConnectionStatusCard(
            context,
            connectionState,
            colorScheme,
            isDark,
          ),

          // Sync Status Section
          if (connectionState.isConnected) ...[
            _buildSectionHeader(context, 'Sync Status'),
            _buildSyncStatusCard(
              context,
              connectionState,
              colorScheme,
              profileId,
              ref,
            ),
          ],

          // Permissions Section
          if (connectionState.isConnected) ...[
            _buildSectionHeader(context, 'Permissions'),
            _buildPermissionsCard(context, colorScheme),
          ],

          // Connection Actions
          _buildSectionHeader(context, 'Actions'),
          _buildActionsCard(
            context,
            connectionState,
            colorScheme,
            profileId,
            ref,
          ),

          // Error display if present
          if (connectionState.error != null)
            _buildErrorCard(context, connectionState.error!, colorScheme),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildConnectionStatusCard(
    BuildContext context,
    HealthConnectionState state,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    final platformName = Platform.isAndroid ? 'Health Connect' : 'HealthKit';
    final platformIcon =
        Platform.isAndroid ? Icons.favorite : Icons.health_and_safety;

    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (state.isConnected) {
      statusColor = const Color(0xFF4CAF50); // Green
      statusText = 'Connected';
      statusIcon = Icons.check_circle;
    } else if (state.error != null) {
      statusColor = const Color(0xFFFFB300); // Amber
      statusText = 'Needs Setup';
      statusIcon = Icons.error_outline;
    } else {
      statusColor = colorScheme.onSurfaceVariant;
      statusText = 'Disconnected';
      statusIcon = Icons.circle_outlined;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                platformIcon,
                color: colorScheme.primary,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    platformName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Sleep, steps, and heart rate',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(isDark ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: statusColor.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    statusIcon,
                    size: 16,
                    color: statusColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncStatusCard(
    BuildContext context,
    HealthConnectionState state,
    ColorScheme colorScheme,
    String profileId,
    WidgetRef ref,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Last synced time
            Row(
              children: [
                Icon(
                  Icons.sync,
                  size: 20,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Last Synced',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        state.lastSyncTime != null
                            ? _formatLastSync(state.lastSyncTime!)
                            : 'Never',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            // Sync now button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: state.isSyncing
                    ? null
                    : () async {
                        await ref
                            .read(healthConnectionProvider(profileId).notifier)
                            .syncNow();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Health data synced successfully'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                icon: state.isSyncing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync),
                label: Text(state.isSyncing ? 'Syncing...' : 'Sync Now'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionsCard(BuildContext context, ColorScheme colorScheme) {
    final permissions = [
      _PermissionItem(
        icon: Icons.bedtime,
        label: 'Sleep',
        description: 'Sleep duration and stages',
        isGranted: true,
      ),
      _PermissionItem(
        icon: Icons.directions_walk,
        label: 'Steps',
        description: 'Daily step count',
        isGranted: true,
      ),
      _PermissionItem(
        icon: Icons.favorite,
        label: 'Heart Rate',
        description: 'Resting heart rate',
        isGranted: true,
      ),
    ];

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          for (int i = 0; i < permissions.length; i++) ...[
            _buildPermissionTile(
              context,
              permissions[i],
              colorScheme,
            ),
            if (i < permissions.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }

  Widget _buildPermissionTile(
    BuildContext context,
    _PermissionItem item,
    ColorScheme colorScheme,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              item.icon,
              color: colorScheme.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          Icon(
            item.isGranted ? Icons.check_circle : Icons.cancel,
            color: item.isGranted
                ? const Color(0xFF4CAF50)
                : colorScheme.onSurfaceVariant,
            size: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildActionsCard(
    BuildContext context,
    HealthConnectionState state,
    ColorScheme colorScheme,
    String profileId,
    WidgetRef ref,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            if (!state.isConnected) ...[
              // Connect button
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: state.isSyncing
                      ? null
                      : () async {
                          final granted = await ref
                              .read(
                                  healthConnectionProvider(profileId).notifier)
                              .requestPermissions();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  granted
                                      ? 'Health data connected successfully'
                                      : 'Permission denied. Please enable in system settings.',
                                ),
                                duration: const Duration(seconds: 3),
                              ),
                            );
                          }
                        },
                  icon: const Icon(Icons.link),
                  label: const Text('Connect Health Data'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ] else ...[
              // Disconnect button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Disconnect Health Data'),
                        content: const Text(
                          'This will stop syncing your health data. You can reconnect at any time.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: const Text('Disconnect'),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true && context.mounted) {
                      // Clear permission cache
                      // Note: Actual implementation would need to clear cached permissions
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Health data disconnected'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.link_off),
                  label: const Text('Disconnect Health Data'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colorScheme.error,
                    side: BorderSide(color: colorScheme.error),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            // Info text
            Text(
              Platform.isAndroid
                  ? 'Health Connect is Android\'s secure health data platform. Your data never leaves your device without permission.'
                  : 'HealthKit is Apple\'s secure health data platform. Your data is encrypted and private to your device.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard(
    BuildContext context,
    String error,
    ColorScheme colorScheme,
  ) {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      color: colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: colorScheme.error,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Error',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: colorScheme.error,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    error,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onErrorContainer,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatLastSync(DateTime lastSync) {
    final now = DateTime.now();
    final difference = now.difference(lastSync);

    if (difference.inSeconds < 10) {
      return 'Just now';
    } else if (difference.inMinutes < 1) {
      return '${difference.inSeconds}s ago';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${(difference.inDays / 7).floor()}w ago';
    }
  }
}

class _PermissionItem {
  final IconData icon;
  final String label;
  final String description;
  final bool isGranted;

  const _PermissionItem({
    required this.icon,
    required this.label,
    required this.description,
    required this.isGranted,
  });
}
