import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/meal_repository.dart';
import '../../profile/presentation/profile_provider.dart';
import '../../recipes/domain/recipe_entity.dart';

class LogMealScreen extends ConsumerStatefulWidget {

  const LogMealScreen({
    super.key,
    this.recipe,
  });
  final RecipeEntity? recipe;

  @override
  ConsumerState<LogMealScreen> createState() => _LogMealScreenState();
}

class _LogMealScreenState extends ConsumerState<LogMealScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _servingsController = TextEditingController();
  final _notesController = TextEditingController();

  String _mealType = 'lunch';
  double _rating = 3.0;
  bool _isLoading = false;

  final List<String> _mealTypes = [
    'breakfast',
    'lunch',
    'dinner',
    'snack',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.recipe != null) {
      _nameController.text = widget.recipe!.title;
      _servingsController.text = widget.recipe!.servings.toString();
    } else {
      _servingsController.text = '1';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _servingsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _logMeal() async {
    if (!_formKey.currentState!.validate()) return;

    final profileAsync = ref.read(activeProfileProvider);
    final profile = profileAsync.value;

    if (profile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No active profile found'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final servings = double.tryParse(_servingsController.text) ?? 1.0;

      // Extract nutrition info from recipe if available
      Map<String, dynamic>? nutritionInfo;
      if (widget.recipe != null) {
        // TODO: Calculate nutrition based on servings consumed
        // For now, use placeholder
        nutritionInfo = {
          'source': 'recipe',
          'recipe_id': widget.recipe!.id,
          'servings_consumed': servings,
          'recipe_servings': widget.recipe!.servings,
        };
      }

      await ref.read(mealRepositoryProvider).logMeal(
            profileId: profile.id,
            recipeId: widget.recipe?.id,
            mealDate: DateTime.now(),
            mealType: _mealType,
            name: _nameController.text.trim(),
            servingsConsumed: servings,
            nutritionInfo: nutritionInfo,
            score: widget.recipe?.nutritionScore,
            rating: _rating,
            notes: _notesController.text.trim().isNotEmpty
                ? _notesController.text.trim()
                : null,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_nameController.text} logged successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to log meal: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Log Meal'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Recipe info card (if from recipe)
            if (widget.recipe != null) ...[
              Card(
                color: theme.colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.restaurant,
                        size: 40,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'From Recipe',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                            Text(
                              widget.recipe!.title,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Meal name
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Meal Name',
                hintText: 'What did you eat?',
                prefixIcon: Icon(Icons.fastfood),
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a meal name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Meal type selector
            DropdownButtonFormField<String>(
              initialValue: _mealType,
              decoration: const InputDecoration(
                labelText: 'Meal Type',
                prefixIcon: Icon(Icons.category),
                border: OutlineInputBorder(),
              ),
              items: _mealTypes.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Row(
                    children: [
                      Icon(_getMealTypeIcon(type), size: 20),
                      const SizedBox(width: 8),
                      Text(type[0].toUpperCase() + type.substring(1)),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _mealType = value;
                  });
                }
              },
            ),
            const SizedBox(height: 16),

            // Servings consumed
            TextFormField(
              controller: _servingsController,
              decoration: const InputDecoration(
                labelText: 'Servings Consumed',
                hintText: '1',
                prefixIcon: Icon(Icons.pie_chart),
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter servings consumed';
                }
                final servings = double.tryParse(value);
                if (servings == null || servings <= 0) {
                  return 'Please enter a valid number';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Rating
            Text(
              'How was it?',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        return IconButton(
                          icon: Icon(
                            index < _rating ? Icons.star : Icons.star_border,
                            size: 36,
                          ),
                          color: Colors.amber,
                          onPressed: () {
                            setState(() {
                              _rating = (index + 1).toDouble();
                            });
                          },
                        );
                      }),
                    ),
                    Text(
                      _getRatingText(_rating),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Notes
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (Optional)',
                hintText: 'Any additional comments...',
                prefixIcon: Icon(Icons.note),
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            // Photo placeholder
            Card(
              child: InkWell(
                onTap: () {
                  // TODO: Implement photo capture
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Photo capture coming soon!'),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Icon(
                        Icons.add_a_photo,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add Photo',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Save button
            FilledButton(
              onPressed: _isLoading ? null : _logMeal,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Log Meal'),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getMealTypeIcon(String type) {
    switch (type) {
      case 'breakfast':
        return Icons.free_breakfast;
      case 'lunch':
        return Icons.lunch_dining;
      case 'dinner':
        return Icons.dinner_dining;
      case 'snack':
        return Icons.cookie;
      default:
        return Icons.fastfood;
    }
  }

  String _getRatingText(double rating) {
    if (rating >= 5) return 'Excellent!';
    if (rating >= 4) return 'Very Good';
    if (rating >= 3) return 'Good';
    if (rating >= 2) return 'Fair';
    return 'Poor';
  }
}
