// lib/features/workouts/presentation/body_map_screen.dart
//
// Body Map Screen — visual representation of weekly muscle training volume.
//
// Layout uses a structured grid of tapable muscle-group cards arranged to
// roughly mirror the shape of the human body (no SVG required).
// Each card is colour-coded by set count:
//   Green  (>= 10 sets) — well-trained
//   Amber  (1–9 sets)   — lightly trained
//   Grey   (0 sets)     — not hit this week
//
// Tapping a card opens a bottom sheet with full week details for that muscle.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../shared/core/router/app_router.dart';
import 'progress_provider.dart';

// ---------------------------------------------------------------------------
// Muscle group model
// ---------------------------------------------------------------------------

class _MuscleGroup {
  const _MuscleGroup({
    required this.name,
    required this.dbKey,
    required this.icon,
  });

  /// Display label shown on card and bottom sheet.
  final String name;

  /// Key used to look up volume/set data (must match wt_exercises.muscle_groups values).
  final String dbKey;

  /// Icon representing this muscle group.
  final IconData icon;
}

// All muscle groups in display order — arranged top-to-bottom like a body.
const _allMuscles = <_MuscleGroup>[
  _MuscleGroup(name: 'Shoulders', dbKey: 'shoulders', icon: Icons.airline_seat_flat),
  _MuscleGroup(name: 'Chest', dbKey: 'chest', icon: Icons.favorite_outline),
  _MuscleGroup(name: 'Back', dbKey: 'back', icon: Icons.swap_horiz),
  _MuscleGroup(name: 'Biceps', dbKey: 'biceps', icon: Icons.fitness_center),
  _MuscleGroup(name: 'Triceps', dbKey: 'triceps', icon: Icons.fitness_center),
  _MuscleGroup(name: 'Core', dbKey: 'core', icon: Icons.circle_outlined),
  _MuscleGroup(name: 'Quads', dbKey: 'quadriceps', icon: Icons.directions_walk),
  _MuscleGroup(name: 'Hamstrings', dbKey: 'hamstrings', icon: Icons.directions_walk),
  _MuscleGroup(name: 'Calves', dbKey: 'calves', icon: Icons.directions_walk),
  _MuscleGroup(name: 'Glutes', dbKey: 'glutes', icon: Icons.airline_seat_recline_normal),
];

// Grid layout — each row is a list of muscle indices into [_allMuscles].
// Row structure mirrors a rough body silhouette:
//   [Shoulders]
//   [Chest]  [Back]
//   [Biceps] [Triceps]
//   [Core]
//   [Quads]  [Hamstrings]
//   [Calves] [Glutes]
const _bodyGrid = <List<int>>[
  [0],          // Shoulders — full width
  [1, 2],       // Chest | Back
  [3, 4],       // Biceps | Triceps
  [5],          // Core — full width
  [6, 7],       // Quads | Hamstrings
  [8, 9],       // Calves | Glutes
];

// ---------------------------------------------------------------------------
// Training status helpers
// ---------------------------------------------------------------------------

enum _TrainingStatus { wellTrained, lightlyTrained, notHit }

_TrainingStatus _statusForSets(int sets) {
  if (sets >= 10) return _TrainingStatus.wellTrained;
  if (sets >= 1) return _TrainingStatus.lightlyTrained;
  return _TrainingStatus.notHit;
}

Color _colorForStatus(_TrainingStatus status, ColorScheme cs) {
  switch (status) {
    case _TrainingStatus.wellTrained:
      return const Color(0xFF4CAF50); // green
    case _TrainingStatus.lightlyTrained:
      return const Color(0xFFFFB300); // amber
    case _TrainingStatus.notHit:
      return cs.surfaceContainerHighest;
  }
}

Color _foregroundForStatus(_TrainingStatus status, ColorScheme cs) {
  switch (status) {
    case _TrainingStatus.wellTrained:
      return Colors.white;
    case _TrainingStatus.lightlyTrained:
      return Colors.black87;
    case _TrainingStatus.notHit:
      return cs.onSurface.withValues(alpha: 0.45);
  }
}

