import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../core/errors/app_exception.dart';
import '../models/discount_config.dart';

// ─── Filter model ──────────────────────────────────────────────────────────────

enum ProductSortBy { newest, nameAsc, nameDesc, priceAsc, priceDesc, stockAsc, stockDesc }
enum ProductStatusFilter { all, active, inactive }
enum ProductStockFilter  { all, inStock, lowStock, outOfStock }

class ProductFilterParams {
  final ProductSortBy      sort;
  final ProductStatusFilter status;
  final ProductStockFilter  stock;
  final String?            categoryId;
  final String?            categoryName;
  final String?            brandId;
  final String?            brandName;
  final double?            minPrice;
  final double?            maxPrice;

  const ProductFilterParams({
    this.sort       = ProductSortBy.newest,
    this.status     = ProductStatusFilter.all,
    this.stock      = ProductStockFilter.all,
    this.categoryId,
    this.categoryName,
    this.brandId,
    this.brandName,
    this.minPrice,
    this.maxPrice,
  });

  ProductFilterParams copyWith({
    ProductSortBy?      sort,
    ProductStatusFilter? status,
    ProductStockFilter?  stock,
    String?             categoryId,
    String?             categoryName,
    String?             brandId,
    String?             brandName,
    double?             minPrice,
    double?             maxPrice,
    bool clearCategory  = false,
    bool clearBrand     = false,
    bool clearMinPrice  = false,
    bool clearMaxPrice  = false,
  }) {
    return ProductFilterParams(
      sort:         sort         ?? this.sort,
      status:       status       ?? this.status,
      stock:        stock        ?? this.stock,
      categoryId:   clearCategory ? null : (categoryId   ?? this.categoryId),
      categoryName: clearCategory ? null : (categoryName ?? this.categoryName),
      brandId:      clearBrand   ? null : (brandId       ?? this.brandId),
      brandName:    clearBrand   ? null : (brandName     ?? this.brandName),
      minPrice:     clearMinPrice ? null : (minPrice      ?? this.minPrice),
      maxPrice:     clearMaxPrice ? null : (maxPrice      ?? this.maxPrice),
    );
  }

  bool get hasActiveFilters =>
      sort         != ProductSortBy.newest       ||
      status       != ProductStatusFilter.all    ||
      stock        != ProductStockFilter.all     ||
      categoryId   != null                       ||
      brandId      != null                       ||
      minPrice     != null                       ||
      maxPrice     != null;

  int get activeCount {
    int n = 0;
    if (sort       != ProductSortBy.newest)    n++;
    if (status     != ProductStatusFilter.all) n++;
    if (stock      != ProductStockFilter.all)  n++;
    if (categoryId != null)                    n++;
    if (brandId    != null)                    n++;
    if (minPrice   != null || maxPrice != null) n++;
    return n;
  }

  static const ProductFilterParams defaults = ProductFilterParams();
}

enum ProductsTab { released, scheduled, trafficSources, viewers }

class ProductsState {
  final bool isLoading;
  final bool isSubmitting;
  final String? error;
  final List<dynamic> products;
  final List<dynamic> brands;
  final List<dynamic> categories;
  final Map<String, dynamic> productDetail;

  // Pagination (Market tab "Load more")
  final int  currentPage;
  final bool hasMore;
  final bool isLoadingMore;

  // Tabs
  final ProductsTab activeTab;
  final List<dynamic> trafficSources;
  final List<dynamic> viewers;
  final bool isLoadingTrafficSources;
  final bool isLoadingViewers;
  final bool trafficSourcesLoaded;
  final bool viewersLoaded;

  // Row selection (Released tab table checkboxes)
  final Set<String> selectedIds;

  // Scheduled tab: not-yet-live products with a future scheduledAt
  final List<dynamic> scheduledProducts;
  final bool isLoadingScheduled;
  final bool isLoadingMoreScheduled;
  final bool scheduledLoaded;
  final int  scheduledCurrentPage;
  final bool scheduledHasMore;
  final Set<String> selectedScheduledIds;

