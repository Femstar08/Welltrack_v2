import 'package:flutter/material.dart';

/// Step 3 of the morning check-in wizard.
///
/// Presents 3 ChoiceChips for today's schedule type.
/// Tapping auto-advances to the next step after a brief delay.
class CheckInStepSchedule extends StatelessWidget {
  const CheckInStepSchedule({
    required this.selectedSchedule,
    required this.onScheduleSelected,
    super.key,
  });

  final String? selectedSchedule;
  final ValueChanged<String> onScheduleSelected;

  static const _options = [
    _ScheduleOption(
      value: 'busy',
      label: 'Busy',
      icon: Icons.bolt,
      description: 'Packed day — need quick solutions',
    ),
    _ScheduleOption(
      value: 'normal',
      label: 'Normal',
      icon: Icons.calendar_today_outlined,
      description: 'Standard day, business as usual',
    ),
    _ScheduleOption(
      value: 'flexible',
      label: 'Flexible',
      icon: Icons.wb_sunny_outlined,
      description: 'Open schedule, room to push harder',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "What's your schedule today?",
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This helps tailor your workout and meals.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 40),
            ..._options.map((option) {
              final isSelected = selectedSchedule == option.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ScheduleCard(
                  option: option,
                  isSelected: isSelected,
                  onTap: () => onScheduleSelected(option.value),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Internal widgets
// ---------------------------------------------------------------------------

class _ScheduleOption {
  const _ScheduleOption({
    required this.value,
    required this.label,
    required this.icon,
    required this.description,
  });

  final String value;
  final String label;
  final IconData icon;
  final String description;
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  final _ScheduleOption option;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? colorScheme.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(
              option.icon,
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
              size: 28,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.label,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    option.description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isSelected
                          ? colorScheme.onPrimaryContainer.withValues(alpha: 0.8)
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: colorScheme.primary, size: 20),
          ],
        ),
      ),
    );
  }
}
