// lib/features/bloodwork/presentation/bloodwork_screen.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../domain/bloodwork_entity.dart';
import '../domain/bloodwork_test_types.dart';
import 'bloodwork_provider.dart';
import 'widgets/ai_interpretation_card.dart';

/// Bloodwork log screen — grouped summary view with per-category tabs.
///
/// Category tabs:  Hormones | Metabolic | Cardiovascular | Vitamins & Thyroid
/// Each tab shows the latest value per test in that category, colour-coded:
///   - Green  : within normal range
///   - Amber  : borderline (within 10 % of a range boundary)
///   - Red    : out of range
///
/// The FAB opens a bottom sheet to add a new result.
class BloodworkScreen extends ConsumerStatefulWidget {
  const BloodworkScreen({super.key, required this.profileId});

  final String profileId;

  @override
  ConsumerState<BloodworkScreen> createState() => _BloodworkScreenState();
}

class _BloodworkScreenState extends ConsumerState<BloodworkScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  static const _categories = BloodworkCategory.values;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);
    Future.microtask(() {
      ref.read(bloodworkProvider(widget.profileId).notifier).loadResults();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ─── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(bloodworkProvider(widget.profileId));
    final theme = Theme.of(context);

    // Show error snackbar when a write fails.
    ref.listen(bloodworkProvider(widget.profileId), (previous, next) {
      if (next.error != null && next.error != previous?.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: theme.colorScheme.error,
            action: SnackBarAction(
              label: 'Dismiss',
              onPressed: () {
                ref
                    .read(bloodworkProvider(widget.profileId).notifier)
                    .clearError();
              },
            ),
          ),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bloodwork'),
        actions: [
          if (state.outOfRangeCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Chip(
                avatar: const Icon(Icons.warning_amber_rounded, size: 16),
                label: Text('${state.outOfRangeCount} flagged'),
                backgroundColor: theme.colorScheme.errorContainer,
                labelStyle: TextStyle(
                  color: theme.colorScheme.onErrorContainer,
                  fontSize: 12,
                ),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: _categories
              .map((c) => Tab(text: c.displayName))
              .toList(),
        ),
      ),
      body: state.isLoading && state.results.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ── Tab results ──────────────────────────────────────────────
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: _categories
                        .map(
                          (category) => _CategoryTab(
                            category: category,
                            profileId: widget.profileId,
                            latestByTest: state.latestByTest,
                            allResults: state.results,
                          ),
                        )
                        .toList(),
                  ),
                ),

                // ── AI interpretation section ────────────────────────────────
                _AiInterpretationSection(profileId: widget.profileId),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddResultSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Result'),
      ),
    );
  }

  // ─── Add result bottom sheet ───────────────────────────────────────────────

  Future<void> _showAddResultSheet(BuildContext context) async {
    unawaited(HapticFeedback.selectionClick());
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _AddResultSheet(profileId: widget.profileId),
    );
  }
}

// ─── Category Tab ─────────────────────────────────────────────────────────────

class _CategoryTab extends ConsumerWidget {
  const _CategoryTab({
    required this.category,
    required this.profileId,
    required this.latestByTest,
    required this.allResults,
  });

  final BloodworkCategory category;
  final String profileId;
  final Map<String, BloodworkEntity> latestByTest;
  final List<BloodworkEntity> allResults;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final testTypes = BloodworkTestType.catalogue
        .where((t) => t.category == category)
        .toList();

    // Also include any custom-named results in this category.
    // Custom results have a testName that is NOT in the catalogue.
    final catalogueNames = BloodworkTestType.catalogue.map((t) => t.name).toSet();
    final customResults = latestByTest.values
        .where(
          (e) =>
              !catalogueNames.contains(e.testName) &&
              // Associate custom results with the Hormones tab only;
              // users can view them there since we have no category info.
              category == BloodworkCategory.hormones,
        )
        .toList();

    if (testTypes.isEmpty && customResults.isEmpty) {
      return const Center(child: Text('No tests in this category.'));
    }

    final allItems = [
      ...testTypes.map((t) => _TestRowData.fromType(t, latestByTest[t.name])),
      ...customResults.map(
        (e) => _TestRowData.fromEntity(e),
      ),
    ];