  const ProductsState({
    this.isLoading    = false,
    this.isSubmitting = false,
    this.error,
    this.products      = const [],
    this.brands        = const [],
    this.categories    = const [],
    this.productDetail = const {},
    this.currentPage   = 0,
    this.hasMore       = true,
    this.isLoadingMore = false,
    this.activeTab     = ProductsTab.released,
    this.trafficSources = const [],
    this.viewers         = const [],
    this.isLoadingTrafficSources = false,
    this.isLoadingViewers        = false,
    this.trafficSourcesLoaded    = false,
    this.viewersLoaded           = false,
    this.selectedIds = const {},
    this.scheduledProducts       = const [],
    this.isLoadingScheduled      = false,
    this.isLoadingMoreScheduled  = false,
    this.scheduledLoaded         = false,
    this.scheduledCurrentPage    = 0,
    this.scheduledHasMore        = true,
    this.selectedScheduledIds    = const {},
  });

  ProductsState copyWith({
    bool? isLoading,
    bool? isSubmitting,
    String? error,
    List<dynamic>? products,
    List<dynamic>? brands,
    List<dynamic>? categories,
    Map<String, dynamic>? productDetail,
    int? currentPage,
    bool? hasMore,
    bool? isLoadingMore,
    ProductsTab? activeTab,
    List<dynamic>? trafficSources,
    List<dynamic>? viewers,
    bool? isLoadingTrafficSources,
    bool? isLoadingViewers,
    bool? trafficSourcesLoaded,
    bool? viewersLoaded,
    Set<String>? selectedIds,
    List<dynamic>? scheduledProducts,
    bool? isLoadingScheduled,
    bool? isLoadingMoreScheduled,
    bool? scheduledLoaded,
    int?  scheduledCurrentPage,
    bool? scheduledHasMore,
    Set<String>? selectedScheduledIds,
  }) {
    return ProductsState(
      isLoading:     isLoading     ?? this.isLoading,
      isSubmitting:  isSubmitting  ?? this.isSubmitting,
      error:         error,
      products:      products      ?? this.products,
      brands:        brands        ?? this.brands,
      categories:    categories    ?? this.categories,
      productDetail: productDetail ?? this.productDetail,
      currentPage:   currentPage   ?? this.currentPage,
      hasMore:       hasMore       ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      activeTab:     activeTab     ?? this.activeTab,
      trafficSources: trafficSources ?? this.trafficSources,
      viewers:         viewers         ?? this.viewers,
      isLoadingTrafficSources: isLoadingTrafficSources ?? this.isLoadingTrafficSources,
      isLoadingViewers:        isLoadingViewers         ?? this.isLoadingViewers,
      trafficSourcesLoaded:    trafficSourcesLoaded     ?? this.trafficSourcesLoaded,
      viewersLoaded:           viewersLoaded             ?? this.viewersLoaded,
      selectedIds:   selectedIds   ?? this.selectedIds,
      scheduledProducts:      scheduledProducts      ?? this.scheduledProducts,
      isLoadingScheduled:     isLoadingScheduled      ?? this.isLoadingScheduled,
      isLoadingMoreScheduled: isLoadingMoreScheduled  ?? this.isLoadingMoreScheduled,
      scheduledLoaded:        scheduledLoaded         ?? this.scheduledLoaded,
      scheduledCurrentPage:   scheduledCurrentPage    ?? this.scheduledCurrentPage,
      scheduledHasMore:       scheduledHasMore        ?? this.scheduledHasMore,
      selectedScheduledIds:   selectedScheduledIds    ?? this.selectedScheduledIds,
    );
  }
}

class ProductsNotifier extends StateNotifier<ProductsState> {
  ProductsNotifier() : super(const ProductsState());

  Dio get _client => ApiClient.instance.client;

