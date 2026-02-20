// lib/features/settings/presentation/rest_timer_settings.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../features/workouts/presentation/rest_timer_provider.dart';

const _kRestTimerAlertKey = 'rest_timer_alert_mode';

/// Loads the stored rest timer alert mode from Hive on app start.
Future<RestTimerAlertMode> loadRestTimerAlertMode() async {
  final box = Hive.box('settings');
  final stored = box.get(_kRestTimerAlertKey, defaultValue: 0) as int;
  if (stored >= 0 && stored < RestTimerAlertMode.values.length) {
    return RestTimerAlertMode.values[stored];
  }
  return RestTimerAlertMode.vibrateOnly;
}

/// Persists the rest timer alert mode to Hive.
Future<void> saveRestTimerAlertMode(RestTimerAlertMode mode) async {
  final box = Hive.box('settings');
  await box.put(_kRestTimerAlertKey, mode.index);
}

void showRestTimerAlertPicker(BuildContext context, WidgetRef ref) {
  final current = ref.read(restTimerAlertModeProvider);

  showModalBottomSheet(
    context: context,
    builder: (context) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Rest Timer Alert',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const Divider(height: 1),
            ...RestTimerAlertMode.values.map((mode) {
              final label = switch (mode) {
                RestTimerAlertMode.vibrateOnly => 'Vibrate only',
                RestTimerAlertMode.soundOnly => 'Sound only',
                RestTimerAlertMode.both => 'Vibrate + Sound',
                RestTimerAlertMode.silent => 'Silent',
              };
              final icon = switch (mode) {
                RestTimerAlertMode.vibrateOnly => Icons.vibration,
                RestTimerAlertMode.soundOnly => Icons.volume_up,
                RestTimerAlertMode.both => Icons.notifications_active,
                RestTimerAlertMode.silent => Icons.notifications_off,
              };

              return ListTile(
                leading: Icon(icon),
                title: Text(label),
                trailing: current == mode
                    ? Icon(Icons.check,
                        color: Theme.of(context).colorScheme.primary)
                    : null,
                onTap: () {
                  ref.read(restTimerAlertModeProvider.notifier).state = mode;
                  saveRestTimerAlertMode(mode);
                  Navigator.of(context).pop();
                },
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}
