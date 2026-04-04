import 'package:flutter/material.dart';

/// Strava brand orange — #FC4C02.
const _stravaOrange = Color(0xFFFC4C02);

/// Displays a compact "Powered by Strava" attribution line.
///
/// Strava's API agreement requires attribution wherever Strava activity data
/// is displayed.  This widget uses Strava's brand orange (#FC4C02) for the
/// icon and text, per Strava's brand guidelines.
///
/// Pass [visible] = false (or omit the widget) when Strava is not connected —
/// the widget collapses to [SizedBox.shrink] at zero cost.
class StravaAttributionWidget extends StatelessWidget {
  const StravaAttributionWidget({
    super.key,
    this.visible = true,
  });

  /// When false the widget renders nothing.  Use this flag instead of
  /// wrapping in an [if] expression to keep widget-tree diffing minimal.
  final bool visible;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();

    return Semantics(
      label: 'Powered by Strava',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.directions_bike, size: 12, color: _stravaOrange),
          const SizedBox(width: 4),
          Text(
            'Powered by Strava',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _stravaOrange,
                ),
          ),
        ],
      ),
    );
  }
}
