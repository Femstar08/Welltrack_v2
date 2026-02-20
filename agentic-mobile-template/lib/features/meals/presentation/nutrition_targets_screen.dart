import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../profile/data/profile_repository.dart';
import '../../../shared/core/router/app_router.dart';
import '../data/macro_calculator.dart';
import 'nutrition_targets_provider.dart';

class NutritionTargetsScreen extends ConsumerStatefulWidget {
  const NutritionTargetsScreen({super.key});

  @override
  ConsumerState<NutritionTargetsScreen> createState() =>
      _NutritionTargetsScreenState();
}

class _NutritionTargetsScreenState
    extends ConsumerState<NutritionTargetsScreen> {
  String? _profileId;
  bool _profileLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profileId = ref.read(activeProfileIdProvider);
    if (profileId != null && profileId.isNotEmpty) {
      setState(() => _profileId = profileId);
      await _fetchAndLoad(profileId);
      return;
    }
    // Fallback: fetch active profile
    try {
      final repo = ref.read(profileRepositoryProvider);
      final profile = await repo.getActiveProfile();
      if (profile != null && mounted) {
        setState(() => _profileId = profile.id);
        await _fetchAndLoad(profile.id, profile: profile);
      }
    } catch (_) {}
  }

  Future<void> _fetchAndLoad(String profileId,
      {dynamic profile}) async {
    if (profile == null) {
      try {
        final repo = ref.read(profileRepositoryProvider);
        profile = await repo.getProfile(profileId);
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() => _profileLoaded = true);
    await ref.read(nutritionTargetsProvider(profileId).notifier).loadTargets(
          weightKg: profile?.weightKg,
          activityLevel: profile?.activityLevel,
          fitnessGoal: profile?.primaryGoal,
          gender: profile?.gender,
          age: profile?.age,
        );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (!_profileLoaded || _profileId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Nutrition Targets')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final state = ref.watch(nutritionTargetsProvider(_profileId!));

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Nutrition Targets'),
        centerTitle: false,
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Text(
                      'Set custom macro targets per training day type. '
                      'When set, these override the auto-calculated values.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                if (state.error != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: _ErrorBanner(
                        message: state.error!,
                        onDismiss: () => ref
                            .read(nutritionTargetsProvider(_profileId!).notifier)
                            .loadTargets(),
                      ),
                    ),
                  ),
                SliverPadding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _DayTypeCard(
                        profileId: _profileId!,
                        dayType: 'strength',
                        label: 'Strength Day',
                        icon: Icons.fitness_center_rounded,
                        iconColor: colorScheme.primary,
                        targetState: state.strength,
                      ),
                      const SizedBox(height: 12),
                      _DayTypeCard(
                        profileId: _profileId!,
                        dayType: 'cardio',
                        label: 'Cardio Day',
                        icon: Icons.directions_run_rounded,
                        iconColor: Colors.orange,
                        targetState: state.cardio,
                      ),
                      const SizedBox(height: 12),
                      _DayTypeCard(
                        profileId: _profileId!,
                        dayType: 'rest',
                        label: 'Rest Day',
                        icon: Icons.self_improvement_rounded,
                        iconColor: Colors.teal,
                        targetState: state.rest,
                      ),
                      const SizedBox(height: 32),
                    ]),
                  ),
                ),
              ],
            ),
    );
  }
}

class _DayTypeCard extends ConsumerStatefulWidget {
  const _DayTypeCard({
    required this.profileId,
    required this.dayType,
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.targetState,
  });

  final String profileId;
  final String dayType;
  final String label;
  final IconData icon;
  final Color iconColor;
  final DayTypeTargetState targetState;

  @override
  ConsumerState<_DayTypeCard> createState() => _DayTypeCardState();
}

