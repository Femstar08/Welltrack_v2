import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/core/router/app_router.dart';
import '../domain/shopping_list_entity.dart';
import 'create_shopping_list_sheet.dart';
import 'shopping_list_provider.dart';

class ShoppingListsScreen extends ConsumerStatefulWidget {
  const ShoppingListsScreen({super.key});

  @override
  ConsumerState<ShoppingListsScreen> createState() =>
      _ShoppingListsScreenState();
}

class _ShoppingListsScreenState extends ConsumerState<ShoppingListsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final profileId = ref.read(activeProfileIdProvider) ?? '';
      if (profileId.isNotEmpty) {
        ref.read(shoppingListsProvider(profileId).notifier).loadLists();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final profileId = ref.watch(activeProfileIdProvider) ?? '';
    final state = ref.watch(shoppingListsProvider(profileId));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Shopping Lists')),
      body: _buildBody(state, profileId, theme),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateSheet(profileId),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody(
      ShoppingListsState state, String profileId, ThemeData theme) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64,
                color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text('Failed to load lists',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => ref
                  .read(shoppingListsProvider(profileId).notifier)
                  .loadLists(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (state.lists.isEmpty) {
      return _buildEmptyState(theme, profileId);
    }

    return RefreshIndicator(
      onRefresh: () =>
          ref.read(shoppingListsProvider(profileId).notifier).refresh(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
        itemCount: state.lists.length,
        itemBuilder: (context, index) {
          final list = state.lists[index];
          return _ShoppingListCard(
            list: list,
            onTap: () => context.push('/shopping/${list.id}'),
            onArchive: () => ref
                .read(shoppingListsProvider(profileId).notifier)
                .archiveList(list.id),
            onDelete: () => _confirmDelete(profileId, list),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, String profileId) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_cart_outlined, size: 80,
                color: theme.colorScheme.outline),
            const SizedBox(height: 24),
            Text('No shopping lists yet',
                style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Create a list from your recipes or start an empty one.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => _showCreateSheet(profileId),
              icon: const Icon(Icons.add),
              label: const Text('Create your first list'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateSheet(String profileId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => CreateShoppingListSheet(profileId: profileId),
    );
  }

  void _confirmDelete(String profileId, ShoppingListEntity list) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete list?'),
        content: Text('Delete "${list.name}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref
                  .read(shoppingListsProvider(profileId).notifier)
                  .deleteList(list.id);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _ShoppingListCard extends StatelessWidget {
  const _ShoppingListCard({
    required this.list,
    required this.onTap,
    required this.onArchive,
    required this.onDelete,
  });

  final ShoppingListEntity list;
  final VoidCallback onTap;
  final VoidCallback onArchive;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = list.progressPercent;

    return Dismissible(
      key: ValueKey(list.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: theme.colorScheme.tertiary,
        child: Icon(Icons.archive, color: theme.colorScheme.onTertiary),
      ),
      confirmDismiss: (_) async {
        onArchive();
        return false;
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: InkWell(
          onTap: onTap,
          onLongPress: () => _showContextMenu(context),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        list.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (list.isComplete && list.totalCount > 0)
                      Icon(Icons.check_circle,
                          color: theme.colorScheme.primary, size: 20),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor:
                      theme.colorScheme.surfaceContainerHighest,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      '${list.checkedCount}/${list.totalCount} items',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (list.recipeIds.isNotEmpty) ...[
                      const Spacer(),
                      Icon(Icons.restaurant, size: 14,
                          color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(
                        '${list.recipeIds.length} recipe${list.recipeIds.length > 1 ? 's' : ''}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.archive),
              title: const Text('Archive'),
              onTap: () {
                Navigator.pop(ctx);
                onArchive();
              },
            ),
            ListTile(
              leading: Icon(Icons.delete,
                  color: Theme.of(context).colorScheme.error),
              title: Text('Delete',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.error)),
              onTap: () {
                Navigator.pop(ctx);
                onDelete();
              },
            ),
          ],
        ),
      ),
    );
  }
}
