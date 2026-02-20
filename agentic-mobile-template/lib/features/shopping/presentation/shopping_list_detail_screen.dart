import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/shopping_list_repository.dart';
import '../data/aisle_mapper.dart';
import '../domain/shopping_list_entity.dart';
import '../domain/shopping_list_item_entity.dart';
import 'shopping_list_provider.dart';

class ShoppingListDetailScreen extends ConsumerWidget {
  const ShoppingListDetailScreen({super.key, required this.listId});

  final String listId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(shoppingListDetailProvider(listId));

    return listAsync.when(
      data: (list) => _DetailContent(list: list, listId: listId),
      loading: () => Scaffold(
        appBar: AppBar(
          leading: const BackButton(),
          title: const Text('Shopping List'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) {
        final theme = Theme.of(context);
        return Scaffold(
          appBar: AppBar(
            leading: const BackButton(),
            title: const Text('Shopping List'),
          ),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64,
                      color: theme.colorScheme.error),
                  const SizedBox(height: 16),
                  Text('Failed to load list',
                      style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    error.toString(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () =>
                        ref.invalidate(shoppingListDetailProvider(listId)),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => context.pop(),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DetailContent extends ConsumerWidget {
  const _DetailContent({required this.list, required this.listId});

  final ShoppingListEntity list;
  final String listId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final aisleGroups = list.itemsByAisle;
    final allDone = list.isComplete && list.totalCount > 0;

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(list.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Scan barcode',
            onPressed: () => context.push(
              '/shopping/$listId/barcode-scan',
              extra: list.items,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.camera_alt),
            tooltip: 'Scan items from photo',
            onPressed: () => context.push('/shopping/$listId/photo-import'),
          ),
          PopupMenuButton<String>(
            onSelected: (action) =>
                _handleAction(action, context, ref),
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'check_all',
                child: Text('Mark All Complete'),
              ),
              const PopupMenuItem(
                value: 'uncheck_all',
                child: Text('Mark All Unchecked'),
              ),
              const PopupMenuItem(
                value: 'archive',
                child: Text('Archive'),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Text('Delete'),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddItemDialog(context, ref),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          // Progress header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Column(
              children: [
                LinearProgressIndicator(
                  value: list.progressPercent,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3),
                ),
                const SizedBox(height: 8),
                Text(
                  '${list.checkedCount} of ${list.totalCount} items',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          // All done banner
          if (allDone)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.celebration,
                      color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'All done!',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

          // Items by aisle
          Expanded(
            child: list.items.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shopping_cart_outlined,
                            size: 64,
                            color: theme.colorScheme.onSurfaceVariant
                                .withOpacity(0.5)),
                        const SizedBox(height: 16),
                        Text(
                          'No items yet',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap + to add items',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.only(bottom: 80),
                    children: aisleGroups.entries.map((entry) {
                      return _AisleSection(
                        aisle: entry.key,
                        items: entry.value,
                        listId: listId,
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddItemDialog(BuildContext context, WidgetRef ref) async {
    final result = await showModalBottomSheet<ShoppingListItemEntity>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _AddEditItemSheet(listId: listId),
    );

    if (result != null) {
      final repo = ref.read(shoppingListRepositoryProvider);
      await repo.addItems(listId, [result]);
      ref.invalidate(shoppingListDetailProvider(listId));
    }
  }

  Future<void> _handleAction(
      String action, BuildContext context, WidgetRef ref) async {
    final repo = ref.read(shoppingListRepositoryProvider);
    final router = GoRouter.of(context);
    switch (action) {
      case 'check_all':
        await repo.toggleAllItems(listId, true);
        ref.invalidate(shoppingListDetailProvider(listId));
      case 'uncheck_all':
        await repo.toggleAllItems(listId, false);
        ref.invalidate(shoppingListDetailProvider(listId));
      case 'archive':
        await repo.updateListStatus(listId, 'archived');
        router.pop();
      case 'delete':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete list?'),
            content: const Text('This cannot be undone.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        if (confirmed == true) {
          await repo.deleteList(listId);
          router.pop();
        }
    }
  }
}

class _AisleSection extends ConsumerWidget {
  const _AisleSection({
    required this.aisle,
    required this.items,
    required this.listId,
  });

  final String aisle;
  final List<ShoppingListItemEntity> items;
  final String listId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return ExpansionTile(
      title: Text(
        aisle,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.primary,
        ),
      ),
      trailing: Text(
        '${items.where((i) => i.isChecked).length}/${items.length}',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      initiallyExpanded: true,
      children: items.map((item) {
        return Dismissible(
          key: ValueKey(item.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            color: theme.colorScheme.errorContainer,
            padding: const EdgeInsets.only(right: 16),
            child: Icon(Icons.delete_outline,
                color: theme.colorScheme.onErrorContainer),
          ),
          confirmDismiss: (_) async {
            return await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Remove item?'),
                content: Text('Remove "${item.ingredientName}" from the list?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Remove'),
                  ),
                ],
              ),
            );
          },
          onDismissed: (_) {
            ref
                .read(shoppingListRepositoryProvider)
                .deleteItem(item.id)
                .then((_) {
              ref.invalidate(shoppingListDetailProvider(listId));
            });
          },
          child: InkWell(
            onLongPress: () => _showEditDialog(context, ref, item),
            child: CheckboxListTile(
              value: item.isChecked,
              onChanged: (checked) {
                ref
                    .read(shoppingListRepositoryProvider)
                    .toggleItem(item.id, checked ?? false)
                    .then((_) {
                  ref.invalidate(shoppingListDetailProvider(listId));
                });
              },
              title: Text(
                item.ingredientName,
                style: TextStyle(
                  decoration:
                      item.isChecked ? TextDecoration.lineThrough : null,
                  color: item.isChecked
                      ? theme.colorScheme.onSurfaceVariant
                      : null,
                ),
              ),
              subtitle: _buildSubtitle(item, theme),
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget? _buildSubtitle(ShoppingListItemEntity item, ThemeData theme) {
    final parts = <String>[];
    if (item.quantity != null) {
      final q = item.quantity!;
      parts.add(q == q.roundToDouble() ? q.toInt().toString() : q.toString());
    }
    if (item.unit != null) parts.add(item.unit!);
    if (parts.isEmpty) return null;
    return Text(
      parts.join(' '),
      style: TextStyle(
        decoration: item.isChecked ? TextDecoration.lineThrough : null,
      ),
    );
  }

  Future<void> _showEditDialog(
      BuildContext context, WidgetRef ref, ShoppingListItemEntity item) async {
    final result = await showModalBottomSheet<ShoppingListItemEntity>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _AddEditItemSheet(
        listId: listId,
        existingItem: item,
      ),
    );

    if (result != null) {
      final repo = ref.read(shoppingListRepositoryProvider);
      await repo.updateItem(item.id, result);
      ref.invalidate(shoppingListDetailProvider(listId));
    }
  }
}

// ── Add / Edit Item Bottom Sheet ─────────────────────────────────────────────

class _AddEditItemSheet extends StatefulWidget {
  const _AddEditItemSheet({
    required this.listId,
    this.existingItem,
  });

  final String listId;
  final ShoppingListItemEntity? existingItem;

  @override
  State<_AddEditItemSheet> createState() => _AddEditItemSheetState();
}

class _AddEditItemSheetState extends State<_AddEditItemSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _quantityCtrl;
  late final TextEditingController _unitCtrl;
  late String _selectedAisle;

  bool get _isEditing => widget.existingItem != null;

  static const _aisles = [
    'Produce',
    'Bakery',
    'Dairy',
    'Meat & Seafood',
    'Frozen',
    'Canned Goods',
    'Dry Goods',
    'Oils & Sauces',
    'Spices & Seasonings',
    'Beverages',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    final item = widget.existingItem;
    _nameCtrl = TextEditingController(text: item?.ingredientName ?? '');
    _quantityCtrl = TextEditingController(
      text: item?.quantity != null
          ? (item!.quantity! == item.quantity!.roundToDouble()
              ? item.quantity!.toInt().toString()
              : item.quantity.toString())
          : '',
    );
    _unitCtrl = TextEditingController(text: item?.unit ?? '');
    _selectedAisle = item?.aisle ?? 'Other';

    // Auto-detect aisle as user types name
    _nameCtrl.addListener(_autoDetectAisle);
  }

  void _autoDetectAisle() {
    if (_isEditing) return; // Don't auto-change aisle when editing
    final detected = AisleMapper.getAisle(_nameCtrl.text);
    if (detected != _selectedAisle) {
      setState(() => _selectedAisle = detected);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _quantityCtrl.dispose();
    _unitCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    final quantity = double.tryParse(_quantityCtrl.text.trim());
    final unit = _unitCtrl.text.trim().isEmpty ? null : _unitCtrl.text.trim();

    final item = ShoppingListItemEntity(
      id: widget.existingItem?.id ?? '',
      shoppingListId: widget.listId,
      ingredientName: name,
      quantity: quantity,
      unit: unit,
      aisle: _selectedAisle,
      isChecked: widget.existingItem?.isChecked ?? false,
      sortOrder: widget.existingItem?.sortOrder ?? 0,
      createdAt: widget.existingItem?.createdAt ?? DateTime.now(),
    );

    Navigator.pop(context, item);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            _isEditing ? 'Edit Item' : 'Add Item',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          // Item name
          TextField(
            controller: _nameCtrl,
            autofocus: !_isEditing,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Item name',
              hintText: 'e.g. Chicken breast',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.shopping_basket_outlined),
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 12),
          // Quantity + Unit row
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _quantityCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Qty',
                    hintText: '1',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _unitCtrl,
                  textCapitalization: TextCapitalization.none,
                  decoration: InputDecoration(
                    labelText: 'Unit',
                    hintText: 'kg, pcs, ml...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Aisle dropdown
          DropdownButtonFormField<String>(
            value: _selectedAisle,
            decoration: InputDecoration(
              labelText: 'Aisle',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.store_outlined),
            ),
            items: _aisles
                .map((a) => DropdownMenuItem(value: a, child: Text(a)))
                .toList(),
            onChanged: (val) {
              if (val != null) setState(() => _selectedAisle = val);
            },
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _nameCtrl.text.trim().isEmpty ? null : _submit,
            child: Text(_isEditing ? 'Save Changes' : 'Add Item'),
          ),
        ],
      ),
    );
  }
}
