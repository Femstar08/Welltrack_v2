// lib/features/supplements/presentation/supplements_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../domain/supplement_entity.dart';
import '../domain/supplement_protocol_entity.dart';
import '../domain/supplement_log_entity.dart';
import 'supplement_provider.dart';

class SupplementsScreen extends ConsumerStatefulWidget {

  const SupplementsScreen({
    required this.profileId,
    super.key,
  });
  final String profileId;

  @override
  ConsumerState<SupplementsScreen> createState() => _SupplementsScreenState();
}

class _SupplementsScreenState extends ConsumerState<SupplementsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    Future.microtask(() {
      ref.read(supplementProvider(widget.profileId).notifier).loadData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(supplementProvider(widget.profileId));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Supplements'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Today\'s Protocol'),
            Tab(text: 'All Supplements'),
          ],
        ),
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildTodayTab(context, state),
                _buildAllSupplementsTab(context, state),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSupplementDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Supplement'),
      ),
    );
  }

  Widget _buildTodayTab(BuildContext context, SupplementState state) {
    final activeProtocols = state.activeProtocols;
    final logsByProtocol = state.todayLogsByProtocol;

    if (activeProtocols.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.medication_outlined,
              size: 80,
              color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No active supplement protocols',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text('Add supplements and create protocols to get started'),
          ],
        ),
      );
    }

    final groupedByTime = <ProtocolTimeOfDay, List<SupplementProtocolEntity>>{};
    for (final protocol in activeProtocols) {
      groupedByTime.putIfAbsent(protocol.timeOfDay, () => []).add(protocol);
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(supplementProvider(widget.profileId).notifier).loadData(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircularProgressIndicator(
                    value: state.completionPercentage / 100,
                    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Today\'s Progress',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          '${state.completionPercentage.toStringAsFixed(0)}% Complete',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ...groupedByTime.entries.map((entry) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    entry.key.label,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                ...entry.value.map((protocol) {
                  final log = logsByProtocol[protocol.id];
                  return _buildProtocolCard(context, protocol, log);
                }),
                const SizedBox(height: 8),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildProtocolCard(
    BuildContext context,
    SupplementProtocolEntity protocol,
    SupplementLogEntity? log,
  ) {
    final isTaken = log?.isTaken ?? false;
    final isSkipped = log?.isSkipped ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          isTaken
              ? Icons.check_circle
              : isSkipped
                  ? Icons.cancel
                  : Icons.radio_button_unchecked,
          color: isTaken
              ? Colors.green
              : isSkipped
                  ? Colors.orange
                  : null,
        ),
        title: Text(protocol.supplementName),
        subtitle: Text('${protocol.dosage} ${protocol.unit}'),
        trailing: log == null
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.check, color: Colors.green),
                    onPressed: () => _logSupplement(
                      protocol,
                      SupplementLogStatus.taken,
                    ),
                    tooltip: 'Mark as taken',
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.orange),
                    onPressed: () => _logSupplement(
                      protocol,
                      SupplementLogStatus.skipped,
                    ),
                    tooltip: 'Mark as skipped',
                  ),
                ],
              )
            : Text(
                '${log.takenAt.hour.toString().padLeft(2, '0')}:${log.takenAt.minute.toString().padLeft(2, '0')}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
      ),
    );
  }

  Widget _buildAllSupplementsTab(BuildContext context, SupplementState state) {
    if (state.supplements.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.medication_outlined,
              size: 80,
              color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No supplements added',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text('Tap the + button to add your first supplement'),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(supplementProvider(widget.profileId).notifier).loadData(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: state.supplements.length,
        itemBuilder: (context, index) {
          final supplement = state.supplements[index];
          final protocols = state.protocols
              .where((p) => p.supplementId == supplement.id)
              .toList();

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ExpansionTile(
              leading: const Icon(Icons.medication),
              title: Text(supplement.name),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (supplement.brand != null)
                    Text('Brand: ${supplement.brand}'),
                  Text('${supplement.dosage} ${supplement.unit}'),
                  if (protocols.isNotEmpty)
                    Text(
                      'Protocols: ${protocols.where((p) => p.isActive).length} active',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                ],
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (supplement.description != null) ...[
                        Text(
                          'Description',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(supplement.description!),
                        const SizedBox(height: 12),
                      ],
                      if (protocols.isNotEmpty) ...[
                        Text(
                          'Protocols',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        ...protocols.map((p) => ListTile(
                              dense: true,
                              leading: Icon(
                                p.isActive ? Icons.check : Icons.pause,
                                color: p.isActive ? Colors.green : Colors.grey,
                              ),
                              title: Text(p.timeOfDay.label),
                              subtitle: Text('${p.dosage} ${p.unit}'),
                              trailing: IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: () => _showEditProtocolDialog(context, p),
                              ),
                            )),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            onPressed: () => _showAddProtocolDialog(context, supplement.id, supplement.name),
                            icon: const Icon(Icons.add),
                            label: const Text('Add Protocol'),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () => _showEditSupplementDialog(context, supplement),
                            child: const Text('Edit'),
                          ),
                          TextButton(
                            onPressed: () => _confirmDelete(context, supplement.id),
                            style: TextButton.styleFrom(
                              foregroundColor: Theme.of(context).colorScheme.error,
                            ),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _logSupplement(
    SupplementProtocolEntity protocol,
    SupplementLogStatus status,
  ) {
    ref.read(supplementProvider(widget.profileId).notifier).logSupplement(
          supplementId: protocol.supplementId,
          supplementName: protocol.supplementName,
          protocolTime: protocol.timeOfDay,
          dosage: protocol.dosage,
          unit: protocol.unit,
          status: status,
        );
  }

  void _showAddSupplementDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => _AddSupplementSheet(
        profileId: widget.profileId,
        onSave: (name, brand, dosage, unit, notes) async {
          await ref.read(supplementProvider(widget.profileId).notifier).addSupplement(
                name: name,
                brand: brand?.isNotEmpty == true ? brand : null,
                dosage: dosage,
                unit: unit,
                notes: notes?.isNotEmpty == true ? notes : null,
              );
          if (sheetContext.mounted) Navigator.of(sheetContext).pop();
          final error = ref.read(supplementProvider(widget.profileId)).error;
          if (error != null && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: $error'), backgroundColor: Theme.of(context).colorScheme.error),
            );
          }
        },
      ),
    );
  }

  void _showEditSupplementDialog(BuildContext context, SupplementEntity supplement) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => _EditSupplementSheet(
        supplement: supplement,
        onSave: (name, brand, dosage, unit, notes) async {
          final updated = supplement.copyWith(
            name: name,
            brand: brand?.isNotEmpty == true ? brand : null,
            dosage: dosage,
            unit: unit,
            notes: notes?.isNotEmpty == true ? notes : null,
          );
          await ref.read(supplementProvider(widget.profileId).notifier).updateSupplement(updated);
          if (sheetContext.mounted) Navigator.of(sheetContext).pop();
          final error = ref.read(supplementProvider(widget.profileId)).error;
          if (error != null && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: $error'), backgroundColor: Theme.of(context).colorScheme.error),
            );
          }
        },
        onDelete: () async {
          final confirmed = await _confirmDeleteProtocol(sheetContext, 'supplement');
          if (!confirmed) return;
          if (sheetContext.mounted) Navigator.of(sheetContext).pop();
          await ref.read(supplementProvider(widget.profileId).notifier).deleteSupplement(supplement.id);
          final error = ref.read(supplementProvider(widget.profileId)).error;
          if (error != null && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: $error'), backgroundColor: Theme.of(context).colorScheme.error),
            );
          }
        },
      ),
    );
  }

  void _showAddProtocolDialog(BuildContext context, String supplementId, String supplementName) {
    final state = ref.read(supplementProvider(widget.profileId));
    final supplement = state.supplements.firstWhere((s) => s.id == supplementId);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => _AddProtocolSheet(
        supplementName: supplementName,
        defaultDosage: supplement.dosage,
        defaultUnit: supplement.unit,
        onSave: (timeOfDay, dosage, unit) async {
          await ref.read(supplementProvider(widget.profileId).notifier).addProtocol(
                supplementId: supplementId,
                supplementName: supplementName,
                timeOfDay: timeOfDay,
                dosage: dosage,
                unit: unit,
              );
          if (sheetContext.mounted) Navigator.of(sheetContext).pop();
          final error = ref.read(supplementProvider(widget.profileId)).error;
          if (error != null && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: $error'), backgroundColor: Theme.of(context).colorScheme.error),
            );
          }
        },
      ),
    );
  }

  void _showEditProtocolDialog(BuildContext context, SupplementProtocolEntity protocol) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => _EditProtocolSheet(
        protocol: protocol,
        onSave: (isActive, timeOfDay, dosage, unit) async {
          // Delete old, create updated — keeps the notifier API clean.
          await ref.read(supplementProvider(widget.profileId).notifier).deleteProtocol(protocol.id);
          await ref.read(supplementProvider(widget.profileId).notifier).addProtocol(
                supplementId: protocol.supplementId,
                supplementName: protocol.supplementName,
                timeOfDay: timeOfDay,
                dosage: dosage,
                unit: unit,
              );
          // Toggle active if needed (new protocol defaults to true).
          if (!isActive) {
            final state = ref.read(supplementProvider(widget.profileId));
            final newProtocol = state.protocols
                .where((p) =>
                    p.supplementId == protocol.supplementId &&
                    p.timeOfDay == timeOfDay)
                .lastOrNull;
            if (newProtocol != null) {
              await ref.read(supplementProvider(widget.profileId).notifier).toggleProtocol(newProtocol.id);
            }
          }
          if (sheetContext.mounted) Navigator.of(sheetContext).pop();
          final error = ref.read(supplementProvider(widget.profileId)).error;
          if (error != null && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: $error'), backgroundColor: Theme.of(context).colorScheme.error),
            );
          }
        },
        onDelete: () async {
          final confirmed = await _confirmDeleteProtocol(sheetContext, 'protocol');
          if (!confirmed) return;
          if (sheetContext.mounted) Navigator.of(sheetContext).pop();
          await ref.read(supplementProvider(widget.profileId).notifier).deleteProtocol(protocol.id);
          final error = ref.read(supplementProvider(widget.profileId)).error;
          if (error != null && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: $error'), backgroundColor: Theme.of(context).colorScheme.error),
            );
          }
        },
      ),
    );
  }

  Future<bool> _confirmDeleteProtocol(BuildContext context, String itemType) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete ${itemType[0].toUpperCase()}${itemType.substring(1)}'),
        content: Text(
          itemType == 'supplement'
              ? 'Are you sure you want to delete this supplement? This will also delete all associated protocols and logs.'
              : 'Are you sure you want to delete this protocol?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _confirmDelete(BuildContext context, String supplementId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Supplement'),
        content: const Text(
          'Are you sure you want to delete this supplement? This will also delete all associated protocols and logs.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(supplementProvider(widget.profileId).notifier).deleteSupplement(supplementId);
              Navigator.of(context).pop();
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

const _kUnits = ['mg', 'mcg', 'IU', 'g', 'ml'];

Widget _buildSectionLabel(BuildContext context, String label) {
  return Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 8),
    child: Text(label, style: Theme.of(context).textTheme.titleSmall),
  );
}