  // GET /api/v1/seller/product/my-products  (ES-backed search, falls back to DB if ES is down)
  // GET /api/v1/seller/product/my-categories
  //
  // [page]/[size] default to the first page of 50 as before. When [append] is
  // true, the fetched page is concatenated onto the existing `state.products`
  // (used by the "Load more" control) instead of replacing it; [page] then
  // also becomes the new `state.currentPage`. `hasMore` is derived from
  // whether the page returned a full page of results.
  Future<void> fetchProducts({
    ProductFilterParams? filters,
    String? query,
    int page = 0,
    int size = 50,
    bool append = false,
  }) async {
    state = state.copyWith(
      isLoading:     append ? state.isLoading : true,
      isLoadingMore: append,
      error:         null,
    );

    // Each fetch is independent — a failed categories call never blocks
    // the products fetch. Brands are fetched lazily (see fetchBrandsIfNeeded)
    // only when the filter sheet is actually opened.
    final results = await Future.wait([
      _fetchProductsSafe(filters: filters, query: query, page: page, size: size),
      if (!append && state.categories.isEmpty) _fetchSafe(_client.get(ApiEndpoints.sellerCategories)),
    ]);

    final fetched    = results[0];
    final categories = results.length > 1 ? results[1] : state.categories;
    final merged     = append ? [...state.products, ...fetched] : fetched;

    state = state.copyWith(
      isLoading:     false,
      isLoadingMore: false,
      error:         null,
      products:      merged,
      categories:    categories,
      currentPage:   page,
      hasMore:       fetched.length >= size,
    );
  }

  // GET /api/v1/brand — only called when the filter sheet is opened, since
  // brands are only used there (not on the products list itself).
  Future<void> fetchBrandsIfNeeded() async {
    if (state.brands.isNotEmpty) return;
    final brands = await _fetchSafe(_client.get(ApiEndpoints.brands));
    state = state.copyWith(brands: brands);
  }

  // ── Tabs (Released / Scheduled / Traffic sources / Viewers) ────────────────

  // Switches the active tab and lazily fetches that tab's data on first
  // switch — mirrors fetchBrandsIfNeeded's "don't refetch if already loaded"
  // pattern.
  Future<void> setTab(ProductsTab tab) async {
    state = state.copyWith(activeTab: tab);
    switch (tab) {
      case ProductsTab.released:
        break;
      case ProductsTab.scheduled:
        if (!state.scheduledLoaded) await fetchScheduledProducts();
        break;
      case ProductsTab.trafficSources:
        if (!state.trafficSourcesLoaded) await fetchTrafficSources();
        break;
      case ProductsTab.viewers:
        if (!state.viewersLoaded) await fetchViewers();
        break;
    }
  }

  // ── Scheduled tab ────────────────────────────────────────────────────────

  // GET /api/v1/seller/product/scheduled-products?page=&size=&query=
  Future<void> fetchScheduledProducts({String? query, int page = 0, int size = 50, bool append = false}) async {
    state = state.copyWith(
      isLoadingScheduled:     append ? state.isLoadingScheduled : true,
      isLoadingMoreScheduled: append,
    );
    try {
      final params = <String, dynamic>{'page': page, 'size': size};
      if (query != null && query.trim().isNotEmpty) params['query'] = query.trim();
      final res  = await _client.get(ApiEndpoints.sellerProductScheduled, queryParameters: params);
      final body = res.data as Map<String, dynamic>?;
      final data = body?['data'];
      final fetched = (data is Map && data['products'] is List)
          ? List<dynamic>.from(data['products'] as List)
          : <dynamic>[];
      final merged = append ? [...state.scheduledProducts, ...fetched] : fetched;
      state = state.copyWith(
        isLoadingScheduled:     false,
        isLoadingMoreScheduled: false,
        scheduledProducts:      merged,
        scheduledLoaded:        true,
        scheduledCurrentPage:   page,
        scheduledHasMore:       fetched.length >= size,
      );
    } catch (_) {
      state = state.copyWith(isLoadingScheduled: false, isLoadingMoreScheduled: false, scheduledLoaded: true);
    }
  }

