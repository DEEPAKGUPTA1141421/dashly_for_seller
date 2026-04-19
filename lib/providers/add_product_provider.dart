import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../core/errors/app_exception.dart';

class AddProductState {
  final bool isLoading;
  final bool isSubmitting;
  final String? error;
  final int currentStep;

  // Fetched from API
  final List<dynamic> categories;
  final List<dynamic> brands;
  // All attributes for selected category (basic + additional merged for UI)
  final List<dynamic> attributes;

  // Step 0 – Category
  final String? categoryId;
  final String? categoryName;

  // Step 1 – Basic Info
  final String productName;
  final String description;

  // Step 2 – Images
  final List<String> imagePaths;

  // Step 3 – Pricing
  final String price;
  final String mrp;
  final String stock;
  final String sku;
  final String weight;

  // Step 4 – Attributes  (categoryAttributeId → comma-separated value string)
  final Map<String, String> attributeValues;

  // Step 5 – Variants
  final List<Map<String, dynamic>> variants;

  // Step 6 – Brand & Tags
  final String? brandId;
  final String? brandName;
  final List<String> tags;

  // Set after create API call
  final String? createdProductId;

  const AddProductState({
    this.isLoading       = false,
    this.isSubmitting    = false,
    this.error,
    this.currentStep     = 0,
    this.categories      = const [],
    this.brands          = const [],
    this.attributes      = const [],
    this.categoryId,
    this.categoryName,
    this.productName     = '',
    this.description     = '',
    this.imagePaths      = const [],
    this.price           = '',
    this.mrp             = '',
    this.stock           = '',
    this.sku             = '',
    this.weight          = '100g',
    this.attributeValues = const {},
    this.variants        = const [],
    this.brandId,
    this.brandName,
    this.tags            = const [],
    this.createdProductId,
  });

  AddProductState copyWith({
    bool? isLoading,
    bool? isSubmitting,
    String? error,
    int? currentStep,
    List<dynamic>? categories,
    List<dynamic>? brands,
    List<dynamic>? attributes,
    String? categoryId,
    String? categoryName,
    String? productName,
    String? description,
    List<String>? imagePaths,
    String? price,
    String? mrp,
    String? stock,
    String? sku,
    String? weight,
    Map<String, String>? attributeValues,
    List<Map<String, dynamic>>? variants,
    String? brandId,
    String? brandName,
    List<String>? tags,
    String? createdProductId,
  }) {
    return AddProductState(
      isLoading:        isLoading        ?? this.isLoading,
      isSubmitting:     isSubmitting     ?? this.isSubmitting,
      error:            error,
      currentStep:      currentStep      ?? this.currentStep,
      categories:       categories       ?? this.categories,
      brands:           brands           ?? this.brands,
      attributes:       attributes       ?? this.attributes,
      categoryId:       categoryId       ?? this.categoryId,
      categoryName:     categoryName     ?? this.categoryName,
      productName:      productName      ?? this.productName,
      description:      description      ?? this.description,
      imagePaths:       imagePaths       ?? this.imagePaths,
      price:            price            ?? this.price,
      mrp:              mrp              ?? this.mrp,
      stock:            stock            ?? this.stock,
      sku:              sku              ?? this.sku,
      weight:           weight           ?? this.weight,
      attributeValues:  attributeValues  ?? this.attributeValues,
      variants:         variants         ?? this.variants,
      brandId:          brandId          ?? this.brandId,
      brandName:        brandName        ?? this.brandName,
      tags:             tags             ?? this.tags,
      createdProductId: createdProductId ?? this.createdProductId,
    );
  }
}

class AddProductNotifier extends StateNotifier<AddProductState> {
  AddProductNotifier() : super(const AddProductState());

  Dio get _client => ApiClient.instance.client;

  // ── Init ─────────────────────────────────────────────────────────────────
  Future<void> init() async {
    state = state.copyWith(isLoading: true, error: null);

    List<dynamic> cats   = [];
    List<dynamic> brands = [];

    try {
      final res = await _client.get(ApiEndpoints.sellerCategories);
      cats = _list(res.data);
    } on DioException catch (e) {
      state = state.copyWith(error: AppException.fromDioError(e).message);
    } catch (_) {}

    try {
      final res = await _client.get(ApiEndpoints.brands);
      brands = _list(res.data);
    } catch (_) {}

    state = state.copyWith(isLoading: false, categories: cats, brands: brands);
  }

