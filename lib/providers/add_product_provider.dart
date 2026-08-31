import 'dart:convert';
import 'dart:io' show File;
import 'dart:math' show max;
import 'dart:typed_data' show Uint8List;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../core/errors/app_exception.dart';
import '../models/discount_config.dart';

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
  // Seller-configured discount applied to newly-created SKUs when the
  // Variants step submits to add-variants (per-combo overrides are held on
  // that step's own local item state, not here — see VariantsStep).
  final DiscountConfig? discount;

  // Set after create API call
  final String? createdProductId;

  // Draft/resume flow
  final bool draftChecked;
  final bool hasDraft;

  // True when this state represents editing an existing LIVE product
  // rather than the linear create-wizard flow.
  final bool isEditMode;

  const AddProductState({
    this.isLoading       = false,
    this.isCreating      = false,
    this.isSubmitting    = false,
    this.error,
    this.currentStep      = 0,
    this.maxReachedStep   = 0,
    this.draftChecked    = false,
    this.hasDraft        = false,
    this.isEditMode      = false,
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
    this.discount,
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
    DiscountConfig? discount,
    bool clearDiscount = false,
    String? createdProductId,
    bool? draftChecked,
    bool? hasDraft,
    bool? isEditMode,
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
      isEditMode:       isEditMode       ?? this.isEditMode,
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
      discount:         clearDiscount ? null : (discount ?? this.discount),
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
  // Per-attribute value string ("Blue,Red") last confirmed saved to the
  // backend — lets saveAttributesAndContinue send only the attributes whose
  // value actually changed, instead of resending everything every time.
  final Map<String, String> _savedAttrValueByAttr = {};

  // ── Init ─────────────────────────────────────────────────────────────────
  Future<void> init() async {
    state = state.copyWith(isLoading: true, error: null);

    List<dynamic> cats = [];

    try {
      final res = await _client.get(ApiEndpoints.sellerCategories);
      cats = _list(res.data);
    } on DioException catch (e) {
      state = state.copyWith(error: AppException.fromDioError(e).message);
    } catch (_) {}

    // Brands are fetched lazily by the brand-picker sheet in step 5
    // (scoped to the chosen category), not eagerly here.
    state = state.copyWith(isLoading: false, categories: cats);
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
    // We send the user to the NEXT step so they continue naturally. Wizard
    // step indices (see add_product_screen.dart): 0=Category 1=BasicInfo
    // 2=Attributes 3=Variants 4=Images 5=TagsBrand 6=Review.
    // PRODUCT_BRAND_AND_TAGS = everything done → go to Review (step 6).
    final currentStepStr = data['currentStep']?.toString() ?? '';
    const stepMap = {
      'PRODUCT_NAME':           2, // basic info done      → next: Attributes
      'PRODUCT_ATTRIBUTE':      3, // attributes done       → next: Variants
      'PRODUCT_VARIANT':        4, // variants done         → next: Images
      'PRODUCT_IMAGE':          5, // images done           → next: TagsBrand
      'PRODUCT_BRAND_AND_TAGS': 6, // brand & tags done     → next: Review
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
    // Response: { id, categoryAttributeId, value (string), isImageAttribute, ... }
    // A variant attribute (e.g. Color) has one row PER selected value — merge
    // them into the same comma-separated format the wizard UI uses instead of
    // the last row silently overwriting the rest (was losing every value but
    // the last one, e.g. "Blue" disappearing when "Red" was also selected).
    final attrsRaw        = data['attributes'] as List<dynamic>? ?? [];
    final attrValueSets    = <String, Set<String>>{}; // catAttrId → ordered set of values
    // Build value→categoryAttributeId index for image attributes (used for media mapping)
    final imageAttrIndex  = <String, String>{}; // attrValue → categoryAttributeId

    for (final a in attrsRaw) {
      final attr      = a as Map<String, dynamic>;
      final catAttrId = attr['categoryAttributeId']?.toString() ?? '';
      final val       = attr['value']?.toString()              ?? '';
      if (catAttrId.isNotEmpty && val.isNotEmpty) {
        (attrValueSets[catAttrId] ??= <String>{}).add(val);
        if (attr['isImageAttribute'] == true) {
          imageAttrIndex[val] = catAttrId;
        }
        final prodAttrId = attr['id']?.toString();
        if (prodAttrId != null && prodAttrId.isNotEmpty) {
          _existingAttributeValueIds['$catAttrId::$val'] = prodAttrId;
        }
      }
    }
    final attributeValues = attrValueSets.map((k, v) => MapEntry(k, v.join(',')));

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
    _savedAttrValueByAttr
      ..clear()
      ..addAll(attributeValues);
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

  // ── Edit an existing (already-LIVE) product ────────────────────────────────
  // Raw variant rows from GET /variants, kept around so saveVariantsAndContinue
  // can diff new combos against them (the add-variants endpoint is append-only).
  List<Map<String, dynamic>> _existingVariants = [];

  // "{categoryAttributeId}::{value}" → existing productAttributeId, so
  // saveAttributesAndContinue can UPDATE that specific row instead of
  // creating a duplicate ProductAttribute — keyed per VALUE (not just per
  // attribute) since a multi-value variant attribute like Color has one row
  // per selected value, each with its own id. Populated from both the draft
  // (resumeDraft) and live-edit (loadForEdit) load paths, and refreshed after
  // every successful save so newly-created rows are known within the session.
  final Map<String, String> _existingAttributeValueIds = {};

  Future<void> loadForEdit(String productId) async {
    state = state.copyWith(isLoading: true, error: null, isEditMode: true);

    Map<String, dynamic> editData = {};
    try {
      final res  = await _client.get('${ApiEndpoints.sellerProductBase}/$productId/edit-data');
      final body = res.data as Map<String, dynamic>;
      editData   = (body['data'] as Map<String, dynamic>?) ?? {};
    } catch (e) {
      state = state.copyWith(isLoading: false, isEditMode: true,
          error: e is DioException ? AppException.fromDioError(e).message : e.toString());
      return;
    }

    final name        = editData['name'] as String? ?? '';
    final desc        = editData['description'] as String? ?? '';
    final categoryId  = editData['categoryId'] as String?;
    final categoryName = editData['categoryName'] as String? ?? '';
    final brandId      = editData['brandId'] as String?;
    final brandName    = editData['brandName'] as String?;
    final tags = (editData['tags'] as List<dynamic>?)
        ?.map((t) => (t as Map<String, dynamic>)['name']?.toString() ?? '')
        .where((t) => t.isNotEmpty)
        .toList() ?? [];

    // Attribute values — mirrors resumeDraft's parsing so both AttributesStep
    // and the ImagesStep's per-value sections (which key off attributeValues
    // to know which values need a photo slot) work the same as in create mode.
    // Existing images for image-type attributes are captured separately, keyed
    // the same way the create-wizard keys them: "{categoryAttributeId}::{value}".
    final rawAttrs = (editData['attributes'] as List<dynamic>?) ?? [];
    final attributeValues = <String, String>{};
    final attributeImages = <String, List<String>>{};
    for (final a in rawAttrs) {
      final attr      = a as Map<String, dynamic>;
      final catAttrId = attr['categoryAttributeId']?.toString() ?? '';
      final val       = attr['value']?.toString() ?? '';
      if (catAttrId.isEmpty || val.isEmpty) continue;
      // A variant-defining attribute (e.g. Color) has one ProductAttribute row
      // per distinct value used across the product's variants — merge them into
      // the same comma-separated format the create wizard uses, instead of the
      // last row silently overwriting the rest.
      final existingVals = attributeValues[catAttrId]?.split(',').map((v) => v.trim()).toSet() ?? <String>{};
      existingVals.add(val);
      attributeValues[catAttrId] = existingVals.join(',');
      // Keyed per VALUE (not just per attribute) — a multi-value attribute has
      // one row per value, each with its own id; a single per-attribute id
      // would silently apply to the wrong row on the next save.
      final prodAttrId = attr['productAttributeId']?.toString();
      if (prodAttrId != null && prodAttrId.isNotEmpty) {
        _existingAttributeValueIds['$catAttrId::$val'] = prodAttrId;
      }
      if (attr['isImage'] == true) {
        final urls = (attr['images'] as List<dynamic>?)
            ?.map((u) => u.toString())
            .where((u) => u.isNotEmpty)
            .toList() ?? [];
        if (urls.isNotEmpty) attributeImages['$catAttrId::$val'] = urls;
      }
    }

    // Category attribute definitions (needed for the Attributes/Variants step UI)
    List<dynamic> attrs = [];
    if (categoryId != null) {
      try {
        final res  = await _client.get('${ApiEndpoints.categoryAttributes}/$categoryId');
        final body = res.data as Map<String, dynamic>;
        final d    = body['data'] as Map<String, dynamic>? ?? {};
        attrs = (d['attributeIds'] as List<dynamic>?) ?? [];
      } catch (_) {}
    }

    // Existing variants
    List<Map<String, dynamic>> variants = [];
    try {
      final res  = await _client.get('${ApiEndpoints.sellerProductBase}/$productId/variants');
      final body = res.data as Map<String, dynamic>;
      final list = (body['data'] as List<dynamic>?) ?? [];
      variants = list.map((v) {
        final m = v as Map<String, dynamic>;
        return {
          'id':          m['id']?.toString(),
          'label':       m['label']?.toString() ?? '',
          'combination': Map<String, String>.from(
              (m['combination'] as Map<dynamic, dynamic>? ?? {})
                  .map((k, v) => MapEntry(k.toString(), v.toString()))),
          'price':  double.tryParse(m['priceRupees']?.toString() ?? '') ?? 0,
          'mrp':    double.tryParse(m['mrpRupees']?.toString() ?? '') ?? 0,
          'stock':  m['stock'] is num ? (m['stock'] as num).toInt() : int.tryParse(m['stock']?.toString() ?? '') ?? 0,
          'sku':    m['sku']?.toString() ?? '',
        };
      }).toList();
    } catch (_) {}
    _existingVariants = variants;

    // Existing cover image
    final coverImages = <String>[];
    final mediaTypes  = <String, String>{};
    try {
      final res  = await _client.get('${ApiEndpoints.sellerProductBase}/$productId/media');
      final body = res.data as Map<String, dynamic>;
      final list = (body['data'] as List<dynamic>?) ?? [];
      final cover = list.cast<Map<String, dynamic>>().firstWhere(
        (m) => m['isCover'] == true,
        orElse: () => list.isNotEmpty ? list.first as Map<String, dynamic> : <String, dynamic>{},
      );
      final url = cover['url']?.toString();
      if (url != null && url.isNotEmpty) {
        coverImages.add(url);
        final mt = cover['mediaType']?.toString().toLowerCase();
        mediaTypes[url] = mt == 'video' ? 'video' : 'image';
      }
    } catch (_) {}

    _savedName           = name;
    _savedDesc           = desc;
    _savedAttrValuesJson = jsonEncode(attributeValues);
    _savedAttrValueByAttr
      ..clear()
      ..addAll(attributeValues);
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
      isEditMode:       true,
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
      mediaTypes:       mediaTypes,
      tags:             tags,
      brandId:          brandId,
      brandName:        brandName,
      // Edit steps (no Category step): 0=BasicInfo 1=Attributes 2=Variants 3=Photos 4=Brand&Tags
      currentStep:      0,
      maxReachedStep:   4,
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
        currentStep: state.isEditMode ? 1 : 2, maxReachedStep: max(state.maxReachedStep, 2),
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
          currentStep:      state.isEditMode ? 1 : 2,
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
        currentStep: state.isEditMode ? 2 : 3, maxReachedStep: max(state.maxReachedStep, 3),
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
          final trimmed = rawValue.trim();
          if (trimmed.isEmpty) return;
          // Only send an attribute whose value actually changed since the last
          // confirmed save — sending an unchanged attribute is harmless (its
          // values resolve to their own existing ids below and just get
          // re-set to the same value), but skipping it keeps the payload
          // proportional to what the seller actually edited.
          if (_savedAttrValueByAttr[attrId] == trimmed) return;

          final vals = trimmed.split(',').map((v) => v.trim()).where((v) => v.isNotEmpty).toList();
          if (vals.isEmpty) return;
          catAttrIds.add(attrId);
          attrValues.add(vals);
          // One entry per value (matches the backend's flat index) — each
          // value gets its OWN existing id (not one id shared across every
          // value of the attribute), so an already-saved value updates its
          // own row and only a genuinely new value creates a new one.
          for (final v in vals) {
            prodAttrIds.add(_existingAttributeValueIds['$attrId::$v']);
          }
        });

        if (catAttrIds.isNotEmpty) {
          final res = await _client.post(ApiEndpoints.sellerProductCreateAttribute, data: {
            'productId':           productId,
            'categoryAttributeId': catAttrIds,
            'values':              attrValues,
            'productAttributeIds': prodAttrIds,
            'step':                'PRODUCT_ATTRIBUTE',
          });

          // Refresh the existing-id map from the response so a subsequent
          // save within this same session already knows the ids of rows
          // just created (and won't duplicate them) without needing a reload.
          final body  = res.data as Map<String, dynamic>?;
          final saved = (body?['data'] as List<dynamic>?) ?? [];
          for (final row in saved) {
            final m         = row as Map<String, dynamic>;
            final savedAttr = m['categoryAttributeId']?.toString();
            final savedVal  = m['value']?.toString();
            final savedId   = m['id']?.toString();
            if (savedAttr != null && savedVal != null && savedId != null) {
              _existingAttributeValueIds['$savedAttr::$savedVal'] = savedId;
            }
          }

          for (final attrId in catAttrIds) {
            _savedAttrValueByAttr[attrId] = values[attrId]!.trim();
          }
        }
      }
      _savedAttrValuesJson = valuesJson;
      state = state.copyWith(
        isCreating: false,
        currentStep: state.isEditMode ? 2 : 3,
        maxReachedStep: max(state.maxReachedStep, 3),
      );
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
        currentStep: state.isEditMode ? 3 : 4, maxReachedStep: max(state.maxReachedStep, 4),
      );
      return true;
    }

    state = state.copyWith(variants: variants, isCreating: true, error: null);
    try {
      final productId = state.createdProductId;
      if (productId != null && variants.isNotEmpty) {
        if (state.isEditMode) {
          // add-variants is append-only on the backend — only POST combos
          // that don't already exist, and PATCH price/stock changes on the rest.
          final newVariants = <Map<String, dynamic>>[];
          for (final v in variants) {
            final combo = Map<String, String>.from(v['combination'] as Map);
            final existing = _existingVariants.firstWhere(
              (e) => _combosEqual(e['combination'] as Map<String, String>, combo),
              orElse: () => const {},
            );
            if (existing.isEmpty) {
              newVariants.add(v);
              continue;
            }
            final priceInPaise = ((v['price'] as num?) ?? 0) * 100;
            final stock        = (v['stock'] as num?)?.toInt() ?? 0;
            final priceChanged = priceInPaise.round() != (((existing['price'] as num?) ?? 0) * 100).round();
            final stockChanged = stock != ((existing['stock'] as num?) ?? 0);
            if (priceChanged || stockChanged) {
              try {
                await _client.patch(
                  '${ApiEndpoints.sellerProductBase}/$productId/variants/${existing['id']}',
                  data: {
                    if (priceChanged) 'priceInPaise': priceInPaise.round(),
                    if (stockChanged) 'stock': stock,
                  },
                );
              } catch (_) {}
            }
          }
          if (newVariants.isNotEmpty) {
            await _client.post(ApiEndpoints.sellerProductAddVariants, data: {
              'productId': productId,
              'variants':  newVariants,
            });
          }
        } else {
          await _client.post(ApiEndpoints.sellerProductAddVariants, data: {
            'productId': productId,
            'variants':  variants,
          });
        }
      }
      _savedVariantsJson = variantsJson;
      state = state.copyWith(
        isCreating: false,
        currentStep: state.isEditMode ? 3 : 4,
        maxReachedStep: max(state.maxReachedStep, 4),
      );
      return true;
    } on DioException catch (e) {
      state = state.copyWith(isCreating: false, error: AppException.fromDioError(e).message);
      return false;
    } catch (e) {
      state = state.copyWith(isCreating: false, error: e.toString());
      return false;
    }
  }

  bool _combosEqual(Map<String, String> a, Map<String, String> b) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) return false;
    }
    return true;
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

  /// Removes the cover media at [index]. If it's already uploaded (an http
  /// URL), this first deletes it on the backend — DB row AND the Cloudinary
  /// asset — and only drops it from local state once that succeeds; a
  /// not-yet-uploaded local file is just dropped locally (nothing to clean
  /// up server-side). Returns false (leaving state untouched) if the backend
  /// call fails, so the caller can surface the error.
  Future<bool> removeMedia(int index) async {
    if (index < 0 || index >= state.imagePaths.length) return false;
    final path = state.imagePaths[index];

    if (path.startsWith('http')) {
      final productId = state.createdProductId;
      if (productId == null) return false;
      try {
        await _client.delete(ApiEndpoints.sellerProductMediaRemove, data: {
          'productId': productId,
          'purpose':   'cover',
          'url':       path,
        });
      } on DioException catch (e) {
        state = state.copyWith(error: AppException.fromDioError(e).message);
        return false;
      } catch (e) {
        state = state.copyWith(error: e.toString());
        return false;
      }
    }

    final updated  = [...state.imagePaths]..removeAt(index);
    final newTypes = Map<String, String>.from(state.mediaTypes)..remove(path);
    final newBytes = Map<String, Uint8List>.from(state.mediaBytes)..remove(path);
    state = state.copyWith(imagePaths: updated, mediaTypes: newTypes, mediaBytes: newBytes);
    // Keep the saved-snapshot in sync so a subsequent Continue doesn't think
    // this removed item is still what's "already saved" and skip re-checking.
    _savedImagePathsJson = jsonEncode(state.imagePaths);
    return true;
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

  /// Same as [removeMedia] but for one item in an attribute-value gallery.
  Future<bool> removeAttributeMedia(String key, int index) async {
    final list = state.attributeImages[key] ?? const <String>[];
    if (index < 0 || index >= list.length) return false;
    final removedPath = list[index];

    if (removedPath.startsWith('http')) {
      final productId = state.createdProductId;
      if (productId == null) return false;
      try {
        await _client.delete(ApiEndpoints.sellerProductMediaRemove, data: {
          'productId':     productId,
          'purpose':       'attribute',
          'attributeKey':  key,
          'url':           removedPath,
        });
      } on DioException catch (e) {
        state = state.copyWith(error: AppException.fromDioError(e).message);
        return false;
      } catch (e) {
        state = state.copyWith(error: e.toString());
        return false;
      }
    }

    final updatedList = [...list]..removeAt(index);
    final updatedMap  = Map<String, List<String>>.from(state.attributeImages)..[key] = updatedList;
    final newTypes = Map<String, String>.from(state.mediaTypes)..remove(removedPath);
    final newBytes = Map<String, Uint8List>.from(state.mediaBytes)..remove(removedPath);
    state = state.copyWith(
      attributeImages: updatedMap,
      mediaTypes:      newTypes,
      mediaBytes:      newBytes,
    );
    _savedAttrImagesJson = jsonEncode(state.attributeImages);
    return true;
  }

  // Client-side size guard — matches the backend defaults in
  // application.properties (app.upload.max-image-bytes / max-video-bytes).
  // This is a fast, friendly rejection before any network call; the backend
  // independently re-validates the ACTUAL uploaded size in confirmMediaUpload
  // and destroys the Cloudinary asset if a tampered client got past this.
  static const int maxImageBytes = 5 * 1024 * 1024;  // 5MB
  static const int maxVideoBytes = 50 * 1024 * 1024; // 50MB

  /// Client-side mirror of the backend's /media/status gate: a cover photo
  /// or video, plus at least one image for every value of every
  /// image-required attribute (e.g. one photo per selected Color). Used to
  /// fail fast in the UI without a network round trip — the backend call in
  /// uploadImagesAndContinue() is still the authoritative check, since local
  /// state could in principle drift from what's actually saved.
  List<String> missingMediaRequirements() {
    final missing = <String>[];
    if (state.imagePaths.isEmpty) missing.add('Cover photo or video');

    for (final raw in state.attributes) {
      final attr = raw as Map;
      if (attr['isImageAttribute'] != true) continue;
      final attrId = attr['id']?.toString() ?? attr['attributeId']?.toString() ?? '';
      if (attrId.isEmpty) continue;
      final values = (state.attributeValues[attrId] ?? '')
          .split(',').map((v) => v.trim()).where((v) => v.isNotEmpty);
      for (final v in values) {
        final key = '$attrId::$v';
        if ((state.attributeImages[key] ?? const <String>[]).isEmpty) {
          missing.add('$v photo/video');
        }
      }
    }
    return missing;
  }

  // Upload ALL media – cover photos + per-attribute-value photos/videos —
  // directly to Cloudinary via a short-lived, product-scoped signed URL.
  // Raw file bytes never pass through this backend; only the resulting
  // Cloudinary metadata (URL/public_id/byte count) is sent to it afterward.
  Future<bool> uploadImagesAndContinue() async {
    // Fast, local fail — catches the common case (no cover picked at all)
    // without a network round trip.
    final localMissing = missingMediaRequirements();
    if (localMissing.isNotEmpty) {
      state = state.copyWith(error: 'Missing required media: ${localMissing.join(', ')}');
      return false;
    }

    final pathsJson    = jsonEncode(state.imagePaths);
    final attrImgJson  = jsonEncode(state.attributeImages);
    final productId    = state.createdProductId;
    final alreadySaved = productId != null &&
        pathsJson == _savedImagePathsJson &&
        attrImgJson == _savedAttrImagesJson;

    state = state.copyWith(isCreating: true, error: null);
    try {
      if (productId != null && !alreadySaved) {
        // Cover — only the first path, and only when it's a fresh local file
        // (an "http" path is already-uploaded CDN media from a prior save —
        // that swap happens below, right after each successful upload, so a
        // later call here never re-uploads something already on Cloudinary).
        if (state.imagePaths.isNotEmpty && !state.imagePaths[0].startsWith('http')) {
          final path = state.imagePaths[0];
          final url  = await _uploadAndAttach(productId: productId, purpose: 'cover', path: path);
          _markCoverUploaded(path, url);
        }

        for (final entry in state.attributeImages.entries.toList()) {
          for (final path in List<String>.from(entry.value)) {
            if (path.startsWith('http')) continue; // already on CDN, skip
            final url = await _uploadAndAttach(
              productId: productId,
              purpose: 'attribute',
              attributeKey: entry.key,
              path: path,
            );
            _markAttributeImageUploaded(entry.key, path, url);
          }
        }

        // Snapshot AFTER the loop, not the pre-upload paths captured above —
        // local paths were swapped for CDN URLs as each upload succeeded, so
        // this reflects what's actually now on Cloudinary.
        _savedImagePathsJson = jsonEncode(state.imagePaths);
        _savedAttrImagesJson = jsonEncode(state.attributeImages);
      }

      // Authoritative backend gate — re-checked every time, even when
      // nothing new needed uploading, since an earlier removal could have
      // made a previously-complete product incomplete again.
      if (productId != null) {
        final statusRes  = await _client.get(ApiEndpoints.sellerProductMediaStatus(productId));
        final statusBody = statusRes.data as Map<String, dynamic>;
        final statusData = statusBody['data'] as Map<String, dynamic>?;
        if (statusData?['complete'] != true) {
          final missing = ((statusData?['missing'] as List<dynamic>?) ?? []).join(', ');
          state = state.copyWith(
            isCreating: false,
            error: missing.isNotEmpty ? 'Missing required media: $missing' : 'Please add the required product media',
          );
          return false;
        }
      }

      state = state.copyWith(
        isCreating: false,
        currentStep: state.isEditMode ? 4 : 5,
        maxReachedStep: max(state.maxReachedStep, 5),
      );
      return true;
    } on DioException catch (e) {
      state = state.copyWith(isCreating: false, error: AppException.fromDioError(e).message);
      return false;
    } catch (e) {
      state = state.copyWith(isCreating: false, error: e is AppException ? e.message : e.toString());
      return false;
    }
  }

  /// One local media file → Cloudinary (direct, signed) → attach to the
  /// product. Three hops: (1) ask this backend for a signature scoped to
  /// this exact product+purpose, (2) upload straight to Cloudinary with a
  /// bare Dio instance — the seller's auth token/interceptors never reach a
  /// third-party host, (3) hand the resulting metadata back to this backend.
  Future<String> _uploadAndAttach({
    required String productId,
    required String purpose, // 'cover' | 'attribute'
    String? attributeKey,
    required String path,
  }) async {
    final type     = state.mediaTypes[path] ?? 'image';
    final isVideo  = type == 'video';
    final resourceType = isVideo ? 'video' : 'image';

    Uint8List? bytes = state.mediaBytes[path];
    if (bytes == null && !kIsWeb) {
      bytes = await File(path).readAsBytes();
    }
    if (bytes == null || bytes.isEmpty) {
      throw AppException(message: 'Could not read file to upload: $path');
    }

    final limit = isVideo ? maxVideoBytes : maxImageBytes;
    if (bytes.length > limit) {
      throw AppException(
        message: '${isVideo ? "Video" : "Image"} exceeds the ${limit ~/ (1024 * 1024)}MB limit',
      );
    }

    final sigRes = await _client.post(
      ApiEndpoints.sellerProductMediaSignature(productId),
      data: {
        'purpose':      purpose,
        if (attributeKey != null) 'attributeKey': attributeKey,
        'resourceType': resourceType,
      },
    );
    final sigBody = sigRes.data as Map<String, dynamic>;
    final sig     = sigBody['data'] as Map<String, dynamic>;

    final filename = _filenameFromPath(path);
    final mime     = isVideo ? 'video/mp4' : 'image/jpeg';
    final formData = FormData.fromMap({
      'file':      MultipartFile.fromBytes(bytes, filename: filename, contentType: DioMediaType.parse(mime)),
      'api_key':   sig['apiKey'].toString(),
      'timestamp': sig['timestamp'].toString(),
      'signature': sig['signature'].toString(),
      'folder':    sig['folder'].toString(),
      'public_id': sig['publicId'].toString(),
    });
    // A bare Dio — not the app's authenticated _client — since this request
    // goes to Cloudinary, a third-party host, and must not carry the
    // seller's bearer token or any of this app's interceptors.
    final cloudinaryUrl = 'https://api.cloudinary.com/v1_1/${sig['cloudName']}/$resourceType/upload';
    final uploadRes  = await Dio().post(cloudinaryUrl, data: formData);
    final uploadBody = uploadRes.data as Map<String, dynamic>;

    final secureUrl = uploadBody['secure_url'].toString();
    await _client.post(ApiEndpoints.sellerProductMediaConfirm, data: {
      'productId':    productId,
      'purpose':      purpose,
      if (attributeKey != null) 'attributeKey': attributeKey,
      'publicId':     uploadBody['public_id'],
      'secureUrl':    secureUrl,
      'resourceType': resourceType,
      'bytes':        uploadBody['bytes'] ?? bytes.length,
    });
    return secureUrl;
  }

  // Swaps a just-uploaded local cover path for its CDN URL in state, so a
  // later uploadImagesAndContinue() call sees the "already on CDN" (http)
  // check succeed instead of uploading the same file again.
  void _markCoverUploaded(String oldPath, String newUrl) {
    if (state.imagePaths.isEmpty || state.imagePaths[0] != oldPath) return;
    final updatedPaths = [newUrl, ...state.imagePaths.skip(1)];
    final newTypes = Map<String, String>.from(state.mediaTypes);
    final t = newTypes.remove(oldPath);
    if (t != null) newTypes[newUrl] = t;
    final newBytes = Map<String, Uint8List>.from(state.mediaBytes)..remove(oldPath);
    state = state.copyWith(imagePaths: updatedPaths, mediaTypes: newTypes, mediaBytes: newBytes);
  }

  // Same swap as above, but for one entry within a per-attribute-value gallery.
  void _markAttributeImageUploaded(String key, String oldPath, String newUrl) {
    final list = state.attributeImages[key];
    if (list == null) return;
    final idx = list.indexOf(oldPath);
    if (idx == -1) return;
    final updatedList = [...list]..[idx] = newUrl;
    final updatedMap  = Map<String, List<String>>.from(state.attributeImages)..[key] = updatedList;
    final newTypes = Map<String, String>.from(state.mediaTypes);
    final t = newTypes.remove(oldPath);
    if (t != null) newTypes[newUrl] = t;
    final newBytes = Map<String, Uint8List>.from(state.mediaBytes)..remove(oldPath);
    state = state.copyWith(attributeImages: updatedMap, mediaTypes: newTypes, mediaBytes: newBytes);
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
        currentStep: state.isEditMode ? state.currentStep : 6,
        maxReachedStep: max(state.maxReachedStep, 6),
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
      state = state.copyWith(
        isCreating: false,
        currentStep: state.isEditMode ? state.currentStep : 6,
        maxReachedStep: max(state.maxReachedStep, 6),
      );
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
  // [discount] is the seller-configured discount to apply to SKUs created via
  // the Variants step's add-variants request (see saveVariantsAndContinue).
  // Pass null to clear a previously-set discount.
  void savePricing({
    required String price,
    required String mrp,
    required String stock,
    required String sku,
    required String weight,
    DiscountConfig? discount,
  }) => state = state.copyWith(
        price: price, mrp: mrp, stock: stock, sku: sku, weight: weight,
        discount: discount, clearDiscount: discount == null,
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
