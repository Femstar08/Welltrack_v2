import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../meals/data/meal_plan_repository.dart';
import '../../pantry/data/pantry_repository.dart';
import '../../recipes/data/recipe_repository.dart';
import '../domain/shopping_list_entity.dart';
import '../domain/shopping_list_item_entity.dart';
import 'aisle_mapper.dart';

final shoppingListRepositoryProvider = Provider<ShoppingListRepository>((ref) {
  return ShoppingListRepository(
    Supabase.instance.client,
    ref.watch(recipeRepositoryProvider),
    ref.watch(mealPlanRepositoryProvider),
    ref.watch(pantryRepositoryProvider),
  );
});

class ShoppingListRepository {
  ShoppingListRepository(
    this._client,
    this._recipeRepository,
    this._mealPlanRepository,
    this._pantryRepository,
  );

  final SupabaseClient _client;
  final RecipeRepository _recipeRepository;
  final MealPlanRepository _mealPlanRepository;
  final PantryRepository _pantryRepository;

  Future<List<ShoppingListEntity>> getLists(String profileId) async {
    try {
      final response = await _client
          .from('wt_shopping_lists')
          .select()
          .eq('profile_id', profileId)
          .neq('status', 'archived')
          .order('updated_at', ascending: false);

      final lists = <ShoppingListEntity>[];
      for (final json in response as List) {
        final list = ShoppingListEntity.fromJson(json);
        final itemsResponse = await _client
            .from('wt_shopping_list_items')
            .select()
            .eq('shopping_list_id', list.id)
            .order('aisle')
            .order('sort_order', ascending: true);

        final items = (itemsResponse as List)
            .map((j) => ShoppingListItemEntity.fromJson(j))
            .toList();

        lists.add(list.copyWith(items: items));
      }
      return lists;
    } catch (e) {
      throw Exception('Failed to fetch shopping lists: $e');
    }
  }

  Future<ShoppingListEntity> getList(String listId) async {
    try {
      final listResponse = await _client
          .from('wt_shopping_lists')
          .select()
          .eq('id', listId)
          .single();

      final list = ShoppingListEntity.fromJson(listResponse);

      final itemsResponse = await _client
          .from('wt_shopping_list_items')
          .select()
          .eq('shopping_list_id', listId)
          .order('aisle')
          .order('sort_order', ascending: true);

      final items = (itemsResponse as List)
          .map((json) => ShoppingListItemEntity.fromJson(json))
          .toList();

      return list.copyWith(items: items);
    } catch (e) {
      throw Exception('Failed to fetch shopping list: $e');
    }
  }

  Future<ShoppingListEntity> createList({
    required String profileId,
    required String name,
    List<String>? recipeIds,
    required List<ShoppingListItemEntity> items,
  }) async {
    try {
      final now = DateTime.now();
      final listData = {
        'profile_id': profileId,
        'name': name,
        'recipe_ids': recipeIds ?? [],
        'status': 'active',
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };

      final listResponse = await _client
          .from('wt_shopping_lists')
          .insert(listData)
          .select()
          .single();

      final listId = listResponse['id'] as String;

      if (items.isNotEmpty) {
        final itemsData = items.asMap().entries.map((entry) {
          final item = entry.value;
          return {
            'shopping_list_id': listId,
            'ingredient_name': item.ingredientName,
            'quantity': item.quantity,
            'unit': item.unit,
            'aisle': item.aisle,
            'is_checked': false,
            'notes': item.notes,
            'source_recipe_id': item.sourceRecipeId,
            'sort_order': entry.key,
            'created_at': now.toIso8601String(),
          };
        }).toList();

        await _client.from('wt_shopping_list_items').insert(itemsData);
      }

      return await getList(listId);
    } catch (e) {
      throw Exception('Failed to create shopping list: $e');
    }
  }

