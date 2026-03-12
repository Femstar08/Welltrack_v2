import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../recipes/data/recipe_repository.dart';
import '../../recipes/domain/recipe_entity.dart';
import 'shopping_list_provider.dart';

class CreateShoppingListSheet extends ConsumerStatefulWidget {
  const CreateShoppingListSheet({super.key, required this.profileId});

  final String profileId;

  @override
  ConsumerState<CreateShoppingListSheet> createState() =>
      _CreateShoppingListSheetState();
}

class _CreateShoppingListSheetState
    extends ConsumerState<CreateShoppingListSheet> {
  final _nameController = TextEditingController();
  bool _isFromRecipes = false;
  bool _isFromMealPlan = false;
  bool _isCreating = false;
  List<RecipeEntity> _recipes = [];
  bool _recipesLoading = false;
  final Set<String> _selectedRecipeIds = {};

  // Meal plan date range — defaults to today through the next 6 days
  late DateTime _mealPlanStart;
  late DateTime _mealPlanEnd;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _mealPlanStart = DateTime(today.year, today.month, today.day);
    _mealPlanEnd = _mealPlanStart.add(const Duration(days: 6));
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('New Shopping List',
                  style: theme.textTheme.headlineSmall),
              const SizedBox(height: 16),

              // List name
              TextField(
                controller: _nameController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'List name',
                  hintText: 'e.g. Weekly Groceries',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),

              if (!_isFromRecipes && !_isFromMealPlan) ...[
                // Option tiles
                ListTile(
                  leading: const Icon(Icons.restaurant_menu),
                  title: const Text('From Meal Plan'),
                  subtitle: const Text('Generate from this week\'s meals'),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: theme.colorScheme.outlineVariant),
                  ),
                  onTap: () => setState(() => _isFromMealPlan = true),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.auto_awesome),
                  title: const Text('From Recipes'),
                  subtitle: const Text('Pick recipes to generate items'),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: theme.colorScheme.outlineVariant),
                  ),
                  onTap: _loadRecipesAndSwitch,
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.edit_note),
                  title: const Text('Empty List'),
                  subtitle: const Text('Start from scratch'),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: theme.colorScheme.outlineVariant),
                  ),
                  onTap: _createEmptyList,
                ),
              ] else if (_isFromMealPlan) ...[
                // Meal plan date range picker
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => setState(() => _isFromMealPlan = false),
                    ),
                    Text('Select Date Range',
                        style: theme.textTheme.titleMedium),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Items will be generated from your meal plans in this range, '
                  'minus anything already in your pantry.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text(_formatDate(_mealPlanStart)),
                        onPressed: () => _pickDate(isStart: true),
                        style: OutlinedButton.styleFrom(
                          alignment: Alignment.centerLeft,
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('→'),
                    ),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text(_formatDate(_mealPlanEnd)),
                        onPressed: () => _pickDate(isStart: false),
                        style: OutlinedButton.styleFrom(
                          alignment: Alignment.centerLeft,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: _isCreating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.shopping_cart_outlined),
                    label: const Text('Generate Shopping List'),
                    onPressed: _isCreating ? null : _createFromMealPlan,
                  ),
                ),
              ] else ...[
                // Recipe picker
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => setState(() => _isFromRecipes = false),
                    ),
                    Text('Select Recipes',
                        style: theme.textTheme.titleMedium),
                  ],
                ),
                const SizedBox(height: 8),

                if (_recipesLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (_recipes.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        'No saved recipes found.\nGenerate some recipes first.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  )
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 300),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _recipes.length,
                      itemBuilder: (context, index) {
                        final recipe = _recipes[index];
                        final selected =
                            _selectedRecipeIds.contains(recipe.id);
                        return CheckboxListTile(
                          value: selected,
                          onChanged: (checked) {
                            setState(() {
                              if (checked == true) {
                                _selectedRecipeIds.add(recipe.id);
                              } else {
                                _selectedRecipeIds.remove(recipe.id);
                              }
                            });
                          },
                          title: Text(recipe.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          subtitle: Text(
                            '${recipe.ingredients.length} ingredients',
                            style: theme.textTheme.bodySmall,
                          ),
                          dense: true,
                        );
                      },
                    ),
                  ),

                if (_recipes.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _selectedRecipeIds.isNotEmpty && !_isCreating
                          ? _createFromRecipes
                          : null,
                      child: _isCreating
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              'Create List (${_selectedRecipeIds.length} selected)'),
                    ),
                  ),
                ],
              ],

              if (_isCreating && !_isFromRecipes && !_isFromMealPlan)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day} ${months[date.month - 1]}';
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart ? _mealPlanStart : _mealPlanEnd;
    final first = isStart ? DateTime(2020) : _mealPlanStart;
    final last = isStart ? _mealPlanEnd : DateTime(2100);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
    );

    if (picked != null && mounted) {
      setState(() {
        if (isStart) {
          _mealPlanStart = picked;
          if (_mealPlanEnd.isBefore(_mealPlanStart)) {
            _mealPlanEnd = _mealPlanStart.add(const Duration(days: 6));
          }
        } else {
          _mealPlanEnd = picked;
        }
      });
    }
  }

  Future<void> _createFromMealPlan() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a list name')),
      );
      return;
    }

    setState(() => _isCreating = true);

    final list = await ref
        .read(shoppingListsProvider(widget.profileId).notifier)
        .createFromMealPlan(
          name: name,
          startDate: _mealPlanStart,
          endDate: _mealPlanEnd,
        );

    if (!mounted) return;
    setState(() => _isCreating = false);

    if (list != null) {
      Navigator.pop(context);
      unawaited(context.push('/shopping/${list.id}'));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No meal plans found for this date range')),
      );
    }
  }

  Future<void> _loadRecipesAndSwitch() async {
    setState(() {
      _isFromRecipes = true;
      _recipesLoading = true;
    });

    try {
      final recipes = await ref
          .read(recipeRepositoryProvider)
          .getRecipes(widget.profileId);
      if (mounted) {
        setState(() {
          _recipes = recipes;
          _recipesLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _recipesLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load recipes: $e')),
        );
      }
    }
  }

  Future<void> _createEmptyList() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a list name')),
      );
      return;
    }

    setState(() => _isCreating = true);

    final list = await ref
        .read(shoppingListsProvider(widget.profileId).notifier)
        .createList(name: name, items: []);

    if (!mounted) return;
    setState(() => _isCreating = false);

    if (list != null) {
      Navigator.pop(context);
      unawaited(context.push('/shopping/${list.id}'));
    }
  }

  Future<void> _createFromRecipes() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a list name')),
      );
      return;
    }

    setState(() => _isCreating = true);

    final list = await ref
        .read(shoppingListsProvider(widget.profileId).notifier)
        .createFromRecipes(
          name: name,
          recipeIds: _selectedRecipeIds.toList(),
        );

    if (!mounted) return;
    setState(() => _isCreating = false);

    if (list != null) {
      Navigator.pop(context);
      unawaited(context.push('/shopping/${list.id}'));
    }
  }
}
