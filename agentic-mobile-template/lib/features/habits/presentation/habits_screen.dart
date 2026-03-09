// lib/features/habits/presentation/habits_screen.dart
//
// Phase 12 — Habit Tracker screen.
//
// Displays all active habits for the profile, each showing:
//   - Habit icon and label
//   - Today's completion toggle (checkbox)
//   - Current streak with fire icon
//   - Last 30 days as a dot grid (green = done, grey = missed, today = ring)
//
// FAB opens an add-habit bottom sheet.
// Milestones trigger StreakMilestoneDialog after a successful toggle.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/habit_repository.dart';
import '../domain/habit_entity.dart';
import 'habit_provider.dart';
import 'widgets/streak_milestone_dialog.dart';

// ---------------------------------------------------------------------------
// Icons & metadata for pre-defined habit types
// ---------------------------------------------------------------------------

class _HabitMeta {
  const _HabitMeta(this.icon, this.label, this.color);

  final IconData icon;
  final String label;
  final Color color;
}

const Map<String, _HabitMeta> _presetMeta = {
  HabitType.pornFree: _HabitMeta(
    Icons.block,
    'Porn-free',
    Color(0xFF7E57C2),
  ),
  HabitType.kegels: _HabitMeta(
    Icons.self_improvement,
    'Kegels',
    Color(0xFF42A5F5),
  ),
  HabitType.sleepTarget: _HabitMeta(
    Icons.bedtime,
    'Sleep target',
    Color(0xFF5C6BC0),
  ),
  HabitType.stepsTarget: _HabitMeta(
    Icons.directions_walk,
    'Steps target',
    Color(0xFF66BB6A),
  ),
};

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class HabitsScreen extends ConsumerStatefulWidget {
  const HabitsScreen({super.key, required this.profileId});

  final String profileId;

  @override
  ConsumerState<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends ConsumerState<HabitsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(habitProvider(widget.profileId).notifier).loadHabits();
    });
  }

  // -------------------------------------------------------------------------
  // Milestone listener
  // -------------------------------------------------------------------------

  /// Called after every build — shows the milestone dialog when one is pending.
  void _maybeShowMilestone(HabitState habitState) {
    final milestone = habitState.milestoneReached;
    if (milestone == null) return;

    // Defer until after the current frame to avoid setState-during-build.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      // Find the habit that just hit the milestone so we can show its label.
      final habit = habitState.habits.firstWhere(
        (h) => h.currentStreakDays == milestone,
        orElse: () => habitState.habits.first,
      );

      final label = habit.habitLabel ?? _labelFor(habit.habitType);

      await StreakMilestoneDialog.show(
        context,
        milestone: milestone,
        habitLabel: label,
      );

      if (mounted) {
        ref
            .read(habitProvider(widget.profileId).notifier)
            .clearMilestone();
      }
    });
  }

  // -------------------------------------------------------------------------
  // Add habit bottom sheet
  // -------------------------------------------------------------------------

  Future<void> _showAddHabitSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddHabitSheet(
        profileId: widget.profileId,
        onAdd: (label) {
          ref
              .read(habitProvider(widget.profileId).notifier)
              .addCustomHabit(label);
        },
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final habitState = ref.watch(habitProvider(widget.profileId));

    // Trigger milestone dialog as a side-effect after render.
    _maybeShowMilestone(habitState);

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Habits'),
        centerTitle: false,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddHabitSheet,
        icon: const Icon(Icons.add),
        label: const Text('Add habit'),
      ),
      body: habitState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : habitState.error != null && habitState.habits.isEmpty
              ? _ErrorBody(
                  error: habitState.error!,
                  onRetry: () => ref
                      .read(habitProvider(widget.profileId).notifier)
                      .loadHabits(),
                )
              : habitState.habits.isEmpty
                  ? _EmptyBody(onAdd: _showAddHabitSheet)
                  : RefreshIndicator(
                      onRefresh: () => ref
                          .read(habitProvider(widget.profileId).notifier)
                          .loadHabits(),
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                        itemCount: habitState.habits.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final habit = habitState.habits[index];
                          return _HabitCard(
                            habit: habit,
                            isCompletedToday:
                                habitState.todayLogs[habit.habitType] ?? false,
                            last30Logs: habitState
                                    .last30DaysLogs[habit.habitType] ??
                                const [],
                            onToggle: () => ref
                                .read(habitProvider(widget.profileId).notifier)
                                .toggleHabitToday(habit.habitType),
                            onDelete: () => _confirmDelete(context, habit),
                            theme: theme,
                            onStartTimer: habit.habitType == HabitType.kegels
                                ? () => context.push('/habits/kegel-timer')
                                : null,
                          );
                        },
                      ),
                    ),
    );
  }

  // -------------------------------------------------------------------------
  // Delete confirmation
  // -------------------------------------------------------------------------

  Future<void> _confirmDelete(BuildContext context, HabitEntity habit) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove habit?'),
        content: Text(
          'Your history for "${habit.habitLabel ?? _labelFor(habit.habitType)}" '
          'will be kept, but the habit will be removed from your tracker.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref
          .read(habitProvider(widget.profileId).notifier)
          .deleteHabit(habit.id);
    }
  }
}

// ---------------------------------------------------------------------------
// Habit card
// ---------------------------------------------------------------------------

class _HabitCard extends StatelessWidget {
  const _HabitCard({
    required this.habit,
    required this.isCompletedToday,
    required this.last30Logs,
    required this.onToggle,
    required this.onDelete,
    required this.theme,
    this.onStartTimer,
  });

  final HabitEntity habit;
  final bool isCompletedToday;
  final List<dynamic> last30Logs;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final ThemeData theme;

  /// Non-null only for habit types that have a dedicated guided timer.
  final VoidCallback? onStartTimer;

