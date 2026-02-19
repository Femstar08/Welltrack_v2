// lib/features/supplements/presentation/supplements_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    // TODO: Implement add supplement dialog
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Add supplement dialog - TODO')),
    );
  }

  void _showEditSupplementDialog(BuildContext context, supplement) {
    // TODO: Implement edit supplement dialog
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Edit supplement dialog - TODO')),
    );
  }

  void _showAddProtocolDialog(BuildContext context, String supplementId, String supplementName) {
    // TODO: Implement add protocol dialog
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Add protocol dialog - TODO')),
    );
  }

  void _showEditProtocolDialog(BuildContext context, protocol) {
    // TODO: Implement edit protocol dialog
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Edit protocol dialog - TODO')),
    );
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
