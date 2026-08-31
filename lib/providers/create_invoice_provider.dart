import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../core/errors/app_exception.dart';
import '../models/invoice_draft.dart';

class PriceOverridePrompt {
  final int itemIndex;
  final double catalogPrice;
  final double enteredPrice;
  final double percentageDifference;
  const PriceOverridePrompt({
    required this.itemIndex,
    required this.catalogPrice,
    required this.enteredPrice,
    required this.percentageDifference,
  });
}

class CreateInvoiceState {
  final InvoiceDraftCustomer? customer;
  final List<InvoiceDraftItem> items;
  final double invoiceDiscount;
  final bool generating;
  final String? error;
  final Map<String, dynamic>? generatedInvoice; // set once finalize succeeds
  final PriceOverridePrompt? pendingOverride; // backend rejected — needs seller confirmation

  const CreateInvoiceState({
    this.customer,
    this.items = const [],
    this.invoiceDiscount = 0,
    this.generating = false,
    this.error,
    this.generatedInvoice,
    this.pendingOverride,
  });

  double get subtotal => items.fold(0.0, (sum, i) => sum + i.lineSubtotal);
  double get lineDiscounts => items.fold(0.0, (sum, i) => sum + i.discount);
  double get totalDiscount => lineDiscounts + invoiceDiscount;
  double get tax => items.fold(0.0, (sum, i) => sum + i.lineTax);
  double get total => (subtotal - totalDiscount + tax).clamp(0, double.infinity);

  CreateInvoiceState copyWith({
    InvoiceDraftCustomer? customer,
    bool clearCustomer = false,
    List<InvoiceDraftItem>? items,
    double? invoiceDiscount,
    bool? generating,
    String? error,
    bool clearError = false,
    Map<String, dynamic>? generatedInvoice,
    PriceOverridePrompt? pendingOverride,
    bool clearPendingOverride = false,
  }) {
    return CreateInvoiceState(
      customer: clearCustomer ? null : (customer ?? this.customer),
      items: items ?? this.items,
      invoiceDiscount: invoiceDiscount ?? this.invoiceDiscount,
      generating: generating ?? this.generating,
      error: clearError ? null : (error ?? this.error),
      generatedInvoice: generatedInvoice ?? this.generatedInvoice,
      pendingOverride: clearPendingOverride ? null : (pendingOverride ?? this.pendingOverride),
    );
  }
}

class CreateInvoiceNotifier extends StateNotifier<CreateInvoiceState> {
  CreateInvoiceNotifier() : super(const CreateInvoiceState());

  Dio get _client => ApiClient.instance.orderClient;
  int _localIdSeq = 0;
  String _nextId() => 'local-${_localIdSeq++}';

  void reset() => state = const CreateInvoiceState();

  void setCustomer(InvoiceDraftCustomer? customer) {
    state = state.copyWith(customer: customer, clearCustomer: customer == null);
  }

  void addItem(InvoiceDraftItem item) {
    state = state.copyWith(items: [...state.items, item], clearError: true);
  }

  /// Adds a catalog product, merging into an existing line (qty++) if that
  /// exact product/variant is already on the invoice — avoids duplicate rows
  /// from repeated scans of the same barcode.
  void addOrMergeCatalogItem({
    required String productId,
    String? variantId,
    required String name,
    String? sku,
    required double catalogPrice,
  }) {
    final existingIndex = state.items.indexWhere(
      (i) => i.type == 'CATALOG' && i.productId == productId && i.variantId == variantId,
    );
    if (existingIndex != -1) {
      updateItem(existingIndex, quantity: state.items[existingIndex].quantity + 1);
      return;
    }
    addItem(InvoiceDraftItem(
      id: _nextId(),
      type: 'CATALOG',
      productId: productId,
      variantId: variantId,
      name: name,
      sku: sku,
      catalogPrice: catalogPrice,
      unitPrice: catalogPrice,
    ));
  }

  void removeItem(String id) {
    state = state.copyWith(items: state.items.where((i) => i.id != id).toList());
  }

  void updateItem(int index, {double? unitPrice, int? quantity, double? discount, double? taxRate,
      bool? priceOverrideConfirmed, String? overrideReason}) {
    final items = [...state.items];
    if (index < 0 || index >= items.length) return;
    final item = items[index];
    if (unitPrice != null) item.unitPrice = unitPrice;
    if (quantity != null) item.quantity = quantity.clamp(1, 9999);
    if (discount != null) item.discount = discount;
    if (taxRate != null) item.taxRate = taxRate;
    if (priceOverrideConfirmed != null) item.priceOverrideConfirmed = priceOverrideConfirmed;
    if (overrideReason != null) item.overrideReason = overrideReason;
    state = state.copyWith(items: items);
  }

  void setInvoiceDiscount(double value) => state = state.copyWith(invoiceDiscount: value);

  void clearPendingOverride() => state = state.copyWith(clearPendingOverride: true);

  /// Confirms the flagged item's price and retries generate().
  Future<bool> confirmOverrideAndRetry() async {
    final prompt = state.pendingOverride;
    if (prompt == null) return false;
    updateItem(prompt.itemIndex, priceOverrideConfirmed: true);
    state = state.copyWith(clearPendingOverride: true);
    return generate();
  }

  /// Creates the draft on the backend, then immediately finalizes it —
  /// there's no separate "save draft for later" step in this flow, matching
  /// the seller's mental model of "fill it in, generate it, send it".
  Future<bool> generate() async {
    if (state.customer == null) {
      state = state.copyWith(error: 'Add customer details before generating an invoice');
      return false;
    }
    if (state.items.isEmpty) {
      state = state.copyWith(error: 'Add at least one item before generating an invoice');
      return false;
    }
    state = state.copyWith(generating: true, clearError: true, clearPendingOverride: true);
    try {
      final body = {
        if (state.customer != null) 'customer': state.customer!.toRequestJson(),
        'items': state.items.map((i) => i.toRequestJson()).toList(),
        'invoiceDiscount': state.invoiceDiscount,
      };
      final createRes = await _client.post(ApiEndpoints.invoices, data: body);
      final createBody = createRes.data as Map<String, dynamic>;
      final invoiceId = (createBody['data'] as Map)['id'].toString();

      final finalizeRes = await _client.post('${ApiEndpoints.invoices}/$invoiceId/finalize');
      final finalizeBody = finalizeRes.data as Map<String, dynamic>;

      state = state.copyWith(
        generating: false,
        generatedInvoice: (finalizeBody['data'] as Map).cast<String, dynamic>(),
      );
      return true;
    } on DioException catch (e) {
      if (e.response?.statusCode == 422) {
        final data = e.response?.data;
        if (data is Map && data['data'] is Map) {
          final d = (data['data'] as Map);
          state = state.copyWith(
            generating: false,
            pendingOverride: PriceOverridePrompt(
              itemIndex: (d['itemIndex'] as num).toInt(),
              catalogPrice: (d['catalogPrice'] as num).toDouble(),
              enteredPrice: (d['enteredPrice'] as num).toDouble(),
              percentageDifference: (d['percentageDifference'] as num).toDouble(),
            ),
          );
          return false;
        }
      }
      state = state.copyWith(generating: false, error: AppException.fromDioError(e).message);
      return false;
    } catch (e) {
      state = state.copyWith(generating: false, error: e.toString());
      return false;
    }
  }
}

final createInvoicePod = StateNotifierProvider.autoDispose<CreateInvoiceNotifier, CreateInvoiceState>(
  (ref) => CreateInvoiceNotifier(),
);