    if (allItems.every((item) => item.latest == null) &&
        customResults.isEmpty) {
      return _EmptyCategoryPlaceholder(category: category);
    }

    return RefreshIndicator(
      onRefresh: () async {
        await ref
            .read(bloodworkProvider(profileId).notifier)
            .loadResults();
      },
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        itemCount: allItems.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final item = allItems[index];
          return _TestResultCard(
            data: item,
            profileId: profileId,
            allResults: allResults,
          );
        },
      ),
    );
  }
}

// ─── Empty placeholder ─────────────────────────────────────────────────────────

class _EmptyCategoryPlaceholder extends StatelessWidget {
  const _EmptyCategoryPlaceholder({required this.category});

  final BloodworkCategory category;

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
              Icons.science_outlined,
              size: 56,
              color: theme.colorScheme.onSurface.withAlpha(80),
            ),
            const SizedBox(height: 16),
            Text(
              'No ${category.displayName} results yet',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Tap "Add Result" to log your first lab result.',
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Row data DTO ──────────────────────────────────────────────────────────────

class _TestRowData {
  const _TestRowData({
    required this.name,
    required this.unit,
    this.referenceLow,
    this.referenceHigh,
    this.rangeNote,
    this.latest,
  });

  factory _TestRowData.fromType(
    BloodworkTestType type,
    BloodworkEntity? latest,
  ) {
    return _TestRowData(
      name: type.name,
      unit: type.unit,
      referenceLow: type.referenceLow,
      referenceHigh: type.referenceHigh,
      rangeNote: type.rangeNote,
      latest: latest,
    );
  }

  factory _TestRowData.fromEntity(BloodworkEntity entity) {
    return _TestRowData(
      name: entity.testName,
      unit: entity.unit,
      referenceLow: entity.referenceRangeLow,
      referenceHigh: entity.referenceRangeHigh,
      latest: entity,
    );
  }

  final String name;
  final String unit;
  final double? referenceLow;
  final double? referenceHigh;
  final String? rangeNote;
  final BloodworkEntity? latest;
}

// ─── Test result card ──────────────────────────────────────────────────────────

class _TestResultCard extends ConsumerWidget {
  const _TestResultCard({
    required this.data,
    required this.profileId,
    required this.allResults,
  });

  final _TestRowData data;
  final String profileId;
  final List<BloodworkEntity> allResults;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final latest = data.latest;

    Color statusColor;
    IconData statusIcon;

    if (latest == null) {
      statusColor = theme.colorScheme.onSurface.withAlpha(80);
      statusIcon = Icons.remove_circle_outline;
    } else if (latest.isOutOfRange) {
      statusColor = theme.colorScheme.error;
      statusIcon = Icons.warning_amber_rounded;
    } else if (latest.isBorderline) {
      statusColor = const Color(0xFFF59E0B); // amber
      statusIcon = Icons.info_outline;
    } else {
      statusColor = const Color(0xFF22C55E); // green
      statusIcon = Icons.check_circle_outline;
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: latest != null
              ? statusColor.withAlpha(76)
              : theme.colorScheme.outline.withAlpha(30),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        // Primary tap: navigate to the trend chart / detail screen.
        onTap: latest != null
            ? () => context.push(
                '/bloodwork/${Uri.encodeComponent(data.name)}',
              )
            : null,
        // Long-press: edit / delete options.
        onLongPress: latest != null
            ? () => _showResultOptions(context, ref, latest)
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Status icon
              Icon(statusIcon, color: statusColor, size: 20),
              const SizedBox(width: 12),

              // Name + range
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.name,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      data.rangeNote ?? _rangeText(data),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withAlpha(153),
                      ),
                    ),
                  ],
                ),
              ),

              // Value + date
              if (latest != null) ...[
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatValue(latest.valueNum),
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          latest.unit,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      _formatDate(latest.testDate),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurface.withAlpha(120),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 4),
                if (latest.isOutOfRange)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '!',
                      style: TextStyle(
                        color: theme.colorScheme.onErrorContainer,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                const SizedBox(width: 4),
                Icon(
                  Icons.show_chart,
                  size: 16,
                  color: theme.colorScheme.onSurface.withAlpha(80),
                ),
              ] else
                Text(
                  '—',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withAlpha(80),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _rangeText(_TestRowData data) {
    if (data.referenceLow != null && data.referenceHigh != null) {
      return '${_formatValue(data.referenceLow!)} – ${_formatValue(data.referenceHigh!)} ${data.unit}';
    }
    if (data.referenceLow != null) {
      return '> ${_formatValue(data.referenceLow!)} ${data.unit}';
    }
    if (data.referenceHigh != null) {
      return '< ${_formatValue(data.referenceHigh!)} ${data.unit}';
    }
    return data.unit;
  }

  String _formatValue(double v) {
    // Show up to 2 decimal places, strip trailing zeros.
    return v.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}';
  }

  void _showResultOptions(
    BuildContext context,
    WidgetRef ref,
    BloodworkEntity entity,
  ) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit result'),
              onTap: () {
                Navigator.pop(ctx);
                showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => _AddResultSheet(
                    profileId: profileId,
                    existing: entity,
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(
                Icons.delete_outline,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                'Delete result',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDelete(context, ref, entity);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    BloodworkEntity entity,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete result?'),
        content: Text(
          'Remove the ${entity.testName} result from ${_formatDate(entity.testDate)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && entity.id != null) {
      await ref
          .read(bloodworkProvider(profileId).notifier)
          .deleteResult(entity.id!);
    }
  }
}

// ─── AI interpretation section ─────────────────────────────────────────────────

/// Bottom panel that hosts the "Get AI Suggestion" button and, once a result
/// is available, the [AiInterpretationCard].
///
/// Consent handling:
/// - If the user has not enabled "Share bloodwork data with AI" in Settings,
///   a dialog is shown prompting them to enable it there.
/// - If consent is granted, the AI interpretation is requested immediately.
class _AiInterpretationSection extends ConsumerWidget {
  const _AiInterpretationSection({required this.profileId});

  final String profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(bloodworkProvider(profileId));
    final notifier = ref.read(bloodworkProvider(profileId).notifier);
    final theme = Theme.of(context);

    // Handle consent error returned by the notifier — show a dialog pointing
    // the user to Settings, then clear the error so it does not re-trigger.
    ref.listen(bloodworkProvider(profileId), (previous, next) {
      if (next.aiError == 'consent_required' &&
          next.aiError != previous?.aiError) {
        notifier.clearAiInterpretation();
        _showConsentDialog(context);
      }
    });

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outline.withAlpha(40),
          ),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Show the card when an interpretation (or error) is present.
          if (state.aiInterpretation != null ||
              (state.aiError != null &&
                  state.aiError != 'consent_required')) ...[
            AiInterpretationCard(
              interpretation: state.aiInterpretation,
              isLoading: state.isLoadingAi,
              error: state.aiError,
              onRetry: () => notifier.requestAiInterpretation(),
            ),
            const SizedBox(height: 12),
          ] else if (state.isLoadingAi) ...[
            const AiInterpretationCard(
              interpretation: null,
              isLoading: true,
            ),
            const SizedBox(height: 12),
          ],

          // Primary action button.
          OutlinedButton.icon(
            onPressed: state.isLoadingAi || state.results.isEmpty
                ? null
                : () => notifier.requestAiInterpretation(),
            icon: state.isLoadingAi
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome_outlined, size: 18),
            label: Text(
              state.aiInterpretation != null
                  ? 'Refresh AI Suggestion'
                  : 'Get AI Suggestion',
            ),
          ),

          if (state.results.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Add bloodwork results first to enable AI suggestions.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withAlpha(120),
                ),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  void _showConsentDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('AI Consent Required'),
        content: const Text(
          'To receive AI suggestions on your bloodwork, enable '
          '"Share bloodwork data with AI" in Settings > Privacy & AI.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              // Navigate to settings — the settings route is /settings.
              context.push('/settings');
            },
            child: const Text('Go to Settings'),
          ),
        ],
      ),
    );
  }
}