  @override
  Widget build(BuildContext context) {
    final meta = _presetMeta[habit.habitType];
    final accentColor =
        meta?.color ?? theme.colorScheme.primary;
    final icon = meta?.icon ?? Icons.check_circle_outline;
    final label = habit.habitLabel ?? meta?.label ?? _labelFor(habit.habitType);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Row 1: icon, label, streak, toggle ──
            Row(
              children: [
                // Habit icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: accentColor, size: 24),
                ),
                const SizedBox(width: 12),

                // Label + streak
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      _StreakBadge(
                        currentStreak: habit.currentStreakDays,
                        accentColor: accentColor,
                        isAlive: habit.isStreakAlive,
                        theme: theme,
                      ),
                    ],
                  ),
                ),

                // Completion toggle
                GestureDetector(
                  onTap: onToggle,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isCompletedToday
                          ? accentColor
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: accentColor,
                        width: 2,
                      ),
                    ),
                    child: isCompletedToday
                        ? const Icon(Icons.check, color: Colors.white, size: 20)
                        : null,
                  ),
                ),

                // Delete menu
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert,
                    color: theme.colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, size: 18),
                          SizedBox(width: 8),
                          Text('Remove habit'),
                        ],
                      ),
                    ),
                  ],
                  onSelected: (value) {
                    if (value == 'delete') onDelete();
                  },
                ),
              ],
            ),

            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 14),

            // ── Row 2: 30-day dot grid ──
            _DotGrid(
              habitType: habit.habitType,
              logs: last30Logs,
              accentColor: accentColor,
              theme: theme,
            ),

            // ── Row 3: guided timer button (kegels only) ──
            if (onStartTimer != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onStartTimer,
                  icon: Icon(
                    Icons.timer_outlined,
                    size: 18,
                    color: accentColor,
                  ),
                  label: Text(
                    'Start guided timer',
                    style: TextStyle(color: accentColor),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: accentColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Streak badge
// ---------------------------------------------------------------------------

class _StreakBadge extends StatelessWidget {
  const _StreakBadge({
    required this.currentStreak,
    required this.accentColor,
    required this.isAlive,
    required this.theme,
  });

  final int currentStreak;
  final Color accentColor;
  final bool isAlive;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final streakColor = isAlive ? accentColor : theme.colorScheme.outline;

    return Row(
      children: [
        Icon(
          Icons.local_fire_department,
          size: 16,
          color: streakColor,
        ),
        const SizedBox(width: 4),
        Text(
          '$currentStreak day${currentStreak == 1 ? '' : 's'}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: streakColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (!isAlive && currentStreak > 0) ...[
          const SizedBox(width: 4),
          Text(
            '(streak ended)',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 30-day dot grid
// ---------------------------------------------------------------------------

class _DotGrid extends StatelessWidget {
  const _DotGrid({
    required this.habitType,
    required this.logs,
    required this.accentColor,
    required this.theme,
  });

  final String habitType;
  final List<dynamic> logs;
  final Color accentColor;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final today = _today();

    // Build a map of dateString -> completed for quick lookup.
    final Map<String, bool> completedMap = {};
    for (final log in logs) {
      if (log is! Object) continue;
      // Access via dynamic — log is HabitLogEntity but we avoid import here.
      try {
        final logDate = (log as dynamic).logDate as DateTime;
        final completed = (log as dynamic).completed as bool;
        final key =
            '${logDate.year}-${logDate.month.toString().padLeft(2, '0')}-${logDate.day.toString().padLeft(2, '0')}';
        completedMap[key] = completed;
      } catch (_) {
        // Skip malformed entries silently.
      }
    }

    // Generate the last 30 days starting from 29 days ago up to today.
    final days = List.generate(30, (i) {
      return today.subtract(Duration(days: 29 - i));
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Last 30 days',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 5,
          runSpacing: 5,
          children: days.map((day) {
            final key =
                '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
            final isToday = day == today;
            final isCompleted = completedMap[key] ?? false;

            Color dotColor;
            if (isCompleted) {
              dotColor = accentColor;
            } else {
              dotColor = theme.colorScheme.surfaceContainerHighest;
            }

            return Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
                border: isToday
                    ? Border.all(
                        color: accentColor,
                        width: 1.5,
                      )
                    : null,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }
}

// ---------------------------------------------------------------------------
// Add habit bottom sheet
// ---------------------------------------------------------------------------

class _AddHabitSheet extends StatefulWidget {
  const _AddHabitSheet({
    required this.profileId,
    required this.onAdd,
  });

  final String profileId;
  final void Function(String label) onAdd;

  @override
  State<_AddHabitSheet> createState() => _AddHabitSheetState();
}

class _AddHabitSheetState extends State<_AddHabitSheet> {
  final TextEditingController _controller = TextEditingController();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final hasText = _controller.text.trim().isNotEmpty;
      if (hasText != _hasText) setState(() => _hasText = hasText);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_hasText) return;
    widget.onAdd(_controller.text.trim());
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            Text(
              'New habit',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Give your habit a clear, action-focused name.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),

            TextField(
              controller: _controller,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'e.g. Cold shower, Meditation...',
                prefixIcon: const Icon(Icons.track_changes),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _hasText ? _submit : null,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Add habit',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty & error states
// ---------------------------------------------------------------------------

class _EmptyBody extends StatelessWidget {
  const _EmptyBody({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.local_fire_department_outlined,
              size: 64,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'No habits yet',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start tracking daily habits to build streaks '
              'and earn milestone rewards.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Add your first habit'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load habits',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Utility
// ---------------------------------------------------------------------------

/// Fallback human-readable label for unknown / custom habit types.
String _labelFor(String habitType) {
  return habitType
      .replaceAll('_', ' ')
      .split(' ')
      .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}
