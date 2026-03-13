import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/meal_plan_entity.dart';
import '../data/food_database_service.dart';
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

  /// Tracks whether the user dismissed the end-of-day variance card this
  /// session. Reset to false whenever the selected date changes.
  bool _varianceSummaryDismissed = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _loadData();
  }

  Future<void> _loadData() async {
    final profileRepo = ref.read(profileRepositoryProvider);
    _profile = await profileRepo.getActiveProfile();
    await ref.read(mealPlanProvider(widget.profileId).notifier).loadPlan(_selectedDate);
  }

  void _changeDate(int delta) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: delta));
      _varianceSummaryDismissed = false;
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

  /// Navigate to food search and log the selected item.
  Future<void> _logFood() async {
    final food = await context.push<FoodItem>('/meals/food-search');
    if (food == null || !mounted) return;

    final result = await _showFoodPortionPicker(food);
    if (result == null || !mounted) return;

    final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
    await ref.read(mealPlanProvider(widget.profileId).notifier).addFoodToLog(
          userId: userId,
          foodItem: food,
          mealType: result.$1,
          portionG: result.$2,
        );
  }

  /// Bottom sheet to select meal type + gram amount for a food-search item.
  Future<(String, double)?> _showFoodPortionPicker(FoodItem food) async {
    return showModalBottomSheet<(String, double)>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _FoodPortionPickerSheet(food: food),
    );
  }

  /// Bottom sheet showing full meal detail, macro breakdown, portion options,
  /// and quick action buttons (mark eaten / swap).
  void _showMealDetailSheet(MealPlanItemEntity item) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx2, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant
                        .withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Meal type badge + name
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      item.mealTypeDisplayName,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (item.source == 'food_search') ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.tertiaryContainer,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'logged',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onTertiaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              Text(item.name, style: theme.textTheme.headlineSmall),
              if (item.description != null && item.description!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  item.description!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                  ),
                ),
              ],
              if (item.isLogged && item.portionMultiplier != 1.0) ...[
                const SizedBox(height: 4),
                Text(
                  'Logged at ${(item.portionMultiplier * 100).round()}% portion',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              const SizedBox(height: 20),

              // Macro grid
              Text(
                'Nutrition',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 10),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 2.8,
                children: [
                  _MacroDetailTile(
                    label: 'Calories',
                    value: '${item.effectiveCalories}',
                    unit: 'kcal',
                    color: theme.colorScheme.primary,
                  ),
                  _MacroDetailTile(
                    label: 'Protein',
                    value: '${item.effectiveProteinG}',
                    unit: 'g',
                    color: Colors.red.shade400,
                  ),
                  _MacroDetailTile(
                    label: 'Carbs',
                    value: '${item.effectiveCarbsG}',
                    unit: 'g',
                    color: Colors.amber.shade600,
                  ),
                  _MacroDetailTile(
                    label: 'Fat',
                    value: '${item.effectiveFatG}',
                    unit: 'g',
                    color: Colors.green.shade400,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Portion adjustment (only for plan items, not food-search items)
              if (item.source != 'food_search') ...[
                Text(
                  'Portion',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [0.5, 0.75, 1.0, 1.25, 1.5].map((pct) {
                    final isActive = item.portionMultiplier == pct;
                    return ChoiceChip(
                      label: Text('${(pct * 100).round()}%'),
                      selected: isActive,
                      onSelected: (_) async {
                        Navigator.pop(ctx);
                        await ref
                            .read(mealPlanProvider(widget.profileId).notifier)
                            .markMealLogged(
                              item.id,
                              isLogged: true,
                              portionMultiplier: pct,
                            );
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
              ],

              // Action buttons
              if (item.isLogged)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.remove_circle_outline, size: 18),
                    label: const Text('Unmark as Eaten'),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await ref
                          .read(mealPlanProvider(widget.profileId).notifier)
                          .markMealLogged(item.id, isLogged: false);
                    },
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text('Mark as Eaten'),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await _showPortionPicker(item);
                    },
                  ),
                ),
              if (item.source != 'food_search') ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.swap_horiz, size: 18),
                    label: const Text('Swap Meal'),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showSwapSheet(item);
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Bottom sheet for portion adjustment on plan items.
  Future<void> _showPortionPicker(MealPlanItemEntity item) async {
    unawaited(HapticFeedback.selectionClick());
    final multiplier = await showModalBottomSheet<double>(
      context: context,
      builder: (ctx) => _PortionPickerSheet(itemName: item.name),
    );
    if (multiplier == null || !mounted) return;

    await ref.read(mealPlanProvider(widget.profileId).notifier).markMealLogged(
          item.id,
          isLogged: true,
          portionMultiplier: multiplier,
        );
  }

  /// Bottom sheet showing 3 swap alternatives from AI.
  Future<void> _showSwapSheet(MealPlanItemEntity item) async {
    final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _SwapAlternativesSheet(
        item: item,
        profileId: widget.profileId,
        userId: userId,
      ),
    );
  }

  Future<void> _regenerateMeal(MealPlanItemEntity item) async {
    final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
    unawaited(HapticFeedback.mediumImpact());
    await ref.read(mealPlanProvider(widget.profileId).notifier).regenerateMeal(
          userId: userId,
          itemId: item.id,
          mealType: item.mealType,
        );
  }

  Future<void> _deleteAndRegenerate() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete current plan?'),
        content: const Text('All logged meals will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete & Regenerate'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    unawaited(HapticFeedback.mediumImpact());
    final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
    final state = ref.read(mealPlanProvider(widget.profileId));
    await ref
        .read(mealPlanProvider(widget.profileId).notifier)
        .deleteAndRegeneratePlan(
          userId: userId,
          dayType: state.dayType,
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
          padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Edit $dayLabel Targets',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
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
                        await customRepo.deleteTarget(widget.profileId, dayType);
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      child: const Text('Reset to Auto'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () async {
                        final cal = int.tryParse(calController.text) ?? targets.calories;
                        final pro = int.tryParse(proteinController.text) ?? targets.proteinG;
                        final carbs = int.tryParse(carbsController.text) ?? targets.carbsG;
                        final fat = int.tryParse(fatController.text) ?? targets.fatG;

                        await ref
                            .read(nutritionTargetsProvider(widget.profileId).notifier)
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
            icon: const Icon(Icons.kitchen_outlined),
            tooltip: 'Meal Prep',
            onPressed: () => context.push('/meals/prep'),
          ),
          IconButton(
            icon: const Icon(Icons.shopping_cart_outlined),
            tooltip: 'Generate shopping list',
            onPressed: () => context.push('/meals/shopping-generator'),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: 'More options',
            onSelected: (value) {
              if (value == 'delete_regenerate') _deleteAndRegenerate();
              if (value == 'weekly_summary') {
                context.push('/meals/weekly-summary');
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'weekly_summary',
                child: Row(
                  children: [
                    Icon(Icons.bar_chart_outlined, size: 18),
                    SizedBox(width: 8),
                    Text('Weekly Summary'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete_regenerate',
                child: Row(
                  children: [
                    Icon(Icons.refresh, size: 18),
                    SizedBox(width: 8),
                    Text('Delete & Regenerate Plan'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: state.isSaving ? null : _logFood,
        icon: state.isSaving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.add),
        label: const Text('Log Food'),
      ),
      body: Column(
        children: [
          _DateSelector(
            date: _selectedDate,
            formattedDate: _formatDate(_selectedDate),
            onPrevious: () => _changeDate(-1),
            onNext: () => _changeDate(1),
          ),
          _DayTypePicker(
            selected: state.dayType,
            onChanged: (type) =>
                ref.read(mealPlanProvider(widget.profileId).notifier).setDayType(type),
          ),
          const SizedBox(height: 8),
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
          Text('Generating your meal plan...', style: theme.textTheme.titleMedium),
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
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
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
      onRefresh: () =>
          ref.read(mealPlanProvider(widget.profileId).notifier).loadPlan(_selectedDate),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          // End-of-day nutrition variance summary — shown after 8 PM for today only
          if (!_varianceSummaryDismissed)
            _NutritionVarianceSummaryCard(
              plan: plan,
              selectedDate: _selectedDate,
              onDismiss: () => setState(() => _varianceSummaryDismissed = true),
            ),

          // Macro summary bar (tap to edit targets)
          GestureDetector(
            onTap: () => _showQuickTargetEditor(state.dayType),
            child: _MacroSummaryBar(
              plan: plan,
              recoveryAdjustmentLabel: state.recoveryAdjustmentLabel,
            ),
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
                    Icon(Icons.auto_awesome, size: 18, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(plan.aiRationale!, style: theme.textTheme.bodySmall),
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
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
              ),
            ),

          const SizedBox(height: 100),
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
            onTap: () => _showMealDetailSheet(item),
            onSwap: () => _showSwapSheet(item),
            onRegenerate: () => _regenerateMeal(item),
            onToggleLogged: () {
              if (item.isLogged) {
                // Unmark immediately
                HapticFeedback.selectionClick();
                ref
                    .read(mealPlanProvider(widget.profileId).notifier)
                    .markMealLogged(item.id, isLogged: false);
              } else {
                // Show portion picker before marking
                _showPortionPicker(item);
              }
            },
          )),
    ];
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

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
          IconButton(icon: const Icon(Icons.chevron_left), tooltip: 'Previous day', onPressed: onPrevious),
          Text(
            formattedDate,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          IconButton(icon: const Icon(Icons.chevron_right), tooltip: 'Next day', onPressed: onNext),
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
          ButtonSegment(
              value: 'strength',
              label: Text('Strength'),
              icon: Icon(Icons.fitness_center, size: 16)),
          ButtonSegment(
              value: 'cardio',
              label: Text('Cardio'),
              icon: Icon(Icons.directions_run, size: 16)),
        ],
        selected: {selected},
        onSelectionChanged: (set) => onChanged(set.first),
        showSelectedIcon: false,
      ),
    );
  }
}

/// Macro summary bar — shows CONSUMED (logged) vs TARGET.
/// When [recoveryAdjustmentLabel] is non-null it displays a pill explaining
/// why the calorie target was adjusted from the base TDEE.
class _MacroSummaryBar extends StatelessWidget {
  const _MacroSummaryBar({
    required this.plan,
    this.recoveryAdjustmentLabel,
  });

  final MealPlanEntity plan;

  /// Human-readable recovery adjustment label from the prescription engine,
  /// e.g. "Reduced −10% — fair recovery". Null when no adjustment is active.
  final String? recoveryAdjustmentLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _MacroRing(
                  label: 'Calories',
                  current: plan.consumedCalories,
                  target: plan.totalCalories ?? 0,
                  unit: 'kcal',
                  color: theme.colorScheme.primary,
                ),
                _MacroRing(
                  label: 'Protein',
                  current: plan.consumedProteinG,
                  target: plan.totalProteinG ?? 0,
                  unit: 'g',
                  color: Colors.red.shade400,
                ),
                _MacroRing(
                  label: 'Carbs',
                  current: plan.consumedCarbsG,
                  target: plan.totalCarbsG ?? 0,
                  unit: 'g',
                  color: Colors.amber.shade600,
                ),
                _MacroRing(
                  label: 'Fat',
                  current: plan.consumedFatG,
                  target: plan.totalFatG ?? 0,
                  unit: 'g',
                  color: Colors.green.shade400,
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Recovery adjustment pill — only shown when a recovery score
            // is available and has modified today's calorie target.
            if (recoveryAdjustmentLabel != null &&
                recoveryAdjustmentLabel!.isNotEmpty) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer
                      .withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.favorite_rounded,
                      size: 11,
                      color: theme.colorScheme.secondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      recoveryAdjustmentLabel!,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSecondaryContainer,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
            ],
            Text(
              '${plan.loggedCount}/${plan.items.length} meals logged  ·  tap to edit targets',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
              ),
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
    required this.onTap,
    required this.onSwap,
    required this.onRegenerate,
    required this.onToggleLogged,
  });

  final MealPlanItemEntity item;
  final bool isSwapping;
  final VoidCallback onTap;
  final VoidCallback onSwap;
  final VoidCallback onRegenerate;
  final VoidCallback onToggleLogged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: AnimatedOpacity(
        opacity: item.isLogged ? 0.65 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Logged circle (tap = mark/unmark, long press = portion picker)
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
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.name,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              decoration:
                                  item.isLogged ? TextDecoration.lineThrough : null,
                            ),
                          ),
                        ),
                        // Source badge for food-search items
                        if (item.source == 'food_search')
                          Container(
                            margin: const EdgeInsets.only(left: 4),
                            padding:
                                const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.tertiaryContainer,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'logged',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onTertiaryContainer,
                                fontSize: 9,
                              ),
                            ),
                          ),
                      ],
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
                    if (item.isLogged && item.portionMultiplier != 1.0) ...[
                      const SizedBox(height: 2),
                      Text(
                        '${(item.portionMultiplier * 100).round()}% portion',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      children: [
                        _MacroChip(
                          label: '${item.effectiveCalories} cal',
                          color: theme.colorScheme.primary,
                        ),
                        _MacroChip(
                            label: '${item.effectiveProteinG}g P',
                            color: Colors.red.shade400),
                        _MacroChip(
                            label: '${item.effectiveCarbsG}g C',
                            color: Colors.amber.shade600),
                        _MacroChip(
                            label: '${item.effectiveFatG}g F',
                            color: Colors.green.shade400),
                      ],
                    ),
                  ],
                ),
              ),

              // Action buttons: swap + more menu
              if (isSwapping)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (item.source != 'food_search') ...[
                IconButton(
                  icon: const Icon(Icons.swap_horiz, size: 22),
                  onPressed: onSwap,
                  tooltip: 'Swap meal',
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20),
                  tooltip: 'More options',
                  onSelected: (v) {
                    if (v == 'regenerate') onRegenerate();
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'regenerate',
                      child: Row(
                        children: [
                          Icon(Icons.refresh, size: 18),
                          SizedBox(width: 8),
                          Text('Regenerate'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
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

// ---------------------------------------------------------------------------
// Macro detail tile — used inside the meal detail bottom sheet
// ---------------------------------------------------------------------------

class _MacroDetailTile extends StatelessWidget {
  const _MacroDetailTile({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  final String label;
  final String value;
  final String unit;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 28,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                ),
              ),
              Text(
                '$value $unit',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Portion picker — for plan items (percentage-based)
// ---------------------------------------------------------------------------

class _PortionPickerSheet extends StatefulWidget {
  const _PortionPickerSheet({required this.itemName});

  final String itemName;

  @override
  State<_PortionPickerSheet> createState() => _PortionPickerSheetState();
}

class _PortionPickerSheetState extends State<_PortionPickerSheet> {
  double _selected = 1.0;
  final _customController = TextEditingController();
  bool _useCustom = false;

  static const _presets = [0.5, 0.75, 1.0, 1.25, 1.5];

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 24, 24, 24 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How much did you eat?',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            widget.itemName,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),

          // Preset percentage chips
          Wrap(
            spacing: 8,
            children: _presets.map((p) {
              final isSelected = !_useCustom && _selected == p;
              return ChoiceChip(
                label: Text('${(p * 100).round()}%'),
                selected: isSelected,
                onSelected: (_) => setState(() {
                  _selected = p;
                  _useCustom = false;
                }),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),

          // Custom % input
          Row(
            children: [
              Checkbox(
                value: _useCustom,
                onChanged: (v) => setState(() => _useCustom = v ?? false),
              ),
              const Text('Custom: '),
              SizedBox(
                width: 70,
                child: TextField(
                  controller: _customController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    hintText: '100',
                    suffixText: '%',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onTap: () => setState(() => _useCustom = true),
                  onChanged: (_) => setState(() => _useCustom = true),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                double multiplier;
                if (_useCustom) {
                  final pct = double.tryParse(_customController.text) ?? 100;
                  multiplier = (pct / 100).clamp(0.01, 5.0);
                } else {
                  multiplier = _selected;
                }
                Navigator.pop(context, multiplier);
              },
              child: const Text('Mark as Eaten'),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Food portion picker — for food-search items (gram-based + meal type)
// ---------------------------------------------------------------------------

class _FoodPortionPickerSheet extends StatefulWidget {
  const _FoodPortionPickerSheet({required this.food});

  final FoodItem food;

  @override
  State<_FoodPortionPickerSheet> createState() =>
      _FoodPortionPickerSheetState();
}

class _FoodPortionPickerSheetState extends State<_FoodPortionPickerSheet> {
  double _portionG = 100;
  String _mealType = 'snack';
  final _controller = TextEditingController(text: '100');

  static const _gramPresets = [50.0, 100.0, 150.0, 200.0, 250.0];
  static const _mealTypes = ['breakfast', 'lunch', 'dinner', 'snack'];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int get _effectiveCal => (widget.food.caloriesPer100g * _portionG / 100).round();
  int get _effectiveProtein => (widget.food.proteinPer100g * _portionG / 100).round();
  int get _effectiveCarbs => (widget.food.carbsPer100g * _portionG / 100).round();
  int get _effectiveFat => (widget.food.fatPer100g * _portionG / 100).round();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 24, 24, 24 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.food.name,
            style:
                theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            '$_effectiveCal cal · ${_effectiveProtein}g P · ${_effectiveCarbs}g C · ${_effectiveFat}g F',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 16),

          // Gram presets
          Text('Portion', style: theme.textTheme.labelMedium),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: _gramPresets.map((g) {
              return ChoiceChip(
                label: Text('${g.round()}g'),
                selected: _portionG == g,
                onSelected: (_) => setState(() {
                  _portionG = g;
                  _controller.text = g.round().toString();
                }),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),

          // Custom gram input
          Row(
            children: [
              const Text('Custom: '),
              SizedBox(
                width: 80,
                child: TextField(
                  controller: _controller,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    suffixText: 'g',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) => setState(() {
                    _portionG = double.tryParse(v) ?? _portionG;
                  }),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Meal type
          Text('Add to', style: theme.textTheme.labelMedium),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: _mealTypes.map((t) {
              final label = t[0].toUpperCase() + t.substring(1);
              return ChoiceChip(
                label: Text(label),
                selected: _mealType == t,
                onSelected: (_) => setState(() => _mealType = t),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(context, (_mealType, _portionG)),
              child: const Text('Log Food'),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// End-of-day nutrition variance summary card
// ---------------------------------------------------------------------------

/// Displays a planned-vs-actual breakdown after 8 PM for today's plan only.
///
/// Visibility rules:
/// - Only shown when the selected date is today and the clock is at or past 20:00.
/// - Replaced by an "insufficient data" message when fewer than half the plan
///   items have been logged.
/// - Colour-codes each macro based on distance from target:
///     green  → within ±10 %
///     amber  → ±10–25 %
///     red    → > ±25 %
/// - The card is session-dismissible via the X button (parent manages state).
class _NutritionVarianceSummaryCard extends StatelessWidget {
  const _NutritionVarianceSummaryCard({
    required this.plan,
    required this.selectedDate,
    required this.onDismiss,
  });

  final MealPlanEntity plan;
  final DateTime selectedDate;
  final VoidCallback onDismiss;

  // Returns true only when the selected date is today AND the hour is >= 20.
  bool get _shouldShow {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selected =
        DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    return selected == today && now.hour >= 20;
  }

  // Returns true when fewer than half the plan items are logged.
  bool get _insufficientData {
    if (plan.items.isEmpty) return true;
    return plan.loggedCount < (plan.items.length / 2);
  }

  /// Computes the percentage variance of [actual] relative to [target].
  /// Returns 0.0 when [target] is zero to avoid division by zero.
  double _variancePct(int actual, int target) {
    if (target == 0) return 0.0;
    return ((actual - target) / target * 100).abs();
  }

  /// Maps a variance percentage to a status colour.
  ///   <= 10 % → green
  ///   <= 25 % → amber
  ///   >  25 % → red
  Color _statusColor(double pct) {
    if (pct <= 10) return Colors.green.shade500;
    if (pct <= 25) return Colors.amber.shade700;
    return Colors.red.shade500;
  }

  /// Formats the signed variance delta for display, e.g. "+120 kcal" or "−8 g".
  String _delta(int actual, int target, String unit) {
    final diff = actual - target;
    final sign = diff >= 0 ? '+' : '\u2212'; // minus sign (−)
    return '$sign${diff.abs()} $unit';
  }

  @override
  Widget build(BuildContext context) {
    // Render nothing when conditions are not met — zero height, no layout cost.
    if (!_shouldShow) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        color: theme.colorScheme.surfaceContainerHigh,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Icon(
                    Icons.bar_chart_rounded,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'End-of-day summary',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  // Dismiss button
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    tooltip: 'Dismiss',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    onPressed: onDismiss,
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Insufficient data message
              if (_insufficientData)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    'Log more meals for an accurate summary.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.65),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                )
              else ...[
                // Macro variance rows
                _VarianceRow(
                  label: 'Calories',
                  planned: plan.totalCalories ?? 0,
                  actual: plan.consumedCalories,
                  unit: 'kcal',
                  variancePct: _variancePct(
                      plan.consumedCalories, plan.totalCalories ?? 0),
                  statusColor: _statusColor(_variancePct(
                      plan.consumedCalories, plan.totalCalories ?? 0)),
                  delta: _delta(
                      plan.consumedCalories, plan.totalCalories ?? 0, 'kcal'),
                ),
                _VarianceRow(
                  label: 'Protein',
                  planned: plan.totalProteinG ?? 0,
                  actual: plan.consumedProteinG,
                  unit: 'g',
                  variancePct: _variancePct(
                      plan.consumedProteinG, plan.totalProteinG ?? 0),
                  statusColor: _statusColor(_variancePct(
                      plan.consumedProteinG, plan.totalProteinG ?? 0)),
                  delta: _delta(
                      plan.consumedProteinG, plan.totalProteinG ?? 0, 'g'),
                ),
                _VarianceRow(
                  label: 'Carbs',
                  planned: plan.totalCarbsG ?? 0,
                  actual: plan.consumedCarbsG,
                  unit: 'g',
                  variancePct: _variancePct(
                      plan.consumedCarbsG, plan.totalCarbsG ?? 0),
                  statusColor: _statusColor(
                      _variancePct(plan.consumedCarbsG, plan.totalCarbsG ?? 0)),
                  delta: _delta(
                      plan.consumedCarbsG, plan.totalCarbsG ?? 0, 'g'),
                ),
                _VarianceRow(
                  label: 'Fat',
                  planned: plan.totalFatG ?? 0,
                  actual: plan.consumedFatG,
                  unit: 'g',
                  variancePct:
                      _variancePct(plan.consumedFatG, plan.totalFatG ?? 0),
                  statusColor: _statusColor(
                      _variancePct(plan.consumedFatG, plan.totalFatG ?? 0)),
                  delta:
                      _delta(plan.consumedFatG, plan.totalFatG ?? 0, 'g'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A single row in the variance summary showing planned, actual, delta and
/// a colour-coded status indicator.
class _VarianceRow extends StatelessWidget {
  const _VarianceRow({
    required this.label,
    required this.planned,
    required this.actual,
    required this.unit,
    required this.variancePct,
    required this.statusColor,
    required this.delta,
  });

  final String label;
  final int planned;
  final int actual;
  final String unit;
  final double variancePct;
  final Color statusColor;
  final String delta;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 8, right: 8),
      child: Row(
        children: [
          // Colour dot indicator
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),

          // Macro label
          SizedBox(
            width: 52,
            child: Text(
              label,
              style: theme.textTheme.bodySmall
                  ?.copyWith(fontWeight: FontWeight.w500),
            ),
          ),

          // Planned value
          Expanded(
            child: Text(
              '$planned $unit planned',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
              ),
            ),
          ),

          // Actual + delta
          Text(
            '$actual $unit',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '($delta)',
            style: theme.textTheme.labelSmall?.copyWith(
              color: statusColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Swap alternatives sheet — loads 3 options from AI and lets user pick one
// ---------------------------------------------------------------------------

class _SwapAlternativesSheet extends ConsumerStatefulWidget {
  const _SwapAlternativesSheet({
    required this.item,
    required this.profileId,
    required this.userId,
  });

  final MealPlanItemEntity item;
  final String profileId;
  final String userId;

  @override
  ConsumerState<_SwapAlternativesSheet> createState() =>
      _SwapAlternativesSheetState();
}

class _SwapAlternativesSheetState
    extends ConsumerState<_SwapAlternativesSheet> {
  late Future<List<Map<String, dynamic>>> _alternativesFuture;
  int? _applyingIndex;

  @override
  void initState() {
    super.initState();
    _alternativesFuture = ref
        .read(mealPlanProvider(widget.profileId).notifier)
        .getSwapAlternatives(userId: widget.userId, itemId: widget.item.id);
  }

  Future<void> _applyAlternative(
      Map<String, dynamic> alternative, int index) async {
    setState(() => _applyingIndex = index);
    await ref
        .read(mealPlanProvider(widget.profileId).notifier)
        .applySwapAlternative(
          itemId: widget.item.id,
          alternative: alternative,
        );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Swap "${widget.item.name}"',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            'Choose an alternative',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 16),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _alternativesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.hasError || (snapshot.data?.isEmpty ?? true)) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'Could not load alternatives. Try again.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                );
              }

              final alternatives = snapshot.data!;
              return Column(
                children: alternatives.asMap().entries.map((entry) {
                  final i = entry.key;
                  final alt = entry.value;
                  final isApplying = _applyingIndex == i;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      title: Text(
                        alt['name'] as String? ?? 'Option ${i + 1}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (alt['description'] != null)
                            Text(
                              alt['description'] as String,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall,
                            ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            children: [
                              _MacroChip(
                                label: '${alt['calories'] ?? 0} cal',
                                color: theme.colorScheme.primary,
                              ),
                              _MacroChip(
                                label: '${alt['protein_g'] ?? 0}g P',
                                color: Colors.red.shade400,
                              ),
                              _MacroChip(
                                label: '${alt['carbs_g'] ?? 0}g C',
                                color: Colors.amber.shade600,
                              ),
                              _MacroChip(
                                label: '${alt['fat_g'] ?? 0}g F',
                                color: Colors.green.shade400,
                              ),
                            ],
                          ),
                        ],
                      ),
                      trailing: isApplying
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : FilledButton(
                              onPressed: _applyingIndex != null
                                  ? null
                                  : () => _applyAlternative(alt, i),
                              child: const Text('Pick'),
                            ),
                      isThreeLine: true,
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