// ─── Add / Edit result bottom sheet ───────────────────────────────────────────

class _AddResultSheet extends ConsumerStatefulWidget {
  const _AddResultSheet({
    required this.profileId,
    this.existing,
  });

  final String profileId;

  /// When non-null the sheet operates in edit mode.
  final BloodworkEntity? existing;

  @override
  ConsumerState<_AddResultSheet> createState() => _AddResultSheetState();
}

class _AddResultSheetState extends ConsumerState<_AddResultSheet> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  late final TextEditingController _valueController;
  late final TextEditingController _notesController;
  late final TextEditingController _customNameController;

  // Selected test (null = custom name entered)
  BloodworkTestType? _selectedType;
  bool _useCustomName = false;
  DateTime _selectedDate = DateTime.now();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _valueController =
          TextEditingController(text: _formatValue(existing.valueNum));
      _notesController = TextEditingController(text: existing.notes ?? '');
      _customNameController =
          TextEditingController(text: existing.testName);
      _selectedDate = existing.testDate;

      final found =
          BloodworkTestType.findByName(existing.testName);
      if (found != null) {
        _selectedType = found;
        _useCustomName = false;
      } else {
        _useCustomName = true;
      }
    } else {
      _valueController = TextEditingController();
      _notesController = TextEditingController();
      _customNameController = TextEditingController();
    }
  }

  @override
  void dispose() {
    _valueController.dispose();
    _notesController.dispose();
    _customNameController.dispose();
    super.dispose();
  }

  String _formatValue(double v) =>
      v.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEdit = widget.existing != null;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomInset),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title
              Text(
                isEdit ? 'Edit Result' : 'Add Result',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),

              // Test type selector
              if (!_useCustomName) ...[
                DropdownButtonFormField<BloodworkTestType>(
                  initialValue: _selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Test type',
                    border: OutlineInputBorder(),
                  ),
                  items: BloodworkTestType.catalogue
                      .map(
                        (t) => DropdownMenuItem(
                          value: t,
                          child: Text(t.name),
                        ),
                      )
                      .toList(),
                  onChanged: (t) => setState(() => _selectedType = t),
                  validator: (_) =>
                      (!_useCustomName && _selectedType == null)
                          ? 'Select a test type'
                          : null,
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => setState(() => _useCustomName = true),
                  child: const Text('Enter custom test name'),
                ),
              ] else ...[
                TextFormField(
                  controller: _customNameController,
                  decoration: const InputDecoration(
                    labelText: 'Test name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Enter a test name'
                      : null,
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () =>
                      setState(() => _useCustomName = false),
                  child: const Text('Pick from catalogue'),
                ),
              ],

              const SizedBox(height: 12),

              // Value + unit row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _valueController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Value',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Required';
                        }
                        if (double.tryParse(v.trim()) == null) {
                          return 'Enter a number';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Unit',
                        border: OutlineInputBorder(),
                      ),
                      child: Text(
                        _resolvedUnit,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Date picker
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(8),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Test date',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today_outlined),
                  ),
                  child: Text(_formatDate(_selectedDate)),
                ),
              ),

              const SizedBox(height: 16),

              // Notes
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),

              const SizedBox(height: 24),

              // Save button
              FilledButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(isEdit ? 'Save changes' : 'Add result'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  /// The unit to display — comes from the selected catalogue type, or from the
  /// existing entity when editing a custom test.
  String get _resolvedUnit {
    if (_selectedType != null) return _selectedType!.unit;
    if (widget.existing != null) return widget.existing!.unit;
    return '—';
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final testType = _selectedType;
    final customName = _customNameController.text.trim();
    final testName = _useCustomName ? customName : testType!.name;
    final unit = testType?.unit ?? (widget.existing?.unit ?? '');
    final value = double.parse(_valueController.text.trim());
    final notes = _notesController.text.trim();

    final entity = BloodworkEntity(
      id: widget.existing?.id,
      profileId: widget.profileId,
      testName: testName,
      valueNum: value,
      unit: unit,
      referenceRangeLow:
          testType?.referenceLow ?? widget.existing?.referenceRangeLow,
      referenceRangeHigh:
          testType?.referenceHigh ?? widget.existing?.referenceRangeHigh,
      testDate: _selectedDate,
      notes: notes.isEmpty ? null : notes,
      isSensitive: true,
    );

    try {
      final notifier =
          ref.read(bloodworkProvider(widget.profileId).notifier);

      if (widget.existing != null) {
        await notifier.updateResult(entity);
      } else {
        await notifier.addResult(entity);
      }

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    }
  }
}
