import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/core/router/app_router.dart' show activeProfileIdProvider;
import '../../pantry/data/pantry_repository.dart';
import '../../pantry/domain/pantry_item_entity.dart';
import '../../freemium/data/freemium_repository.dart';
import '../../freemium/domain/plan_tier.dart';

/// Shows a bottom sheet for selecting ingredients (typed + pantry) for meal generation.
/// Returns a list of ingredient name strings, or null if cancelled.
Future<List<String>?> showIngredientSelectionSheet(
    BuildContext context) async {
  return showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _IngredientSelectionSheet(),
  );
}

class _IngredientSelectionSheet extends ConsumerStatefulWidget {
  const _IngredientSelectionSheet();

  @override
  ConsumerState<_IngredientSelectionSheet> createState() =>
      _IngredientSelectionSheetState();
}

class _IngredientSelectionSheetState
    extends ConsumerState<_IngredientSelectionSheet> {
  final _textController = TextEditingController();
  final _selectedPantryItems = <String>{};
  List<PantryItemEntity> _pantryItems = [];
  bool _loadingPantry = true;

  @override
  void initState() {
    super.initState();
    _loadPantryItems();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _loadPantryItems() async {
    try {
      final profileId =
          ref.read(activeProfileIdProvider) ?? '';
      if (profileId.isEmpty) {
        setState(() => _loadingPantry = false);
        return;
      }
      final items = await ref
          .read(pantryRepositoryProvider)
          .getAvailableItems(profileId);
      if (mounted) {
        setState(() {
          _pantryItems = items;
          _loadingPantry = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingPantry = false);
    }
  }

  List<String> _getSelectedIngredients() {
    final typed = _textController.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final fromPantry = _selectedPantryItems.toList();
    return [...typed, ...fromPantry];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tierAsync = ref.watch(currentPlanTierProvider);
    final isPro = tierAsync.valueOrNull == PlanTier.pro;

    if (!isPro) {
      return _buildProGate(context, theme);
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(top: 8, bottom: 12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant
                        .withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Generate from ingredients',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Text input for typed ingredients
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  controller: _textController,
                  decoration: InputDecoration(
                    labelText: 'Type ingredients',
                    hintText: 'chicken, rice, broccoli...',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.edit_outlined),
                    suffixIcon: _textController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _textController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                  ),
                  textInputAction: TextInputAction.done,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(height: 16),

              // Pantry items header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Icon(Icons.kitchen_outlined,
                        size: 20, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'From your pantry',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    if (_selectedPantryItems.isNotEmpty)
                      Text(
                        '${_selectedPantryItems.length} selected',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Pantry items list
              Expanded(
                child: _loadingPantry
                    ? const Center(child: CircularProgressIndicator())
                    : _pantryItems.isEmpty
                        ? Center(
                            child: Text(
                              'No pantry items available',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: _pantryItems.length,
                            itemBuilder: (context, index) {
                              final item = _pantryItems[index];
                              final isSelected =
                                  _selectedPantryItems.contains(item.name);
                              return CheckboxListTile(
                                value: isSelected,
                                title: Text(item.name),
                                subtitle: item.quantity != null
                                    ? Text(
                                        '${item.quantity} ${item.unit ?? ''}')
                                    : null,
                                onChanged: (checked) {
                                  setState(() {
                                    if (checked == true) {
                                      _selectedPantryItems.add(item.name);
                                    } else {
                                      _selectedPantryItems.remove(item.name);
                                    }
                                  });
                                },
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                dense: true,
                              );
                            },
                          ),
              ),

              // Generate button
              Padding(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _getSelectedIngredients().isEmpty
                        ? null
                        : () {
                            Navigator.pop(
                                context, _getSelectedIngredients());
                          },
                    icon: const Icon(Icons.auto_awesome),
                    label: Text(
                      _getSelectedIngredients().isEmpty
                          ? 'Select or type ingredients'
                          : 'Generate plan (${_getSelectedIngredients().length} ingredients)',
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProGate(BuildContext context, ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_outline_rounded,
              size: 48, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 16),
          Text('Generate from Ingredients',
              style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Upgrade to Pro to generate meal plans from your available ingredients.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              context.push('/paywall');
            },
            child: const Text('Upgrade to Pro'),
          ),
        ],
      ),
    );
  }
}