  void toggleScheduledSelected(String id) {
    final next = Set<String>.from(state.selectedScheduledIds);
    if (!next.remove(id)) next.add(id);
    state = state.copyWith(selectedScheduledIds: next);
  }

  void selectAllScheduled(List<String> ids) {
    state = state.copyWith(selectedScheduledIds: Set<String>.from(ids));
  }

  void clearScheduledSelection() {
    state = state.copyWith(selectedScheduledIds: const {});
  }

  // POST {productId}/schedule — also used to reschedule an already-scheduled product.
  Future<bool> scheduleProduct(String productId, DateTime scheduledAt) async {
    try {
      final res  = await _client.post(
        '${ApiEndpoints.sellerProductBase}/$productId/schedule',
        data: {'scheduledAt': scheduledAt.toUtc().toIso8601String()},
      );
      final body = res.data as Map<String, dynamic>;
      if (body['success'] == true) {
        state = state.copyWith(
          scheduledProducts: state.scheduledProducts.map((p) {
            final m = p as Map<String, dynamic>;
            return m['id']?.toString() == productId
                ? {...m, 'scheduledAt': scheduledAt.toUtc().toIso8601String()}
                : m;
          }).toList(),
        );
        return true;
      }
      state = state.copyWith(error: body['message'] as String?);
      return false;
    } on DioException catch (e) {
      state = state.copyWith(error: AppException.fromDioError(e).message);
      return false;
    }
  }

  // POST {productId}/publish-now
  Future<bool> publishScheduledProductNow(String productId) async {
    try {
      final res  = await _client.post('${ApiEndpoints.sellerProductBase}/$productId/publish-now');
      final body = res.data as Map<String, dynamic>;
      if (body['success'] == true) {
        state = state.copyWith(
          scheduledProducts: state.scheduledProducts.where((p) => (p as Map)['id']?.toString() != productId).toList(),
        );
        return true;
      }
      state = state.copyWith(error: body['message'] as String?);
      return false;
    } on DioException catch (e) {
      state = state.copyWith(error: AppException.fromDioError(e).message);
      return false;
    }
  }

  // Loops over scheduleProduct for each selected id (mirrors bulkDelete/bulkToggleActive).
  Future<void> bulkReschedule(DateTime scheduledAt) async {
    final ids = List<String>.from(state.selectedScheduledIds);
    for (final id in ids) {
      await scheduleProduct(id, scheduledAt);
    }
    clearScheduledSelection();
  }

  // Loops over publishScheduledProductNow for each selected id.
  Future<void> bulkPublishNow() async {
    final ids = List<String>.from(state.selectedScheduledIds);
    for (final id in ids) {
      await publishScheduledProductNow(id);
    }
    clearScheduledSelection();
  }

  // GET /api/v1/seller/product/traffic-sources?days=7 → [{source, count}]
  Future<void> fetchTrafficSources({int days = 7}) async {
    state = state.copyWith(isLoadingTrafficSources: true);
    final data = await _fetchSafe(
      _client.get(ApiEndpoints.sellerProductTrafficSources, queryParameters: {'days': days}),
    );
    state = state.copyWith(
      isLoadingTrafficSources: false,
      trafficSources: data,
      trafficSourcesLoaded: true,
    );
  }

  // GET /api/v1/seller/product/viewers?days=7 → [{productId, productName, viewerCount}]
  Future<void> fetchViewers({int days = 7}) async {
    state = state.copyWith(isLoadingViewers: true);
    final data = await _fetchSafe(
      _client.get(ApiEndpoints.sellerProductViewers, queryParameters: {'days': days}),
    );
    state = state.copyWith(
      isLoadingViewers: false,
      viewers: data,
      viewersLoaded: true,
    );
  }

  // ── Row selection & bulk actions (Market tab table checkboxes) ────────────

  void toggleSelected(String id) {
    final next = Set<String>.from(state.selectedIds);
    if (!next.remove(id)) next.add(id);
    state = state.copyWith(selectedIds: next);
  }

