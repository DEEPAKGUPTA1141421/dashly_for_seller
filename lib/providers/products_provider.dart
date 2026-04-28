import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../core/errors/app_exception.dart';

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

  // GET /api/v1/seller/product/my-products  (seller's own live products)
  // GET /api/v1/seller/product/categories
  // GET /api/v1/brand
  Future<void> fetchProducts() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final results = await Future.wait([
        _client.get(ApiEndpoints.sellerProducts, queryParameters: {'page': 0, 'size': 50}),
        _client.get(ApiEndpoints.sellerCategories),
        _client.get(ApiEndpoints.brands),
      ]);
      state = state.copyWith(
        isLoading:  false,
        products:   _asList(results[0].data),
        categories: _asList(results[1].data),
        brands:     _asList(results[2].data),
      );
    } on DioException catch (e) {
      state = state.copyWith(isLoading: false, error: AppException.fromDioError(e).message);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  // POST /api/v1/seller/product/create  (multipart/form-data)
  // Fields: name, description, price, quantity, images (file), categoryId, brandId, etc.
  Future<bool> addProduct(Map<String, dynamic> data) async {
    state = state.copyWith(isSubmitting: true, error: null);
    try {
      final formData = FormData.fromMap({
        'name':        data['name'],
        'description': data['description'],
        'price':       data['price'],
        'quantity':    data['stock'],
        if (data['categoryId'] != null) 'categoryId': data['categoryId'],
        if (data['brandId']    != null) 'brandId':    data['brandId'],
        if (data['sku']        != null) 'sku':        data['sku'],
        if (data['weight']     != null) 'weight':     data['weight'],
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

  // PATCH /api/v1/seller/product/{productId}/toggle-active
  Future<bool> toggleActive(String productId) async {
    try {
      final res  = await _client.patch('${ApiEndpoints.sellerProductBase}/$productId/toggle-active');
      final body = res.data as Map<String, dynamic>;
      if (body['success'] == true) {
        final newActive = (body['data'] as Map<String, dynamic>?)?['isActive'] as bool? ?? false;
        state = state.copyWith(
          products: state.products.map((p) {
            final m = p as Map<String, dynamic>;
            return m['id']?.toString() == productId ? {...m, 'isActive': newActive} : m;
          }).toList(),
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

  // PATCH /api/v1/seller/product/{productId}/quick-update
  Future<bool> quickUpdate(String productId, {String? name, int? priceInPaise, int? stock}) async {
    state = state.copyWith(isSubmitting: true, error: null);
    try {
      final body = <String, dynamic>{};
      if (name         != null) body['name']         = name;
      if (priceInPaise != null) body['priceInPaise'] = priceInPaise;
      if (stock        != null) body['stock']        = stock;
      final res  = await _client.patch('${ApiEndpoints.sellerProductBase}/$productId/quick-update', data: body);
      final resp = res.data as Map<String, dynamic>;
      if (resp['success'] == true) {
        state = state.copyWith(isSubmitting: false);
        await fetchProducts();
        return true;
      }
      state = state.copyWith(isSubmitting: false, error: resp['message']);
      return false;
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
