/// Typed representation of a seller product row.
///
/// Mirrors the raw `Map` fields currently read ad-hoc in
/// `lib/screens/products_screen.dart` (`_ProductCard`), with defensive
/// parsing matching that file's `_stockOf`/`_priceOf` style — numeric
/// fields may arrive as `num` or as a numeric `String`, and newer fields
/// (`views`, `likes`, `sales`) may be entirely absent from stale cached
/// data or an older backend response.
class ProductRow {
  final String id;
  final String name;
  final String imageUrl;
  final bool isActive;
  final double price;
  final int sales;
  final int views;
  final int likes;
  final String? brand;
  final String? categoryName;

  const ProductRow({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.isActive,
    required this.price,
    required this.sales,
    required this.views,
    required this.likes,
    this.brand,
    this.categoryName,
  });

  factory ProductRow.fromJson(Map<String, dynamic> json) {
    return ProductRow(
      id:           json['id']?.toString() ?? '',
      name:         json['name'] as String? ?? 'Product',
      imageUrl:     json['imageUrl'] as String? ?? '',
      isActive:     json['isActive'] as bool? ?? true,
      price:        _toDouble(json['price']),
      sales:        _toInt(json['sales']),
      views:        _toInt(json['views']),
      likes:        _toInt(json['likes']),
      brand:        json['brand'] as String?,
      categoryName: json['categoryName'] as String?,
    );
  }

  static double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0.0;
  }

  static int _toInt(dynamic v) {
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }
}
