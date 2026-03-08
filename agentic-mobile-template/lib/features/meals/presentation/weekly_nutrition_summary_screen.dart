import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/meal_plan_repository.dart';
import '../domain/meal_plan_entity.dart';

// ── Provider ──────────────────────────────────────────────────────────────────

/// State for the weekly nutrition summary screen.
class WeeklyNutritionState {
  const WeeklyNutritionState({
    this.plans = const [],
    this.isLoading = false,
    this.error,
  });

  final List<MealPlanEntity> plans;
  final bool isLoading;
  final String? error;

  WeeklyNutritionState copyWith({
    List<MealPlanEntity>? plans,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return WeeklyNutritionState(
      plans: plans ?? this.plans,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }

  /// Only days that have at least one logged item count as "logged".
  List<MealPlanEntity> get loggedDays =>
      plans.where((p) => p.loggedCount > 0).toList();

  bool get hasEnoughData => loggedDays.length >= 3;

  /// Average consumed calories across logged days.
  double get avgConsumedCalories {
    if (loggedDays.isEmpty) return 0;
    final total = loggedDays.fold<int>(0, (sum, p) => sum + p.consumedCalories);
    return total / loggedDays.length;
  }

  /// Average consumed protein across logged days.
  double get avgProteinG {
    if (loggedDays.isEmpty) return 0;
    final total = loggedDays.fold<int>(0, (sum, p) => sum + p.consumedProteinG);
    return total / loggedDays.length;
  }

  /// Average consumed carbs across logged days.
  double get avgCarbsG {
    if (loggedDays.isEmpty) return 0;
    final total = loggedDays.fold<int>(0, (sum, p) => sum + p.consumedCarbsG);
    return total / loggedDays.length;
  }

  /// Average consumed fat across logged days.
  double get avgFatG {
    if (loggedDays.isEmpty) return 0;
    final total = loggedDays.fold<int>(0, (sum, p) => sum + p.consumedFatG);
    return total / loggedDays.length;
  }

  /// The average calorie target across all plans that have a target set.
  double get avgCalorieTarget {
    final withTarget = plans.where((p) => p.totalCalories != null).toList();
    if (withTarget.isEmpty) return 2000;
    final total =
        withTarget.fold<int>(0, (sum, p) => sum + (p.totalCalories ?? 0));
    return total / withTarget.length;
  }

  /// Best day: logged day closest to its own daily target (or average target).
  MealPlanEntity? get bestDay {
    if (loggedDays.isEmpty) return null;
    final target = avgCalorieTarget;
    return loggedDays.reduce((a, b) {
      final diffA = (a.consumedCalories - (a.totalCalories ?? target)).abs();
      final diffB = (b.consumedCalories - (b.totalCalories ?? target)).abs();
      return diffA <= diffB ? a : b;
    });
  }

  /// Worst day: logged day furthest from its own daily target.
  MealPlanEntity? get worstDay {
    if (loggedDays.isEmpty) return null;
    final target = avgCalorieTarget;
    return loggedDays.reduce((a, b) {
      final diffA = (a.consumedCalories - (a.totalCalories ?? target)).abs();
      final diffB = (b.consumedCalories - (b.totalCalories ?? target)).abs();
      return diffA >= diffB ? a : b;
    });
  }
}

class WeeklyNutritionNotifier extends StateNotifier<WeeklyNutritionState> {
  WeeklyNutritionNotifier(this._repository, this._profileId)
      : super(const WeeklyNutritionState());

  final MealPlanRepository _repository;
  final String _profileId;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final sevenDaysAgo = today.subtract(const Duration(days: 6));

      final plans = await _repository.getMealPlans(
        _profileId,
        sevenDaysAgo,
        today,
      );
      state = state.copyWith(plans: plans, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load weekly data: $e',
      );
    }
  }
}

/// Family provider keyed on profileId.
final weeklyNutritionProvider = StateNotifierProvider.family<
    WeeklyNutritionNotifier, WeeklyNutritionState, String>(
  (ref, profileId) {
    final repo = ref.watch(mealPlanRepositoryProvider);
    return WeeklyNutritionNotifier(repo, profileId);
  },
);

// ── Screen ────────────────────────────────────────────────────────────────────

class WeeklyNutritionSummaryScreen extends ConsumerStatefulWidget {
  const WeeklyNutritionSummaryScreen({super.key, required this.profileId});

  final String profileId;

  @override
  ConsumerState<WeeklyNutritionSummaryScreen> createState() =>
      _WeeklyNutritionSummaryScreenState();
}