  Future<ShoppingListEntity> createListFromRecipes({
    required String profileId,
    required String name,
    required List<String> recipeIds,
  }) async {
    try {
      // Collect all ingredients from requested recipes
      final consolidated = <String, _ConsolidatedIngredient>{};

      for (final recipeId in recipeIds) {
        final recipe = await _recipeRepository.getRecipe(recipeId);
        for (final ingredient in recipe.ingredients) {
          final key = ingredient.ingredientName.toLowerCase();
          if (consolidated.containsKey(key)) {
            final existing = consolidated[key]!;
            // Sum quantities when units match
            if (existing.unit == ingredient.unit &&
                existing.quantity != null &&
                ingredient.quantity != null) {
              consolidated[key] = existing.copyWith(
                quantity: existing.quantity! + ingredient.quantity!,
              );
            }
            // Keep the existing entry when units don't match
          } else {
            consolidated[key] = _ConsolidatedIngredient(
              ingredientName: ingredient.ingredientName,
              quantity: ingredient.quantity,
              unit: ingredient.unit,
              sourceRecipeId: recipeId,
            );
          }
        }
      }

      // Map to ShoppingListItemEntity with aisle assignment
      final now = DateTime.now();
      final items = consolidated.values.toList();
      items.sort((a, b) {
        final aisleCmp = AisleMapper.getAisleSortOrder(
                AisleMapper.getAisle(a.ingredientName))
            .compareTo(AisleMapper.getAisleSortOrder(
                AisleMapper.getAisle(b.ingredientName)));
        if (aisleCmp != 0) return aisleCmp;
        return a.ingredientName.compareTo(b.ingredientName);
      });

      final itemEntities = items.asMap().entries.map((entry) {
        final item = entry.value;
        return ShoppingListItemEntity(
          id: '',
          shoppingListId: '',
          ingredientName: item.ingredientName,
          quantity: item.quantity,
          unit: item.unit,
          aisle: AisleMapper.getAisle(item.ingredientName),
          sourceRecipeId: item.sourceRecipeId,
          sortOrder: entry.key,
          createdAt: now,
        );
      }).toList();

      return await createList(
        profileId: profileId,
        name: name,
        recipeIds: recipeIds,
        items: itemEntities,
      );
    } catch (e) {
      throw Exception('Failed to create shopping list from recipes: $e');
    }
  }

  Future<void> toggleItem(String itemId, bool isChecked) async {
    try {
      await _client
          .from('wt_shopping_list_items')
          .update({'is_checked': isChecked})
          .eq('id', itemId);
    } catch (e) {
      throw Exception('Failed to toggle item: $e');
    }
  }

  Future<void> toggleAllItems(String listId, bool isChecked) async {
    try {
      await _client
          .from('wt_shopping_list_items')
          .update({'is_checked': isChecked})
          .eq('shopping_list_id', listId);
    } catch (e) {
      throw Exception('Failed to toggle all items: $e');
    }
  }

