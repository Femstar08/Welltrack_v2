import 'package:flutter/material.dart';

/// Step 4 of the morning check-in wizard — Vitality check.
///
/// Always shown (MVP: data is collected privately regardless of AI consent).
/// Includes:
/// - Morning erection: Yes / No chips
/// - On Sundays: weekly erection quality slider (1–10)
///
/// A clear privacy note is displayed. This step can be skipped.
class CheckInStepVitality extends StatefulWidget {
  const CheckInStepVitality({
    required this.morningErection,
    required this.erectionQualityWeekly,
    required this.isSunday,
    required this.onMorningErection,
    required this.onErectionQuality,
    required this.onNext,
    required this.onSkip,
    super.key,
  });

  final bool? morningErection;
  final int? erectionQualityWeekly;
  final bool isSunday;
  final ValueChanged<bool?> onMorningErection;
  final ValueChanged<int> onErectionQuality;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  @override
  State<CheckInStepVitality> createState() => _CheckInStepVitalityState();
}

class _CheckInStepVitalityState extends State<CheckInStepVitality> {
  late double _weeklyQuality;

  @override
  void initState() {
    super.initState();
    _weeklyQuality = (widget.erectionQualityWeekly ?? 7).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
                      'Morning check',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Privacy note
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.lock_outline,
                              size: 16, color: colorScheme.onSurfaceVariant),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'This data is private. Not shared with AI unless you enable '
                              'Vitality Data in Settings.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // ── Morning erection ──────────────────────────────────
                    Text(
                      'Morning erection today?',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _VitalityChip(
                            label: 'Yes',
                            isSelected: widget.morningErection == true,
                            onTap: () => widget.onMorningErection(true),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _VitalityChip(
                            label: 'No',
                            isSelected: widget.morningErection == false,
                            onTap: () => widget.onMorningErection(false),
                          ),
                        ),
                      ],
                    ),

                    // ── Sunday: weekly quality slider ─────────────────────
                    if (widget.isSunday) ...[
                      const SizedBox(height: 32),
                      Text(
                        'Erection quality this week?',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '1 = very poor, 10 = excellent',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: Text(
                          '${_weeklyQuality.round()}',
                          style: theme.textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(trackHeight: 6),
                        child: Slider(
                          value: _weeklyQuality,
                          min: 1,
                          max: 10,
                          divisions: 9,
                          label: '${_weeklyQuality.round()}',
                          onChanged: (value) {
                            setState(() => _weeklyQuality = value);
                            widget.onErectionQuality(value.round());
                          },
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('1', style: theme.textTheme.bodySmall),
                          Text('10', style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ],

                    const Spacer(),

                    // ── Actions ───────────────────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: widget.onSkip,
                            child: const Text('Skip'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: widget.onNext,
                            child: const Text('Next'),
                          ),
                        ),
                      ],
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

class _VitalityChip extends StatelessWidget {
  const _VitalityChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? colorScheme.primary : Colors.transparent,
            width: 2,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: isSelected
                ? colorScheme.onPrimaryContainer
                : colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}