  // ── Step 0 – Category ─────────────────────────────────────────────────────
  // GET /api/v1/seller/product/getall-category-attribute/{categoryId}
  // Response: { success, data: { attributeIds: [ { id, name, fieldType,
  //   isRequired, isAdditionalAttribute, isRadio, options } ] } }
  Future<void> saveCategory(String id, String name) async {
    state = state.copyWith(categoryId: id, categoryName: name, isLoading: true, error: null);
    try {
      final res  = await _client.get('${ApiEndpoints.categoryAttributes}/$id');
      final body = res.data as Map<String, dynamic>;
      final data = body['data'] as Map<String, dynamic>? ?? {};
      final attrs = (data['attributeIds'] as List<dynamic>?) ?? [];
      state = state.copyWith(isLoading: false, attributes: attrs, currentStep: 1);
    } on DioException {
      // Advance even if attributes fail — they are optional
      state = state.copyWith(isLoading: false, attributes: [], currentStep: 1);
    }
  }

  // ── Step 1 – Basic Info ───────────────────────────────────────────────────
  void saveBasicInfo(String name, String desc) =>
      state = state.copyWith(productName: name, description: desc, currentStep: 2);

  // ── Step 2 – Images ───────────────────────────────────────────────────────
  void addImage(String path) =>
      state = state.copyWith(imagePaths: [...state.imagePaths, path]);

  void removeImage(int index) {
    final updated = [...state.imagePaths]..removeAt(index);
    state = state.copyWith(imagePaths: updated);
  }

  void advanceFromImages() =>
      state = state.copyWith(currentStep: 3);

  // ── Step 3 – Pricing ──────────────────────────────────────────────────────
  void savePricing({
    required String price,
    required String mrp,
    required String stock,
    required String sku,
    required String weight,
  }) => state = state.copyWith(
        price: price, mrp: mrp, stock: stock, sku: sku, weight: weight, currentStep: 4,
      );

  // ── Step 4 – Attributes ───────────────────────────────────────────────────
  void saveAttributes(Map<String, String> values) =>
      state = state.copyWith(attributeValues: values, currentStep: 5);

  // ── Step 5 – Variants ─────────────────────────────────────────────────────
  void addVariant(Map<String, dynamic> variant) =>
      state = state.copyWith(variants: [...state.variants, variant]);

  void removeVariant(int index) {
    final updated = [...state.variants]..removeAt(index);
    state = state.copyWith(variants: updated);
  }

  void advanceFromVariants() =>
      state = state.copyWith(currentStep: 6);

  // ── Step 6 – Brand & Tags ─────────────────────────────────────────────────
  void saveBrandAndTags({
    String? brandId,
    String? brandName,
    required List<String> tags,
  }) => state = state.copyWith(
        brandId: brandId, brandName: brandName, tags: tags, currentStep: 7,
      );

  // ── Back ──────────────────────────────────────────────────────────────────
  void prevStep() {
    if (state.currentStep > 0) {
      state = state.copyWith(currentStep: state.currentStep - 1);
    }
  }

