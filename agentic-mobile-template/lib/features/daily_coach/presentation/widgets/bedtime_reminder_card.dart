import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class BedtimeReminderCard extends StatelessWidget {
  const BedtimeReminderCard({
    super.key,
    this.bedtimeHour,
    this.bedtimeMinute,
  });

  final int? bedtimeHour;
  final int? bedtimeMinute;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bedtimeText = _formatBedtime(bedtimeHour, bedtimeMinute);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      color: theme.colorScheme.surfaceContainerLow,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.bedtime_outlined,
              color: theme.colorScheme.onSurfaceVariant,
              size: 28,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bedtimeText != null
                        ? 'Bedtime: $bedtimeText'
                        : 'Bedtime Reminder',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Aim for 7+ hours of sleep tonight.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              color: theme.colorScheme.onSurfaceVariant,
              onPressed: () => context.push('/reminders'),
            ),
          ],
        ),
      ),
    );
  }

  String? _formatBedtime(int? hour, int? minute) {
    if (hour == null) return null;
    final m = minute ?? 0;
    final period = hour >= 12 ? 'PM' : 'AM';
    final h = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final minStr = m.toString().padLeft(2, '0');
    return '$h:$minStr $period';
  }
}
