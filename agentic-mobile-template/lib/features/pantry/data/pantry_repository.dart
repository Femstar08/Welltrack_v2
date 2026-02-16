import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:welltrack/features/pantry/domain/pantry_item_entity.dart';

final pantryRepositoryProvider = Provider<PantryRepository>((ref) {
  return PantryRepository(Supabase.instance.client);
});

class PantryRepository {
  final SupabaseClient _client;

  PantryRepository(this._client);

  Future<List<PantryItemEntity>> getItems(String profileId, {String? category}) async {
    try {
      var query = _client
          .from('wt_pantry_items')
          .select()
          .eq('profile_id', profileId);

      if (category != null) {
        query = query.eq('category', category);
      }

      final response = await query
          .order('expiry_date', ascending: true)
          .order('name', ascending: true);

      return (response as List)
          .map((json) => PantryItemEntity.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch pantry items: $e');
    }
  }

  Future<List<PantryItemEntity>> getAvailableItems(String profileId) async {
    try {
      final response = await _client
          .from('wt_pantry_items')
          .select()
          .eq('profile_id', profileId)
          .eq('is_available', true)
          .order('name', ascending: true);

      return (response as List)
          .map((json) => PantryItemEntity.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch available items: $e');
    }
  }

  Future<List<PantryItemEntity>> searchItems(String profileId, String query) async {
    try {
      final response = await _client
          .from('wt_pantry_items')
          .select()
          .eq('profile_id', profileId)
          .ilike('name', '%$query%')
          .order('name', ascending: true);

      return (response as List)
          .map((json) => PantryItemEntity.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to search pantry items: $e');
    }
  }

  Future<PantryItemEntity> addItem({
    required String profileId,
    required String name,
    required String category,
    double? quantity,
    String? unit,
    DateTime? expiryDate,
    bool isAvailable = true,
    String? barcode,
    double? cost,
    String? notes,
  }) async {
    try {
      final now = DateTime.now();
      final itemData = {
        'profile_id': profileId,
        'name': name,
        'category': category,
        'quantity': quantity,
        'unit': unit,
        'expiry_date': expiryDate?.toIso8601String(),
        'is_available': isAvailable,
        'barcode': barcode,
        'cost': cost,
        'notes': notes,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };

      final response = await _client
          .from('wt_pantry_items')
          .insert(itemData)
          .select()
          .single();

      return PantryItemEntity.fromJson(response);
    } catch (e) {
      throw Exception('Failed to add pantry item: $e');
    }
  }

  Future<PantryItemEntity> updateItem(
    String itemId,
    Map<String, dynamic> fields,
  ) async {
    try {
      final updateData = {
        ...fields,
        'updated_at': DateTime.now().toIso8601String(),
      };

      final response = await _client
          .from('wt_pantry_items')
          .update(updateData)
          .eq('id', itemId)
          .select()
          .single();

      return PantryItemEntity.fromJson(response);
    } catch (e) {
      throw Exception('Failed to update pantry item: $e');
    }
  }

  Future<void> deleteItem(String itemId) async {
    try {
      await _client
          .from('wt_pantry_items')
          .delete()
          .eq('id', itemId);
    } catch (e) {
      throw Exception('Failed to delete pantry item: $e');
    }
  }

  Future<void> markAsUnavailable(String itemId) async {
    try {
      await _client
          .from('wt_pantry_items')
          .update({
            'is_available': false,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', itemId);
    } catch (e) {
      throw Exception('Failed to mark item as unavailable: $e');
    }
  }

  Future<List<PantryItemEntity>> getItemsByCategory(
    String profileId,
    String category,
  ) async {
    try {
      final response = await _client
          .from('wt_pantry_items')
          .select()
          .eq('profile_id', profileId)
          .eq('category', category)
          .order('expiry_date', ascending: true)
          .order('name', ascending: true);

      return (response as List)
          .map((json) => PantryItemEntity.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch items by category: $e');
    }
  }
}
