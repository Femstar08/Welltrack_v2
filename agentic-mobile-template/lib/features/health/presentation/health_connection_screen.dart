import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:welltrack/features/health/presentation/health_provider.dart';
import 'package:welltrack/features/health/domain/health_metric_entity.dart';

class HealthConnectionScreen extends ConsumerWidget {
  final String profileId;

  const HealthConnectionScreen({
    Key? key,
    required this.profileId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionState = ref.watch(healthConnectionProvider(profileId));
    final baselineStatus = ref.watch(baselineStatusProvider(profileId));
    final calibrationProgress = ref.watch(calibrationProgressProvider(profileId));
    final latestMetrics = ref.watch(latestMetricsProvider(profileId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Health Connections'),
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(baselineStatusProvider(profileId));
          ref.invalidate(latestMetricsProvider(profileId));
          ref.invalidate(calibrationProgressProvider(profileId));
        },
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            _buildPlatformHealthCard(
              context,
              ref,
              connectionState,
              baselineStatus,
              calibrationProgress,
            ),
            const SizedBox(height: 16),
            _buildLatestMetricsCard(context, latestMetrics),
            const SizedBox(height: 16),
            _buildConnectionCard(
              context,
              title: 'Garmin',
              subtitle: 'Stress, VO2 max, and detailed workout metrics',
              icon: Icons.watch,
              isConnected: false,
              isComingSoon: true,
            ),
            const SizedBox(height: 16),
            _buildConnectionCard(
              context,
              title: 'Strava',
              subtitle: 'Activities, routes, and performance analytics',
              icon: Icons.directions_run,
              isConnected: false,
              isComingSoon: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlatformHealthCard(
    BuildContext context,
    WidgetRef ref,
    HealthConnectionState connectionState,
    AsyncValue<Map<MetricType, dynamic>> baselineStatus,
    AsyncValue<Map<MetricType, double>> calibrationProgress,
  ) {
    final platformName = (!kIsWeb && Platform.isAndroid) ? 'Health Connect' : 'HealthKit';
    final platformIcon = (!kIsWeb && Platform.isAndroid) ? Icons.favorite : Icons.health_and_safety;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(platformIcon, size: 32, color: Theme.of(context).primaryColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        platformName,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        'Sleep, steps, and heart rate',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                    ],
                  ),
                ),
                _buildConnectionStatusBadge(context, connectionState.isConnected),
              ],
            ),
            const SizedBox(height: 16),

            if (!connectionState.isConnected) ...[
              ElevatedButton.icon(
                onPressed: connectionState.isSyncing
                    ? null
                    : () async {
                        await ref
                            .read(healthConnectionProvider(profileId).notifier)
                            .requestPermissions();
                      },
                icon: const Icon(Icons.link),
                label: const Text('Connect'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            ] else ...[
              if (connectionState.lastSyncTime != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Row(
                    children: [
                      Icon(Icons.sync, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Text(
                        'Last synced: ${_formatLastSync(connectionState.lastSyncTime!)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                    ],
                  ),
                ),

              // Calibration progress
              calibrationProgress.when(
                data: (progress) {
                  if (progress.isEmpty) return const SizedBox.shrink();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Divider(),
                      const SizedBox(height: 8),
                      Text(
                        'Baseline Calibration',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      ...progress.entries.map((entry) =>
                        _buildCalibrationProgressBar(
                          context,
                          entry.key,
                          entry.value,
                        ),
                      ),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => const SizedBox.shrink(),
              ),

              const SizedBox(height: 12),

              OutlinedButton.icon(
                onPressed: connectionState.isSyncing
                    ? null
                    : () async {
                        await ref
                            .read(healthConnectionProvider(profileId).notifier)
                            .syncNow();
                      },
                icon: connectionState.isSyncing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync),
                label: Text(connectionState.isSyncing ? 'Syncing...' : 'Sync Now'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            ],

            if (connectionState.error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red[700], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        connectionState.error!,
                        style: TextStyle(color: Colors.red[700], fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLatestMetricsCard(
    BuildContext context,
    AsyncValue<Map<MetricType, HealthMetricEntity?>> latestMetrics,
  ) {
    return latestMetrics.when(
      data: (metrics) {
        if (metrics.values.every((m) => m == null)) {
          return const SizedBox.shrink();
        }

        return Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Latest Data',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                ...metrics.entries
                    .where((e) => e.value != null)
                    .map((e) => _buildMetricRow(context, e.key, e.value!)),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildMetricRow(
    BuildContext context,
    MetricType type,
    HealthMetricEntity metric,
  ) {
    final icon = _getMetricIcon(type);
    final label = _getMetricLabel(type);
    final value = _formatMetricValue(metric);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).primaryColor),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildCalibrationProgressBar(
    BuildContext context,
    MetricType metricType,
    double progress,
  ) {
    final label = _getMetricLabel(metricType);
    final isComplete = progress >= 100;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              Text(
                isComplete ? 'Complete' : '${progress.toStringAsFixed(0)}%',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isComplete ? Colors.green : Colors.grey[600],
                      fontWeight: isComplete ? FontWeight.bold : FontWeight.normal,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: progress / 100,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation(
              isComplete ? Colors.green : Theme.of(context).primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isConnected,
    bool isComingSoon = false,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(icon, size: 32, color: Colors.grey[400]),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                ],
              ),
            ),
            if (isComingSoon)
              Chip(
                label: const Text('Coming Soon', style: TextStyle(fontSize: 11)),
                backgroundColor: Colors.grey[200],
                padding: EdgeInsets.zero,
              )
            else
              _buildConnectionStatusBadge(context, isConnected),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionStatusBadge(BuildContext context, bool isConnected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isConnected ? Colors.green[50] : Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isConnected ? Colors.green[200]! : Colors.grey[300]!,
        ),
      ),
      child: Text(
        isConnected ? 'Connected' : 'Not Connected',
        style: TextStyle(
          color: isConnected ? Colors.green[700] : Colors.grey[700],
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _formatLastSync(DateTime lastSync) {
    final now = DateTime.now();
    final difference = now.difference(lastSync);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  IconData _getMetricIcon(MetricType type) {
    switch (type) {
      case MetricType.sleep:
        return Icons.bedtime;
      case MetricType.steps:
        return Icons.directions_walk;
      case MetricType.hr:
        return Icons.favorite;
      default:
        return Icons.analytics;
    }
  }

  String _getMetricLabel(MetricType type) {
    switch (type) {
      case MetricType.sleep:
        return 'Sleep';
      case MetricType.steps:
        return 'Steps';
      case MetricType.hr:
        return 'Resting HR';
      default:
        return type.name;
    }
  }

  String _formatMetricValue(HealthMetricEntity metric) {
    if (metric.valueNum == null) return 'N/A';

    switch (metric.metricType) {
      case MetricType.sleep:
        final hours = metric.valueNum! / 60;
        return '${hours.toStringAsFixed(1)}h';
      case MetricType.steps:
        return metric.valueNum!.toInt().toString();
      case MetricType.hr:
        return '${metric.valueNum!.toInt()} bpm';
      default:
        return '${metric.valueNum!.toStringAsFixed(1)} ${metric.unit}';
    }
  }
}