  Future<void> updateListStatus(String listId, String status) async {
    try {
      await _client
          .from('wt_shopping_lists')
          .update({
            'status': status,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', listId);
    } catch (e) {
      throw Exception('Failed to update list status: $e');
    }
  }

  Future<void> deleteList(String listId) async {
    try {
      await _client
          .from('wt_shopping_list_items')
          .delete()
          .eq('shopping_list_id', listId);

      await _client
          .from('wt_shopping_lists')
          .delete()
          .eq('id', listId);
    } catch (e) {
      throw Exception('Failed to delete shopping list: $e');
    }
  }

  Future<void> updateItem(String itemId, ShoppingListItemEntity item) async {
    try {
      await _client
          .from('wt_shopping_list_items')
          .update({
            'ingredient_name': item.ingredientName,
            'quantity': item.quantity,
            'unit': item.unit,
            'aisle': item.aisle,
          })
          .eq('id', itemId);
    } catch (e) {
      throw Exception('Failed to update item: $e');
    }
  }

  Future<void> deleteItem(String itemId) async {
    try {
      await _client
          .from('wt_shopping_list_items')
          .delete()
          .eq('id', itemId);
    } catch (e) {
      throw Exception('Failed to delete item: $e');
    }
  }

  Future<ShoppingListEntity> createListFromMealPlan({
    required String profileId,
    required String name,
    required DateTime startDate,
    required DateTime endDate,
    bool excludePantryItems = true,
  }) async {
    try {
      // 1. Fetch meal plans for the date range
      final mealPlans = await _mealPlanRepository.getMealPlans(
        profileId,
        startDate,
        endDate,
      );

      // 2. Consolidated ingredient map: key = lowercase ingredient name
      final consolidated = <String, _ConsolidatedIngredient>{};

      // 2a. Collect unique recipe IDs from plan items
      final recipeIds = <String>{};
      for (final plan in mealPlans) {
        for (final item in plan.items) {
          if (item.recipeId != null) recipeIds.add(item.recipeId!);
        }
      }

      // 2b. Pull actual ingredients from linked recipes
      for (final recipeId in recipeIds) {
        try {
          final recipe = await _recipeRepository.getRecipe(recipeId);
          for (final ingredient in recipe.ingredients) {
            final key = ingredient.ingredientName.toLowerCase().trim();
            if (consolidated.containsKey(key)) {
              final existing = consolidated[key]!;
              if (existing.unit == ingredient.unit &&
                  existing.quantity != null &&
                  ingredient.quantity != null) {
                consolidated[key] = existing.copyWith(
                  quantity: existing.quantity! + ingredient.quantity!,
                );
              }
            } else {
              consolidated[key] = _ConsolidatedIngredient(
                ingredientName: ingredient.ingredientName,
                quantity: ingredient.quantity,
                unit: ingredient.unit,
                sourceRecipeId: recipeId,
              );
            }
          }
        } catch (_) {
          // Skip recipes that fail to load
        }
      }

      // 2c. For meal items without a recipe, use the meal name as an ingredient
      for (final plan in mealPlans) {
        for (final item in plan.items) {
          if (item.recipeId == null) {
            final key = item.name.toLowerCase().trim();
            if (!consolidated.containsKey(key)) {
              consolidated[key] = _ConsolidatedIngredient(
                ingredientName: item.name,
                quantity: null,
                unit: null,
              );
            }
          }
        }
      }

      // 3. Cross-reference with pantry — exclude items already available
      if (excludePantryItems && consolidated.isNotEmpty) {
        try {
          final pantryItems =
              await _pantryRepository.getAvailableItems(profileId);
          final pantryNames = pantryItems
              .map((p) => p.name.toLowerCase().trim())
              .toSet();
          consolidated.removeWhere((key, _) {
            return pantryNames.any(
              (pantryName) =>
                  pantryName.contains(key) || key.contains(pantryName),
            );
          });
        } catch (_) {
          // If pantry lookup fails, proceed without filtering
        }
      }

      // 4. Sort by aisle then name
      final items = consolidated.values.toList()
        ..sort((a, b) {
          final aisleCmp = AisleMapper.getAisleSortOrder(
                  AisleMapper.getAisle(a.ingredientName))
              .compareTo(AisleMapper.getAisleSortOrder(
                  AisleMapper.getAisle(b.ingredientName)));
          if (aisleCmp != 0) return aisleCmp;
          return a.ingredientName.compareTo(b.ingredientName);
        });

      final now = DateTime.now();
      final itemEntities = items.asMap().entries.map((entry) {
        final item = entry.value;
        return ShoppingListItemEntity(
          id: '',
          shoppingListId: '',
          ingredientName: item.ingredientName,
          quantity: item.quantity,
          unit: item.unit,
          aisle: AisleMapper.getAisle(item.ingredientName),
          sourceRecipeId: item.sourceRecipeId,
          sortOrder: entry.key,
          createdAt: now,
        );
      }).toList();

      return await createList(
        profileId: profileId,
        name: name,
        items: itemEntities,
      );
    } catch (e) {
      throw Exception('Failed to create shopping list from meal plan: $e');
    }
  }

  Future<void> addItems(
      String listId, List<ShoppingListItemEntity> items) async {
    try {
      if (items.isEmpty) return;

      final now = DateTime.now();
      final itemsData = items.map((item) {
        return {
          'shopping_list_id': listId,
          'ingredient_name': item.ingredientName,
          'quantity': item.quantity,
          'unit': item.unit,
          'aisle': item.aisle,
          'is_checked': false,
          'notes': item.notes,
          'source_recipe_id': item.sourceRecipeId,
          'sort_order': item.sortOrder,
          'created_at': now.toIso8601String(),
        };
      }).toList();

      await _client.from('wt_shopping_list_items').insert(itemsData);
    } catch (e) {
      throw Exception('Failed to add items: $e');
    }
  }
}

/// Internal helper for ingredient consolidation
class _ConsolidatedIngredient {
  _ConsolidatedIngredient({
    required this.ingredientName,
    this.quantity,
    this.unit,
    this.sourceRecipeId,
  });

  final String ingredientName;
  final double? quantity;
  final String? unit;
  final String? sourceRecipeId;

  _ConsolidatedIngredient copyWith({
    double? quantity,
  }) {
    return _ConsolidatedIngredient(
      ingredientName: ingredientName,
      quantity: quantity ?? this.quantity,
      unit: unit,
      sourceRecipeId: sourceRecipeId,
    );
  }
}
