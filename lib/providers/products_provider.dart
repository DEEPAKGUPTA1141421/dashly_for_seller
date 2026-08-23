import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../core/errors/app_exception.dart';

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

class ProductsState {
  final bool isLoading;
  final bool isSubmitting;
  final String? error;
  final List<dynamic> products;
  final List<dynamic> brands;
  final List<dynamic> categories;
  final Map<String, dynamic> productDetail;

  const ProductsState({
    this.isLoading    = false,
    this.isSubmitting = false,
    this.error,
    this.products      = const [],
    this.brands        = const [],
    this.categories    = const [],
    this.productDetail = const {},
  });

  ProductsState copyWith({
    bool? isLoading,
    bool? isSubmitting,
    String? error,
    List<dynamic>? products,
    List<dynamic>? brands,
    List<dynamic>? categories,
    Map<String, dynamic>? productDetail,
  }) {
    return ProductsState(
      isLoading:     isLoading     ?? this.isLoading,
      isSubmitting:  isSubmitting  ?? this.isSubmitting,
      error:         error,
      products:      products      ?? this.products,
      brands:        brands        ?? this.brands,
      categories:    categories    ?? this.categories,
      productDetail: productDetail ?? this.productDetail,
    );
  }
}

class ProductsNotifier extends StateNotifier<ProductsState> {
  ProductsNotifier() : super(const ProductsState());

  Dio get _client => ApiClient.instance.client;

  // GET /api/v1/seller/product/my-products-es  (ES-backed, falls back to DB)
  // GET /api/v1/seller/product/categories
  // GET /api/v1/brand
  Future<void> fetchProducts({ProductFilterParams? filters}) async {
    state = state.copyWith(isLoading: true, error: null);

    // Each fetch is independent — a failed brands/categories call never
    // blocks the products fetch.
    final results = await Future.wait([
      _fetchProductsSafe(filters: filters),
      if (state.categories.isEmpty) _fetchSafe(_client.get(ApiEndpoints.sellerCategories)),
      if (state.brands.isEmpty)     _fetchSafe(_client.get(ApiEndpoints.brands)),
    ]);

    final products   = results[0];
    final categories = results.length > 1 ? results[1] : state.categories;
    final brands     = results.length > 2 ? results[2] : state.brands;

    state = state.copyWith(
      isLoading:  false,
      error:      null,
      products:   products,
      categories: categories,
      brands:     brands,
    );
  }

  // Tries ES endpoint (with optional filter params) first, falls back to DB.
  Future<List<dynamic>> _fetchProductsSafe({ProductFilterParams? filters}) async {
    try {
      final params = <String, dynamic>{'page': 0, 'size': 50};
      if (filters != null) {
        if (filters.categoryId != null) params['categoryId'] = filters.categoryId;
        if (filters.brandId    != null) params['brandId']    = filters.brandId;
        if (filters.minPrice   != null) params['minPrice']   = filters.minPrice;
        if (filters.maxPrice   != null) params['maxPrice']   = filters.maxPrice;
        params['sortBy'] = _toEsSortBy(filters.sort);
      }
      final res  = await _client.get(ApiEndpoints.sellerProductsEs, queryParameters: params);
      final body = res.data as Map<String, dynamic>?;
      final data = body?['data'] as Map<String, dynamic>?;
      final list = data?['products'];
      if (list is List && list.isNotEmpty) return List<dynamic>.from(list);
    } catch (_) {}

    // ES endpoint unavailable — fall back to DB endpoint
    try {
      final res = await _client.get(
        ApiEndpoints.sellerProducts,
        queryParameters: {'page': 0, 'size': 50},
      );
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
          products: state.products.where((p) => (p as Map)['id']?.toString() != productId).toList(),
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
