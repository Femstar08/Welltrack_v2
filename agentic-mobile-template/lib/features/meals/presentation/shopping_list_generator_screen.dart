import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'shopping_list_generator_provider.dart';

class ShoppingListGeneratorScreen extends ConsumerStatefulWidget {
  const ShoppingListGeneratorScreen({super.key, required this.profileId});

  final String profileId;

  @override
  ConsumerState<ShoppingListGeneratorScreen> createState() =>
      _ShoppingListGeneratorScreenState();
}

class _ShoppingListGeneratorScreenState
    extends ConsumerState<ShoppingListGeneratorScreen> {
  final _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(shoppingListGeneratorProvider(widget.profileId).notifier)
          .loadAvailableDates();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(shoppingListGeneratorProvider(widget.profileId));
    final notifier =
        ref.read(shoppingListGeneratorProvider(widget.profileId).notifier);

    // After list is created, navigate to it
    ref.listen(shoppingListGeneratorProvider(widget.profileId), (prev, next) {
      if (next.createdListId != null && prev?.createdListId == null) {
        context.push('/shopping/${next.createdListId}');
      }
      // Sync name controller with provider state
      if (next.listName != _nameController.text) {
        _nameController.text = next.listName;
        _nameController.selection = TextSelection.fromPosition(
          TextPosition(offset: next.listName.length),
        );
      }
    });

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shopping List from Meals'),
      ),
      body: _buildBody(context, theme, state, notifier),
    );
  }

  Widget _buildBody(
    BuildContext context,
    ThemeData theme,
    ShoppingListGeneratorState state,
    ShoppingListGeneratorNotifier notifier,
  ) {
    // Step 2: Generating
    if (state.isGenerating) {
      return _GeneratingView(theme: theme);
    }

    // Step 3: Review Items
    if (state.generatedItems.isNotEmpty) {
      return _ReviewItemsView(
        theme: theme,
        state: state,
        notifier: notifier,
        nameController: _nameController,
      );
    }

    // Step 1: Date Selection
    return _DateSelectionView(
      theme: theme,
      state: state,
      notifier: notifier,
      profileId: widget.profileId,
    );
  }
}

// ── Step 1: Date Selection ────────────────────────────────────────────────────

class _DateSelectionView extends ConsumerWidget {
  const _DateSelectionView({
    required this.theme,
    required this.state,
    required this.notifier,
    required this.profileId,
  });

  final ThemeData theme;
  final ShoppingListGeneratorState state;
  final ShoppingListGeneratorNotifier notifier;
  final String profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.isLoadingDates) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null && state.availableDates.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline,
                  size: 64, color: theme.colorScheme.error),
              const SizedBox(height: 16),
              Text(state.error!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: notifier.loadAvailableDates,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select days to shop for',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Only days with meal plans can be selected.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: state.availableDates.length,
            itemBuilder: (context, index) {
              final dateInfo = state.availableDates[index];
              return _DateTile(
                dateInfo: dateInfo,
                isSelected: state.selectedDates.contains(
                  DateTime(dateInfo.date.year, dateInfo.date.month,
                      dateInfo.date.day),
                ),
                onTap: dateInfo.hasPlan
                    ? () => notifier.toggleDate(dateInfo.date)
                    : null,
                theme: theme,
              );
            },
          ),
        ),
        _DateSelectionFooter(
          theme: theme,
          state: state,
          notifier: notifier,
          profileId: profileId,
        ),
      ],
    );
  }
}

class _DateTile extends StatelessWidget {
  const _DateTile({
    required this.dateInfo,
    required this.isSelected,
    required this.onTap,
    required this.theme,
  });

  final DateWithPlan dateInfo;
  final bool isSelected;
  final VoidCallback? onTap;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final date = dateInfo.date;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isToday = date == today;

    final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final dayName = dayNames[date.weekday - 1];
    const monthNames = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final dateLabel =
        '${isToday ? 'Today' : dayName}, ${monthNames[date.month - 1]} ${date.day}';

