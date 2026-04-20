import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/widgets/app_button.dart';
import '../../../providers/add_product_provider.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/haptic_utils.dart';

class TagsBrandStep extends ConsumerStatefulWidget {
  const TagsBrandStep({super.key});

  @override
  ConsumerState<TagsBrandStep> createState() => _TagsBrandStepState();
}

class _TagsBrandStepState extends ConsumerState<TagsBrandStep> {
  final _tagCtrl = TextEditingController();

  List<String> _tags      = [];
  String?      _brandId;
  String?      _brandName;

  @override
  void initState() {
    super.initState();
    final s  = ref.read(addProductPod);
    _tags      = [...s.tags];
    _brandId   = s.brandId;
    _brandName = s.brandName;
  }

  @override
  void dispose() {
    _tagCtrl.dispose();
    super.dispose();
  }

  void _addTag() {
    final tag = _tagCtrl.text.trim().toLowerCase().replaceAll(' ', '-');
    if (tag.isEmpty || _tags.contains(tag) || _tags.length >= 10) return;
    setState(() => _tags.add(tag));
    _tagCtrl.clear();
    HapticUtils.light();
  }

  void _removeTag(String tag) {
    setState(() => _tags.remove(tag));
    HapticUtils.light();
  }

  Future<void> _openBrandSheet() async {
    HapticUtils.light();
    final categoryId = ref.read(addProductPod).categoryId ?? '';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BrandSheet(
        categoryId:    categoryId,
        selectedId:    _brandId,
        onSelect: (id, name) {
          setState(() {
            _brandId   = id;
            _brandName = name;
          });
          HapticUtils.medium();
        },
      ),
    );
  }

  Future<void> _next() async {
    await ref.read(addProductPod.notifier).saveBrandTagsAndContinue(
      brandId:   _brandId,
      brandName: _brandName,
      tags:      _tags,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(addProductPod);
    final error = state.error;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Help buyers discover your product with brand and tags.',
            style: TextStyle(color: AppColors.grey, fontSize: 14),
          ).animate().fadeIn(),

          // ── Error banner ────────────────────────────────────────────────────
          if (error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color:        AppColors.error.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border:       Border.all(color: AppColors.error.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded,
                      color: AppColors.error, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(error,
                        style: const TextStyle(
                            color: AppColors.error, fontSize: 12)),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          // ── Brand ──────────────────────────────────────────────────────────
          const Text('BRAND',
              style: TextStyle(
                  color: AppColors.grey,
                  fontSize: 13,
                  fontWeight: FontWeight.w500))
              .animate().fadeIn(delay: 60.ms),
          const SizedBox(height: 8),

          GestureDetector(
            onTap: _openBrandSheet,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color:  AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _brandId != null
                      ? AppColors.success
                      : AppColors.border,
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _brandId != null
                        ? Icons.check_circle_rounded
                        : Icons.storefront_outlined,
                    color: _brandId != null ? AppColors.success : AppColors.grey,
                    size: 18,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _brandName ?? 'Select a brand',
                      style: TextStyle(
                        color: _brandId != null
                            ? AppColors.white
                            : AppColors.greyDark,
                        fontSize: 14,
                        fontWeight: _brandId != null
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_brandId != null)
                        GestureDetector(
                          onTap: () {
                            setState(() { _brandId = null; _brandName = null; });
                            HapticUtils.light();
                          },
                          child: const Padding(
                            padding: EdgeInsets.only(right: 8),
                            child: Icon(Icons.close_rounded,
                                color: AppColors.grey, size: 16),
                          ),
                        ),
                      const Icon(Icons.keyboard_arrow_down_rounded,
                          color: AppColors.grey, size: 20),
                    ],
                  ),
                ],
              ),
            ),
          ).animate().fadeIn(delay: 80.ms),

          const SizedBox(height: 24),

          // ── Tags ───────────────────────────────────────────────────────────
          Row(
            children: [
              const Text('TAGS',
                  style: TextStyle(
                      color: AppColors.grey,
                      fontSize: 13,
                      fontWeight: FontWeight.w500)),
              const Spacer(),
              Text('${_tags.length}/10',
                  style: const TextStyle(
                      color: AppColors.greyDark, fontSize: 12)),
            ],
          ).animate().fadeIn(delay: 120.ms),
          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _tagCtrl,
                  onSubmitted: (_) => _addTag(),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'[a-zA-Z0-9\s\-]'))
                  ],
                  style: const TextStyle(color: AppColors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText:  'e.g. cotton, summer, casual',
                    hintStyle: const TextStyle(
                        color: AppColors.greyDark, fontSize: 13),
                    filled:    true,
                    fillColor: AppColors.surface,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                            const BorderSide(color: AppColors.border)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                            const BorderSide(color: AppColors.border)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                            color: AppColors.white, width: 1.5)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _addTag,
                child: Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.add_rounded,
                      color: AppColors.bg, size: 22),
                ),
              ),
            ],
          ).animate().fadeIn(delay: 140.ms),

          const SizedBox(height: 12),

          if (_tags.isNotEmpty)
            Wrap(
              spacing: 8, runSpacing: 8,
              children: _tags.map((t) => _TagChip(
                label:    t,
                onRemove: () => _removeTag(t),
              )).toList(),
            ).animate().fadeIn(),

          if (_tags.isEmpty)
            const Text(
              'Type a tag and press Enter or + to add',
              style: TextStyle(color: AppColors.greyDark, fontSize: 12),
            ).animate().fadeIn(),

          const SizedBox(height: 40),

          AppButton(
            isLoading: state.isCreating,
            label:     'Continue to Review',
            onTap:     _next,
            icon:      Icons.arrow_forward_rounded,
          ).animate().fadeIn(delay: 200.ms),
        ],
      ),
    );
  }
}