  void selectAll(List<String> ids) {
    state = state.copyWith(selectedIds: Set<String>.from(ids));
  }

  void clearSelection() {
    state = state.copyWith(selectedIds: const {});
  }

  // Loops over the existing single-item deleteProduct for each selected id
  // (no new bulk backend endpoint for v1). Clears selection when done.
  Future<void> bulkDelete() async {
    final ids = List<String>.from(state.selectedIds);
    for (final id in ids) {
      await deleteProduct(id);
    }
    clearSelection();
  }

  // Loops over the existing single-item toggleActive for each selected id
  // whose current state doesn't already match [makeActive].
  Future<void> bulkToggleActive(bool makeActive) async {
    final ids = List<String>.from(state.selectedIds);
    for (final id in ids) {
      final product = state.products.cast<Map>().firstWhere(
        (p) => p['id']?.toString() == id,
        orElse: () => <String, dynamic>{},
      );
      final isActive = product['isActive'] as bool? ?? true;
      if (isActive != makeActive) {
        await toggleActive(id);
      }
    }
    clearSelection();
  }

  Future<List<dynamic>> _fetchProductsSafe({
    ProductFilterParams? filters,
    String? query,
    int page = 0,
    int size = 50,
  }) async {
    try {
      final params = <String, dynamic>{'page': page, 'size': size};
      if (query != null && query.trim().isNotEmpty) params['query'] = query.trim();
      if (filters != null) {
        if (filters.categoryId != null) params['categoryId'] = filters.categoryId;
        if (filters.brandId    != null) params['brandId']    = filters.brandId;
        if (filters.minPrice   != null) params['minPrice']   = filters.minPrice;
        if (filters.maxPrice   != null) params['maxPrice']   = filters.maxPrice;
        params['sortBy'] = _toEsSortBy(filters.sort);

        // Status → backend isActive
        if (filters.status == ProductStatusFilter.active)   params['isActive'] = true;
        if (filters.status == ProductStatusFilter.inactive) params['isActive'] = false;

        // Stock → backend maxStock (upper bound only; exact bucketing refined client-side)
        if (filters.stock == ProductStockFilter.outOfStock) params['maxStock'] = 0;
        if (filters.stock == ProductStockFilter.lowStock)   params['maxStock'] = 10;
      }
      final res  = await _client.get(ApiEndpoints.sellerProducts, queryParameters: params);
      final body = res.data as Map<String, dynamic>?;
      final data = body?['data'];
      if (data is Map && data['products'] is List) return List<dynamic>.from(data['products'] as List);
      return _asList(res.data);
    } catch (e) {
      state = state.copyWith(error: e is DioException
          ? AppException.fromDioError(e).message
          : e.toString());
      return [];
    }
  }

  String _toEsSortBy(ProductSortBy sort) {
    switch (sort) {
      case ProductSortBy.priceAsc:  return 'price_asc';
      case ProductSortBy.priceDesc: return 'price_desc';
      case ProductSortBy.newest:    return 'newest';
      default:                      return 'newest';
    }
  }

  // Returns an empty list instead of throwing so it never blocks sibling fetches.
  Future<List<dynamic>> _fetchSafe(Future<dynamic> call) async {
    try {
      final res = await call;
      return _asList(res.data);
    } catch (_) {
      return [];
    }
  }

  // POST /api/v1/seller/product/create  (multipart/form-data)
  Future<bool> addProduct(Map<String, dynamic> data) async {
    state = state.copyWith(isSubmitting: true, error: null);
    try {
      final formData = FormData.fromMap({
        'name':        data['name'],
        'description': data['description'],
        if (data['categoryId'] != null) 'category': data['categoryId'],
        'step': 'BASIC_INFO',
      });
      final res  = await _client.post(
        ApiEndpoints.sellerProductCreate,
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );
      final body = res.data as Map<String, dynamic>;
      if (body['success'] == true) {
        state = state.copyWith(isSubmitting: false);
        await fetchProducts();
        return true;
      }
      state = state.copyWith(isSubmitting: false, error: body['message']);
      return false;
    } on DioException catch (e) {
      state = state.copyWith(isSubmitting: false, error: AppException.fromDioError(e).message);
      return false;
    }
  }

