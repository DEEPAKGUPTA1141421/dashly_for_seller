import 'dart:convert';
import 'dart:math' show max;
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
  // Highest step ever reached — allows jumping forward within already-completed steps
  final int maxReachedStep;

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

  // Draft/resume flow
  final bool draftChecked;
  final bool hasDraft;

  const AddProductState({
    this.isLoading       = false,
    this.isCreating      = false,
    this.isSubmitting    = false,
    this.error,
    this.currentStep      = 0,
    this.maxReachedStep   = 0,
    this.draftChecked    = false,
    this.hasDraft        = false,
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
    int? maxReachedStep,
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
    bool? draftChecked,
    bool? hasDraft,
  }) {
    return AddProductState(
      isLoading:        isLoading        ?? this.isLoading,
      isCreating:       isCreating       ?? this.isCreating,
      isSubmitting:     isSubmitting     ?? this.isSubmitting,
      error:            error,
      currentStep:      currentStep      ?? this.currentStep,
      maxReachedStep:   maxReachedStep   ?? this.maxReachedStep,
      draftChecked:     draftChecked     ?? this.draftChecked,
      hasDraft:         hasDraft         ?? this.hasDraft,
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

  Map<String, dynamic>? _pendingDraftData;

  // ── Saved-to-backend snapshots (dirty-check before re-hitting APIs) ───────
  String? _savedName;
  String? _savedDesc;
  String? _savedAttrValuesJson;
  String? _savedVariantsJson;
  String? _savedImagePathsJson;
  String? _savedAttrImagesJson;
  String? _savedBrandId;
  String? _savedTagsJson;

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

  // ── Draft / Resume ───────────────────────────────────────────────────────
  Future<void> checkForDraft() async {
    try {
      final res  = await _client.get(ApiEndpoints.sellerProductDraftFull);
      final body = res.data as Map<String, dynamic>;
      final data = (body['data'] ?? body) as Map<String, dynamic>?;
      if (data != null && data['productId'] != null) {
        _pendingDraftData = data;
        state = state.copyWith(draftChecked: true, hasDraft: true);
        return;
      }
    } catch (_) {}
    state = state.copyWith(draftChecked: true, hasDraft: false);
  }

  Future<void> resumeDraft() async {
    final data = _pendingDraftData;
    if (data == null) return;
    _pendingDraftData = null;

    // ── Step mapping ─────────────────────────────────────────────────────────
    // Each enum value represents "this step was the last one completed".
    // We send the user to the NEXT step so they continue naturally.
    // PRODUCT_BRAND_AND_TAGS = everything done → go to Review (step 6).
    final currentStepStr = data['currentStep']?.toString() ?? '';
    const stepMap = {
      'PRODUCT_NAME':           1,
      'PRODUCT_ATTRIBUTE':      2,
      'PRODUCT_VARIANT':        3,
      'PRODUCT_IMAGE':          4,
      'PRODUCT_BRAND_AND_TAGS': 6,
    };
    final targetStep = stepMap[currentStepStr] ?? 1;

    // ── Basic info ────────────────────────────────────────────────────────────
    final productId   = data['productId']?.toString();
    final basicInfo   = data['basicInfo'] as Map<String, dynamic>? ?? {};
    final name        = basicInfo['name']?.toString()        ?? '';
    final desc        = basicInfo['description']?.toString() ?? '';
    final categoryId  = (basicInfo['categoryId']  ?? data['categoryId'])?.toString();
    final categoryName = (basicInfo['categoryName'] ?? data['categoryName'])?.toString() ?? '';

    // ── Attributes ────────────────────────────────────────────────────────────
    // Response: { categoryAttributeId, value (string), isImageAttribute, ... }
    final attrsRaw        = data['attributes'] as List<dynamic>? ?? [];
    final attributeValues = <String, String>{};
    // Build value→categoryAttributeId index for image attributes (used for media mapping)
    final imageAttrIndex  = <String, String>{}; // attrValue → categoryAttributeId

    for (final a in attrsRaw) {
      final attr      = a as Map<String, dynamic>;
      final catAttrId = attr['categoryAttributeId']?.toString() ?? '';
      final val       = attr['value']?.toString()              ?? '';
      if (catAttrId.isNotEmpty && val.isNotEmpty) {
        attributeValues[catAttrId] = val;
        if (attr['isImageAttribute'] == true) {
          imageAttrIndex[val] = catAttrId;
        }
      }
    }

    // ── Variants ─────────────────────────────────────────────────────────────
    final variantsRaw = data['variants'] as List<dynamic>? ?? [];
    final variants    = variantsRaw.map((v) => Map<String, dynamic>.from(v as Map)).toList();

    // ── Media ─────────────────────────────────────────────────────────────────
    // Response: { coverImageUrl: "...", attributeMedia: { "Red": ["url"] } }
    final mediaRaw    = data['media'] as Map<String, dynamic>? ?? {};
    final coverUrl    = mediaRaw['coverImageUrl']?.toString();
    final coverImages = coverUrl != null && coverUrl.isNotEmpty ? [coverUrl] : <String>[];

    // attributeMedia keys are attribute values (e.g. "Red").
    // State expects keys as "{categoryAttributeId}::{value}".
    final attrMediaRaw  = mediaRaw['attributeMedia'] as Map<String, dynamic>? ?? {};
    final attributeImages = <String, List<String>>{};
    attrMediaRaw.forEach((value, urls) {
      final catAttrId = imageAttrIndex[value];
      final key = catAttrId != null ? '$catAttrId::$value' : value;
      attributeImages[key] = (urls as List<dynamic>).map((u) => u.toString()).toList();
    });

    // ── Tags ──────────────────────────────────────────────────────────────────
    // Response: [{ id, name }]
    final tags = (data['tags'] as List<dynamic>?)
        ?.map((t) => (t as Map<String, dynamic>)['name']?.toString() ?? '')
        .where((t) => t.isNotEmpty)
        .toList() ?? [];

    // ── Brand ─────────────────────────────────────────────────────────────────
    final brandRaw  = data['brand'] as Map<String, dynamic>? ?? {};
    final brandId   = brandRaw['id']?.toString();
    final brandName = brandRaw['name']?.toString();

    // ── Category attributes (needed for the Attributes step UI) ──────────────
    List<dynamic> attrs = [];
    if (categoryId != null && targetStep >= 2) {
      try {
        final res  = await _client.get('${ApiEndpoints.categoryAttributes}/$categoryId');
        final body = res.data as Map<String, dynamic>;
        final d    = body['data'] as Map<String, dynamic>? ?? {};
        attrs = (d['attributeIds'] as List<dynamic>?) ?? [];
      } catch (_) {}
    }

    // Mark everything as already-saved so re-visiting steps doesn't re-call APIs
    _savedName           = name;
    _savedDesc           = desc;
    _savedAttrValuesJson = jsonEncode(attributeValues);
    _savedVariantsJson   = jsonEncode(variants);
    _savedImagePathsJson = jsonEncode(coverImages);
    _savedAttrImagesJson = jsonEncode(attributeImages);
    _savedBrandId        = brandId;
    _savedTagsJson       = jsonEncode(tags);

    state = AddProductState(
      categories:       state.categories,
      brands:           state.brands,
      draftChecked:     true,
      hasDraft:         false,
      createdProductId: productId,
      productName:      name,
      description:      desc,
      categoryId:       categoryId,
      categoryName:     categoryName,
      attributes:       attrs,
      attributeValues:  attributeValues,
      variants:         variants,
      imagePaths:       coverImages,
      attributeImages:  attributeImages,
      tags:             tags,
      brandId:          brandId,
      brandName:        brandName,
      currentStep:      targetStep,
      maxReachedStep:   targetStep,
    );
  }

  Future<void> discardDraft() async {
    _pendingDraftData = null;
    try {
      await _client.delete(ApiEndpoints.sellerProductDiscardDraft);
    } catch (_) {}
    state = state.copyWith(draftChecked: true, hasDraft: false);
  }

  // ── Step 0 – Category ─────────────────────────────────────────────────────
  Future<void> saveCategory(String id, String name) async {
    state = state.copyWith(categoryId: id, categoryName: name, isLoading: true, error: null);
    try {
      final res   = await _client.get('${ApiEndpoints.categoryAttributes}/$id');
      final body  = res.data as Map<String, dynamic>;
      final data  = body['data'] as Map<String, dynamic>? ?? {};
      final attrs = (data['attributeIds'] as List<dynamic>?) ?? [];
      state = state.copyWith(isLoading: false, attributes: attrs, currentStep: 1, maxReachedStep: max(state.maxReachedStep, 1));
    } on DioException {
      state = state.copyWith(isLoading: false, attributes: [], currentStep: 1, maxReachedStep: max(state.maxReachedStep, 1));
    }
  }

  // ── Step 1 – Basic Info ───────────────────────────────────────────────────
  Future<bool> createProduct(String name, String desc) async {
    // Skip API if nothing changed and product already exists
    if (state.createdProductId != null &&
        name == _savedName && desc == _savedDesc) {
      state = state.copyWith(
        productName: name, description: desc,
        currentStep: 2, maxReachedStep: max(state.maxReachedStep, 2),
      );
      return true;
    }

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
        _savedName = name;
        _savedDesc = desc;
        state = state.copyWith(
          isCreating:       false,
          productName:      name,
          description:      desc,
          createdProductId: productId,
          currentStep:      2,
          maxReachedStep:   max(state.maxReachedStep, 2),
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
    final valuesJson = jsonEncode(values);
    if (state.createdProductId != null && valuesJson == _savedAttrValuesJson) {
      state = state.copyWith(
        attributeValues: values,
        currentStep: 3, maxReachedStep: max(state.maxReachedStep, 3),
      );
      return true;
    }

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
      _savedAttrValuesJson = valuesJson;
      state = state.copyWith(isCreating: false, currentStep: 3, maxReachedStep: max(state.maxReachedStep, 3));
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
    final variantsJson = jsonEncode(variants);
    if (state.createdProductId != null && variantsJson == _savedVariantsJson) {
      state = state.copyWith(
        variants: variants,
        currentStep: 4, maxReachedStep: max(state.maxReachedStep, 4),
      );
      return true;
    }

    state = state.copyWith(variants: variants, isCreating: true, error: null);
    try {
      final productId = state.createdProductId;
      if (productId != null && variants.isNotEmpty) {
        await _client.post(ApiEndpoints.sellerProductAddVariants, data: {
          'productId': productId,
          'variants':  variants,
        });
      }
      _savedVariantsJson = variantsJson;
      state = state.copyWith(isCreating: false, currentStep: 4, maxReachedStep: max(state.maxReachedStep, 4));
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
    final pathsJson    = jsonEncode(state.imagePaths);
    final attrImgJson  = jsonEncode(state.attributeImages);
    if (state.createdProductId != null &&
        pathsJson == _savedImagePathsJson &&
        attrImgJson == _savedAttrImagesJson) {
      state = state.copyWith(
        currentStep: 5, maxReachedStep: max(state.maxReachedStep, 5),
      );
      return true;
    }

    state = state.copyWith(isCreating: true, error: null);
    try {
      final productId = state.createdProductId;
      if (productId != null) {
        final coverFiles = await _buildFiles(state.imagePaths);

        final attrKeys  = <String>[];
        final attrFiles = <MultipartFile>[];
        for (final entry in state.attributeImages.entries) {
          final files = await _buildFiles(entry.value);
          for (final f in files) {
            attrKeys.add(entry.key);
            attrFiles.add(f);
          }
        }

        final hasAny = coverFiles.isNotEmpty || attrFiles.isNotEmpty;
        if (hasAny) {
          final formMap = <String, dynamic>{'productId': productId};
          if (coverFiles.isNotEmpty) formMap['images']             = coverFiles;
          if (attrFiles.isNotEmpty)  formMap['attributeImageKeys'] = attrKeys;
          if (attrFiles.isNotEmpty)  formMap['attributeImages']    = attrFiles;

          await _client.post(
            ApiEndpoints.sellerProductUploadImages,
            data: FormData.fromMap(formMap),
            options: Options(
              contentType:    'multipart/form-data',
              sendTimeout:    null,
              receiveTimeout: null,
            ),
          );
        }
      }
      _savedImagePathsJson = pathsJson;
      _savedAttrImagesJson = attrImgJson;
      state = state.copyWith(isCreating: false, currentStep: 5, maxReachedStep: max(state.maxReachedStep, 5));
      return true;
    } on DioException catch (e) {
      state = state.copyWith(isCreating: false, error: AppException.fromDioError(e).message);
      return false;
    } catch (e) {
      state = state.copyWith(isCreating: false, error: e.toString());
      return false;
    }
  }

  // Build MultipartFile list — skips CDN URLs (already uploaded).
  Future<List<MultipartFile>> _buildFiles(List<String> paths) async {
    final files = <MultipartFile>[];
    for (final path in paths) {
      if (path.startsWith('http')) continue; // already on CDN, skip
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

    final tagsJson = jsonEncode(tags);
    if (brandId == _savedBrandId && tagsJson == _savedTagsJson) {
      state = state.copyWith(
        brandId: brandId, brandName: brandName, tags: tags,
        currentStep: 6, maxReachedStep: max(state.maxReachedStep, 6),
      );
      return true;
    }

    state = state.copyWith(
        brandId:    brandId,
        brandName:  brandName,
        tags:       tags,
        isCreating: true,
        error:      null);
    try {
      // Tags changed — only call if tags differ
      if (tagsJson != _savedTagsJson && tags.isNotEmpty) {
        await _client.post(
          ApiEndpoints.sellerProductAddTag,
          data: {'product_id': productId, 'tags': tags},
          options: Options(contentType: Headers.jsonContentType),
        );
      }

      // Brand changed — only call if brandId differs
      if (brandId != _savedBrandId && brandId != null && brandId.isNotEmpty) {
        await _client.post(
          ApiEndpoints.sellerProductAttachBrand,
          queryParameters: {'productId': productId, 'brandId': brandId},
          data: null,
        );
      }

      _savedBrandId  = brandId;
      _savedTagsJson = tagsJson;
      state = state.copyWith(isCreating: false, currentStep: 6, maxReachedStep: max(state.maxReachedStep, 6));
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
    if (step >= 0 && step <= state.maxReachedStep && step != state.currentStep) {
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