// ── Brand bottom sheet ────────────────────────────────────────────────────────

class _BrandSheet extends StatefulWidget {
  final String   categoryId;
  final String?  selectedId;
  final void Function(String id, String name) onSelect;

  const _BrandSheet({
    required this.categoryId,
    required this.onSelect,
    this.selectedId,
  });

  @override
  State<_BrandSheet> createState() => _BrandSheetState();
}

class _BrandSheetState extends State<_BrandSheet> {
  final _searchCtrl = TextEditingController();
  final _client     = ApiClient.instance.client;

  List<dynamic> _brands      = [];
  List<dynamic> _topBrands   = [];
  bool          _loading     = true;
  bool          _searching   = false;
  String        _query       = '';
  Timer?        _debounce;

  @override
  void initState() {
    super.initState();
    _fetchTopBrands();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  // GET /api/v1/brands/category/{categoryId}
  Future<void> _fetchTopBrands() async {
    setState(() { _loading = true; });
    try {
      final res  = await _client.get(
          '${ApiEndpoints.brandsByCategory}/${widget.categoryId}');
      final list = _extractList(res.data);
      setState(() { _topBrands = list; _brands = list; _loading = false; });
    } catch (_) {
      setState(() { _loading = false; });
    }
  }

  // GET /api/v1/brands/search?categoryId=&keyword=
  Future<void> _search(String keyword) async {
    if (keyword.length < 2) {
      setState(() { _brands = _topBrands; _searching = false; });
      return;
    }
    setState(() { _searching = true; });
    try {
      final res  = await _client.get(
        ApiEndpoints.brandsSearch,
        queryParameters: {
          'categoryId': widget.categoryId,
          'keyword':    keyword,
        },
      );
      final list = _extractList(res.data);
      if (mounted) setState(() { _brands = list; _searching = false; });
    } on DioException catch (_) {
      if (mounted) setState(() { _searching = false; });
    }
  }

  void _onSearchChanged(String value) {
    setState(() => _query = value);
    _debounce?.cancel();
    if (value.isEmpty) {
      setState(() { _brands = _topBrands; _searching = false; });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 500), () => _search(value));
  }

