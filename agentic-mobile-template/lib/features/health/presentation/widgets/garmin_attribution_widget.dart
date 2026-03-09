import 'package:flutter/material.dart';

/// Displays a compact "Data provided by Garmin" attribution line.
///
/// Garmin's developer program requires brand attribution wherever Garmin data
/// is displayed.  This widget must be rendered any time a chart or metric is
/// sourced from a connected Garmin device.
///
/// Pass [visible] = false (or simply omit the widget) when Garmin is not
/// connected — the widget collapses to [SizedBox.shrink] at zero cost.
class GarminAttributionWidget extends StatelessWidget {
  const GarminAttributionWidget({
    super.key,
    this.visible = true,
  });

  /// When false the widget renders nothing.  Use this flag instead of
  /// wrapping in an [if] expression to keep widget-tree diffing minimal.
  final bool visible;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();

    final color = Theme.of(context).colorScheme.onSurfaceVariant;

    return Semantics(
      label: 'Data provided by Garmin',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.watch, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            'Data provided by Garmin',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: color,
                ),
          ),
        ],
      ),
    );
  }
}
