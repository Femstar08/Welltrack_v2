import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/meal_plan_entity.dart';
import '../data/custom_macro_target_repository.dart';
import '../data/macro_calculator.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/domain/profile_entity.dart';
import 'meal_plan_provider.dart';
import 'nutrition_targets_provider.dart';

class MealPlanScreen extends ConsumerStatefulWidget {
  const MealPlanScreen({super.key, required this.profileId});
  final String profileId;

  @override
  ConsumerState<MealPlanScreen> createState() => _MealPlanScreenState();
}

class _MealPlanScreenState extends ConsumerState<MealPlanScreen> {
  late DateTime _selectedDate;
  ProfileEntity? _profile;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _loadData();
  }

  Future<void> _loadData() async {
    // Load profile for macro calc context
    final profileRepo = ref.read(profileRepositoryProvider);
    _profile = await profileRepo.getActiveProfile();

    // Load plan for today
    await ref.read(mealPlanProvider(widget.profileId).notifier).loadPlan(_selectedDate);
  }

  void _changeDate(int delta) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: delta));
    });
    ref.read(mealPlanProvider(widget.profileId).notifier).loadPlan(_selectedDate);
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selected = DateTime(date.year, date.month, date.day);

    if (selected == today) return 'Today';
    if (selected == today.subtract(const Duration(days: 1))) return 'Yesterday';
    if (selected == today.add(const Duration(days: 1))) return 'Tomorrow';

    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}';
  }

  Future<void> _generatePlan(String dayType) async {
    final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
    unawaited(HapticFeedback.mediumImpact());

    await ref.read(mealPlanProvider(widget.profileId).notifier).generatePlan(
          userId: userId,
          dayType: dayType,
          weightKg: _profile?.weightKg,
          activityLevel: _profile?.activityLevel,
          fitnessGoal: _profile?.fitnessGoals,
          gender: _profile?.gender,
          age: _profile?.age,
        );
  }

  void _showQuickTargetEditor(String dayType) {
    final calController = TextEditingController();
    final proteinController = TextEditingController();
    final carbsController = TextEditingController();
    final fatController = TextEditingController();

    // Pre-fill with current auto-calculated values
    final targets = MacroCalculator.calculateDailyTargets(
      weightKg: _profile?.weightKg ?? 75.0,
      activityLevel: _profile?.activityLevel,
      dayType: dayType,
      fitnessGoal: _profile?.fitnessGoals,
      gender: _profile?.gender,
      age: _profile?.age,
    );
    calController.text = targets.calories.toString();
    proteinController.text = targets.proteinG.toString();
    carbsController.text = targets.carbsG.toString();
    fatController.text = targets.fatG.toString();

    // Check for existing custom target
    final customRepo = ref.read(customMacroTargetRepositoryProvider);
    customRepo.getTarget(widget.profileId, dayType).then((custom) {
      if (custom != null && mounted) {
        calController.text = custom.calories.toString();
        proteinController.text = custom.proteinG.toString();
        carbsController.text = custom.carbsG.toString();
        fatController.text = custom.fatG.toString();
      }
    });

    final dayLabel = switch (dayType) {
      'strength' => 'Strength Day',
      'cardio' => 'Cardio Day',
      'rest' => 'Rest Day',
      _ => dayType,
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            24 + MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Edit $dayLabel Targets',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: calController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Calories',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: proteinController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Protein (g)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: carbsController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Carbs (g)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: fatController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Fat (g)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        await customRepo.deleteTarget(
                            widget.profileId, dayType);
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      child: const Text('Reset to Auto'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () async {
                        final cal =
                            int.tryParse(calController.text) ?? targets.calories;
                        final pro = int.tryParse(proteinController.text) ??
                            targets.proteinG;
                        final carbs = int.tryParse(carbsController.text) ??
                            targets.carbsG;
                        final fat =
                            int.tryParse(fatController.text) ?? targets.fatG;

                        await ref
                            .read(nutritionTargetsProvider(widget.profileId)
                                .notifier)
                            .saveTarget(
                              dayType: dayType,
                              calories: cal,
                              proteinG: pro,
                              carbsG: carbs,
                              fatG: fat,
                            );
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      child: const Text('Save'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(mealPlanProvider(widget.profileId));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meal Plan'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_cart_outlined),
            tooltip: 'Generate shopping list',
            onPressed: () => context.push('/meals/shopping-generator'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Date selector
          _DateSelector(
            date: _selectedDate,
            formattedDate: _formatDate(_selectedDate),
            onPrevious: () => _changeDate(-1),
            onNext: () => _changeDate(1),
          ),

          // Day type picker
          _DayTypePicker(
            selected: state.dayType,
            onChanged: (type) =>
                ref.read(mealPlanProvider(widget.profileId).notifier).setDayType(type),
          ),

          const SizedBox(height: 8),

          // Content
          Expanded(
            child: state.isGenerating
                ? _buildLoading(theme)
                : state.plan != null
                    ? _buildPlanContent(state, theme)
                    : _buildEmptyState(state, theme),
          ),
        ],
      ),
    );
  }

  Widget _buildLoading(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          const SizedBox(height: 24),
          Text(
            'Generating your meal plan...',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Crafting meals to match your macros',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(MealPlanState state, ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.restaurant_menu,
              size: 80,
              color: theme.colorScheme.primary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 24),
            Text(
              'No meal plan for ${_formatDate(_selectedDate)}',
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Generate an AI-powered meal plan tailored to your goals and training day.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => _generatePlan(state.dayType),
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Generate Meal Plan'),
            ),
            if (state.error != null) ...[
              const SizedBox(height: 16),
              Text(
                state.error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPlanContent(MealPlanState state, ThemeData theme) {
    final plan = state.plan!;

    return RefreshIndicator(
      onRefresh: () => ref
          .read(mealPlanProvider(widget.profileId).notifier)
          .loadPlan(_selectedDate),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          // Macro summary bar (tap to edit targets)
          GestureDetector(
            onTap: () => _showQuickTargetEditor(state.dayType),
            child: _MacroSummaryBar(plan: plan),
          ),
          const SizedBox(height: 16),

          // AI rationale
          if (plan.aiRationale != null) ...[
            Card(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome,
                        size: 18, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        plan.aiRationale!,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Meal sections
          for (final type in ['breakfast', 'lunch', 'dinner', 'snack'])
            ..._buildMealSection(type, plan, state, theme),

          // Error display
          if (state.error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                state.error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  List<Widget> _buildMealSection(
    String type,
    MealPlanEntity plan,
    MealPlanState state,
    ThemeData theme,
  ) {
    final items = plan.mealsForType(type);
    if (items.isEmpty) return [];

    final label = switch (type) {
      'breakfast' => 'Breakfast',
      'lunch' => 'Lunch',
      'dinner' => 'Dinner',
      'snack' => 'Snacks',
      _ => type,
    };

    return [
      Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 4),
        child: Text(
          label,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            letterSpacing: 0.5,
          ),
        ),
      ),
      ...items.map((item) => _MealItemCard(
            item: item,
            isSwapping: state.isSwapping && state.swappingItemId == item.id,
            onSwap: () {
              final userId =
                  Supabase.instance.client.auth.currentUser?.id ?? '';
              HapticFeedback.lightImpact();
              ref.read(mealPlanProvider(widget.profileId).notifier).swapMeal(
                    userId: userId,
                    itemId: item.id,
                  );
            },
            onToggleLogged: () {
              HapticFeedback.selectionClick();
              ref
                  .read(mealPlanProvider(widget.profileId).notifier)
                  .markMealLogged(item.id, isLogged: !item.isLogged);
            },
          )),
    ];
  }
}

// --- Sub-widgets ---

class _DateSelector extends StatelessWidget {
  const _DateSelector({
    required this.date,
    required this.formattedDate,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime date;
  final String formattedDate;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: onPrevious,
          ),
          Text(
            formattedDate,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: onNext,
          ),
        ],
      ),
    );
  }
}

class _DayTypePicker extends StatelessWidget {
  const _DayTypePicker({required this.selected, required this.onChanged});

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SegmentedButton<String>(
        segments: const [
          ButtonSegment(value: 'rest', label: Text('Rest'), icon: Icon(Icons.weekend, size: 16)),
          ButtonSegment(value: 'strength', label: Text('Strength'), icon: Icon(Icons.fitness_center, size: 16)),
          ButtonSegment(value: 'cardio', label: Text('Cardio'), icon: Icon(Icons.directions_run, size: 16)),
        ],
        selected: {selected},
        onSelectionChanged: (set) => onChanged(set.first),
        showSelectedIcon: false,
      ),
    );
  }
}

class _MacroSummaryBar extends StatelessWidget {
  const _MacroSummaryBar({required this.plan});

  final MealPlanEntity plan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _MacroRing(
              label: 'Calories',
              current: plan.totalCaloriesActual,
              target: plan.totalCalories ?? 0,
              unit: 'kcal',
              color: theme.colorScheme.primary,
            ),
            _MacroRing(
              label: 'Protein',
              current: plan.totalProteinActual,
              target: plan.totalProteinG ?? 0,
              unit: 'g',
              color: Colors.red.shade400,
            ),
            _MacroRing(
              label: 'Carbs',
              current: plan.totalCarbsActual,
              target: plan.totalCarbsG ?? 0,
              unit: 'g',
              color: Colors.amber.shade600,
            ),
            _MacroRing(
              label: 'Fat',
              current: plan.totalFatActual,
              target: plan.totalFatG ?? 0,
              unit: 'g',
              color: Colors.green.shade400,
            ),
          ],
        ),
      ),
    );
  }
}

