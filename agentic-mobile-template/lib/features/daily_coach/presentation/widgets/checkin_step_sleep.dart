import 'package:flutter/material.dart';

/// Step 2 of the morning check-in wizard.
///
/// Shows auto-detected sleep duration from Health Connect.
/// User can override via a 1–10 slider.
/// Mapping: 10 = 10+ hours, 1 = <1 hour (not sleep quality, sleep hours mapped
/// to a 1–10 scale where 8 hours = 8.0).
class CheckInStepSleep extends StatefulWidget {
  const CheckInStepSleep({
    required this.autoSleepMinutes,
    required this.sleepQualityOverride,
    required this.overrideValue,
    required this.onOverride,
    required this.onUseAuto,
    required this.onNext,
    super.key,
  });

  /// Raw minutes from Health Connect; null if unavailable.
  final int? autoSleepMinutes;

  /// True when the user has moved the slider.
  final bool sleepQualityOverride;

  /// Current override value (1–10); null when using auto.
  final double? overrideValue;

  final ValueChanged<double> onOverride;
  final VoidCallback onUseAuto;
  final VoidCallback onNext;

  @override
  State<CheckInStepSleep> createState() => _CheckInStepSleepState();
}

class _CheckInStepSleepState extends State<CheckInStepSleep> {
  late double _sliderValue;

  @override
  void initState() {
    super.initState();
    _sliderValue = _computeInitialSlider();
  }

  double _computeInitialSlider() {
    if (widget.sleepQualityOverride && widget.overrideValue != null) {
      return widget.overrideValue!;
    }
    if (widget.autoSleepMinutes != null) {
      return (widget.autoSleepMinutes! / 60.0).clamp(1.0, 10.0);
    }
    return 7.0;
  }

  String _hoursLabel(double value) {
    final hours = value.toStringAsFixed(1);
    return '~$hours hours';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final autoHoursLabel = widget.autoSleepMinutes != null
        ? _hoursLabel(widget.autoSleepMinutes! / 60.0)
        : null;
    final isOverriding = widget.sleepQualityOverride;

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 64,
              ),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'How did you sleep?',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (autoHoursLabel != null && !isOverriding) ...[
                      Row(
                        children: [
                          Icon(Icons.bedtime_outlined,
                              size: 18, color: colorScheme.primary),
                          const SizedBox(width: 6),
                          Text(
                            'Auto-detected: $autoHoursLabel',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      Text(
                        'How long did you sleep?',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 40),

                    // ── Sleep hour display ────────────────────────────────
                    Center(
                      child: Text(
                        _hoursLabel(_sliderValue),
                        style: theme.textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 6,
                        thumbShape:
                            const RoundSliderThumbShape(enabledThumbRadius: 12),
                      ),
                      child: Slider(
                        value: _sliderValue,
                        min: 1,
                        max: 10,
                        divisions: 18, // 0.5-hour steps
                        label: _hoursLabel(_sliderValue),
                        onChanged: (value) {
                          setState(() => _sliderValue = value);
                          widget.onOverride(value);
                        },
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('<1h', style: theme.textTheme.bodySmall),
                        Text('10h+', style: theme.textTheme.bodySmall),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // ── Auto toggle ───────────────────────────────────────
                    if (autoHoursLabel != null)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            isOverriding
                                ? 'Using your value'
                                : 'Using auto-detected value',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (isOverriding)
                            TextButton(
                              onPressed: () {
                                widget.onUseAuto();
                                setState(
                                    () => _sliderValue = _computeInitialSlider());
                              },
                              child: const Text('Reset to auto'),
                            ),
                        ],
                      ),

                    const Spacer(),

                    FilledButton(
                      onPressed: widget.onNext,
                      child: const Text('Next'),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
