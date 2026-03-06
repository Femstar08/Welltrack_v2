import 'package:flutter/material.dart';

/// Step 1 of the morning check-in wizard.
///
/// Displays 5 ChoiceChips. Tapping one calls [onFeelingSelected] and
/// automatically advances to the next step after a brief delay.
class CheckInStepFeeling extends StatelessWidget {
  const CheckInStepFeeling({
    required this.selectedFeeling,
    required this.onFeelingSelected,
    super.key,
  });

  final String? selectedFeeling;
  final ValueChanged<String> onFeelingSelected;

  static const _options = [
    _FeelingOption(value: 'great', label: 'Great', emoji: '😊'),
    _FeelingOption(value: 'good', label: 'Good', emoji: '👍'),
    _FeelingOption(value: 'tired', label: 'Tired', emoji: '😴'),
    _FeelingOption(value: 'sore', label: 'Sore', emoji: '💪'),
    _FeelingOption(value: 'unwell', label: 'Unwell', emoji: '🤒'),
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
              'How are you feeling?',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap to select and move on.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 40),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.start,
              children: _options.map((option) {
                final isSelected = selectedFeeling == option.value;
                return _FeelingChip(
                  option: option,
                  isSelected: isSelected,
                  onTap: () => onFeelingSelected(option.value),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Internal widgets
// ---------------------------------------------------------------------------

class _FeelingOption {
  const _FeelingOption({
    required this.value,
    required this.label,
    required this.emoji,
  });

  final String value;
  final String label;
  final String emoji;
}

class _FeelingChip extends StatelessWidget {
  const _FeelingChip({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  final _FeelingOption option;
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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
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
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(option.emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 8),
            Text(
              option.label,
              style: theme.textTheme.titleMedium?.copyWith(
                color: isSelected
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurface,
                fontWeight:
                    isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
