import 'dart:typed_data' show Uint8List;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../core/errors/app_exception.dart';

class AddProductState {
  final bool isLoading;
  final bool isCreating;
  final bool isSubmitting;
  final String? error;
  final int currentStep;

  // Fetched from API
  final List<dynamic> categories;
  final List<dynamic> brands;
  final List<dynamic> attributes;

  // Step 0 – Category
  final String? categoryId;
  final String? categoryName;

  // Step 1 – Basic Info
  final String productName;
  final String description;

  // Step 2 – Attributes (categoryAttributeId → comma-separated value string)
  final Map<String, String> attributeValues;

  // Step 3 – Variants
  final List<Map<String, dynamic>> variants;

  // Step 4 – Images / Videos
  // Paths (file path on native, blob URL on web)
  final List<String> imagePaths;
  // Per-attribute-value media: key = "{attrId}::{value}" → list of local paths
  final Map<String, List<String>> attributeImages;
  // Media type per path: 'image' | 'video'
  final Map<String, String> mediaTypes;
  // Raw bytes for cross-platform upload (populated at pick time)
  final Map<String, Uint8List> mediaBytes;

  // Step 5 – Brand & Tags
  final String? brandId;
  final String? brandName;
  final List<String> tags;

  // Legacy pricing fields (kept for PricingStep compatibility)
  final String price;
  final String mrp;
  final String stock;
  final String sku;
  final String weight;

  // Set after create API call
  final String? createdProductId;

  const AddProductState({
    this.isLoading       = false,
    this.isCreating      = false,
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
    this.attributeValues = const {},
    this.variants        = const [],
    this.imagePaths      = const [],
    this.attributeImages = const {},
    this.mediaTypes      = const {},
    this.mediaBytes      = const {},
    this.brandId,
    this.brandName,
    this.tags            = const [],
    this.price           = '',
    this.mrp             = '',
    this.stock           = '',
    this.sku             = '',
    this.weight          = '100g',
    this.createdProductId,
  });