// ===========================================================================
// BodyMapScreen
// ===========================================================================

class BodyMapScreen extends ConsumerStatefulWidget {
  const BodyMapScreen({super.key});

  @override
  ConsumerState<BodyMapScreen> createState() => _BodyMapScreenState();
}

class _BodyMapScreenState extends ConsumerState<BodyMapScreen> {
  /// Week offset: 0 = current week, -1 = last week, etc.
  int _weekOffset = 0;

  DateTime get _selectedWeekStart {
    final thisMonday = mondayOf(DateTime.now());
    return thisMonday.add(Duration(days: _weekOffset * 7));
  }

  String get _weekLabel {
    if (_weekOffset == 0) return 'This Week';
    if (_weekOffset == -1) return 'Last Week';
    return DateFormat('d MMM').format(_selectedWeekStart);
  }

  void _goBackWeek() => setState(() => _weekOffset--);

  void _goForwardWeek() {
    if (_weekOffset < 0) setState(() => _weekOffset++);
  }

  @override
  Widget build(BuildContext context) {
    final profileId = ref.watch(activeProfileIdProvider) ?? '';
    final weekStart = _selectedWeekStart;

    final asyncSets = profileId.isEmpty
        ? null
        : ref.watch(
            weeklyMuscleSetsProvider(
              (profileId: profileId, weekStart: weekStart),
            ),
          );
    final asyncVolume = profileId.isEmpty
        ? null
        : ref.watch(
            weeklyMuscleVolumeProvider(
              (profileId: profileId, weekStart: weekStart),
            ),
          );

    final isLoading = asyncSets?.isLoading == true || asyncVolume?.isLoading == true;
    final hasError = asyncSets?.hasError == true || asyncVolume?.hasError == true;

    final setsMap = asyncSets?.valueOrNull ?? <String, int>{};
    final volumeMap = asyncVolume?.valueOrNull ?? <String, double>{};

    return Scaffold(
      appBar: AppBar(
        title: const Text('Body Map'),
        actions: [
          // Week selector — left arrow
          IconButton(
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Previous week',
            onPressed: _goBackWeek,
          ),
          // Week label — centred between arrows
          GestureDetector(
            onTap: () => setState(() => _weekOffset = 0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              constraints: const BoxConstraints(minWidth: 88),
              child: Text(
                _weekLabel,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
          ),
          // Right arrow — disabled when viewing current week
          IconButton(
            icon: Icon(
              Icons.chevron_right,
              color: _weekOffset == 0
                  ? Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.3)
                  : null,
            ),
            tooltip: _weekOffset == 0 ? null : 'Next week',
            onPressed: _weekOffset == 0 ? null : _goForwardWeek,
          ),
        ],
      ),
      body: profileId.isEmpty
          ? const _CenteredMessage(
              icon: Icons.account_circle_outlined,
              message: 'No profile found.',
            )
          : hasError
              ? _CenteredMessage(
                  icon: Icons.error_outline,
                  message: 'Failed to load data.',
                  action: TextButton(
                    onPressed: () {
                      ref.invalidate(
                        weeklyMuscleSetsProvider(
                          (profileId: profileId, weekStart: weekStart),
                        ),
                      );
                      ref.invalidate(
                        weeklyMuscleVolumeProvider(
                          (profileId: profileId, weekStart: weekStart),
                        ),
                      );
                    },
                    child: const Text('Retry'),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Date range subtitle
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: _WeekSubtitle(weekStart: weekStart),
                    ),

                    // Loading overlay or body grid
                    Expanded(
                      child: isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : _BodyGrid(
                              setsMap: setsMap,
                              volumeMap: volumeMap,
                              onMuscleTap: (muscle) => _showMuscleSheet(
                                context,
                                muscle: muscle,
                                sets: setsMap[muscle.dbKey] ?? 0,
                                volume: volumeMap[muscle.dbKey] ?? 0,
                                weekStart: weekStart,
                                setsMap: setsMap,
                                volumeMap: volumeMap,
                              ),
                            ),
                    ),

                    // Legend
                    const _StatusLegend(),
                    const SizedBox(height: 12),
                  ],
                ),
    );
  }

