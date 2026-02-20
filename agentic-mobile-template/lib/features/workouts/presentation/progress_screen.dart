// lib/features/workouts/presentation/progress_screen.dart
//
// Workout Progress Screen — 3-tab analytics view:
//   Volume   : Stacked weekly muscle volume bar chart (last 8 weeks)
//   Strength : Per-exercise estimated 1RM line chart (last 12 weeks)
//   Records  : Sortable list of all-time personal records

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../shared/core/router/app_router.dart';
import '../domain/exercise_entity.dart';
import '../domain/exercise_record_entity.dart';
import 'exercise_browser_provider.dart';
import 'progress_provider.dart';

// ---------------------------------------------------------------------------
// Muscle-group colour palette — 10 distinct colours for chart stacks
// ---------------------------------------------------------------------------

const _muscleColors = <String, Color>{
  'chest': Color(0xFF1A73E8),
  'back': Color(0xFF00BFA5),
  'shoulders': Color(0xFFFF7043),
  'biceps': Color(0xFF9C27B0),
  'triceps': Color(0xFFE91E63),
  'forearms': Color(0xFF795548),
  'core': Color(0xFFFFCA28),
  'quads': Color(0xFF4CAF50),
  'hamstrings': Color(0xFF03A9F4),
  'glutes': Color(0xFFFF5722),
  'calves': Color(0xFF607D8B),
  'legs': Color(0xFF8BC34A),
};

Color _colorForMuscle(String muscle) {
  final key = muscle.toLowerCase();
  for (final entry in _muscleColors.entries) {
    if (key.contains(entry.key)) return entry.value;
  }
  // Deterministic fallback colour from hash
  final hue = (muscle.hashCode.abs() % 360).toDouble();
  return HSLColor.fromAHSL(1, hue, 0.6, 0.5).toColor();
}

// ---------------------------------------------------------------------------
// Root screen widget
// ---------------------------------------------------------------------------

class ProgressScreen extends ConsumerStatefulWidget {
  const ProgressScreen({super.key});

  @override
  ConsumerState<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends ConsumerState<ProgressScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Trigger initial data loads after the frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final profileId = ref.read(activeProfileIdProvider) ?? '';
      if (profileId.isNotEmpty) {
        ref
            .read(exerciseBrowserProvider(profileId).notifier)
            .load();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Progress'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Volume'),
            Tab(text: 'Strength'),
            Tab(text: 'Records'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _VolumeTab(),
          _StrengthTab(),
          _RecordsTab(),
        ],
      ),
    );
  }
}

// ===========================================================================
// TAB 1: Volume
// ===========================================================================

class _VolumeTab extends ConsumerWidget {
  const _VolumeTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileId = ref.watch(activeProfileIdProvider) ?? '';
    if (profileId.isEmpty) {
      return const _EmptyState(message: 'No profile found.');
    }

    // Last 8 week-start Mondays, oldest first for chart L→R ordering.
    final weekStarts = lastNWeekStarts(8).reversed.toList();

    // Watch all 8 weekly volume async values.
    final asyncVolumes = weekStarts
        .map(
          (ws) => ref.watch(
            weeklyMuscleVolumeProvider((profileId: profileId, weekStart: ws)),
          ),
        )
        .toList();

    final isLoading = asyncVolumes.any((a) => a.isLoading);
    final hasError = asyncVolumes.any((a) => a.hasError);

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (hasError) {
      return _ErrorState(
        message: 'Failed to load volume data.',
        onRetry: () {
          for (final ws in weekStarts) {
            ref.invalidate(
              weeklyMuscleVolumeProvider(
                  (profileId: profileId, weekStart: ws)),
            );
          }
        },
      );
    }

    final weeklyData =
        asyncVolumes.map((a) => a.valueOrNull ?? <String, double>{}).toList();

    // Build sorted set of all muscle groups across all weeks.
    final allMuscles = <String>{};
    for (final map in weeklyData) {
      allMuscles.addAll(map.keys);
    }
    final sortedMuscles = allMuscles.toList()..sort();

