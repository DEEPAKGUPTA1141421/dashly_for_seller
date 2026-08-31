/// Local, unsaved invoice being assembled in the Create Invoice flow.
/// Nothing here touches the backend until CreateInvoiceNotifier.generate()
/// is called — everything before that (search results, custom items, price
/// edits) lives purely client-side so the seller can freely add/remove/edit
/// without round-tripping the server on every keystroke.
class InvoiceDraftItem {
  final String id; // client-local id (uuid-ish), not a backend id
  final String type; // 'CATALOG' | 'CUSTOM'
  final String? productId;
  final String? variantId;
  String name;
  String? sku;
  String? barcode;
  final double? catalogPrice; // null for CUSTOM — nothing to compare against
  double unitPrice;
  int quantity;
  double discount;
  double taxRate;
  bool priceOverrideConfirmed;
  String? overrideReason;

  InvoiceDraftItem({
    required this.id,
    required this.type,
    this.productId,
    this.variantId,
    required this.name,
    this.sku,
    this.barcode,
    this.catalogPrice,
    required this.unitPrice,
    this.quantity = 1,
    this.discount = 0,
    this.taxRate = 0,
    this.priceOverrideConfirmed = false,
    this.overrideReason,
  });

  double get lineSubtotal => unitPrice * quantity;
  double get lineAfterDiscount => (lineSubtotal - discount).clamp(0, double.infinity);
  double get lineTax => lineAfterDiscount * (taxRate / 100.0);
  double get lineTotal => lineAfterDiscount + lineTax;

  /// Same rule as the backend's PriceValidationService — kept in sync manually.
  /// >=50% relative AND >=₹100 absolute deviation from catalog price.
  bool get hasPriceDeviation {
    if (catalogPrice == null || catalogPrice! <= 0) return false;
    final absDiff = (unitPrice - catalogPrice!).abs();
    final pctDiff = (absDiff / catalogPrice!) * 100.0;
    return pctDiff >= 50.0 && absDiff >= 100.0;
  }

  double get deviationPercent {
    if (catalogPrice == null || catalogPrice! <= 0) return 0;
    return ((unitPrice - catalogPrice!).abs() / catalogPrice!) * 100.0;
  }

  Map<String, dynamic> toRequestJson() => {
        'type': type,
        if (productId != null) 'productId': productId,
        if (variantId != null) 'variantId': variantId,
        if (type == 'CUSTOM') 'name': name,
        'sku': sku,
        if (type == 'CUSTOM') 'barcode': barcode,
        'unitPrice': unitPrice,
        'quantity': quantity,
        'discount': discount,
        'taxRate': taxRate,
        if (catalogPrice != null) 'catalogPriceHint': catalogPrice,
        'priceOverrideConfirmed': priceOverrideConfirmed,
        if (overrideReason != null) 'overrideReason': overrideReason,
      };
}

class InvoiceDraftCustomer {
  String name;
  String? phone;
  String? email;
  String? gstin;

  InvoiceDraftCustomer({required this.name, this.phone, this.email, this.gstin});

  Map<String, dynamic> toRequestJson() => {
        'name': name,
        'phone': phone,
        'email': email,
        'gstin': gstin,
      };
}