  // GET /api/v1/seller/product/{productId}/edit-data
  Future<Map<String, dynamic>> fetchEditData(String productId) async {
    try {
      final res  = await _client.get('${ApiEndpoints.sellerProductBase}/$productId/edit-data');
      final body = res.data as Map<String, dynamic>?;
      return (body?['data'] as Map<String, dynamic>?) ?? {};
    } catch (_) {
      return {};
    }
  }

  // Update basic info via create API (name/description/category)
  Future<bool> updateBasicInfo(
    String productId, {
    required String name,
    required String description,
    required String categoryId,
    required String step,
  }) async {
    state = state.copyWith(isSubmitting: true, error: null);
    try {
      final formData = FormData.fromMap({
        'productId':   productId,
        'name':        name,
        'description': description,
        'category':    categoryId,
        'step':        step,
      });
      final res  = await _client.post(
        ApiEndpoints.sellerProductCreate,
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );
      final body = res.data as Map<String, dynamic>;
      if (body['success'] == true) {
        state = state.copyWith(
          isSubmitting: false,
          products: state.products.map((p) {
            final m = p as Map<String, dynamic>;
            return m['id']?.toString() == productId ? {...m, 'name': name} : m;
          }).toList(),
        );
        return true;
      }
      state = state.copyWith(isSubmitting: false, error: body['message'] as String?);
      return false;
    } on DioException catch (e) {
      state = state.copyWith(isSubmitting: false, error: AppException.fromDioError(e).message);
      return false;
    }
  }

  // Toggle active via create API (fetches current data first)
  Future<bool> toggleActive(String productId) async {
    try {
      final edit     = await fetchEditData(productId);
      if (edit.isEmpty) {
        state = state.copyWith(error: 'Could not load product data');
        return false;
      }
      final newActive = !(edit['isActive'] as bool? ?? true);
      final formData  = FormData.fromMap({
        'productId':   productId,
        'name':        edit['name'] as String? ?? '',
        'description': edit['description'] as String? ?? '',
        'category':    edit['categoryId'] as String? ?? '',
        'step':        edit['step'] as String? ?? 'LIVE',
        'isActive':    newActive.toString(),
      });
      final res  = await _client.post(
        ApiEndpoints.sellerProductCreate,
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );
      final body = res.data as Map<String, dynamic>;
      if (body['success'] == true) {
        state = state.copyWith(
          products: state.products.map((p) {
            final m = p as Map<String, dynamic>;
            return m['id']?.toString() == productId ? {...m, 'isActive': newActive} : m;
          }).toList(),
        );
        return true;
      }
      state = state.copyWith(error: body['message'] as String?);
      return false;
    } on DioException catch (e) {
      state = state.copyWith(error: AppException.fromDioError(e).message);
      return false;
    }
  }

  // Update a single variant's price / stock
  Future<bool> updateVariant(String productId, String variantId, {int? priceInPaise, int? stock}) async {
    try {
      final body = <String, dynamic>{};
      if (priceInPaise != null) body['priceInPaise'] = priceInPaise;
      if (stock        != null) body['stock']        = stock;
      final res  = await _client.patch(
        '${ApiEndpoints.sellerProductBase}/$productId/variants/$variantId',
        data: body,
      );
      final resp = res.data as Map<String, dynamic>;
      if (resp['success'] == true) {
        if (stock != null) {
          state = state.copyWith(
            products: state.products.map((p) {
              final m = p as Map<String, dynamic>;
              return m['id']?.toString() == productId ? {...m, 'stock': stock} : m;
            }).toList(),
          );
        }
        return true;
      }
      state = state.copyWith(error: resp['message'] as String?);
      return false;
    } on DioException catch (e) {
      state = state.copyWith(error: AppException.fromDioError(e).message);
      return false;
    }
  }