    final hasData = weeklyData.any((m) => m.isNotEmpty);
    if (!hasData) {
      return const _EmptyState(
        message: 'Complete workouts to see volume trends.',
        icon: Icons.bar_chart_outlined,
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Weekly Volume by Muscle Group',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(
            'Last 8 weeks — total kg lifted',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
                ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 300,
            child: _VolumeBarChart(
              weekStarts: weekStarts,
              weeklyData: weeklyData,
              muscles: sortedMuscles,
            ),
          ),
          const SizedBox(height: 24),
          _MuscleLegend(muscles: sortedMuscles),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Volume stacked bar chart
// ---------------------------------------------------------------------------

class _VolumeBarChart extends StatelessWidget {
  const _VolumeBarChart({
    required this.weekStarts,
    required this.weeklyData,
    required this.muscles,
  });

  final List<DateTime> weekStarts;
  final List<Map<String, double>> weeklyData;
  final List<String> muscles;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    double maxY = 0;
    final groups = <BarChartGroupData>[];

    for (int wi = 0; wi < weekStarts.length; wi++) {
      final volumeMap = weeklyData[wi];
      double weekTotal = 0;
      double fromY = 0;
      final rods = <BarChartRodStackItem>[];

      for (final muscle in muscles) {
        final vol = volumeMap[muscle] ?? 0;
        if (vol > 0) {
          rods.add(
            BarChartRodStackItem(fromY, fromY + vol, _colorForMuscle(muscle)),
          );
          fromY += vol;
          weekTotal += vol;
        }
      }

      if (weekTotal > maxY) maxY = weekTotal;

      groups.add(
        BarChartGroupData(
          x: wi,
          barRods: [
            BarChartRodData(
              toY: weekTotal,
              width: 22,
              rodStackItems: rods,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(4),
              ),
              backDrawRodData: BackgroundBarChartRodData(
                show: true,
                toY: 0,
                color: Colors.transparent,
              ),
            ),
          ],
        ),
      );
    }

    // Give 10% head-room above the tallest bar.
    final chartMaxY = maxY == 0 ? 100.0 : maxY * 1.1;

    return BarChart(
      BarChartData(
        maxY: chartMaxY,
        barGroups: groups,
        alignment: BarChartAlignment.spaceAround,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: chartMaxY / 5,
          getDrawingHorizontalLine: (value) => FlLine(
            color: cs.outlineVariant.withValues(alpha: 0.4),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 48,
              interval: chartMaxY / 5,
              getTitlesWidget: (value, meta) {
                if (value == 0) return const SizedBox.shrink();
                return Text(
                  '${value.round()}',
                  style: TextStyle(
                    fontSize: 10,
                    color: cs.onSurface.withValues(alpha: 0.6),
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= weekStarts.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'W${idx + 1}',
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) =>
                cs.surfaceContainerHighest.withValues(alpha: 0.95),
            tooltipRoundedRadius: 8,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final ws = weekStarts[group.x];
              final label = DateFormat('d MMM').format(ws);
              final total = rod.toY.toStringAsFixed(0);
              return BarTooltipItem(
                '$label\n${total}kg total',
                TextStyle(
                  color: cs.onSurface,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Colour legend for muscle groups
// ---------------------------------------------------------------------------

class _MuscleLegend extends StatelessWidget {
  const _MuscleLegend({required this.muscles});

  final List<String> muscles;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: muscles.map((m) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: _colorForMuscle(m),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              _capitalize(m),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        );
      }).toList(),
    );
  }
}

// ===========================================================================
// TAB 2: Strength
// ===========================================================================

class _StrengthTab extends ConsumerStatefulWidget {
  const _StrengthTab();

  @override
  ConsumerState<_StrengthTab> createState() => _StrengthTabState();
}

class _StrengthTabState extends ConsumerState<_StrengthTab> {
  ExerciseEntity? _selectedExercise;

  @override
  Widget build(BuildContext context) {
    final profileId = ref.watch(activeProfileIdProvider) ?? '';
    if (profileId.isEmpty) {
      return const _EmptyState(message: 'No profile found.');
    }

    final browserState = ref.watch(exerciseBrowserProvider(profileId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Exercise selector ──────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: browserState.isLoading
              ? const LinearProgressIndicator()
              : _ExerciseDropdown(
                  exercises: browserState.allExercises,
                  selected: _selectedExercise,
                  onChanged: (ex) => setState(() => _selectedExercise = ex),
                ),
        ),

        const SizedBox(height: 12),

        // ── Chart area ────────────────────────────────────────────────
        Expanded(
          child: _selectedExercise == null
              ? const _EmptyState(
                  message: 'Select an exercise to view strength history.',
                  icon: Icons.show_chart_outlined,
                )
              : _StrengthChartView(
                  profileId: profileId,
                  exercise: _selectedExercise!,
                ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Exercise dropdown
// ---------------------------------------------------------------------------

class _ExerciseDropdown extends StatelessWidget {
  const _ExerciseDropdown({
    required this.exercises,
    required this.selected,
    required this.onChanged,
  });

  final List<ExerciseEntity> exercises;
  final ExerciseEntity? selected;
  final ValueChanged<ExerciseEntity?> onChanged;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: 'Exercise',
        border: const OutlineInputBorder(),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<ExerciseEntity>(
          value: selected,
          isExpanded: true,
          hint: const Text('Select an exercise'),
          onChanged: onChanged,
          items: exercises.map((ex) {
            return DropdownMenuItem<ExerciseEntity>(
              value: ex,
              child: Text(
                ex.name,
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Strength chart view — fetches 1RM history for the selected exercise
// ---------------------------------------------------------------------------

class _StrengthChartView extends ConsumerWidget {
  const _StrengthChartView({
    required this.profileId,
    required this.exercise,
  });

  final String profileId;
  final ExerciseEntity exercise;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final params = (
      profileId: profileId,
      exerciseId: exercise.id,
      weeks: 12,
    );
    final async1rm = ref.watch(exercise1rmHistoryProvider(params));

    return async1rm.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorState(
        message: 'Failed to load strength data.',
        onRetry: () => ref.invalidate(exercise1rmHistoryProvider(params)),
      ),
      data: (history) {
        if (history.isEmpty) {
          return _EmptyState(
            message: 'No data yet for ${exercise.name}.\nComplete sets to build a strength history.',
            icon: Icons.show_chart_outlined,
          );
        }

        final maxVal =
            history.map((h) => h.estimated1rm).reduce((a, b) => a > b ? a : b);

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Badge — current max 1RM
              _Max1rmBadge(
                exerciseName: exercise.name,
                max1rm: maxVal,
              ),
              const SizedBox(height: 16),
              Text(
                'Estimated 1RM — Last 12 Weeks',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 280,
                child: _StrengthLineChart(history: history),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Max 1RM badge card
// ---------------------------------------------------------------------------

class _Max1rmBadge extends StatelessWidget {
  const _Max1rmBadge({required this.exerciseName, required this.max1rm});

  final String exerciseName;
  final double max1rm;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      color: cs.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(Icons.emoji_events_outlined,
                color: cs.onPrimaryContainer, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current Max 1RM',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: cs.onPrimaryContainer
                              .withValues(alpha: 0.75),
                        ),
                  ),
                  Text(
                    '${max1rm.toStringAsFixed(1)} kg',
                    style:
                        Theme.of(context).textTheme.headlineMedium?.copyWith(
                              color: cs.onPrimaryContainer,
                              fontWeight: FontWeight.w700,
                            ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 1RM line chart using fl_chart
// ---------------------------------------------------------------------------

class _StrengthLineChart extends StatelessWidget {
  const _StrengthLineChart({required this.history});

  final List<({DateTime date, double estimated1rm})> history;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Convert history to FlSpots. X = day offset from earliest date.
    final earliest = history.first.date;
    final spots = history.map((h) {
      final dayOffset =
          h.date.difference(earliest).inDays.toDouble();
      return FlSpot(dayOffset, h.estimated1rm);
    }).toList();

    final minY =
        history.map((h) => h.estimated1rm).reduce((a, b) => a < b ? a : b);
    final maxY =
        history.map((h) => h.estimated1rm).reduce((a, b) => a > b ? a : b);
    final yPadding = ((maxY - minY) * 0.15).clamp(5.0, double.infinity);
    final chartMinY = (minY - yPadding).clamp(0.0, double.infinity);
    final chartMaxY = maxY + yPadding;

    return LineChart(
      LineChartData(
        minY: chartMinY,
        maxY: chartMaxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: (chartMaxY - chartMinY) / 4,
          getDrawingHorizontalLine: (value) => FlLine(
            color: cs.outlineVariant.withValues(alpha: 0.4),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 52,
              interval: (chartMaxY - chartMinY) / 4,
              getTitlesWidget: (value, meta) => Text(
                '${value.round()} kg',
                style: TextStyle(
                  fontSize: 10,
                  color: cs.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval:
                  spots.last.x / 4 < 1 ? 1 : spots.last.x / 4,
              getTitlesWidget: (value, meta) {
                final date = earliest
                    .add(Duration(days: value.toInt()));
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    DateFormat('d MMM').format(date),
                    style: TextStyle(
                      fontSize: 9,
                      color: cs.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.3,
            color: cs.primary,
            barWidth: 2.5,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, bar, index) =>
                  FlDotCirclePainter(
                radius: 4,
                color: cs.primary,
                strokeWidth: 2,
                strokeColor: cs.surface,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: cs.primary.withValues(alpha: 0.08),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) =>
                cs.surfaceContainerHighest.withValues(alpha: 0.95),
            tooltipRoundedRadius: 8,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final date = earliest
                    .add(Duration(days: spot.x.toInt()));
                return LineTooltipItem(
                  '${DateFormat('d MMM').format(date)}\n'
                  '${spot.y.toStringAsFixed(1)} kg',
                  TextStyle(
                    color: cs.onSurface,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// TAB 3: Records
// ===========================================================================

enum _RecordSort { byDate, byName }

class _RecordsTab extends ConsumerStatefulWidget {
  const _RecordsTab();

  @override
  ConsumerState<_RecordsTab> createState() => _RecordsTabState();
}

class _RecordsTabState extends ConsumerState<_RecordsTab> {
  _RecordSort _sort = _RecordSort.byDate;

  @override
  Widget build(BuildContext context) {
    final profileId = ref.watch(activeProfileIdProvider) ?? '';
    if (profileId.isEmpty) {
      return const _EmptyState(message: 'No profile found.');
    }

    final asyncRecords = ref.watch(exerciseRecordsProvider(profileId));
    final asyncExercises = ref.watch(allExercisesProvider(profileId));

    // Build exercise name lookup map.
    final exerciseNames = asyncExercises.valueOrNull
            ?.fold<Map<String, String>>(
              {},
              (map, ex) => map..putIfAbsent(ex.id, () => ex.name),
            ) ??
        {};

    return asyncRecords.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorState(
        message: 'Failed to load personal records.',
        onRetry: () => ref.invalidate(exerciseRecordsProvider(profileId)),
      ),
      data: (records) {
        if (records.isEmpty) {
          return const _EmptyState(
            message:
                'No personal records yet.\nLog workouts and beat your best to see records here.',
            icon: Icons.emoji_events_outlined,
          );
        }

        // Apply sort.
        final sorted = [...records];
        if (_sort == _RecordSort.byDate) {
          sorted.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        } else {
          sorted.sort((a, b) {
            final nameA = exerciseNames[a.exerciseId] ?? a.exerciseId;
            final nameB = exerciseNames[b.exerciseId] ?? b.exerciseId;
            return nameA.compareTo(nameB);
          });
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Sort chips
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Wrap(
                spacing: 8,
                children: [
                  FilterChip(
                    label: const Text('By Date'),
                    selected: _sort == _RecordSort.byDate,
                    onSelected: (_) =>
                        setState(() => _sort = _RecordSort.byDate),
                  ),
                  FilterChip(
                    label: const Text('By Name'),
                    selected: _sort == _RecordSort.byName,
                    onSelected: (_) =>
                        setState(() => _sort = _RecordSort.byName),
                  ),
                ],
              ),
            ),

            // Record list
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async =>
                    ref.invalidate(exerciseRecordsProvider(profileId)),
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: sorted.length,
                  itemBuilder: (context, index) {
                    final record = sorted[index];
                    final name =
                        exerciseNames[record.exerciseId] ?? 'Unknown exercise';
                    return _RecordCard(record: record, exerciseName: name);
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Individual PR card
// ---------------------------------------------------------------------------

class _RecordCard extends StatelessWidget {
  const _RecordCard({
    required this.record,
    required this.exerciseName,
  });

  final ExerciseRecordEntity record;
  final String exerciseName;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    exerciseName,
                    style: tt.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  'Updated ${_shortDate(record.updatedAt)}',
                  style: tt.labelSmall?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                if (record.maxWeightKg != null)
                  _PRStat(
                    label: 'Max Weight',
                    value: '${record.maxWeightKg!.toStringAsFixed(1)} kg',
                    icon: Icons.fitness_center,
                    date: record.maxWeightDate,
                  ),
                if (record.maxReps != null)
                  _PRStat(
                    label: 'Max Reps',
                    value: '${record.maxReps}',
                    icon: Icons.repeat,
                    date: record.maxRepsDate,
                  ),
                if (record.maxEstimated1rm != null)
                  _PRStat(
                    label: 'Est. 1RM',
                    value: '${record.maxEstimated1rm!.toStringAsFixed(1)} kg',
                    icon: Icons.emoji_events_outlined,
                    color: cs.primary,
                    date: record.max1rmDate,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _shortDate(DateTime dt) => DateFormat('d MMM yyyy').format(dt);
}

class _PRStat extends StatelessWidget {
  const _PRStat({
    required this.label,
    required this.value,
    required this.icon,
    this.color,
    this.date,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? color;
  final DateTime? date;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final effective = color ?? cs.onSurface;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: effective.withValues(alpha: 0.7)),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.55),
                  ),
            ),
            Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: effective,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            if (date != null)
              Text(
                DateFormat('d MMM').format(date!),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.4),
                    ),
              ),
          ],
        ),
      ],
    );
  }
}

// ===========================================================================
// Shared utility widgets
// ===========================================================================

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message, this.icon});

  final String message;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon ?? Icons.bar_chart_outlined,
              size: 64,
              color: cs.onSurface.withValues(alpha: 0.25),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.55),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: cs.error),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// String helpers
// ---------------------------------------------------------------------------

String _capitalize(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