class _MacroRing extends StatelessWidget {
  const _MacroRing({
    required this.label,
    required this.current,
    required this.target,
    required this.unit,
    required this.color,
  });

  final String label;
  final int current;
  final int target;
  final String unit;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 56,
          height: 56,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: progress,
                strokeWidth: 4,
                backgroundColor: color.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation(color),
              ),
              Text(
                '$current',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        Text(
          '/ $target$unit',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            fontSize: 9,
          ),
        ),
      ],
    );
  }
}

class _MealItemCard extends StatelessWidget {
  const _MealItemCard({
    required this.item,
    required this.isSwapping,
    required this.onSwap,
    required this.onToggleLogged,
  });

  final MealPlanItemEntity item;
  final bool isSwapping;
  final VoidCallback onSwap;
  final VoidCallback onToggleLogged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: AnimatedOpacity(
        opacity: item.isLogged ? 0.65 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Logged indicator
              GestureDetector(
                onTap: onToggleLogged,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: item.isLogged
                        ? theme.colorScheme.primary
                        : Colors.transparent,
                    border: Border.all(
                      color: item.isLogged
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outline,
                      width: 2,
                    ),
                  ),
                  child: item.isLogged
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : null,
                ),
              ),
              const SizedBox(width: 12),

              // Meal info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        decoration:
                            item.isLogged ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    if (item.description != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.description!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 6),
                    // Macro chips
                    Wrap(
                      spacing: 6,
                      children: [
                        _MacroChip(
                            label: '${item.calories ?? 0} cal',
                            color: theme.colorScheme.primary),
                        _MacroChip(
                            label: '${item.proteinG ?? 0}g P',
                            color: Colors.red.shade400),
                        _MacroChip(
                            label: '${item.carbsG ?? 0}g C',
                            color: Colors.amber.shade600),
                        _MacroChip(
                            label: '${item.fatG ?? 0}g F',
                            color: Colors.green.shade400),
                      ],
                    ),
                  ],
                ),
              ),

              // Swap button
              if (isSwapping)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                IconButton(
                  icon: const Icon(Icons.swap_horiz, size: 22),
                  onPressed: onSwap,
                  tooltip: 'Swap meal',
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MacroChip extends StatelessWidget {
  const _MacroChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
