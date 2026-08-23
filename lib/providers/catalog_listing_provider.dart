import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../models/catalog_product.dart';

// ── State ─────────────────────────────────────────────────────────────────────

class CatalogListingState {
  final String searchQuery;
  final List<CatalogProduct> searchResults;
  final bool isSearching;
  final bool searchDone;

  final CatalogProduct? selectedProduct;

  final List<CatalogVariantEntry> variants;

  final bool isCreating;
  final String? successProductId;
  final String? successImageUrl;
  final String? error;

  const CatalogListingState({
    this.searchQuery = '',
    this.searchResults = const [],
    this.isSearching = false,
    this.searchDone = false,
    this.selectedProduct,
    this.variants = const [],
    this.isCreating = false,
    this.successProductId,
    this.successImageUrl,
    this.error,
  });

  bool get allVariantsValid =>
      variants.isNotEmpty && variants.every((v) => v.isValid);

  CatalogListingState copyWith({
    String? searchQuery,
    List<CatalogProduct>? searchResults,
    bool? isSearching,
    bool? searchDone,
    CatalogProduct? selectedProduct,
    bool clearSelectedProduct = false,
    List<CatalogVariantEntry>? variants,
    bool? isCreating,
    String? successProductId,
    String? successImageUrl,
    String? error,
    bool clearError = false,
    bool clearSuccess = false,
  }) =>
      CatalogListingState(
        searchQuery: searchQuery ?? this.searchQuery,
        searchResults: searchResults ?? this.searchResults,
        isSearching: isSearching ?? this.isSearching,
        searchDone: searchDone ?? this.searchDone,
        selectedProduct:
            clearSelectedProduct ? null : (selectedProduct ?? this.selectedProduct),
        variants: variants ?? this.variants,
        isCreating: isCreating ?? this.isCreating,
        successProductId:
            clearSuccess ? null : (successProductId ?? this.successProductId),
        successImageUrl:
            clearSuccess ? null : (successImageUrl ?? this.successImageUrl),
        error: clearError ? null : (error ?? this.error),
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class CatalogListingNotifier extends StateNotifier<CatalogListingState> {
  CatalogListingNotifier() : super(const CatalogListingState());

  Dio get _dio => ApiClient.instance.client;
  Timer? _debounce;

  // ── Search ────────────────────────────────────────────────────────────────

  void onSearchChanged(String query) {
    state = state.copyWith(searchQuery: query, searchDone: false);
    _debounce?.cancel();
    if (query.trim().length < 2) {
      state = state.copyWith(searchResults: [], searchDone: false);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(query.trim()));
  }

  Future<void> _search(String query) async {
    state = state.copyWith(isSearching: true, clearError: true);
    try {
      final res = await _dio.get(
        ApiEndpoints.sellerProductCatalogSearch,
        queryParameters: {'query': query, 'page': 0, 'size': 20},
      );
      final data = res.data as Map<String, dynamic>;
      if (data['success'] == true) {
        final list = (data['data'] as List<dynamic>? ?? [])
            .map((e) => CatalogProduct.fromJson(e as Map<String, dynamic>))
            .toList();
        state = state.copyWith(
          searchResults: list,
          isSearching: false,
          searchDone: true,
        );
      } else {
        state = state.copyWith(
          isSearching: false,
          searchDone: true,
          error: data['message'] as String? ?? 'Search failed',
        );
      }
    } on DioException catch (e) {
      state = state.copyWith(
        isSearching: false,
        searchDone: true,
        error: e.response?.data?['message'] as String? ?? 'Network error',
      );
    }
  }

  // ── Select product from search results ────────────────────────────────────

  void selectProduct(CatalogProduct product) {
    state = state.copyWith(
      selectedProduct: product,
      // Start with one empty variant
      variants: [CatalogVariantEntry(localId: _id())],
      clearSuccess: true,
      clearError: true,
    );
  }

  // ── Variant management ────────────────────────────────────────────────────

  void addVariant() {
    if (state.variants.length >= 20) return;
    state = state.copyWith(
      variants: [...state.variants, CatalogVariantEntry(localId: _id())],
    );
  }

  void removeVariant(String localId) {
    if (state.variants.length <= 1) return;
    state = state.copyWith(
      variants: state.variants.where((v) => v.localId != localId).toList(),
    );
  }

  void updateVariantLabel(String localId, String value) =>
      _mutate(localId, (v) => v.label = value);

  void updateVariantPrice(String localId, String value) =>
      _mutate(localId, (v) => v.price = value);

  void updateVariantMrp(String localId, String value) =>
      _mutate(localId, (v) => v.mrp = value);

  void updateVariantStock(String localId, String value) =>
      _mutate(localId, (v) => v.stock = value);

  void updateVariantSku(String localId, String value) =>
      _mutate(localId, (v) => v.sku = value);

  void _mutate(String localId, void Function(CatalogVariantEntry) mutator) {
    final updated = state.variants.map((v) {
      if (v.localId == localId) mutator(v);
      return v;
    }).toList();
    state = state.copyWith(variants: updated);
  }

  // ── Create listing ────────────────────────────────────────────────────────

  Future<bool> createListing() async {
    final product = state.selectedProduct;
    if (product == null) return false;
    if (!state.allVariantsValid) return false;

    state = state.copyWith(isCreating: true, clearError: true);
    try {
      final res = await _dio.post(
        ApiEndpoints.sellerProductFromCatalog,
        data: {
          'standardProductId': product.id,
          'variants': state.variants.map((v) => v.toJson()).toList(),
          'goLive': true,
        },
      );
      final data = res.data as Map<String, dynamic>;
      if (data['success'] == true) {
        final payload = data['data'] as Map<String, dynamic>? ?? {};
        state = state.copyWith(
          isCreating: false,
          successProductId: payload['productId'] as String?,
          successImageUrl: payload['imageUrl'] as String?,
        );
        return true;
      } else {
        state = state.copyWith(
          isCreating: false,
          error: data['message'] as String? ?? 'Failed to create listing',
        );
        return false;
      }
    } on DioException catch (e) {
      state = state.copyWith(
        isCreating: false,
        error: e.response?.data?['message'] as String? ?? 'Network error. Please try again.',
      );
      return false;
    }
  }

  // ── Reset ─────────────────────────────────────────────────────────────────

  void reset() {
    _debounce?.cancel();
    state = const CatalogListingState();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  int _counter = 0;
  String _id() => 'v${++_counter}';
}

// ── Provider ──────────────────────────────────────────────────────────────────

final catalogListingPod =
    StateNotifierProvider.autoDispose<CatalogListingNotifier, CatalogListingState>(
  (ref) => CatalogListingNotifier(),
);