    final enabled = dateInfo.hasPlan;
    final color = enabled
        ? (isSelected
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.surface)
        : theme.colorScheme.surfaceContainerHighest.withOpacity(0.4);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant,
              width: isSelected ? 2 : 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Checkbox indicator
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : Colors.transparent,
                  border: Border.all(
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline,
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? Icon(Icons.check,
                        size: 16, color: theme.colorScheme.onPrimary)
                    : null,
              ),
              const SizedBox(width: 12),
              // Date label
              Expanded(
                child: Text(
                  dateLabel,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight:
                        isToday ? FontWeight.bold : FontWeight.normal,
                    color: enabled
                        ? null
                        : theme.colorScheme.onSurface.withOpacity(0.38),
                  ),
                ),
              ),
              // Meal plan chip
              if (dateInfo.hasPlan) ...[
                Chip(
                  label: Text(
                    '${dateInfo.plan!.items.length} meals',
                    style: theme.textTheme.labelSmall,
                  ),
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  backgroundColor: isSelected
                      ? theme.colorScheme.primary.withOpacity(0.15)
                      : theme.colorScheme.secondaryContainer,
                ),
              ] else ...[
                Text(
                  'No plan',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.38),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DateSelectionFooter extends StatelessWidget {
  const _DateSelectionFooter({
    required this.theme,
    required this.state,
    required this.notifier,
    required this.profileId,
  });

  final ThemeData theme;
  final ShoppingListGeneratorState state;
  final ShoppingListGeneratorNotifier notifier;
  final String profileId;

  @override
  Widget build(BuildContext context) {
    final userId =
        Supabase.instance.client.auth.currentUser?.id ?? '';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (state.error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                state.error!,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.error),
                textAlign: TextAlign.center,
              ),
            ),
          Row(
            children: [
              Text(
                state.selectedCount == 0
                    ? 'Select at least 1 day'
                    : '${state.selectedCount} day${state.selectedCount == 1 ? '' : 's'} selected',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: state.selectedCount == 0
                    ? null
                    : () => notifier.generateShoppingList(userId: userId),
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Generate'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Step 2: Generating ────────────────────────────────────────────────────────

class _GeneratingView extends StatelessWidget {
  const _GeneratingView({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            Text(
              'Generating shopping list...',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'AI is consolidating ingredients from your meal plans.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Step 3: Review Items ──────────────────────────────────────────────────────

class _ReviewItemsView extends StatelessWidget {
  const _ReviewItemsView({
    required this.theme,
    required this.state,
    required this.notifier,
    required this.nameController,
  });

  final ThemeData theme;
  final ShoppingListGeneratorState state;
  final ShoppingListGeneratorNotifier notifier;
  final TextEditingController nameController;

  @override
  Widget build(BuildContext context) {
    // Group items by aisle (only included items go to the final list)
    final aisleGroups = <String, List<_IndexedItem>>{};
    for (var i = 0; i < state.generatedItems.length; i++) {
      final item = state.generatedItems[i];
      final aisle = item.aisle;
      aisleGroups.putIfAbsent(aisle, () => []).add(_IndexedItem(i, item));
    }
    final sortedAisles = aisleGroups.keys.toList()..sort();

    return Column(
      children: [
        // List name field
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: nameController,
            onChanged: notifier.setListName,
            decoration: InputDecoration(
              labelText: 'List name',
              hintText: 'e.g. Groceries Jan 20 - Jan 23',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.shopping_cart),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text(
                '${state.includedItemCount} of ${state.generatedItems.length} items included',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 16),
            children: sortedAisles.map((aisle) {
              final items = aisleGroups[aisle]!;
              return _AisleReviewSection(
                aisle: aisle,
                items: items,
                notifier: notifier,
                theme: theme,
              );
            }).toList(),
          ),
        ),
        _ReviewFooter(
          theme: theme,
          state: state,
          notifier: notifier,
        ),
      ],
    );
  }
}

class _IndexedItem {
  const _IndexedItem(this.index, this.item);
  final int index;
  final GeneratedShoppingItem item;
}

class _AisleReviewSection extends StatelessWidget {
  const _AisleReviewSection({
    required this.aisle,
    required this.items,
    required this.notifier,
    required this.theme,
  });

  final String aisle;
  final List<_IndexedItem> items;
  final ShoppingListGeneratorNotifier notifier;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: Text(
        aisle,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.primary,
        ),
      ),
      trailing: Text(
        '${items.where((i) => i.item.isIncluded).length}/${items.length}',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      initiallyExpanded: true,
      children: items.map((indexed) {
        final item = indexed.item;
        return Dismissible(
          key: ValueKey('item_${indexed.index}'),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            color: theme.colorScheme.errorContainer,
            padding: const EdgeInsets.only(right: 16),
            child: Icon(Icons.delete_outline,
                color: theme.colorScheme.onErrorContainer),
          ),
          onDismissed: (_) => notifier.removeItem(indexed.index),
          child: CheckboxListTile(
            value: item.isIncluded,
            onChanged: (_) => notifier.toggleItem(indexed.index),
            title: Text(
              item.ingredientName,
              style: TextStyle(
                decoration:
                    item.isIncluded ? null : TextDecoration.lineThrough,
                color: item.isIncluded
                    ? null
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
            subtitle: _buildSubtitle(item, theme),
            controlAffinity: ListTileControlAffinity.leading,
            dense: true,
          ),
        );
      }).toList(),
    );
  }

  Widget? _buildSubtitle(GeneratedShoppingItem item, ThemeData theme) {
    final parts = <String>[];
    if (item.quantity != null) {
      parts.add(item.quantity! % 1 == 0
          ? item.quantity!.toInt().toString()
          : item.quantity.toString());
    }
    if (item.unit != null) parts.add(item.unit!);
    final quantityStr = parts.join(' ');

    if (quantityStr.isEmpty && item.notes == null) return null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (quantityStr.isNotEmpty)
          Text(
            quantityStr,
            style: theme.textTheme.bodySmall,
          ),
        if (item.notes != null)
          Text(
            item.notes!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );
  }
}

class _ReviewFooter extends StatelessWidget {
  const _ReviewFooter({
    required this.theme,
    required this.state,
    required this.notifier,
  });

  final ThemeData theme;
  final ShoppingListGeneratorState state;
  final ShoppingListGeneratorNotifier notifier;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (state.error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                state.error!,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.error),
                textAlign: TextAlign.center,
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: (state.isCreating ||
                      state.includedItemCount == 0 ||
                      state.listName.isEmpty)
                  ? null
                  : notifier.createShoppingList,
              icon: state.isCreating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: Text(state.isCreating
                  ? 'Creating...'
                  : 'Create Shopping List (${state.includedItemCount} items)'),
            ),
          ),
        ],
      ),
    );
  }
}
