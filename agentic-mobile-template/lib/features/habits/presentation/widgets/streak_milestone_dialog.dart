// lib/features/habits/presentation/widgets/streak_milestone_dialog.dart
//
// Shown as a modal bottom sheet when a habit streak crosses a milestone
// threshold (7, 30, 90, or 180 days).

import 'package:flutter/material.dart';

/// Display a celebratory milestone sheet.
///
/// Usage:
///   StreakMilestoneDialog.show(context, milestone: 30, habitLabel: 'Kegels');
class StreakMilestoneDialog extends StatelessWidget {
  const StreakMilestoneDialog({
    super.key,
    required this.milestone,
    required this.habitLabel,
  });

  /// The milestone day count that was reached (7 / 30 / 90 / 180).
  final int milestone;

  /// Human-readable habit name shown in the body text.
  final String habitLabel;

  // -------------------------------------------------------------------------
  // Static helper — call this from screens rather than pushing the widget
  // directly so the caller does not need to know the bottom-sheet API.
  // -------------------------------------------------------------------------

  static Future<void> show(
    BuildContext context, {
    required int milestone,
    required String habitLabel,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => StreakMilestoneDialog(
        milestone: milestone,
        habitLabel: habitLabel,
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Content helpers
  // -------------------------------------------------------------------------

  String get _headline {
    switch (milestone) {
      case 7:
        return 'Building consistency!';
      case 30:
        return 'One month strong!';
      case 90:
        return 'Quarter year champion!';
      case 180:
        return 'Half year legend!';
      default:
        return '$milestone day streak!';
    }
  }

  String get _body {
    switch (milestone) {
      case 7:
        return 'You have completed "$habitLabel" every day for a week. Keep the momentum going!';
      case 30:
        return '"$habitLabel" is becoming a genuine habit. 30 days of consistency is a real achievement.';
      case 90:
        return 'Three months of "$habitLabel" — at this point it is part of who you are. Outstanding.';
      case 180:
        return 'Six months of unbroken commitment to "$habitLabel". You are in rare company.';
      default:
        return 'You have kept up "$habitLabel" for $milestone consecutive days.';
    }
  }

  Color _accentColor(BuildContext context) {
    switch (milestone) {
      case 7:
        return const Color(0xFF42A5F5); // blue
      case 30:
        return const Color(0xFF66BB6A); // green
      case 90:
        return const Color(0xFFFFCA28); // amber
      case 180:
        return const Color(0xFFFF7043); // deep orange
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = _accentColor(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          // Fire icon with accent ring
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: accent, width: 2),
            ),
            child: Icon(
              Icons.local_fire_department,
              color: accent,
              size: 40,
            ),
          ),
          const SizedBox(height: 16),

          // Milestone day count
          Text(
            '$milestone',
            style: theme.textTheme.displayMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: accent,
              height: 1.0,
            ),
          ),
          Text(
            'day streak',
            style: theme.textTheme.titleMedium?.copyWith(
              color: accent,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),

          // Headline
          Text(
            _headline,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          // Body
          Text(
            _body,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),

          // Dismiss button
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Keep it up!',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
