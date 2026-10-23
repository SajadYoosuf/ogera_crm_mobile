/// Dart model for the product catalogue.
///
/// Mirrors `ProductListItem` from the backend schemas/product.py.
/// We only carry fields shown in the read-only list — no write fields needed.
library;

import '../core/utils/formatters.dart';

class Product {
  const Product({
    required this.id,
    required this.name,
    this.tagline,
    this.material,
    this.modelNumber,
    this.sku,
    this.capacityDisplay,
    this.mrp,
    this.salePrice,
    this.isPopular = false,
    this.isActive = true,
  });

  final int id;
  final String name;
  final String? tagline;
  final String? material;
  final String? modelNumber;
  final String? sku;
  final String? capacityDisplay;
  final double? mrp;
  final double? salePrice;
  final bool isPopular;
  final bool isActive;

  factory Product.fromJson(Map<String, dynamic> json) {
    final materialMap = json['material'];
    return Product(
      id: asInt(json['id']) ?? 0,
      name: asText(json['name']) ?? '',
      tagline: asText(json['tagline']),
      material: materialMap is Map ? asText(materialMap['name']) : null,
      modelNumber: asText(json['model_number']),
      sku: asText(json['sku']),
      capacityDisplay: asText(json['capacity_display']),
      mrp: _toDouble(json['mrp']),
      salePrice: _toDouble(json['sale_price']),
      isPopular: json['is_popular'] == true || json['is_popular'] == 1,
      isActive: json['is_active'] != false && json['is_active'] != 0,
    );
  }
}

double? _toDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}
