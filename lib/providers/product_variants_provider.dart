import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../core/errors/app_exception.dart';
import '../models/discount_config.dart';

class ProductVariantsState {
  final bool isLoading;
  final bool isSubmitting;
  final String? error;
  final List<Map<String, dynamic>> variants;

  const ProductVariantsState({
    this.isLoading   = false,
    this.isSubmitting = false,
    this.error,
    this.variants = const [],
  });

  ProductVariantsState copyWith({
    bool? isLoading,
    bool? isSubmitting,
    String? error,
    List<Map<String, dynamic>>? variants,
  }) => ProductVariantsState(
    isLoading:    isLoading    ?? this.isLoading,
    isSubmitting: isSubmitting ?? this.isSubmitting,
    error:        error,
    variants:     variants     ?? this.variants,
  );
}

class ProductVariantsNotifier extends StateNotifier<ProductVariantsState> {
  ProductVariantsNotifier() : super(const ProductVariantsState());

  Dio get _client => ApiClient.instance.client;

  Future<void> fetchVariants(String productId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res  = await _client.get('${ApiEndpoints.sellerProductBase}/$productId/variants');
      final body = res.data as Map<String, dynamic>;
      final data = (body['data'] as List<dynamic>?) ?? [];
      state = state.copyWith(isLoading: false, variants: data.cast<Map<String, dynamic>>());
    } on DioException catch (e) {
      state = state.copyWith(isLoading: false, error: AppException.fromDioError(e).message);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> updateVariant(
    String productId,
    String variantId, {
    int? priceInPaise,
    int? stock,
  }) async {
    state = state.copyWith(isSubmitting: true, error: null);
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
        state = state.copyWith(isSubmitting: false);
        await fetchVariants(productId);
        return true;
      }
      state = state.copyWith(isSubmitting: false, error: resp['message'] as String?);
      return false;
    } on DioException catch (e) {
      state = state.copyWith(isSubmitting: false, error: AppException.fromDioError(e).message);
      return false;
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: e.toString());
      return false;
    }
  }

  // PATCH .../variants/{variantId}/discount — set or update a variant's discount.
  Future<bool> setVariantDiscount(String productId, String variantId, DiscountConfig config) async {
    state = state.copyWith(isSubmitting: true, error: null);
    try {
      final res  = await _client.patch(
        ApiEndpoints.sellerProductVariantDiscount(productId, variantId),
        data: config.toJson(),
      );
      final resp = res.data as Map<String, dynamic>;
      if (resp['success'] == true) {
        state = state.copyWith(isSubmitting: false);
        await fetchVariants(productId);
        return true;
      }
      state = state.copyWith(isSubmitting: false, error: resp['message'] as String?);
      return false;
    } on DioException catch (e) {
      state = state.copyWith(isSubmitting: false, error: AppException.fromDioError(e).message);
      return false;
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: e.toString());
      return false;
    }
  }

  // DELETE .../variants/{variantId}/discount — remove a variant's discount.
  Future<bool> removeVariantDiscount(String productId, String variantId) async {
    state = state.copyWith(isSubmitting: true, error: null);
    try {
      final res  = await _client.delete(
        ApiEndpoints.sellerProductVariantDiscount(productId, variantId),
      );
      final resp = res.data as Map<String, dynamic>;
      if (resp['success'] == true) {
        state = state.copyWith(isSubmitting: false);
        await fetchVariants(productId);
        return true;
      }
      state = state.copyWith(isSubmitting: false, error: resp['message'] as String?);
      return false;
    } on DioException catch (e) {
      state = state.copyWith(isSubmitting: false, error: AppException.fromDioError(e).message);
      return false;
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: e.toString());
      return false;
    }
  }
}

final productVariantsPod =
    StateNotifierProvider.autoDispose<ProductVariantsNotifier, ProductVariantsState>(
  (ref) => ProductVariantsNotifier(),
);