  AddProductState copyWith({
    bool? isLoading,
    bool? isCreating,
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
    Map<String, String>? attributeValues,
    List<Map<String, dynamic>>? variants,
    List<String>? imagePaths,
    Map<String, List<String>>? attributeImages,
    Map<String, String>? mediaTypes,
    Map<String, Uint8List>? mediaBytes,
    String? brandId,
    String? brandName,
    List<String>? tags,
    String? price,
    String? mrp,
    String? stock,
    String? sku,
    String? weight,
    String? createdProductId,
  }) {
    return AddProductState(
      isLoading:        isLoading        ?? this.isLoading,
      isCreating:       isCreating       ?? this.isCreating,
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
      attributeValues:  attributeValues  ?? this.attributeValues,
      variants:         variants         ?? this.variants,
      imagePaths:       imagePaths       ?? this.imagePaths,
      attributeImages:  attributeImages  ?? this.attributeImages,
      mediaTypes:       mediaTypes       ?? this.mediaTypes,
      mediaBytes:       mediaBytes       ?? this.mediaBytes,
      brandId:          brandId          ?? this.brandId,
      brandName:        brandName        ?? this.brandName,
      tags:             tags             ?? this.tags,
      price:            price            ?? this.price,
      mrp:              mrp              ?? this.mrp,
      stock:            stock            ?? this.stock,
      sku:              sku              ?? this.sku,
      weight:           weight           ?? this.weight,
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
  Future<void> saveCategory(String id, String name) async {
    state = state.copyWith(categoryId: id, categoryName: name, isLoading: true, error: null);
    try {
      final res   = await _client.get('${ApiEndpoints.categoryAttributes}/$id');
      final body  = res.data as Map<String, dynamic>;
      final data  = body['data'] as Map<String, dynamic>? ?? {};
      final attrs = (data['attributeIds'] as List<dynamic>?) ?? [];
      state = state.copyWith(isLoading: false, attributes: attrs, currentStep: 1);
    } on DioException {
      state = state.copyWith(isLoading: false, attributes: [], currentStep: 1);
    }
  }

  // ── Step 1 – Basic Info ───────────────────────────────────────────────────
  Future<bool> createProduct(String name, String desc) async {
    state = state.copyWith(isCreating: true, error: null);
    try {
      final formMap = <String, dynamic>{
        'name':        name,
        'description': desc,
        'step':        'PRODUCT_NAME',
        if (state.categoryId != null)       'category':  state.categoryId,
        if (state.createdProductId != null) 'productId': state.createdProductId,
      };
      final res  = await _client.post(
        ApiEndpoints.sellerProductCreate,
        data: FormData.fromMap(formMap),
        options: Options(contentType: 'multipart/form-data'),
      );
      final body = res.data as Map<String, dynamic>;
      if (body['success'] == true) {
        final data      = body['data'] as Map<String, dynamic>? ?? {};
        final productId = (data['productId'] ?? data['id'])?.toString()
            ?? state.createdProductId;
        state = state.copyWith(
          isCreating:       false,
          productName:      name,
          description:      desc,
          createdProductId: productId,
          currentStep:      2,
        );
        return true;
      }
      state = state.copyWith(
        isCreating: false,
        error: body['message']?.toString() ?? 'Failed to save product info',
      );
      return false;
    } on DioException catch (e) {
      state = state.copyWith(isCreating: false, error: AppException.fromDioError(e).message);
      return false;
    } catch (e) {
      state = state.copyWith(isCreating: false, error: e.toString());
      return false;
    }
  }

  // ── Step 2 – Attributes ───────────────────────────────────────────────────
  Future<bool> saveAttributesAndContinue(Map<String, String> values) async {
    state = state.copyWith(attributeValues: values, isCreating: true, error: null);
    try {
      final productId = state.createdProductId;
      if (productId != null && values.isNotEmpty) {
        final catAttrIds  = <String>[];
        final attrValues  = <List<String>>[];
        final prodAttrIds = <dynamic>[];

        values.forEach((attrId, rawValue) {
          if (rawValue.trim().isEmpty) return;
          catAttrIds.add(attrId);
          attrValues.add(
            rawValue.split(',').map((v) => v.trim()).where((v) => v.isNotEmpty).toList(),
          );
          prodAttrIds.add(null);
        });

        if (catAttrIds.isNotEmpty) {
          await _client.post(ApiEndpoints.sellerProductCreateAttribute, data: {
            'productId':           productId,
            'categoryAttributeId': catAttrIds,
            'values':              attrValues,
            'productAttributeIds': prodAttrIds,
            'step':                'PRODUCT_ATTRIBUTE',
          });
        }
      }
      state = state.copyWith(isCreating: false, currentStep: 3);
      return true;
    } on DioException catch (e) {
      state = state.copyWith(isCreating: false, error: AppException.fromDioError(e).message);
      return false;
    } catch (e) {
      state = state.copyWith(isCreating: false, error: e.toString());
      return false;
    }
  }

  // ── Step 3 – Variants ─────────────────────────────────────────────────────
  Future<bool> saveVariantsAndContinue(List<Map<String, dynamic>> variants) async {
    state = state.copyWith(variants: variants, isCreating: true, error: null);
    try {
      final productId = state.createdProductId;
      if (productId != null && variants.isNotEmpty) {
        await _client.post(ApiEndpoints.sellerProductAddVariants, data: {
          'productId': productId,
          'variants':  variants,
        });
      }
      state = state.copyWith(isCreating: false, currentStep: 4);
      return true;
    } on DioException catch (e) {
      state = state.copyWith(isCreating: false, error: AppException.fromDioError(e).message);
      return false;
    } catch (e) {
      state = state.copyWith(isCreating: false, error: e.toString());
      return false;
    }
  }

  // ── Step 4 – Media (Images + Videos) ─────────────────────────────────────

  // Add a general product media file. Bytes required on web for upload.
  void addMedia(String path, {String type = 'image', Uint8List? bytes}) {
    final newTypes = Map<String, String>.from(state.mediaTypes)..[path] = type;
    final newBytes = Map<String, Uint8List>.from(state.mediaBytes);
    if (bytes != null) newBytes[path] = bytes;
    state = state.copyWith(
      imagePaths:  [...state.imagePaths, path],
      mediaTypes:  newTypes,
      mediaBytes:  newBytes,
    );
  }

  void removeMedia(int index) {
    if (index < 0 || index >= state.imagePaths.length) return;
    final path    = state.imagePaths[index];
    final updated = [...state.imagePaths]..removeAt(index);
    final newTypes = Map<String, String>.from(state.mediaTypes)..remove(path);
    final newBytes = Map<String, Uint8List>.from(state.mediaBytes)..remove(path);
    state = state.copyWith(imagePaths: updated, mediaTypes: newTypes, mediaBytes: newBytes);
  }

  // Add per-attribute-value media. Bytes required on web for upload.
  void addAttributeMedia(String key, String path, {String type = 'image', Uint8List? bytes}) {
    final updated  = Map<String, List<String>>.from(state.attributeImages);
    updated[key]   = [...(updated[key] ?? <String>[]), path];
    final newTypes = Map<String, String>.from(state.mediaTypes)..[path] = type;
    final newBytes = Map<String, Uint8List>.from(state.mediaBytes);
    if (bytes != null) newBytes[path] = bytes;
    state = state.copyWith(
      attributeImages: updated,
      mediaTypes:      newTypes,
      mediaBytes:      newBytes,
    );
  }

  void removeAttributeMedia(String key, int index) {
    final updated = Map<String, List<String>>.from(state.attributeImages);
    final List<String> list = [...(updated[key] ?? <String>[])]..removeAt(index);
    // clean up bytes/types for removed path
    final removedPath = (updated[key] ?? <String>[])[index];
    updated[key] = list;
    final newTypes = Map<String, String>.from(state.mediaTypes)..remove(removedPath);
    final newBytes = Map<String, Uint8List>.from(state.mediaBytes)..remove(removedPath);
    state = state.copyWith(
      attributeImages: updated,
      mediaTypes:      newTypes,
      mediaBytes:      newBytes,
    );
  }

  // Upload ALL media – cover photos + per-attribute-value photos/videos.
  Future<bool> uploadImagesAndContinue() async {
    state = state.copyWith(isCreating: true, error: null);
    try {
      final productId = state.createdProductId;
      if (productId != null) {
        // ── Cover / general product images ──────────────────────────────────
        final coverFiles = await _buildFiles(state.imagePaths);

        // ── Per-attribute-value images (e.g. Red→5 photos, Black→8 photos) ─
        // Sent as parallel arrays so backend can group them:
        //   attributeImageKeys[i]  →  "{categoryAttributeId}::{value}"
        //   attributeImages[i]     →  the actual file
        final attrKeys  = <String>[];
        final attrFiles = <MultipartFile>[];

        for (final entry in state.attributeImages.entries) {
          final key   = entry.key; // e.g. "colorAttrId::Red"
          final files = await _buildFiles(entry.value);
          for (final f in files) {
            attrKeys.add(key);
            attrFiles.add(f);
          }
        }

        final hasAny = coverFiles.isNotEmpty || attrFiles.isNotEmpty;
        if (hasAny) {
          final formMap = <String, dynamic>{'productId': productId};
          if (coverFiles.isNotEmpty) formMap['images']              = coverFiles;
          if (attrFiles.isNotEmpty)  formMap['attributeImageKeys']  = attrKeys;
          if (attrFiles.isNotEmpty)  formMap['attributeImages']     = attrFiles;

          await _client.post(
            ApiEndpoints.sellerProductUploadImages,
            data: FormData.fromMap(formMap),
            options: Options(
              contentType:    'multipart/form-data',
              sendTimeout:    null,   // no timeout — large uploads can take time
              receiveTimeout: null,
            ),
          );
        }
      }
      state = state.copyWith(isCreating: false, currentStep: 5);
      return true;
    } on DioException catch (e) {
      state = state.copyWith(isCreating: false, error: AppException.fromDioError(e).message);
      return false;
    } catch (e) {
      state = state.copyWith(isCreating: false, error: e.toString());
      return false;
    }
  }

  // Build MultipartFile list from a list of local paths / blob URLs.
  Future<List<MultipartFile>> _buildFiles(List<String> paths) async {
    final files = <MultipartFile>[];
    for (final path in paths) {
      final bytes    = state.mediaBytes[path];
      final type     = state.mediaTypes[path] ?? 'image';
      final mime     = type == 'video' ? 'video/mp4' : 'image/jpeg';
      final filename = _filenameFromPath(path);
      if (bytes != null && bytes.isNotEmpty) {
        files.add(MultipartFile.fromBytes(bytes, filename: filename,
            contentType: DioMediaType.parse(mime)));
      } else if (!kIsWeb) {
        files.add(MultipartFile.fromFileSync(path,
            filename: path.split('/').last.split('\\').last));
      }
    }
    return files;
  }

  String _filenameFromPath(String path) {
    if (path.startsWith('blob:') || path.startsWith('http')) {
      return 'media_${DateTime.now().millisecondsSinceEpoch}';
    }
    final parts = path.replaceAll('\\', '/').split('/');
    return parts.last.isNotEmpty ? parts.last : 'media';
  }

  // ── Step 5 – Brand & Tags ─────────────────────────────────────────────────
  Future<bool> saveBrandTagsAndContinue({
    String? brandId,
    String? brandName,
    required List<String> tags,
  }) async {
    // Read productId BEFORE state mutation so it is never lost.
    final productId = state.createdProductId;

    if (productId == null || productId.isEmpty) {
      state = state.copyWith(
        error: 'Product ID is missing. Please go back to Step 1 and re-save.',
      );
      return false;
    }

    state = state.copyWith(
        brandId:    brandId,
        brandName:  brandName,
        tags:       tags,
        isCreating: true,
        error:      null);
    try {
      // ── Tags ──────────────────────────────────────────────────────────────
      // POST /api/v1/seller/product/add-tag
      // Body: { "product_id": "<uuid>", "tags": ["tag1", "tag2"] }
      if (tags.isNotEmpty) {
        await _client.post(
          ApiEndpoints.sellerProductAddTag,
          data: {
            'product_id': productId,   // snake_case matches ProductTagRequestDto
            'tags':        tags,
          },
          options: Options(contentType: Headers.jsonContentType),
        );
      }

      // ── Brand ──────────────────────────────────────────────────────────────
      if (brandId != null && brandId.isNotEmpty) {
        await _client.post(
          ApiEndpoints.sellerProductAttachBrand,
          queryParameters: {'productId': productId, 'brandId': brandId},
          data: null,
        );
      }

      state = state.copyWith(isCreating: false, currentStep: 6);
      return true;
    } on DioException catch (e) {
      state = state.copyWith(isCreating: false, error: AppException.fromDioError(e).message);
      return false;
    } catch (e) {
      state = state.copyWith(isCreating: false, error: e.toString());
      return false;
    }
  }

  // ── Pricing (legacy – kept for PricingStep compatibility) ─────────────────
  void savePricing({
    required String price,
    required String mrp,
    required String stock,
    required String sku,
    required String weight,
  }) => state = state.copyWith(
        price: price, mrp: mrp, stock: stock, sku: sku, weight: weight,
      );

  // ── Navigation helpers ────────────────────────────────────────────────────
  void goToStep(int step) {
    if (step >= 0 && step < state.currentStep) {
      state = state.copyWith(currentStep: step);
    }
  }

  void prevStep() {
    if (state.currentStep > 0) {
      state = state.copyWith(currentStep: state.currentStep - 1);
    }
  }

  // ── Step 6 – Publish ──────────────────────────────────────────────────────
  Future<bool> publishProduct() async {
    state = state.copyWith(isSubmitting: true, error: null);
    try {
      final productId = state.createdProductId;
      if (productId == null || productId.isEmpty) {
        state = state.copyWith(
          isSubmitting: false,
          error: 'No product created yet. Please complete all steps.',
        );
        return false;
      }
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
