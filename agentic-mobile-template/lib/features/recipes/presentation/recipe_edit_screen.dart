import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../domain/recipe_entity.dart';
import '../domain/recipe_ingredient.dart';
import '../domain/recipe_step.dart';
import 'recipe_detail_screen.dart';
import 'recipe_edit_provider.dart';

class RecipeEditScreen extends ConsumerStatefulWidget {
  const RecipeEditScreen({super.key, required this.recipeId});

  final String recipeId;

  @override
  ConsumerState<RecipeEditScreen> createState() => _RecipeEditScreenState();
}

class _RecipeEditScreenState extends ConsumerState<RecipeEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _servingsController;
  late final TextEditingController _prepTimeController;
  late final TextEditingController _cookTimeController;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _descriptionController = TextEditingController();
    _servingsController = TextEditingController();
    _prepTimeController = TextEditingController();
    _cookTimeController = TextEditingController();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _servingsController.dispose();
    _prepTimeController.dispose();
    _cookTimeController.dispose();
    super.dispose();
  }

  void _initFromRecipe(RecipeEntity recipe) {
    if (_initialized) return;
    _initialized = true;
    _titleController.text = recipe.title;
    _descriptionController.text = recipe.description ?? '';
    _servingsController.text = recipe.servings.toString();
    _prepTimeController.text = recipe.prepTimeMin?.toString() ?? '';
    _cookTimeController.text = recipe.cookTimeMin?.toString() ?? '';
    ref.read(recipeEditProvider.notifier).loadRecipe(recipe);
  }

  @override
  Widget build(BuildContext context) {
    final recipeAsync = ref.watch(recipeDetailProvider(widget.recipeId));
    final editState = ref.watch(recipeEditProvider);
    final theme = Theme.of(context);

    return recipeAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: const Text('Edit Recipe')),
        body: Center(child: Text('Error: $error')),
      ),
      data: (recipe) {
        _initFromRecipe(recipe);
        final editedRecipe = editState.recipe ?? recipe;

        return PopScope(
          canPop: !editState.hasChanges,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && editState.hasChanges) {
              _showDiscardDialog();
            }
          },
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Edit Recipe'),
              actions: [
                TextButton(
                  onPressed: editState.hasChanges && !editState.isSaving
                      ? _save
                      : null,
                  child: editState.isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ],
            ),
            body: Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Title',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Title required' : null,
                      onChanged: (v) => ref
                          .read(recipeEditProvider.notifier)
                          .updateTitle(v),
                    ),
                    const SizedBox(height: 16),

                    // Description
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                      onChanged: (v) => ref
                          .read(recipeEditProvider.notifier)
                          .updateDescription(v.isEmpty ? null : v),
                    ),
                    const SizedBox(height: 16),

                    // Servings, Prep, Cook times
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _servingsController,
                            decoration: const InputDecoration(
                              labelText: 'Servings',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            onChanged: (v) {
                              final n = int.tryParse(v);
                              if (n != null && n > 0) {
                                ref
                                    .read(recipeEditProvider.notifier)
                                    .updateServings(n);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _prepTimeController,
                            decoration: const InputDecoration(
                              labelText: 'Prep (min)',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            onChanged: (v) => ref
                                .read(recipeEditProvider.notifier)
                                .updatePrepTime(int.tryParse(v)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _cookTimeController,
                            decoration: const InputDecoration(
                              labelText: 'Cook (min)',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            onChanged: (v) => ref
                                .read(recipeEditProvider.notifier)
                                .updateCookTime(int.tryParse(v)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Tags
                    Text('Tags', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ...editedRecipe.tags.map((tag) => Chip(
                              label: Text(tag),
                              onDeleted: () {
                                final tags =
                                    List<String>.from(editedRecipe.tags);
                                tags.remove(tag);
                                ref
                                    .read(recipeEditProvider.notifier)
                                    .updateTags(tags);
                              },
                            )),
                        ActionChip(
                          avatar: const Icon(Icons.add, size: 18),
                          label: const Text('Add Tag'),
                          onPressed: () => _showAddTagDialog(editedRecipe.tags),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Ingredients
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Ingredients',
                            style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold)),
                        TextButton.icon(
                          onPressed: _showAddIngredientDialog,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ReorderableListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: editedRecipe.ingredients.length,
                      onReorder: (oldIdx, newIdx) {
                        if (newIdx > oldIdx) newIdx--;
                        ref
                            .read(recipeEditProvider.notifier)
                            .reorderIngredients(oldIdx, newIdx);
                      },
                      itemBuilder: (context, index) {
                        final ingredient = editedRecipe.ingredients[index];
                        return _IngredientTile(
                          key: ValueKey('ing-$index-${ingredient.ingredientName}'),
                          ingredient: ingredient,
                          onEdit: () =>
                              _showEditIngredientDialog(index, ingredient),
                          onDelete: () => ref
                              .read(recipeEditProvider.notifier)
                              .removeIngredient(index),
                        );
                      },
                    ),
                    const SizedBox(height: 24),

                    // Steps
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Steps',
                            style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold)),
                        TextButton.icon(
                          onPressed: () => _showAddStepDialog(),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ReorderableListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: editedRecipe.steps.length,
                      onReorder: (oldIdx, newIdx) {
                        if (newIdx > oldIdx) newIdx--;
                        ref
                            .read(recipeEditProvider.notifier)
                            .reorderSteps(oldIdx, newIdx);
                      },
                      itemBuilder: (context, index) {
                        final step = editedRecipe.steps[index];
                        return _StepTile(
                          key: ValueKey('step-$index-${step.stepNumber}'),
                          step: step,
                          index: index,
                          onEdit: () => _showEditStepDialog(index, step),
                          onDelete: () => ref
                              .read(recipeEditProvider.notifier)
                              .removeStep(index),
                        );
                      },
                    ),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final success =
        await ref.read(recipeEditProvider.notifier).saveChanges();

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recipe saved')),
      );
      ref.invalidate(recipeDetailProvider(widget.recipeId));
      context.pop();
    } else {
      final error = ref.read(recipeEditProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error ?? 'Failed to save')),
      );
    }
  }

  void _showDiscardDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard changes?'),
        content:
            const Text('You have unsaved changes that will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.pop();
            },
            child: const Text('Discard'),
          ),
        ],
      ),
    );
  }

  void _showAddTagDialog(List<String> currentTags) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Tag'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Tag name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final tag = controller.text.trim();
              if (tag.isNotEmpty) {
                final tags = List<String>.from(currentTags)..add(tag);
                ref.read(recipeEditProvider.notifier).updateTags(tags);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showAddIngredientDialog() {
    final nameCtrl = TextEditingController();
    final qtyCtrl = TextEditingController();
    final unitCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Ingredient'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: qtyCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Qty',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: unitCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Unit',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              if (name.isNotEmpty) {
                final editState = ref.read(recipeEditProvider);
                final sortOrder = editState.recipe?.ingredients.length ?? 0;
                ref.read(recipeEditProvider.notifier).addIngredient(
                      RecipeIngredient(
                        id: '',
                        ingredientName: name,
                        quantity: double.tryParse(qtyCtrl.text),
                        unit: unitCtrl.text.trim().isEmpty
                            ? null
                            : unitCtrl.text.trim(),
                        sortOrder: sortOrder,
                      ),
                    );
              }
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showEditIngredientDialog(int index, RecipeIngredient ingredient) {
    final nameCtrl = TextEditingController(text: ingredient.ingredientName);
    final qtyCtrl =
        TextEditingController(text: ingredient.quantity?.toString() ?? '');
    final unitCtrl = TextEditingController(text: ingredient.unit ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Ingredient'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: qtyCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Qty',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: unitCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Unit',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              if (name.isNotEmpty) {
                ref.read(recipeEditProvider.notifier).updateIngredient(
                      index,
                      ingredient.copyWith(
                        ingredientName: name,
                        quantity: double.tryParse(qtyCtrl.text),
                        unit: unitCtrl.text.trim().isEmpty
                            ? null
                            : unitCtrl.text.trim(),
                      ),
                    );
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showAddStepDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Step'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Step instruction...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final instruction = controller.text.trim();
              if (instruction.isNotEmpty) {
                ref
                    .read(recipeEditProvider.notifier)
                    .addStep(instruction);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showEditStepDialog(int index, RecipeStep step) {
    final controller =
        TextEditingController(text: step.instruction);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit Step ${index + 1}'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Step instruction...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final instruction = controller.text.trim();
              if (instruction.isNotEmpty) {
                ref
                    .read(recipeEditProvider.notifier)
                    .updateStep(index, instruction);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _IngredientTile extends StatelessWidget {
  const _IngredientTile({
    super.key,
    required this.ingredient,
    required this.onEdit,
    required this.onDelete,
  });

  final RecipeIngredient ingredient;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: const Icon(Icons.drag_handle),
      title: Text(ingredient.ingredientName),
      subtitle: Text(
        [
          if (ingredient.quantity != null) ingredient.quantity.toString(),
          if (ingredient.unit != null) ingredient.unit!,
        ].join(' '),
        style: theme.textTheme.bodySmall,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit, size: 20),
            onPressed: onEdit,
          ),
          IconButton(
            icon: Icon(Icons.delete, size: 20,
                color: theme.colorScheme.error),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({
    super.key,
    required this.step,
    required this.index,
    required this.onEdit,
    required this.onDelete,
  });

  final RecipeStep step;
  final int index;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: CircleAvatar(
        radius: 16,
        child: Text('${index + 1}'),
      ),
      title: Text(
        step.instruction,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: step.isTimed
          ? Text('${step.durationMinutes} min')
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit, size: 20),
            onPressed: onEdit,
          ),
          IconButton(
            icon: Icon(Icons.delete, size: 20,
                color: theme.colorScheme.error),
            onPressed: onDelete,
          ),
          const Icon(Icons.drag_handle),
        ],
      ),
    );
  }
}