// ---------------------------------------------------------------------------
// _AddSupplementSheet
// ---------------------------------------------------------------------------

class _AddSupplementSheet extends StatefulWidget {
  const _AddSupplementSheet({
    required this.profileId,
    required this.onSave,
  });

  final String profileId;
  final Future<void> Function(
    String name,
    String? brand,
    double dosage,
    String unit,
    String? notes,
  ) onSave;

  @override
  State<_AddSupplementSheet> createState() => _AddSupplementSheetState();
}

class _AddSupplementSheetState extends State<_AddSupplementSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _brandController = TextEditingController();
  final _dosageController = TextEditingController();
  final _notesController = TextEditingController();

  String _selectedUnit = 'mg';
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _dosageController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    await widget.onSave(
      _nameController.text.trim(),
      _brandController.text.trim(),
      double.parse(_dosageController.text.trim()),
      _selectedUnit,
      _notesController.text.trim(),
    );
    if (mounted) setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Add Supplement',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildSectionLabel(context, 'Name *'),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  hintText: 'e.g. Vitamin D3',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Name is required' : null,
              ),
              _buildSectionLabel(context, 'Brand (optional)'),
              TextFormField(
                controller: _brandController,
                decoration: const InputDecoration(
                  hintText: 'e.g. Solgar',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              _buildSectionLabel(context, 'Dosage *'),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _dosageController,
                      decoration: const InputDecoration(
                        hintText: 'e.g. 1000',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                      ],
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Required';
                        final parsed = double.tryParse(v.trim());
                        if (parsed == null || parsed <= 0) return 'Enter a valid number';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      // ignore: deprecated_member_use
                      value: _selectedUnit,
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                      items: _kUnits
                          .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedUnit = v ?? 'mg'),
                    ),
                  ),
                ],
              ),
              _buildSectionLabel(context, 'Notes (optional)'),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  hintText: 'e.g. Take with food',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _isSaving ? null : _submit,
                      child: _isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _EditSupplementSheet