class _WeeklyNutritionSummaryScreenState
    extends ConsumerState<WeeklyNutritionSummaryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(weeklyNutritionProvider(widget.profileId).notifier)
          .load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(weeklyNutritionProvider(widget.profileId));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Weekly Nutrition'),
        centerTitle: true,
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.error != null
              ? _buildError(state.error!, theme)
              : RefreshIndicator(
                  onRefresh: () => ref
                      .read(weeklyNutritionProvider(widget.profileId).notifier)
                      .load(),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    child: state.hasEnoughData
                        ? _buildSummary(state, theme)
                        : _buildInsufficientData(state, theme),
                  ),
                ),
    );
  }

  // ── Error state ─────────────────────────────────────────────────────────────

  Widget _buildError(String error, ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
          const SizedBox(height: 12),
          Text(
            'Something went wrong',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: const TextStyle(color: Colors.grey, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => ref
                .read(weeklyNutritionProvider(widget.profileId).notifier)
                .load(),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  // ── Insufficient data state ──────────────────────────────────────────────────

  Widget _buildInsufficientData(WeeklyNutritionState state, ThemeData theme) {
    final logged = state.loggedDays.length;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Column(
            children: [
              Icon(Icons.restaurant_menu_outlined,
                  size: 48, color: Colors.orange.shade400),
              const SizedBox(height: 16),
              Text(
                'Log more days for a weekly summary',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'You have $logged of 3 required days logged this week. '
                'Keep logging your meals to unlock the full weekly analysis.',
                style: const TextStyle(color: Colors.grey, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        if (state.plans.isNotEmpty) ...[
          const SizedBox(height: 24),
          _buildProgressOverview(state, theme),
        ],
      ],
    );
  }

  /// Shows a basic progress overview even when data is insufficient.
  Widget _buildProgressOverview(WeeklyNutritionState state, ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Logged days this week',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...state.plans.map(
              (p) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      p.loggedCount > 0
                          ? Icons.check_circle_outline
                          : Icons.radio_button_unchecked,
                      size: 18,
                      color: p.loggedCount > 0
                          ? Colors.green.shade600
                          : Colors.grey.shade400,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _shortDateLabel(p.planDate),
                      style: TextStyle(
                        color: p.loggedCount > 0
                            ? Colors.black87
                            : Colors.grey.shade500,
                      ),
                    ),
                    const Spacer(),
                    if (p.loggedCount > 0)
                      Text(
                        '${p.consumedCalories} kcal',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Full summary ─────────────────────────────────────────────────────────────

  Widget _buildSummary(WeeklyNutritionState state, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildChartCard(state, theme),
        const SizedBox(height: 20),
        _buildMacroAverages(state, theme),
        const SizedBox(height: 20),
        _buildHighlights(state, theme),
      ],
    );
  }

  // ── 7-day calorie bar chart ──────────────────────────────────────────────────

  Widget _buildChartCard(WeeklyNutritionState state, ThemeData theme) {
    final plans = state.plans;
    final target = state.avgCalorieTarget;

    // Determine chart Y upper bound: max of target and highest consumed, padded.
    final maxConsumed = plans.isEmpty
        ? 0.0
        : plans
            .map((p) => p.consumedCalories.toDouble())
            .reduce((a, b) => a > b ? a : b);
    final upperBound = (maxConsumed > target ? maxConsumed : target) * 1.25;
    final safeUpper = upperBound < 500 ? 2500.0 : upperBound;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Calories Consumed',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  Text(
                    '7-day view',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.blue.shade400,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text('Consumed', style: TextStyle(fontSize: 11)),
                  const SizedBox(width: 10),
                  Container(
                    width: 20,
                    height: 2,
                    color: Colors.orange.shade600,
                  ),
                  const SizedBox(width: 4),
                  const Text('Target', style: TextStyle(fontSize: 11)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: plans.isEmpty
                ? const Center(
                    child: Text(
                      'No data for this week',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : BarChart(_buildBarChartData(plans, target, safeUpper)),
          ),
        ],
      ),
    );
  }

  BarChartData _buildBarChartData(
    List<MealPlanEntity> plans,
    double target,
    double upperBound,
  ) {
    return BarChartData(
      maxY: upperBound,
      extraLinesData: ExtraLinesData(
        horizontalLines: [
          HorizontalLine(
            y: target,
            color: Colors.orange.shade600,
            strokeWidth: 1.5,
            dashArray: [6, 4],
            label: HorizontalLineLabel(
              show: true,
              alignment: Alignment.topRight,
              labelResolver: (_) => 'Target',
              style: TextStyle(
                fontSize: 9,
                color: Colors.orange.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      barTouchData: BarTouchData(
        enabled: true,
        touchTooltipData: BarTouchTooltipData(
          getTooltipItem: (group, groupIndex, rod, rodIndex) {
            final plan = plans[group.x.toInt()];
            final consumed = plan.consumedCalories;
            final planTarget = plan.totalCalories ?? target.round();
            return BarTooltipItem(
              '${_shortDateLabel(plan.planDate)}\n',
              const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
              children: [
                TextSpan(
                  text: '$consumed kcal\n',
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
                TextSpan(
                  text: 'Target: $planTarget kcal',
                  style: const TextStyle(color: Colors.white54, fontSize: 10),
                ),
              ],
            );
          },
        ),
      ),
      titlesData: FlTitlesData(
        show: true,
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
            getTitlesWidget: (value, meta) {
              final index = value.toInt();
              if (index >= 0 && index < plans.length) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _shortDateLabel(plans[index].planDate),
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              }
              return const Text('');
            },
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 44,
            getTitlesWidget: (value, meta) {
              // Show round numbers at reasonable intervals only.
              if (value % 500 == 0) {
                return Text(
                  '${(value / 1000).toStringAsFixed(value >= 1000 ? 1 : 0)}k',
                  style: const TextStyle(fontSize: 9),
                );
              }
              return const Text('');
            },
          ),
        ),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        topTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
      ),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: upperBound / 4,
        getDrawingHorizontalLine: (_) => FlLine(
          color: Colors.grey.shade200,
          strokeWidth: 1,
        ),
      ),
      borderData: FlBorderData(
        show: true,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300),
          left: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      barGroups: plans.asMap().entries.map((entry) {
        final plan = entry.value;
        final consumed = plan.consumedCalories.toDouble();
        final planTarget = (plan.totalCalories ?? target).toDouble();
        final barColor = _calorieBarColor(consumed, planTarget);

        return BarChartGroupData(
          x: entry.key,
          barRods: [
            BarChartRodData(
              toY: consumed == 0 ? 0.0 : consumed,
              color: barColor,
              width: 22,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(4),
              ),
              backDrawRodData: BackgroundBarChartRodData(
                show: true,
                toY: upperBound,
                color: Colors.grey.shade100,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  /// Colour-codes a bar based on how close consumed is to target.
  Color _calorieBarColor(double consumed, double target) {
    if (consumed == 0) return Colors.grey.shade300;
    if (target <= 0) return Colors.blue.shade400;
    final ratio = consumed / target;
    if (ratio >= 0.90 && ratio <= 1.10) return Colors.green.shade400;
    if (ratio < 0.90) return Colors.blue.shade400; // under target
    return Colors.orange.shade400; // over target
  }

  // ── Macro averages ───────────────────────────────────────────────────────────

  Widget _buildMacroAverages(WeeklyNutritionState state, ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Daily Averages (logged days)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildMacroStat(
                  label: 'Protein',
                  value: '${state.avgProteinG.round()}g',
                  icon: Icons.fitness_center_outlined,
                  color: Colors.blue.shade600,
                ),
                const SizedBox(width: 8),
                _buildMacroStat(
                  label: 'Carbs',
                  value: '${state.avgCarbsG.round()}g',
                  icon: Icons.grain_outlined,
                  color: Colors.amber.shade700,
                ),
                const SizedBox(width: 8),
                _buildMacroStat(
                  label: 'Fat',
                  value: '${state.avgFatG.round()}g',
                  icon: Icons.water_drop_outlined,
                  color: Colors.orange.shade600,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Avg daily calories',
                    style: TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                  Text(
                    '${state.avgConsumedCalories.round()} kcal',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
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

  Widget _buildMacroStat({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  // ── Best / worst day highlights ──────────────────────────────────────────────

  Widget _buildHighlights(WeeklyNutritionState state, ThemeData theme) {
    final best = state.bestDay;
    final worst = state.worstDay;

    // Only show highlights if we have more than one logged day;
    // otherwise best and worst are the same day, which is misleading.
    if (best == null || worst == null || state.loggedDays.length < 2) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Week Highlights',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildHighlightRow(
              label: 'Best day',
              date: _shortDateLabel(best.planDate),
              detail: _targetDiffLabel(best, state.avgCalorieTarget),
              icon: Icons.star_outline_rounded,
              color: Colors.green.shade600,
            ),
            const Divider(height: 20),
            _buildHighlightRow(
              label: 'Most off-target',
              date: _shortDateLabel(worst.planDate),
              detail: _targetDiffLabel(worst, state.avgCalorieTarget),
              icon: Icons.flag_outlined,
              color: Colors.orange.shade600,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHighlightRow({
    required String label,
    required String date,
    required String detail,
    required IconData icon,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                    fontSize: 12, color: Colors.grey),
              ),
              Text(
                date,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Text(
          detail,
          style: TextStyle(
            fontSize: 13,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  String _shortDateLabel(DateTime date) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    // weekday: 1=Mon … 7=Sun
    return days[date.weekday - 1];
  }

  String _targetDiffLabel(MealPlanEntity plan, double avgTarget) {
    final target = (plan.totalCalories ?? avgTarget).toDouble();
    final diff = plan.consumedCalories - target;
    if (diff == 0) return 'On target';
    final sign = diff > 0 ? '+' : '';
    return '$sign${diff.round()} kcal';
  }
}