  // ---------------------------------------------------------------------------
  // Bottom sheet — muscle detail
  // ---------------------------------------------------------------------------

  void _showMuscleSheet(
    BuildContext context, {
    required _MuscleGroup muscle,
    required int sets,
    required double volume,
    required DateTime weekStart,
    required Map<String, int> setsMap,
    required Map<String, double> volumeMap,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _MuscleDetailSheet(
        muscle: muscle,
        sets: sets,
        volume: volume,
        weekStart: weekStart,
        setsMap: setsMap,
        volumeMap: volumeMap,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Week subtitle
// ---------------------------------------------------------------------------

class _WeekSubtitle extends StatelessWidget {
  const _WeekSubtitle({required this.weekStart});

  final DateTime weekStart;

  @override
  Widget build(BuildContext context) {
    final weekEnd = weekStart.add(const Duration(days: 6));
    final label =
        '${DateFormat('d MMM').format(weekStart)} – ${DateFormat('d MMM').format(weekEnd)}';
    return Text(
      label,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.55),
          ),
    );
  }
}

// ===========================================================================
// Body grid
// ===========================================================================

class _BodyGrid extends StatelessWidget {
  const _BodyGrid({
    required this.setsMap,
    required this.volumeMap,
    required this.onMuscleTap,
  });

  final Map<String, int> setsMap;
  final Map<String, double> volumeMap;
  final void Function(_MuscleGroup) onMuscleTap;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: _bodyGrid.map((row) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _GridRow(
              muscleIndices: row,
              setsMap: setsMap,
              volumeMap: volumeMap,
              onMuscleTap: onMuscleTap,
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _GridRow extends StatelessWidget {
  const _GridRow({
    required this.muscleIndices,
    required this.setsMap,
    required this.volumeMap,
    required this.onMuscleTap,
  });

  final List<int> muscleIndices;
  final Map<String, int> setsMap;
  final Map<String, double> volumeMap;
  final void Function(_MuscleGroup) onMuscleTap;

  @override
  Widget build(BuildContext context) {
    final isSingle = muscleIndices.length == 1;

    return Row(
      children: muscleIndices.map((idx) {
        final muscle = _allMuscles[idx];
        final sets = setsMap[muscle.dbKey] ?? 0;

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              left: muscleIndices.first != idx ? 4 : 0,
              right: muscleIndices.last != idx ? 4 : 0,
            ),
            child: _MuscleCard(
              muscle: muscle,
              sets: sets,
              isSingle: isSingle,
              onTap: () => onMuscleTap(muscle),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ---------------------------------------------------------------------------
// Individual muscle card
// ---------------------------------------------------------------------------

class _MuscleCard extends StatelessWidget {
  const _MuscleCard({
    required this.muscle,
    required this.sets,
    required this.isSingle,
    required this.onTap,
  });

  final _MuscleGroup muscle;
  final int sets;
  final bool isSingle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final status = _statusForSets(sets);
    final bg = _colorForStatus(status, cs);
    final fg = _foregroundForStatus(status, cs);

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 12,
            vertical: isSingle ? 12 : 16,
          ),
          child: Row(
            mainAxisAlignment: isSingle
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            children: [
              Icon(muscle.icon, size: 18, color: fg),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  muscle.name,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: fg,
                        fontWeight: FontWeight.w600,
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Set count badge
              if (sets > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$sets',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: fg,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// Status legend
// ===========================================================================

class _StatusLegend extends StatelessWidget {
  const _StatusLegend();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _LegendItem(
            color: const Color(0xFF4CAF50),
            label: '>= 10 sets',
          ),
          const SizedBox(width: 16),
          _LegendItem(
            color: const Color(0xFFFFB300),
            label: '1–9 sets',
          ),
          const SizedBox(width: 16),
          _LegendItem(
            color: cs.surfaceContainerHighest,
            label: 'Not trained',
            textColor: cs.onSurface.withValues(alpha: 0.55),
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label, this.textColor});

  final Color color;
  final String label;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(
              color: cs.outlineVariant.withValues(alpha: 0.5),
              width: 0.5,
            ),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: textColor ?? cs.onSurface.withValues(alpha: 0.7),
              ),
        ),
      ],
    );
  }
}

// ===========================================================================
// Muscle detail bottom sheet
// ===========================================================================

class _MuscleDetailSheet extends StatelessWidget {
  const _MuscleDetailSheet({
    required this.muscle,
    required this.sets,
    required this.volume,
    required this.weekStart,
    required this.setsMap,
    required this.volumeMap,
  });

  final _MuscleGroup muscle;
  final int sets;
  final double volume;
  final DateTime weekStart;
  final Map<String, int> setsMap;
  final Map<String, double> volumeMap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final status = _statusForSets(sets);
    final statusColor = _colorForStatus(status, cs);
    final weekEnd = weekStart.add(const Duration(days: 6));
    final weekLabel =
        '${DateFormat('d MMM').format(weekStart)} – ${DateFormat('d MMM').format(weekEnd)}';

    // Build a list of all muscles that have non-zero data this week as
    // "contributing exercises" — the repository returns data keyed by muscle
    // group, not by individual exercise. Surface the related muscle-group
    // contribution context so the user can understand what contributed.
    final relatedMuscles = _allMuscles.where((m) {
      final s = setsMap[m.dbKey] ?? 0;
      return s > 0 && m.dbKey != muscle.dbKey;
    }).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.85,
      expand: false,
      builder: (ctx, scrollController) {
        return ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(muscle.icon, color: statusColor, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        muscle.name,
                        style:
                            Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                      Text(
                        weekLabel,
                        style:
                            Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: cs.onSurface.withValues(alpha: 0.55),
                                ),
                      ),
                    ],
                  ),
                ),
                // Status chip
                Chip(
                  label: Text(
                    _statusLabel(status),
                    style: TextStyle(
                      fontSize: 11,
                      color: _foregroundForStatus(status, cs),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  backgroundColor: statusColor,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Stats row
            Row(
              children: [
                Expanded(
                  child: _StatTile(
                    label: 'Total Sets',
                    value: sets > 0 ? '$sets sets' : '0 sets',
                    icon: Icons.repeat,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatTile(
                    label: 'Total Volume',
                    value: volume > 0
                        ? '${volume.toStringAsFixed(0)} kg'
                        : '0 kg',
                    icon: Icons.fitness_center,
                  ),
                ),
              ],
            ),

            if (sets == 0) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: cs.onSurface.withValues(alpha: 0.55),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${muscle.name} was not trained this week.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: cs.onSurface.withValues(alpha: 0.65),
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Other muscles trained this week (context)
            if (relatedMuscles.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                'Other muscles trained this week',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 10),
              ...relatedMuscles.map((m) {
                final mSets = setsMap[m.dbKey] ?? 0;
                final mVol = volumeMap[m.dbKey] ?? 0;
                final mStatus = _statusForSets(mSets);
                final mColor = _colorForStatus(mStatus, cs);
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 8,
                    height: 36,
                    decoration: BoxDecoration(
                      color: mColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  title: Text(m.name,
                      style: Theme.of(context).textTheme.bodyMedium),
                  trailing: Text(
                    '$mSets sets · ${mVol.toStringAsFixed(0)} kg',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.65),
                        ),
                  ),
                );
              }),
            ],
          ],
        );
      },
    );
  }

  String _statusLabel(_TrainingStatus status) {
    switch (status) {
      case _TrainingStatus.wellTrained:
        return 'Well Trained';
      case _TrainingStatus.lightlyTrained:
        return 'Light';
      case _TrainingStatus.notHit:
        return 'Not Trained';
    }
  }
}

// ---------------------------------------------------------------------------
// Stat tile used inside the bottom sheet
// ---------------------------------------------------------------------------

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: cs.onSurface.withValues(alpha: 0.55)),
              const SizedBox(width: 4),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.55),
                    ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Utility widget — centred icon + message (empty/error states)
// ===========================================================================

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({
    required this.icon,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: cs.onSurface.withValues(alpha: 0.25)),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.55),
                  ),
            ),
            if (action != null) ...[
              const SizedBox(height: 16),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
