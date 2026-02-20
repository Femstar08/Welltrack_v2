import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProductInfo {
  const ProductInfo({
    required this.barcode,
    this.productName,
    this.brand,
    this.imageUrl,
    this.calories,
    this.proteinG,
    this.carbsG,
    this.fatG,
    this.quantity,
  });

  final String barcode;
  final String? productName;
  final String? brand;
  final String? imageUrl;
  final double? calories;
  final double? proteinG;
  final double? carbsG;
  final double? fatG;
  final String? quantity;

  String get displayName {
    final parts = <String>[];
    if (productName != null) parts.add(productName!);
    if (brand != null) parts.add('($brand)');
    return parts.isEmpty ? barcode : parts.join(' ');
  }
}

class ProductLookupService {
  ProductLookupService(this._dio);
  final Dio _dio;

  static const _baseUrl = 'https://world.openfoodfacts.net/api/v2/product';

  Future<ProductInfo?> lookupBarcode(String barcode) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/$barcode',
        queryParameters: {
          'fields':
              'product_name,brands,quantity,image_front_url,nutriments',
        },
        options: Options(
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      final data = response.data as Map<String, dynamic>?;
      if (data == null) return null;

      final status = data['status'] as int?;
      if (status != 1) return null;

      final product = data['product'] as Map<String, dynamic>?;
      if (product == null) return null;

      final nutriments = product['nutriments'] as Map<String, dynamic>?;

      return ProductInfo(
        barcode: barcode,
        productName: product['product_name'] as String?,
        brand: product['brands'] as String?,
        imageUrl: product['image_front_url'] as String?,
        calories: _toDouble(nutriments?['energy-kcal_100g']),
        proteinG: _toDouble(nutriments?['proteins_100g']),
        carbsG: _toDouble(nutriments?['carbohydrates_100g']),
        fatG: _toDouble(nutriments?['fat_100g']),
        quantity: product['quantity'] as String?,
      );
    } on DioException {
      return null;
    } catch (_) {
      return null;
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

final productLookupServiceProvider = Provider<ProductLookupService>((ref) {
  return ProductLookupService(Dio());
});