// ---------------------------------------------------------------------------

class _EditSupplementSheet extends StatefulWidget {
  const _EditSupplementSheet({
    required this.supplement,
    required this.onSave,
    required this.onDelete,
  });

  final SupplementEntity supplement;
  final Future<void> Function(
    String name,
    String? brand,
    double dosage,
    String unit,
    String? notes,
  ) onSave;
  final Future<void> Function() onDelete;

  @override
  State<_EditSupplementSheet> createState() => _EditSupplementSheetState();
}

class _EditSupplementSheetState extends State<_EditSupplementSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _brandController;
  late final TextEditingController _dosageController;
  late final TextEditingController _notesController;

  late String _selectedUnit;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.supplement.name);
    _brandController = TextEditingController(text: widget.supplement.brand ?? '');
    _dosageController = TextEditingController(text: widget.supplement.dosage.toString());
    _notesController = TextEditingController(text: widget.supplement.notes ?? '');
    _selectedUnit = _kUnits.contains(widget.supplement.unit) ? widget.supplement.unit : 'mg';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _dosageController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    await widget.onSave(
      _nameController.text.trim(),
      _brandController.text.trim(),
      double.parse(_dosageController.text.trim()),
      _selectedUnit,
      _notesController.text.trim(),
    );
    if (mounted) setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Edit Supplement',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildSectionLabel(context, 'Name *'),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Name is required' : null,
              ),
              _buildSectionLabel(context, 'Brand (optional)'),
              TextFormField(
                controller: _brandController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              _buildSectionLabel(context, 'Dosage *'),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _dosageController,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                      ],
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Required';
                        final parsed = double.tryParse(v.trim());
                        if (parsed == null || parsed <= 0) return 'Enter a valid number';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      // ignore: deprecated_member_use
                      value: _selectedUnit,
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                      items: _kUnits
                          .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedUnit = v ?? 'mg'),
                    ),
                  ),
                ],
              ),
              _buildSectionLabel(context, 'Notes (optional)'),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              // Delete button
              OutlinedButton.icon(
                onPressed: _isSaving ? null : widget.onDelete,
                icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
                label: Text(
                  'Delete Supplement',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Theme.of(context).colorScheme.error),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _isSaving ? null : _submit,
                      child: _isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _AddProtocolSheet
// ---------------------------------------------------------------------------

class _AddProtocolSheet extends StatefulWidget {
  const _AddProtocolSheet({
    required this.supplementName,
    required this.defaultDosage,
    required this.defaultUnit,
    required this.onSave,
  });

  final String supplementName;
  final double defaultDosage;
  final String defaultUnit;
  final Future<void> Function(
    ProtocolTimeOfDay timeOfDay,
    double dosage,
    String unit,
  ) onSave;

  @override
  State<_AddProtocolSheet> createState() => _AddProtocolSheetState();
}

class _AddProtocolSheetState extends State<_AddProtocolSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _dosageController;

  ProtocolTimeOfDay _selectedTime = ProtocolTimeOfDay.am;
  late String _selectedUnit;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _dosageController = TextEditingController(text: widget.defaultDosage.toString());
    _selectedUnit = _kUnits.contains(widget.defaultUnit) ? widget.defaultUnit : 'mg';
  }

  @override
  void dispose() {
    _dosageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    await widget.onSave(
      _selectedTime,
      double.parse(_dosageController.text.trim()),
      _selectedUnit,
    );
    if (mounted) setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add Protocol',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          widget.supplementName,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildSectionLabel(context, 'Time of Day'),
              Wrap(
                spacing: 8,
                children: ProtocolTimeOfDay.values.map((time) {
                  final isSelected = _selectedTime == time;
                  return ChoiceChip(
                    label: Text(time.label),
                    selected: isSelected,
                    onSelected: (_) => setState(() => _selectedTime = time),
                  );
                }).toList(),
              ),
              _buildSectionLabel(context, 'Dosage'),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _dosageController,
                      decoration: const InputDecoration(
                        hintText: 'Dosage',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                      ],
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Required';
                        final parsed = double.tryParse(v.trim());
                        if (parsed == null || parsed <= 0) return 'Enter a valid number';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      // ignore: deprecated_member_use
                      value: _selectedUnit,
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                      items: _kUnits
                          .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedUnit = v ?? 'mg'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _isSaving ? null : _submit,
                      child: _isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _EditProtocolSheet
// ---------------------------------------------------------------------------

class _EditProtocolSheet extends StatefulWidget {
  const _EditProtocolSheet({
    required this.protocol,
    required this.onSave,
    required this.onDelete,
  });

  final SupplementProtocolEntity protocol;
  final Future<void> Function(
    bool isActive,
    ProtocolTimeOfDay timeOfDay,
    double dosage,
    String unit,
  ) onSave;
  final Future<void> Function() onDelete;

  @override
  State<_EditProtocolSheet> createState() => _EditProtocolSheetState();
}

class _EditProtocolSheetState extends State<_EditProtocolSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _dosageController;

  late ProtocolTimeOfDay _selectedTime;
  late String _selectedUnit;
  late bool _isActive;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _dosageController = TextEditingController(text: widget.protocol.dosage.toString());
    _selectedTime = widget.protocol.timeOfDay;
    _selectedUnit = _kUnits.contains(widget.protocol.unit) ? widget.protocol.unit : 'mg';
    _isActive = widget.protocol.isActive;
  }

  @override
  void dispose() {
    _dosageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    await widget.onSave(
      _isActive,
      _selectedTime,
      double.parse(_dosageController.text.trim()),
      _selectedUnit,
    );
    if (mounted) setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Edit Protocol',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          widget.protocol.supplementName,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Active toggle
              Card(
                child: SwitchListTile(
                  title: const Text('Active'),
                  subtitle: Text(
                    _isActive ? 'Appears in today\'s protocol' : 'Paused — will not appear today',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  value: _isActive,
                  onChanged: (v) => setState(() => _isActive = v),
                ),
              ),
              _buildSectionLabel(context, 'Time of Day'),
              Wrap(
                spacing: 8,
                children: ProtocolTimeOfDay.values.map((time) {
                  final isSelected = _selectedTime == time;
                  return ChoiceChip(
                    label: Text(time.label),
                    selected: isSelected,
                    onSelected: (_) => setState(() => _selectedTime = time),
                  );
                }).toList(),
              ),
              _buildSectionLabel(context, 'Dosage'),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _dosageController,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                      ],
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Required';
                        final parsed = double.tryParse(v.trim());
                        if (parsed == null || parsed <= 0) return 'Enter a valid number';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      // ignore: deprecated_member_use
                      value: _selectedUnit,
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                      items: _kUnits
                          .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedUnit = v ?? 'mg'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Delete button
              OutlinedButton.icon(
                onPressed: _isSaving ? null : widget.onDelete,
                icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
                label: Text(
                  'Delete Protocol',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Theme.of(context).colorScheme.error),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _isSaving ? null : _submit,
                      child: _isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