  List<dynamic> _extractList(dynamic data) {
    if (data is List) return data;
    if (data is Map) {
      final inner = data['data'];
      if (inner is List) return inner;
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize:     0.5,
      maxChildSize:     0.95,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // ── Handle ──────────────────────────────────────────────────────
            const SizedBox(height: 10),
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // ── Header ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Row(
                children: [
                  const Text(
                    'SELECT BRAND',
                    style: TextStyle(
                      color:         AppColors.white,
                      fontSize:      13,
                      fontWeight:    FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close_rounded,
                        color: AppColors.grey, size: 20),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),
            Container(height: 1, color: AppColors.divider),

            // ── Search ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _searchCtrl,
                onChanged:  _onSearchChanged,
                style: const TextStyle(color: AppColors.white, fontSize: 14),
                cursorColor: AppColors.white,
                decoration: InputDecoration(
                  hintText:  'Search brand…',
                  hintStyle: const TextStyle(
                      color: AppColors.greyDark, fontSize: 14),
                  prefixIcon: _searching
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.grey,
                            ),
                          ),
                        )
                      : const Icon(Icons.search_rounded,
                          color: AppColors.grey, size: 18),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded,
                              color: AppColors.grey, size: 16),
                          onPressed: () {
                            _searchCtrl.clear();
                            _onSearchChanged('');
                          },
                        )
                      : null,
                  filled:    true,
                  fillColor: AppColors.surface2,
                  isDense:   true,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: AppColors.border)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: AppColors.border)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: AppColors.white, width: 1.5)),
                ),
              ),
            ),

            Container(height: 1, color: AppColors.divider),

            // ── Section label ────────────────────────────────────────────────
            if (!_loading)
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(16, 10, 16, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _query.length >= 2
                        ? '${_brands.length} result${_brands.length != 1 ? 's' : ''}'
                        : 'TOP BRANDS',
                    style: const TextStyle(
                        color:         AppColors.greyDark,
                        fontSize:      10,
                        fontWeight:    FontWeight.w600,
                        letterSpacing: 0.6),
                  ),
                ),
              ),

            // ── Brand list ───────────────────────────────────────────────────
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.white, strokeWidth: 2),
                    )
                  : _brands.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.storefront_outlined,
                                  color: AppColors.grey, size: 36),
                              const SizedBox(height: 12),
                              Text(
                                _query.isNotEmpty
                                    ? 'No brands found for "$_query"'
                                    : 'No brands available',
                                style: const TextStyle(
                                    color:    AppColors.grey,
                                    fontSize: 13),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          controller:   scrollCtrl,
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          itemCount:    _brands.length,
                          separatorBuilder: (_, __) =>
                              Container(height: 1, color: AppColors.divider),
                          itemBuilder: (_, i) {
                            final b    = _brands[i] as Map;
                            final id   = b['id']?.toString()
                                ?? b['brandId']?.toString() ?? '';
                            final name = b['name']?.toString() ?? '';
                            final logo = b['logo']?.toString()
                                ?? b['logoUrl']?.toString() ?? '';
                            final selected = widget.selectedId == id;

                            return Material(
                              color: selected
                                  ? AppColors.success.withOpacity(0.06)
                                  : Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  widget.onSelect(id, name);
                                  Navigator.pop(context);
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 14),
                                  child: Row(
                                    children: [
                                      // Logo or initial avatar
                                      Container(
                                        width: 38, height: 38,
                                        decoration: BoxDecoration(
                                          color: AppColors.surface2,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          border: Border.all(
                                              color: selected
                                                  ? AppColors.success
                                                      .withOpacity(0.4)
                                                  : AppColors.border),
                                        ),
                                        clipBehavior: Clip.hardEdge,
                                        child: logo.isNotEmpty
                                            ? Image.network(
                                                logo,
                                                fit: BoxFit.contain,
                                                errorBuilder: (_, __, ___) =>
                                                    _BrandInitial(name: name),
                                              )
                                            : _BrandInitial(name: name),
                                      ),
                                      const SizedBox(width: 14),

                                      // Name
                                      Expanded(
                                        child: Text(
                                          name,
                                          style: TextStyle(
                                            color: selected
                                                ? AppColors.white
                                                : AppColors.white,
                                            fontSize:   14,
                                            fontWeight: selected
                                                ? FontWeight.w600
                                                : FontWeight.w400,
                                          ),
                                        ),
                                      ),

                                      // Check
                                      if (selected)
                                        const Icon(Icons.check_circle_rounded,
                                            color: AppColors.success, size: 20),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Brand initial avatar ──────────────────────────────────────────────────────

class _BrandInitial extends StatelessWidget {
  final String name;
  const _BrandInitial({required this.name});

  @override
  Widget build(BuildContext context) {
    final letter = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Center(
      child: Text(
        letter,
        style: const TextStyle(
            color:      AppColors.grey,
            fontSize:   16,
            fontWeight: FontWeight.w700),
      ),
    );
  }
}

// ── Tag chip ──────────────────────────────────────────────────────────────────

class _TagChip extends StatelessWidget {
  final String       label;
  final VoidCallback onRemove;
  const _TagChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('#$label',
              style: const TextStyle(color: AppColors.white, fontSize: 12)),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close_rounded,
                color: AppColors.grey, size: 14),
          ),
        ],
      ),
    );
  }
}