  // PATCH .../variants/{variantId}/discount — set or update a variant's discount.
  // Mirrors updateVariant's error-handling/state-update pattern; this provider's
  // `state.products` (the my-products list) doesn't carry per-variant discount
  // data, so — same as updateVariant does for anything besides `stock` — there
  // is nothing further to reconcile locally beyond the success/failure result.
  Future<bool> setVariantDiscount(String productId, String variantId, DiscountConfig config) async {
    try {
      final res  = await _client.patch(
        ApiEndpoints.sellerProductVariantDiscount(productId, variantId),
        data: config.toJson(),
      );
      final resp = res.data as Map<String, dynamic>;
      if (resp['success'] == true) return true;
      state = state.copyWith(error: resp['message'] as String?);
      return false;
    } on DioException catch (e) {
      state = state.copyWith(error: AppException.fromDioError(e).message);
      return false;
    }
  }

  // DELETE .../variants/{variantId}/discount — remove a variant's discount.
  Future<bool> removeVariantDiscount(String productId, String variantId) async {
    try {
      final res  = await _client.delete(
        ApiEndpoints.sellerProductVariantDiscount(productId, variantId),
      );
      final resp = res.data as Map<String, dynamic>;
      if (resp['success'] == true) return true;
      state = state.copyWith(error: resp['message'] as String?);
      return false;
    } on DioException catch (e) {
      state = state.copyWith(error: AppException.fromDioError(e).message);
      return false;
    }
  }

  // Update brand
  Future<bool> updateBrand(String productId, String brandId) async {
    try {
      final res  = await _client.post(
        ApiEndpoints.sellerProductAttachBrand,
        queryParameters: {'productId': productId, 'brandId': brandId},
      );
      final body = res.data as Map<String, dynamic>;
      if (body['success'] == true) {
        final brand = state.brands.cast<Map>().firstWhere(
          (b) => b['id']?.toString() == brandId,
          orElse: () => <String, dynamic>{},
        );
        state = state.copyWith(
          products: state.products.map((p) {
            final m = p as Map<String, dynamic>;
            return m['id']?.toString() == productId
                ? {...m, 'brand': brand['name'] as String? ?? ''}
                : m;
          }).toList(),
        );
        return true;
      }
      state = state.copyWith(error: body['message'] as String?);
      return false;
    } on DioException catch (e) {
      state = state.copyWith(error: AppException.fromDioError(e).message);
      return false;
    }
  }

  // Add tags
  Future<bool> addTags(String productId, List<String> tags) async {
    try {
      final res  = await _client.post(
        ApiEndpoints.sellerProductAddTag,
        data: {'product_id': productId, 'tags': tags},
      );
      final body = res.data as Map<String, dynamic>;
      return body['success'] == true;
    } on DioException catch (e) {
      state = state.copyWith(error: AppException.fromDioError(e).message);
      return false;
    }
  }

  // Remove a tag
  Future<bool> removeTag(String productId, String tagId) async {
    try {
      final res  = await _client.delete('${ApiEndpoints.sellerProductBase}/$productId/tags/$tagId');
      final body = res.data as Map<String, dynamic>;
      return body['success'] == true;
    } on DioException catch (e) {
      state = state.copyWith(error: AppException.fromDioError(e).message);
      return false;
    }
  }

  // Save attribute values
  Future<bool> saveAttributes(
    String productId,
    String step,
    List<Map<String, dynamic>> attrs,
  ) async {
    try {
      final data = {
        'productId':            productId,
        'step':                 step,
        'categoryAttributeId':  attrs.map((a) => a['categoryAttributeId']).toList(),
        'productAttributeIds':  attrs.map((a) => a['productAttributeId']).toList(),
        'values':               attrs.map((a) => [a['value'] as String]).toList(),
      };
      final res  = await _client.post(ApiEndpoints.sellerProductCreateAttribute, data: data);
      final body = res.data as Map<String, dynamic>;
      return body['success'] == true;
    } on DioException catch (e) {
      state = state.copyWith(error: AppException.fromDioError(e).message);
      return false;
    }
  }