class _DayTypeCardState extends ConsumerState<_DayTypeCard> {
  late bool _isCustom;
  late TextEditingController _caloriesCtrl;
  late TextEditingController _proteinCtrl;
  late TextEditingController _carbsCtrl;
  late TextEditingController _fatCtrl;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _isCustom = widget.targetState.isCustom;
    _initControllers(widget.targetState);
  }

  @override
  void didUpdateWidget(covariant _DayTypeCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.targetState != widget.targetState) {
      _isCustom = widget.targetState.isCustom;
      _updateControllers(widget.targetState);
    }
  }

  void _initControllers(DayTypeTargetState s) {
    _caloriesCtrl =
        TextEditingController(text: s.calories > 0 ? '${s.calories}' : '');
    _proteinCtrl =
        TextEditingController(text: s.proteinG > 0 ? '${s.proteinG}' : '');
    _carbsCtrl =
        TextEditingController(text: s.carbsG > 0 ? '${s.carbsG}' : '');
    _fatCtrl = TextEditingController(text: s.fatG > 0 ? '${s.fatG}' : '');
  }

  void _updateControllers(DayTypeTargetState s) {
    _caloriesCtrl.text = s.calories > 0 ? '${s.calories}' : '';
    _proteinCtrl.text = s.proteinG > 0 ? '${s.proteinG}' : '';
    _carbsCtrl.text = s.carbsG > 0 ? '${s.carbsG}' : '';
    _fatCtrl.text = s.fatG > 0 ? '${s.fatG}' : '';
  }

  @override
  void dispose() {
    _caloriesCtrl.dispose();
    _proteinCtrl.dispose();
    _carbsCtrl.dispose();
    _fatCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final calories = int.tryParse(_caloriesCtrl.text.trim());
    final protein = int.tryParse(_proteinCtrl.text.trim());
    final carbs = int.tryParse(_carbsCtrl.text.trim());
    final fat = int.tryParse(_fatCtrl.text.trim());

    if (calories == null || protein == null || carbs == null || fat == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid numbers for all fields')),
      );
      return;
    }

    if (calories < 800 || calories > 8000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Calories must be between 800 and 8000')),
      );
      return;
    }

    await ref
        .read(nutritionTargetsProvider(widget.profileId).notifier)
        .saveTarget(
          dayType: widget.dayType,
          calories: calories,
          proteinG: protein,
          carbsG: carbs,
          fatG: fat,
        );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${widget.label} targets saved'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _delete() async {
    await ref
        .read(nutritionTargetsProvider(widget.profileId).notifier)
        .deleteTarget(widget.dayType);
    if (mounted) {
      setState(() => _isCustom = false);
      _updateControllers(widget.targetState);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final s = widget.targetState;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: _isCustom
              ? widget.iconColor.withOpacity(0.4)
              : colorScheme.outlineVariant,
        ),
      ),
      child: ExpansionTile(
        initiallyExpanded: _expanded,
        onExpansionChanged: (v) => setState(() => _expanded = v),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: widget.iconColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(widget.icon, color: widget.iconColor, size: 22),
        ),
        title: Text(
          widget.label,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: _isCustom
            ? Text(
                'Custom · ${s.calories} kcal',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: widget.iconColor,
                  fontWeight: FontWeight.w500,
                ),
              )
            : Text(
                'Auto · ${s.calculated?.calories ?? 0} kcal',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
        trailing: s.isSaving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : null,
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          // Custom toggle
          Row(
            children: [
              Icon(
                Icons.tune_rounded,
                size: 18,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Use custom targets',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              Switch(
                value: _isCustom,
                activeColor: widget.iconColor,
                onChanged: (v) {
                  setState(() => _isCustom = v);
                  if (!v && s.custom != null) {
                    _delete();
                  } else if (v) {
                    // Pre-fill with calculated values when enabling
                    final calc = s.calculated;
                    if (calc != null) {
                      _caloriesCtrl.text = '${calc.calories}';
                      _proteinCtrl.text = '${calc.proteinG}';
                      _carbsCtrl.text = '${calc.carbsG}';
                      _fatCtrl.text = '${calc.fatG}';
                    }
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Macro fields
          Row(
            children: [
              Expanded(
                child: _MacroField(
                  controller: _caloriesCtrl,
                  label: 'Calories',
                  unit: 'kcal',
                  enabled: _isCustom,
                  accentColor: widget.iconColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MacroField(
                  controller: _proteinCtrl,
                  label: 'Protein',
                  unit: 'g',
                  enabled: _isCustom,
                  accentColor: widget.iconColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _MacroField(
                  controller: _carbsCtrl,
                  label: 'Carbs',
                  unit: 'g',
                  enabled: _isCustom,
                  accentColor: widget.iconColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MacroField(
                  controller: _fatCtrl,
                  label: 'Fat',
                  unit: 'g',
                  enabled: _isCustom,
                  accentColor: widget.iconColor,
                ),
              ),
            ],
          ),
          if (_isCustom) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: s.isSaving ? null : _save,
                icon: const Icon(Icons.save_rounded, size: 18),
                label: Text('Save ${widget.label} Targets'),
                style: FilledButton.styleFrom(
                  backgroundColor: widget.iconColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
          if (!_isCustom && s.calculated != null) ...[
            const SizedBox(height: 12),
            _AutoCalculatedInfo(targets: s.calculated!),
          ],
        ],
      ),
    );
  }
}

class _MacroField extends StatelessWidget {
  const _MacroField({
    required this.controller,
    required this.label,
    required this.unit,
    required this.enabled,
    required this.accentColor,
  });

  final TextEditingController controller;
  final String label;
  final String unit;
  final bool enabled;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: theme.textTheme.bodyLarge?.copyWith(
        color: enabled ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: label,
        suffixText: unit,
        suffixStyle: theme.textTheme.bodySmall?.copyWith(
          color: enabled ? accentColor : colorScheme.onSurfaceVariant,
        ),
        filled: true,
        fillColor: enabled
            ? accentColor.withOpacity(0.06)
            : colorScheme.surfaceContainerHighest.withOpacity(0.4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: accentColor.withOpacity(0.3)),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: accentColor, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        isDense: true,
      ),
    );
  }
}

class _AutoCalculatedInfo extends StatelessWidget {
  const _AutoCalculatedInfo({required this.targets});
  final MacroTargets targets;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Auto-calculated targets',
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _MacroChip(label: 'Cal', value: '${targets.calories}'),
              const SizedBox(width: 8),
              _MacroChip(label: 'P', value: '${targets.proteinG}g'),
              const SizedBox(width: 8),
              _MacroChip(label: 'C', value: '${targets.carbsG}g'),
              const SizedBox(width: 8),
              _MacroChip(label: 'F', value: '${targets.fatG}g'),
            ],
          ),
        ],
      ),
    );
  }
}

class _MacroChip extends StatelessWidget {
  const _MacroChip({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onDismiss});
  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: Theme.of(context).colorScheme.onErrorContainer,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20),
            onPressed: onDismiss,
            color: Theme.of(context).colorScheme.onErrorContainer,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

