import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

class FoodItem {
  const FoodItem({
    required this.name,
    required this.caloriesPer100g,
    required this.proteinPer100g,
    required this.carbsPer100g,
    required this.fatPer100g,
    this.barcode,
    this.brand,
    this.imageUrl,
  });

  factory FoodItem.fromJson(Map<String, dynamic> json) => FoodItem(
        name: json['name'] as String,
        caloriesPer100g: _toDouble(json['caloriesPer100g']) ?? 0,
        proteinPer100g: _toDouble(json['proteinPer100g']) ?? 0,
        carbsPer100g: _toDouble(json['carbsPer100g']) ?? 0,
        fatPer100g: _toDouble(json['fatPer100g']) ?? 0,
        barcode: json['barcode'] as String?,
        brand: json['brand'] as String?,
        imageUrl: json['imageUrl'] as String?,
      );

  final String name;
  final double caloriesPer100g;
  final double proteinPer100g;
  final double carbsPer100g;
  final double fatPer100g;
  final String? barcode;
  final String? brand;
  final String? imageUrl;

  String get macroSummary =>
      'P: ${proteinPer100g.toStringAsFixed(1)}g · '
      'C: ${carbsPer100g.toStringAsFixed(1)}g · '
      'F: ${fatPer100g.toStringAsFixed(1)}g';

  Map<String, dynamic> toJson() => {
        'name': name,
        'caloriesPer100g': caloriesPer100g,
        'proteinPer100g': proteinPer100g,
        'carbsPer100g': carbsPer100g,
        'fatPer100g': fatPer100g,
        'barcode': barcode,
        'brand': brand,
        'imageUrl': imageUrl,
      };

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}

class FoodDatabaseService {
  FoodDatabaseService(this._dio);

  final Dio _dio;

  static const _searchUrl = 'https://world.openfoodfacts.org/cgi/search.pl';
  static const _productUrl = 'https://world.openfoodfacts.org/api/v0/product';
  static const _boxName = 'food_cache';
  static const _ttlDays = 7;
  static const _userAgent = 'WellTrack/1.0 (Flutter)';

  Future<List<FoodItem>> searchByKeyword(String query) async {
    if (query.trim().isEmpty) return [];

    final cacheKey = 'search:${query.trim().toLowerCase()}';
    final cached = await _fromCache(cacheKey);
    if (cached != null) return cached;

    try {
      final response = await _dio.get<dynamic>(
        _searchUrl,
        queryParameters: {
          'search_terms': query.trim(),
          'search_simple': 1,
          'action': 'process',
          'json': 1,
          'fields': 'product_name,nutriments,image_url,brands,code',
          'page_size': 20,
        },
        options: Options(
          headers: {'User-Agent': _userAgent},
          responseType: ResponseType.json,
          receiveTimeout: const Duration(seconds: 15),
          sendTimeout: const Duration(seconds: 10),
        ),
      );

      final dynamic rawData = response.data;
      final Map<String, dynamic>? data;
      if (rawData is Map<String, dynamic>) {
        data = rawData;
      } else if (rawData is String) {
        // Fallback: manually decode if Dio returned raw string
        data = null;
        debugPrint('[FoodDB] Response was String, not Map — check Dio config');
      } else {
        data = null;
      }

      final products = data?['products'] as List? ?? [];
      final items = products
          .map((p) => _parseProduct(p as Map<String, dynamic>))
          .whereType<FoodItem>()
          .toList();

      debugPrint('[FoodDB] Search "$query" → ${items.length} results');
      await _toCache(cacheKey, items);
      return items;
    } on DioException catch (e) {
      debugPrint('[FoodDB] DioException searching "$query": ${e.type} ${e.message}');
      return [];
    } catch (e) {
      debugPrint('[FoodDB] Error searching "$query": $e');
      return [];
    }
  }

  Future<FoodItem?> searchByBarcode(String barcode) async {
    final cacheKey = 'barcode:$barcode';
    final cached = await _fromCache(cacheKey);
    if (cached != null && cached.isNotEmpty) return cached.first;

    try {
      final response = await _dio.get<dynamic>(
        '$_productUrl/$barcode.json',
        options: Options(
          headers: {'User-Agent': _userAgent},
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      final data = response.data as Map<String, dynamic>?;
      if (data == null) return null;

      final status = data['status'] as int?;
      if (status != 1) return null;

      final product = data['product'] as Map<String, dynamic>?;
      if (product == null) return null;

      final item = _parseProduct(product, barcode: barcode);
      if (item != null) {
        await _toCache(cacheKey, [item]);
      }
      return item;
    } on DioException {
      return null;
    } catch (_) {
      return null;
    }
  }

  FoodItem? _parseProduct(Map<String, dynamic> product, {String? barcode}) {
    final name = product['product_name'] as String?;
    if (name == null || name.trim().isEmpty) return null;

    final nutriments = product['nutriments'] as Map<String, dynamic>? ?? {};

    return FoodItem(
      name: name.trim(),
      caloriesPer100g: _toDouble(
            nutriments['energy-kcal_100g'] ?? nutriments['energy_100g'],
          ) ??
          0,
      proteinPer100g: _toDouble(nutriments['proteins_100g']) ?? 0,
      carbsPer100g: _toDouble(nutriments['carbohydrates_100g']) ?? 0,
      fatPer100g: _toDouble(nutriments['fat_100g']) ?? 0,
      barcode: barcode ?? product['code'] as String?,
      brand: product['brands'] as String?,
      imageUrl: product['image_url'] as String? ??
          product['image_front_url'] as String?,
    );
  }

  Future<List<FoodItem>?> _fromCache(String key) async {
    try {
      final box = await Hive.openBox<dynamic>(_boxName);
      final entry = box.get(key) as Map?;
      if (entry == null) return null;

      final expiresAt = entry['expiresAt'] as int?;
      if (expiresAt == null ||
          DateTime.now().millisecondsSinceEpoch > expiresAt) {
        await box.delete(key);
        return null;
      }

      final rawList = entry['items'] as List?;
      if (rawList == null) return null;

      return rawList
          .map((e) => FoodItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> _toCache(String key, List<FoodItem> items) async {
    try {
      final box = await Hive.openBox<dynamic>(_boxName);
      final expiresAt = DateTime.now()
          .add(const Duration(days: _ttlDays))
          .millisecondsSinceEpoch;
      await box.put(key, {
        'expiresAt': expiresAt,
        'items': items.map((e) => e.toJson()).toList(),
      });
    } catch (_) {
      // Cache write failure is non-fatal
    }
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}

final foodDatabaseServiceProvider = Provider<FoodDatabaseService>((ref) {
  final dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
  ));
  return FoodDatabaseService(dio);
});
