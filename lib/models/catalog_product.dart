class CatalogProduct {
  final String id;
  final String name;
  final String? description;
  final String? imageUrl;
  final String? brandName;
  final String? categoryName;
  final String? specifications;
  final String? ean;
  final String? productCode;

  const CatalogProduct({
    required this.id,
    required this.name,
    this.description,
    this.imageUrl,
    this.brandName,
    this.categoryName,
    this.specifications,
    this.ean,
    this.productCode,
  });

  factory CatalogProduct.fromJson(Map<String, dynamic> json) => CatalogProduct(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        imageUrl: json['primaryImageUrl'] as String?,
        brandName: json['brandName'] as String?,
        categoryName: json['categoryName'] as String?,
        specifications: json['specifications'] as String?,
        ean: json['ean'] as String?,
        productCode: json['productCode'] as String?,
      );
}

class CatalogVariantEntry {
  final String localId;
  String label;
  String price;
  String mrp;
  String stock;
  String sku;
  Map<String, String> combination;

  CatalogVariantEntry({
    required this.localId,
    this.label = '',
    this.price = '',
    this.mrp = '',
    this.stock = '',
    this.sku = '',
    Map<String, String>? combination,
  }) : combination = combination ?? {};

  bool get isValid =>
      price.isNotEmpty &&
      double.tryParse(price) != null &&
      double.tryParse(price)! > 0 &&
      stock.isNotEmpty &&
      int.tryParse(stock) != null &&
      int.tryParse(stock)! >= 0;

  Map<String, dynamic> toJson() => {
        'label': label.trim(),
        'price': double.tryParse(price) ?? 0.0,
        'mrp': double.tryParse(mrp.isNotEmpty ? mrp : price) ?? 0.0,
        'stock': int.tryParse(stock) ?? 0,
        'sku': sku.trim(),
        'combination': combination,
      };
}