  // ── Step 7 – Publish ──────────────────────────────────────────────────────
  //
  // Mirrors launchpad-seller web app exactly:
  //
  //  1. POST /api/v1/seller/product/create  (multipart/form-data)
  //       name, description, images[], step="PRODUCT_NAME", category
  //       + price, mrp, quantity, sku, weight
  //     → response.data.productId
  //
  //  2. POST /api/v1/seller/product/create-product-attribute  (JSON)
  //       { productId, categoryAttributeId[], values[][], productAttributeIds:null[], step }
  //
  //  3. POST /api/v1/seller/product/add-variants  (JSON)
  //
  //  4. POST /api/v1/seller/product/add-tag  (JSON)
  //
  //  5. POST /api/v1/seller/product/attach-brand  — QUERY PARAMS, null body
  //       ?productId=X&brandId=Y
  //
  //  6. GET  /api/v1/seller/product/make-product-live/{productId}
  //
  Future<bool> publishProduct() async {
    state = state.copyWith(isSubmitting: true, error: null);
    try {
      // ── 1. Create ──────────────────────────────────────────────────────────
      final imageFiles = state.imagePaths.isNotEmpty
          ? await Future.wait(state.imagePaths.map((p) => MultipartFile.fromFile(p)))
          : <MultipartFile>[];

      final createForm = FormData.fromMap({
        'name':        state.productName,
        'description': state.description,
        'step':        'PRODUCT_NAME',
        if (state.categoryId != null)  'category': state.categoryId,
        if (state.price.isNotEmpty)    'price':    double.tryParse(state.price)  ?? 0,
        if (state.mrp.isNotEmpty)      'mrp':      double.tryParse(state.mrp),
        if (state.stock.isNotEmpty)    'quantity': int.tryParse(state.stock)     ?? 0,
        if (state.sku.isNotEmpty)      'sku':      state.sku,
        if (state.weight.isNotEmpty)   'weight':   state.weight,
        if (imageFiles.isNotEmpty)     'images':   imageFiles,
      });

      final createRes  = await _client.post(
        ApiEndpoints.sellerProductCreate,
        data: createForm,
        options: Options(contentType: 'multipart/form-data'),
      );
      final createBody = createRes.data as Map<String, dynamic>;
      if (createBody['success'] != true) {
        state = state.copyWith(isSubmitting: false, error: createBody['message']);
        return false;
      }

      final dataMap   = createBody['data'] as Map<String, dynamic>? ?? {};
      // Web app field name is productId; older backend may use id
      final productId = (dataMap['productId'] ?? dataMap['id'])?.toString();
      if (productId == null) {
        state = state.copyWith(isSubmitting: false, error: 'No product ID returned');
        return false;
      }
      state = state.copyWith(createdProductId: productId);

      // ── 2. Create product attributes ───────────────────────────────────────
      if (state.attributeValues.isNotEmpty) {
        final catAttrIds  = <String>[];
        final values      = <List<String>>[];
        final prodAttrIds = <dynamic>[];

        state.attributeValues.forEach((attrId, rawValue) {
          if (rawValue.trim().isEmpty) return;
          catAttrIds.add(attrId);
          values.add(
            rawValue.split(',').map((v) => v.trim()).where((v) => v.isNotEmpty).toList(),
          );
          prodAttrIds.add(null);
        });

        if (catAttrIds.isNotEmpty) {
          await _client.post(ApiEndpoints.sellerProductCreateAttribute, data: {
            'productId':           productId,
            'categoryAttributeId': catAttrIds,
            'values':              values,
            'productAttributeIds': prodAttrIds,
            'step':                'PRODUCT_ATTRIBUTE',
          });
        }
      }

      // ── 3. Add variants ────────────────────────────────────────────────────
      if (state.variants.isNotEmpty) {
        await _client.post(ApiEndpoints.sellerProductAddVariants, data: {
          'productId': productId,
          'variants':  state.variants,
        });
      }

      // ── 4. Add tags ────────────────────────────────────────────────────────
      if (state.tags.isNotEmpty) {
        await _client.post(ApiEndpoints.sellerProductAddTag, data: {
          'productId': productId,
          'tags':      state.tags,
        });
      }

      // ── 5. Attach brand — query params only, null body ─────────────────────
      if (state.brandId != null) {
        await _client.post(
          ApiEndpoints.sellerProductAttachBrand,
          queryParameters: {'productId': productId, 'brandId': state.brandId},
          data: null,
        );
      }

      // ── 6. Make product live ───────────────────────────────────────────────
      await _client.get('${ApiEndpoints.sellerProductMakeLive}/$productId');

      state = state.copyWith(isSubmitting: false);
      return true;
    } on DioException catch (e) {
      state = state.copyWith(isSubmitting: false, error: AppException.fromDioError(e).message);
      return false;
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: e.toString());
      return false;
    }
  }

  List<dynamic> _list(dynamic data) {
    if (data is List) return data;
    if (data is Map) {
      final inner = data['data'];
      if (inner is List) return inner;
    }
    return [];
  }
}

final addProductPod = StateNotifierProvider.autoDispose<AddProductNotifier, AddProductState>(
  (ref) => AddProductNotifier(),
);
