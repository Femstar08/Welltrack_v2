import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../meals/presentation/habit_prompt_provider.dart';

/// Contextual nudge card based on habit streaks and recovery state.
/// Dismissable — does not reappear same session.
class HabitStreakPromptCard extends ConsumerWidget {
  const HabitStreakPromptCard({super.key, required this.profileId});
  final String profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prompt = ref.watch(habitPromptProvider(profileId));
    if (prompt == null) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Dismissible(
        key: ValueKey('habit_prompt_${prompt.message.hashCode}'),
        direction: DismissDirection.horizontal,
        onDismissed: (_) {
          ref.read(habitPromptDismissedProvider.notifier).state = true;
        },
        background: Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 20),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.close, color: theme.colorScheme.onSurfaceVariant),
        ),
        secondaryBackground: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.close, color: theme.colorScheme.onSurfaceVariant),
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _cardColor(theme, prompt.icon),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _borderColor(theme, prompt.icon),
            ),
          ),
          child: Row(
            children: [
              Icon(
                _iconData(prompt.icon),
                size: 28,
                color: _iconColor(theme, prompt.icon),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      prompt.message,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (prompt.actionLabel != null &&
                        prompt.actionRoute != null) ...[
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: () => context.push(prompt.actionRoute!),
                        child: Text(
                          prompt.actionLabel!,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.close,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                tooltip: 'Dismiss',
                onPressed: () {
                  ref.read(habitPromptDismissedProvider.notifier).state = true;
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconData(String iconKey) {
    switch (iconKey) {
      case 'recovery':
        return Icons.battery_alert_rounded;
      case 'recovery_high':
        return Icons.bolt_rounded;
      case 'streak':
        return Icons.local_fire_department_rounded;
      case 'habits':
        return Icons.check_circle_outline_rounded;
      case 'morning':
        return Icons.wb_sunny_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }

  Color _cardColor(ThemeData theme, String iconKey) {
    switch (iconKey) {
      case 'recovery':
        return const Color(0xFFFFF3E0); // amber light
      case 'recovery_high':
        return const Color(0xFFE8F5E9); // green light
      case 'streak':
        return const Color(0xFFFCE4EC); // pink light
      default:
        return theme.colorScheme.surface;
    }
  }

  Color _borderColor(ThemeData theme, String iconKey) {
    switch (iconKey) {
      case 'recovery':
        return const Color(0xFFFFCC80);
      case 'recovery_high':
        return const Color(0xFFA5D6A7);
      case 'streak':
        return const Color(0xFFF48FB1);
      default:
        return theme.colorScheme.outlineVariant;
    }
  }

  Color _iconColor(ThemeData theme, String iconKey) {
    switch (iconKey) {
      case 'recovery':
        return const Color(0xFFFF9800);
      case 'recovery_high':
        return const Color(0xFF4CAF50);
      case 'streak':
        return const Color(0xFFE91E63);
      case 'morning':
        return const Color(0xFFFFC107);
      default:
        return theme.colorScheme.primary;
    }
  }
}