  // GET /api/v1/seller/product/make-product-live/{productId}
  Future<bool> makeProductLive(String productId) async {
    try {
      final res  = await _client.get('${ApiEndpoints.sellerProductMakeLive}/$productId');
      final body = res.data as Map<String, dynamic>;
      return body['success'] == true;
    } on DioException {
      return false;
    }
  }

  // DELETE /api/v1/seller/product/{productId}
  Future<bool> deleteProduct(String productId) async {
    try {
      final res  = await _client.delete('${ApiEndpoints.sellerProductBase}/$productId');
      final body = res.data as Map<String, dynamic>;
      if (body['success'] == true) {
        state = state.copyWith(
          products:          state.products.where((p) => (p as Map)['id']?.toString() != productId).toList(),
          scheduledProducts: state.scheduledProducts.where((p) => (p as Map)['id']?.toString() != productId).toList(),
        );
        return true;
      }
      state = state.copyWith(error: body['message']);
      return false;
    } on DioException catch (e) {
      state = state.copyWith(error: AppException.fromDioError(e).message);
      return false;
    }
  }

  // Quick-update: name, priceInPaise, and/or stock in one call.
  // Fetches current edit-data for the name patch; uses the product's primary
  // variantId (from state) for the price/stock patch.
  Future<bool> quickUpdate(
    String productId, {
    String? name,
    int? priceInPaise,
    int? stock,
  }) async {
    state = state.copyWith(isSubmitting: true, error: null);
    try {
      var success = true;

      if (name != null) {
        final edit = await fetchEditData(productId);
        if (edit.isNotEmpty) {
          final formData = FormData.fromMap({
            'productId':   productId,
            'name':        name,
            'description': edit['description'] as String? ?? '',
            'category':    edit['categoryId']  as String? ?? '',
            'step':        edit['step']         as String? ?? 'LIVE',
          });
          final res  = await _client.post(
            ApiEndpoints.sellerProductCreate,
            data: formData,
            options: Options(contentType: 'multipart/form-data'),
          );
          final body = res.data as Map<String, dynamic>;
          success = success && (body['success'] == true);
          if (!success) state = state.copyWith(error: body['message'] as String?);
        }
      }

      if (priceInPaise != null || stock != null) {
        final product = state.products.cast<Map>().firstWhere(
          (p) => p['id']?.toString() == productId,
          orElse: () => <String, dynamic>{},
        );
        final variantId = product['variantId']?.toString() ?? '';
        if (variantId.isNotEmpty) {
          final varOk = await updateVariant(productId, variantId,
              priceInPaise: priceInPaise, stock: stock);
          success = success && varOk;
        }
      }

      if (success && name != null) {
        state = state.copyWith(
          isSubmitting: false,
          products: state.products.map((p) {
            final m = p as Map<String, dynamic>;
            return m['id']?.toString() == productId ? {...m, 'name': name} : m;
          }).toList(),
        );
      } else {
        state = state.copyWith(isSubmitting: false);
      }
      return success;
    } on DioException catch (e) {
      state = state.copyWith(isSubmitting: false, error: AppException.fromDioError(e).message);
      return false;
    }
  }

  // GET /api/v1/seller/product/catalog/search?query=&page=0&size=20
  Future<List<dynamic>> searchCatalog(String query, {int page = 0}) async {
    try {
      final res  = await _client.get(
        ApiEndpoints.sellerProductCatalogSearch,
        queryParameters: {'query': query, 'page': page, 'size': 20},
      );
      return _asList(res.data);
    } catch (_) {
      return [];
    }
  }

  List<dynamic> _asList(dynamic data) {
    if (data is Map) {
      final inner = data['data'];
      if (inner is List) return inner;
    }
    if (data is List) return data;
    return [];
  }
}

final productsPod = StateNotifierProvider<ProductsNotifier, ProductsState>(
  (ref) => ProductsNotifier(),
);
