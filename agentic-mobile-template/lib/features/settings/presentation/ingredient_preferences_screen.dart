import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../profile/data/profile_repository.dart';
import '../../../shared/core/router/app_router.dart';

class IngredientPreferencesScreen extends ConsumerStatefulWidget {
  const IngredientPreferencesScreen({super.key});

  @override
  ConsumerState<IngredientPreferencesScreen> createState() =>
      _IngredientPreferencesScreenState();
}

class _IngredientPreferencesScreenState
    extends ConsumerState<IngredientPreferencesScreen> {
  final _preferredController = TextEditingController();
  final _excludedController = TextEditingController();

  List<String> _preferred = [];
  List<String> _excluded = [];
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _preferredController.dispose();
    _excludedController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final profileId = ref.read(activeProfileIdProvider);
    if (profileId == null || profileId.isEmpty) return;

    try {
      final repo = ProfileRepository(Supabase.instance.client);
      final profile = await repo.getProfile(profileId);
      if (mounted) {
        setState(() {
          _preferred = List<String>.from(profile.preferredIngredients);
          _excluded = List<String>.from(profile.excludedIngredients);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load preferences: $e')),
        );
      }
    }
  }

  void _addPreferred() {
    final text = _preferredController.text.trim();
    if (text.isEmpty) return;
    if (_preferred.contains(text.toLowerCase())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Already in your preferred list')),
      );
      return;
    }
    setState(() => _preferred.add(text));
    _preferredController.clear();
  }

  void _addExcluded() {
    final text = _excludedController.text.trim();
    if (text.isEmpty) return;
    if (_excluded.contains(text.toLowerCase())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Already in your excluded list')),
      );
      return;
    }
    setState(() => _excluded.add(text));
    _excludedController.clear();
  }

  Future<void> _save() async {
    final profileId = ref.read(activeProfileIdProvider);
    if (profileId == null || profileId.isEmpty) return;

    setState(() => _saving = true);
    try {
      final repo = ProfileRepository(Supabase.instance.client);
      await repo.updateProfile(profileId, {
        'preferred_ingredients': _preferred,
        'excluded_ingredients': _excluded,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ingredient preferences saved')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ingredient Preferences'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Preferred Ingredients
                Text(
                  'PREFERRED INGREDIENTS',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'These will be prioritized in AI-generated meal plans and recipes.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_preferred.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              'No items yet — add ingredients you prefer',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          )
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: _preferred
                                .map(
                                  (item) => Chip(
                                    label: Text(item),
                                    deleteIcon: const Icon(Icons.close, size: 18),
                                    onDeleted: () => setState(
                                      () => _preferred.remove(item),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _preferredController,
                                decoration: const InputDecoration(
                                  hintText: 'e.g. chicken, avocado',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                ),
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) => _addPreferred(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filled(
                              onPressed: _addPreferred,
                              icon: const Icon(Icons.add),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Excluded Ingredients
                Text(
                  'EXCLUDED INGREDIENTS',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'These will never appear in AI-generated meal plans or recipes.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_excluded.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              'No items yet — add ingredients you want to avoid',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          )
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: _excluded
                                .map(
                                  (item) => Chip(
                                    label: Text(item),
                                    backgroundColor: theme.colorScheme.errorContainer,
                                    deleteIcon: const Icon(Icons.close, size: 18),
                                    onDeleted: () => setState(
                                      () => _excluded.remove(item),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _excludedController,
                                decoration: const InputDecoration(
                                  hintText: 'e.g. cilantro, liver',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                ),
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) => _addExcluded(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filled(
                              onPressed: _addExcluded,
                              icon: const Icon(Icons.add),
                              style: IconButton.styleFrom(
                                backgroundColor: theme.colorScheme.error,
                                foregroundColor: theme.colorScheme.onError,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
