import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/pantry_item_entity.dart';
import 'add_pantry_item_sheet.dart';
import 'pantry_provider.dart';
import '../../profile/presentation/profile_provider.dart';
import '../../recipes/presentation/recipe_generation_provider.dart';
import '../../recipes/presentation/recipe_suggestions_screen.dart';

class PantryScreen extends ConsumerStatefulWidget {
  const PantryScreen({super.key});

  @override
  ConsumerState<PantryScreen> createState() => _PantryScreenState();
}

class _PantryScreenState extends ConsumerState<PantryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _currentCategory = 'fridge';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) {
      setState(() {
        _currentCategory = ['fridge', 'cupboard', 'freezer'][_tabController.index];
      });
    }
  }

  void _showAddItemSheet(BuildContext context, String profileId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => AddPantryItemSheet(
        profileId: profileId,
        initialCategory: _currentCategory,
      ),
    );
  }

  void _onSearch(String query, String profileId) {
    unawaited(
      ref.read(pantryItemsProvider(profileId).notifier).searchItems(query),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(activeProfileProvider);

    return profileAsync.when(
      data: (profile) {
        if (profile == null) {
          return const Scaffold(
            body: Center(child: Text('No active profile')),
          );
        }

        final pantryAsync = ref.watch(pantryItemsProvider(profile.id));

        return Scaffold(
          appBar: AppBar(
            title: const Text('Pantry'),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(100),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search pantry items...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  _onSearch('', profile.id);
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                      ),
                      onChanged: (query) => _onSearch(query, profile.id),
                    ),
                  ),
                  TabBar(
                    controller: _tabController,
                    tabs: const [
                      Tab(text: 'Fridge'),
                      Tab(text: 'Cupboard'),
                      Tab(text: 'Freezer'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          body: pantryAsync.when(
            data: (items) {
              final filteredItems = items
                  .where((item) => item.category == _currentCategory)
                  .toList();

              if (filteredItems.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.kitchen_outlined,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No items in $_currentCategory',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () => _showAddItemSheet(context, profile.id),
                        icon: const Icon(Icons.add),
                        label: const Text('Add an item'),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: filteredItems.length,
                itemBuilder: (context, index) {
                  final item = filteredItems[index];
                  return _PantryItemCard(
                    item: item,
                    profileId: profile.id,
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${error.toString()}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      unawaited(
                        Future(() => ref
                            .read(pantryItemsProvider(profile.id).notifier)
                            .refresh()),
                      );
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
          floatingActionButton: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              FloatingActionButton.extended(
                onPressed: () async {
                  final availableItems = pantryAsync.value
                      ?.where((item) => item.isAvailable && !item.isExpired)
                      .toList() ?? [];

                  if (availableItems.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Add some pantry items first!'),
                      ),
                    );
                    return;
                  }

                  // Trigger recipe generation
                  await ref
                      .read(recipeGenerationProvider.notifier)
                      .generateRecipeSuggestions(profile.userId, profile.id, availableItems);

                  // Navigate to suggestions screen
                  if (context.mounted) {
                    unawaited(Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const RecipeSuggestionsScreen(),
                      ),
                    ));
                  }
                },
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Cook with these'),
                heroTag: 'cook',
              ),
              const SizedBox(height: 16),
              FloatingActionButton(
                onPressed: () => _showAddItemSheet(context, profile.id),
                heroTag: 'add',
                child: const Icon(Icons.add),
              ),
            ],
          ),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        body: Center(child: Text('Error: ${error.toString()}')),
      ),
    );
  }
}

class _PantryItemCard extends ConsumerWidget {

  const _PantryItemCard({
    required this.item,
    required this.profileId,
  });
  final PantryItemEntity item;
  final String profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isExpired = item.isExpired;
    final isExpiringSoon = item.isExpiringSoon;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Dismissible(
        key: Key(item.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.delete, color: Colors.white),
        ),
        confirmDismiss: (direction) async {
          return await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Delete Item'),
              content: Text('Remove "${item.name}" from pantry?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Delete'),
                ),
              ],
            ),
          );
        },
        onDismissed: (direction) {
          unawaited(
            ref
                .read(pantryItemsProvider(profileId).notifier)
                .deleteItem(item.id),
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${item.name} removed')),
          );
        },
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: isExpired
                ? Colors.red[100]
                : isExpiringSoon
                    ? Colors.orange[100]
                    : theme.colorScheme.primaryContainer,
            child: Icon(
              _getCategoryIcon(item.category),
              color: isExpired
                  ? Colors.red
                  : isExpiringSoon
                      ? Colors.orange
                      : theme.colorScheme.primary,
            ),
          ),
          title: Text(
            item.name,
            style: TextStyle(
              decoration: isExpired ? TextDecoration.lineThrough : null,
              color: isExpired ? Colors.grey : null,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (item.displayQuantity.isNotEmpty)
                Text(item.displayQuantity),
              if (item.expiryDate != null)
                Text(
                  'Expires: ${_formatDate(item.expiryDate!)}',
                  style: TextStyle(
                    color: isExpired
                        ? Colors.red
                        : isExpiringSoon
                            ? Colors.orange
                            : null,
                    fontWeight: (isExpired || isExpiringSoon)
                        ? FontWeight.bold
                        : null,
                  ),
                ),
            ],
          ),
          trailing: item.isAvailable
              ? null
              : const Chip(
                  label: Text('Used', style: TextStyle(fontSize: 12)),
                  padding: EdgeInsets.zero,
                ),
          onTap: () {
            // TODO: Show edit sheet
          },
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'fridge':
        return Icons.kitchen;
      case 'cupboard':
        return Icons.shelves;
      case 'freezer':
        return Icons.ac_unit;
      default:
        return Icons.category;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = date.difference(now);

    if (difference.isNegative) {
      return 'Expired ${difference.inDays.abs()} days ago';
    } else if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Tomorrow';
    } else if (difference.inDays <= 7) {
      return 'In ${difference.inDays} days';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
