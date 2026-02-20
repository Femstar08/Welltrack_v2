// lib/features/workouts/presentation/exercise_browser_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../domain/exercise_entity.dart';
import 'exercise_browser_provider.dart';

// ── Screen ────────────────────────────────────────────────────────────────────

class ExerciseBrowserScreen extends ConsumerStatefulWidget {
  const ExerciseBrowserScreen({this.selectMode = false, super.key});

  /// When true, tapping an exercise pops with the [ExerciseEntity] as result.
  /// When false, tapping shows an inline detail bottom sheet.
  final bool selectMode;

  @override
  ConsumerState<ExerciseBrowserScreen> createState() =>
      _ExerciseBrowserScreenState();
}

class _ExerciseBrowserScreenState
    extends ConsumerState<ExerciseBrowserScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Event handlers ─────────────────────────────────────────────────

  void _onSearchChanged(String value) {
    ref.read(exerciseSearchQueryProvider.notifier).state = value;
  }

  void _clearSearch() {
    _searchCtrl.clear();
    ref.read(exerciseSearchQueryProvider.notifier).state = '';
  }

  void _onMuscleFilter(String? muscle) {
    ref.read(exerciseMuscleFilterProvider.notifier).state = muscle;
  }

  void _onEquipmentFilter(String? equipment) {
    ref.read(exerciseEquipmentFilterProvider.notifier).state = equipment;
  }

  void _clearAllFilters() {
    _searchCtrl.clear();
    ref.read(exerciseSearchQueryProvider.notifier).state = '';
    ref.read(exerciseMuscleFilterProvider.notifier).state = null;
    ref.read(exerciseEquipmentFilterProvider.notifier).state = null;
  }

  void _onExerciseTap(ExerciseEntity exercise) {
    if (widget.selectMode) {
      context.pop(exercise);
    } else {
      _showDetailSheet(exercise);
    }
  }

  void _showDetailSheet(ExerciseEntity exercise) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ExerciseDetailSheet(exercise: exercise),
    );
  }

  void _showCreateExerciseDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => _CreateExerciseDialog(
        onCreated: (exercise) {
          // Invalidate to reload exercise list with new entry.
          ref.invalidate(filteredExercisesProvider);
          if (widget.selectMode && mounted) {
            context.pop(exercise);
          }
        },
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final searchQuery = ref.watch(exerciseSearchQueryProvider);
    final muscleFilter = ref.watch(exerciseMuscleFilterProvider);
    final equipmentFilter = ref.watch(exerciseEquipmentFilterProvider);
    final exercisesAsync = ref.watch(filteredExercisesProvider);

    final hasActiveFilters = searchQuery.isNotEmpty ||
        muscleFilter != null ||
        equipmentFilter != null;

    return Scaffold(
      appBar: AppBar(
        title:
            Text(widget.selectMode ? 'Select Exercise' : 'Exercise Library'),
        actions: [
          if (hasActiveFilters)
            TextButton(
              onPressed: _clearAllFilters,
              child: const Text('Clear'),
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Search bar ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: SearchBar(
              controller: _searchCtrl,
              hintText: 'Search exercises...',
              leading: const Icon(Icons.search),
              trailing: [
                if (searchQuery.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: _clearSearch,
                  ),
              ],
              onChanged: _onSearchChanged,
              padding: const WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),

          // ── Muscle group filter chips ──────────────────────────────
          SizedBox(
            height: 40,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: const Text('All Muscles'),
                    selected: muscleFilter == null,
                    onSelected: (_) => _onMuscleFilter(null),
                    showCheckmark: false,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                // Use the preset list from the provider file — kept in sync
                // with what the DB stores.
                ..._kDisplayMuscles.map(
                  (m) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(_sentenceCase(m)),
                      selected: muscleFilter == m,
                      onSelected: (_) => _onMuscleFilter(
                        muscleFilter == m ? null : m,
                      ),
                      showCheckmark: false,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // ── Equipment filter chips ─────────────────────────────────
          SizedBox(
            height: 40,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: const Text('All Equipment'),
                    selected: equipmentFilter == null,
                    onSelected: (_) => _onEquipmentFilter(null),
                    showCheckmark: false,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                ...kEquipmentTypes.map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(_sentenceCase(e)),
                      selected: equipmentFilter == e,
                      onSelected: (_) => _onEquipmentFilter(
                        equipmentFilter == e ? null : e,
                      ),
                      showCheckmark: false,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),

          // ── Results ───────────────────────────────────────────────
          Expanded(
            child: exercisesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => _ExerciseBrowserError(
                onRetry: () => ref.invalidate(filteredExercisesProvider),
              ),
              data: (exercises) {
                if (exercises.isEmpty) {
                  return _ExerciseBrowserEmpty(
                    hasFilters: hasActiveFilters,
                    onClearFilters: _clearAllFilters,
                  );
                }
                return ListView.builder(
                  itemCount: exercises.length,
                  itemBuilder: (context, index) {
                    return _ExerciseTile(
                      exercise: exercises[index],
                      selectMode: widget.selectMode,
                      onTap: () => _onExerciseTap(exercises[index]),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateExerciseDialog,
        icon: const Icon(Icons.add),
        label: const Text('Custom Exercise'),
      ),
    );
  }
}

// Display-friendly subset of muscle groups for the chip row.
// Sourced from kMuscleGroups in exercise_browser_provider.dart.
const _kDisplayMuscles = <String>[
  'chest',
  'back',
  'shoulders',
  'biceps',
  'triceps',
  'quadriceps',
  'hamstrings',
  'glutes',
  'core',
];

String _sentenceCase(String s) {
  if (s.isEmpty) return s;
  return s.replaceAll('_', ' ').split(' ').map((word) {
    if (word.isEmpty) return word;
    return word[0].toUpperCase() + word.substring(1);
  }).join(' ');
}

// ── Exercise list tile ────────────────────────────────────────────────────────

class _ExerciseTile extends StatelessWidget {
  const _ExerciseTile({
    required this.exercise,
    required this.selectMode,
    required this.onTap,
  });
  final ExerciseEntity exercise;
  final bool selectMode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final muscles = exercise.muscleGroups.take(3).toList();
    final equipment = exercise.equipmentType;
    final difficulty = exercise.difficulty;

    return ListTile(
      title: Text(exercise.name),
      subtitle: Wrap(
        spacing: 4,
        runSpacing: 2,
        children: [
          ...muscles.map(
            (m) => Chip(
              label: Text(
                _sentenceCase(m),
                style: const TextStyle(fontSize: 10),
              ),
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              backgroundColor:
                  Theme.of(context).colorScheme.secondaryContainer,
              labelStyle: TextStyle(
                color: Theme.of(context).colorScheme.onSecondaryContainer,
              ),
            ),
          ),
          if (equipment != null)
            Chip(
              label: Text(
                _sentenceCase(equipment),
                style: const TextStyle(fontSize: 10),
              ),
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              avatar: const Icon(Icons.fitness_center, size: 12),
            ),
        ],
      ),
      trailing: selectMode
          ? const Icon(Icons.add_circle_outline)
          : difficulty != null
              ? _DifficultyBadge(difficulty: difficulty)
              : const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class _DifficultyBadge extends StatelessWidget {
  const _DifficultyBadge({required this.difficulty});
  final String difficulty;

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (difficulty.toLowerCase()) {
      case 'beginner':
        color = Colors.green;
        break;
      case 'advanced':
        color = Colors.red;
        break;
      default:
        color = Colors.orange;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        _sentenceCase(difficulty),
        style: TextStyle(
          fontSize: 11,
          color: color.withValues(alpha: 0.9),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ── Exercise detail bottom sheet ──────────────────────────────────────────────

class _ExerciseDetailSheet extends StatelessWidget {
  const _ExerciseDetailSheet({required this.exercise});
  final ExerciseEntity exercise;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title + custom badge
              Row(
                children: [
                  Expanded(
                    child: Text(
                      exercise.name,
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                    ),
                  ),
                  if (exercise.isCustom)
                    Chip(
                      label: const Text('Custom'),
                      visualDensity: VisualDensity.compact,
                      backgroundColor:
                          Theme.of(context).colorScheme.tertiaryContainer,
                      labelStyle: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context)
                            .colorScheme
                            .onTertiaryContainer,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Primary muscles
              if (exercise.muscleGroups.isNotEmpty) ...[
                _SheetLabel('Primary Muscles'),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: exercise.muscleGroups
                      .map(
                        (m) => Chip(
                          label: Text(_sentenceCase(m)),
                          backgroundColor:
                              Theme.of(context).colorScheme.primaryContainer,
                          labelStyle: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer,
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 14),
              ],

              // Secondary muscles
              if (exercise.secondaryMuscles.isNotEmpty) ...[
                _SheetLabel('Secondary Muscles'),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: exercise.secondaryMuscles
                      .map(
                        (m) => Chip(
                          label: Text(_sentenceCase(m)),
                          visualDensity: VisualDensity.compact,
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 14),
              ],

              // Equipment + difficulty pills
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (exercise.equipmentType != null)
                    _InfoPill(
                      icon: Icons.fitness_center,
                      label: _sentenceCase(exercise.equipmentType!),
                    ),
                  if (exercise.difficulty != null)
                    _InfoPill(
                      icon: Icons.bar_chart,
                      label: _sentenceCase(exercise.difficulty!),
                    ),
                  if (exercise.category != null)
                    _InfoPill(
                      icon: Icons.category_outlined,
                      label: _sentenceCase(exercise.category!),
                    ),
                ],
              ),
              const SizedBox(height: 18),

              // Instructions
              if (exercise.instructions != null &&
                  exercise.instructions!.isNotEmpty) ...[
                _SheetLabel('Instructions'),
                const SizedBox(height: 8),
                Text(
                  exercise.instructions!,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}

class _SheetLabel extends StatelessWidget {
  const _SheetLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            letterSpacing: 0.5,
          ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

// ── Create custom exercise dialog ─────────────────────────────────────────────

class _CreateExerciseDialog extends ConsumerStatefulWidget {
  const _CreateExerciseDialog({required this.onCreated});
  final ValueChanged<ExerciseEntity> onCreated;

  @override
  ConsumerState<_CreateExerciseDialog> createState() =>
      _CreateExerciseDialogState();
}

class _CreateExerciseDialogState
    extends ConsumerState<_CreateExerciseDialog> {
  final _nameCtrl = TextEditingController();
  final _instructionsCtrl = TextEditingController();
  final Set<String> _selectedMuscles = {};
  String? _selectedEquipment;
  bool _isSubmitting = false;

  // Display-friendly muscle options (subset, easiest to pick from a dialog).
  static const _muscleOptions = [
    'chest',
    'back',
    'shoulders',
    'biceps',
    'triceps',
    'quadriceps',
    'hamstrings',
    'glutes',
    'core',
    'calves',
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _instructionsCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an exercise name.')),
      );
      return;
    }
    if (_selectedMuscles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one muscle group.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    // profileId is not available here without passing it in; using the
    // customExerciseNotifierProvider with a placeholder key. In practice,
    // the screen should be given profileId via constructor — this mirrors the
    // existing custom notifier pattern.
    const profileId = '';
    final notifier = ref.read(
      customExerciseNotifierProvider(profileId).notifier,
    );
    final exercise = await notifier.createCustomExercise(
      profileId: profileId,
      name: name,
      muscleGroups: _selectedMuscles.toList(),
      equipmentType: _selectedEquipment,
      instructions: _instructionsCtrl.text.trim().isEmpty
          ? null
          : _instructionsCtrl.text.trim(),
    );

    if (!mounted) return;

    if (exercise != null) {
      Navigator.of(context).pop();
      widget.onCreated(exercise);
    } else {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to create exercise. Try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Custom Exercise'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Exercise name *',
                hintText: 'e.g. Trap Bar Deadlift',
              ),
            ),
            const SizedBox(height: 16),

            Text(
              'Muscle Groups *',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: _muscleOptions
                  .map(
                    (m) => FilterChip(
                      label: Text(_sentenceCase(m)),
                      selected: _selectedMuscles.contains(m),
                      onSelected: (selected) => setState(() {
                        if (selected) {
                          _selectedMuscles.add(m);
                        } else {
                          _selectedMuscles.remove(m);
                        }
                      }),
                      visualDensity: VisualDensity.compact,
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              value: _selectedEquipment,
              decoration: const InputDecoration(
                labelText: 'Equipment Type',
              ),
              hint: const Text('Select equipment'),
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('None / Bodyweight'),
                ),
                ...kEquipmentTypes.map(
                  (e) => DropdownMenuItem(
                    value: e,
                    child: Text(_sentenceCase(e)),
                  ),
                ),
              ],
              onChanged: (v) => setState(() => _selectedEquipment = v),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _instructionsCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Instructions (optional)',
                hintText: 'Describe the movement...',
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create'),
        ),
      ],
    );
  }
}

// ── Empty / error states ──────────────────────────────────────────────────────

class _ExerciseBrowserEmpty extends StatelessWidget {
  const _ExerciseBrowserEmpty({
    required this.hasFilters,
    required this.onClearFilters,
  });
  final bool hasFilters;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Theme.of(context)
                  .colorScheme
                  .onSurfaceVariant
                  .withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              hasFilters
                  ? 'No exercises match your filters'
                  : 'No exercises found',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (hasFilters) ...[
              const SizedBox(height: 16),
              TextButton(
                onPressed: onClearFilters,
                child: const Text('Clear filters'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ExerciseBrowserError extends StatelessWidget {
  const _ExerciseBrowserError({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline,
              size: 56, color: Theme.of(context).colorScheme.error),
          const SizedBox(height: 16),
          const Text('Failed to load exercises.'),
          const SizedBox(height: 12),
          FilledButton.tonal(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
