import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/responsive.dart';
import '../core/widgets/app_shimmer.dart';
import '../core/widgets/app_toast.dart';
import '../core/widgets/confirm_modal.dart';
import '../providers/products_provider.dart';
import '../utils/app_colors.dart';
import '../utils/haptic_utils.dart';
import '../widgets/products/product_list_card.dart';
import '../widgets/products/product_table_row.dart';
import '../widgets/products/scheduled_product_row.dart';
import 'add_product/catalog_search_screen.dart';
import 'add_product_screen.dart';
import 'edit_product_screen.dart';
import 'share_product_sheet.dart';

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  ProductFilterParams _filters = ProductFilterParams.defaults;
  Timer? _searchDebounce;

  final _scheduledSearchCtrl = TextEditingController();
  String _scheduledQuery = '';
  Timer? _scheduledSearchDebounce;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(productsPod.notifier).fetchProducts());
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    _scheduledSearchDebounce?.cancel();
    _scheduledSearchCtrl.dispose();
    super.dispose();
  }

  // Debounced server-side search: ES-backed on the backend, with a DB fallback
  // if Elasticsearch is down — see SellerService.getMyLiveProducts.
  void _onSearchChanged(String v) {
    setState(() => _query = v);
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      ref.read(productsPod.notifier).fetchProducts(filters: _filters, query: _query);
    });
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    setState(() { _query = ''; _searchCtrl.clear(); });
    ref.read(productsPod.notifier).fetchProducts(filters: _filters);
  }

  void _onScheduledSearchChanged(String v) {
    setState(() => _scheduledQuery = v);
    _scheduledSearchDebounce?.cancel();
    _scheduledSearchDebounce = Timer(const Duration(milliseconds: 400), () {
      ref.read(productsPod.notifier).fetchScheduledProducts(query: _scheduledQuery);
    });
  }

  void _clearScheduledSearch() {
    _scheduledSearchDebounce?.cancel();
    setState(() { _scheduledQuery = ''; _scheduledSearchCtrl.clear(); });
    ref.read(productsPod.notifier).fetchScheduledProducts();
  }

  // ── Scheduled tab: reschedule bottom sheet ──────────────────────────────

  Future<void> _pickScheduledDateTime({DateTime? initial}) async {
    final now  = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initial != null && initial.isAfter(now) ? initial : now.add(const Duration(hours: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial ?? now.add(const Duration(hours: 1))),
    );
    if (time == null) return;
    final scheduledAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    if (scheduledAt.isBefore(DateTime.now())) {
      if (!mounted) return;
      AppToast.show(context, message: 'Pick a future date and time', type: ToastType.error);
      return;
    }
    _lastPickedScheduledAt = scheduledAt;
  }

  DateTime? _lastPickedScheduledAt;

  Future<void> _onRescheduleOne(String id, DateTime? current) async {
    HapticUtils.light();
    await _pickScheduledDateTime(initial: current);
    final picked = _lastPickedScheduledAt;
    _lastPickedScheduledAt = null;
    if (picked == null) return;
    final ok = await ref.read(productsPod.notifier).scheduleProduct(id, picked);
    if (!mounted) return;
    AppToast.show(context,
        message: ok ? 'Product rescheduled' : (ref.read(productsPod).error ?? 'Could not reschedule'),
        type: ok ? ToastType.success : ToastType.error);
  }

  Future<void> _onBulkReschedule() async {
    HapticUtils.medium();
    await _pickScheduledDateTime();
    final picked = _lastPickedScheduledAt;
    _lastPickedScheduledAt = null;
    if (picked == null) return;
    await ref.read(productsPod.notifier).bulkReschedule(picked);
    if (!mounted) return;
    AppToast.show(context, message: 'Products rescheduled', type: ToastType.success);
  }

  Future<void> _onPublishNowOne(String id) async {
    HapticUtils.medium();
    final confirmed = await showConfirmModal(
      context,
      title: 'Publish Now',
      message: 'This product will go live immediately instead of at its scheduled time.',
      confirmLabel: 'Publish',
    );
    if (!confirmed) return;
    final ok = await ref.read(productsPod.notifier).publishScheduledProductNow(id);
    if (!mounted) return;
    AppToast.show(context,
        message: ok ? 'Product published' : (ref.read(productsPod).error ?? 'Could not publish product'),
        type: ok ? ToastType.success : ToastType.error);
  }

  Future<void> _onBulkPublishNow() async {
    HapticUtils.medium();
    final count = ref.read(productsPod).selectedScheduledIds.length;
    final confirmed = await showConfirmModal(
      context,
      title: 'Publish Now',
      message: '$count selected product${count > 1 ? 's' : ''} will go live immediately.',
      confirmLabel: 'Publish',
    );
    if (!confirmed) return;
    await ref.read(productsPod.notifier).bulkPublishNow();
    if (!mounted) return;
    AppToast.show(context, message: 'Products published', type: ToastType.success);
  }

  Future<void> _onDeleteScheduled(String id) async {
    HapticUtils.medium();
    final confirmed = await showConfirmModal(
      context,
      title: 'Delete Product',
      message: 'This will permanently remove the product.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed) return;
    final ok = await ref.read(productsPod.notifier).deleteProduct(id);
    if (!mounted) return;
    AppToast.show(context,
        message: ok ? 'Product deleted' : (ref.read(productsPod).error ?? 'Cannot delete product'),
        type: ok ? ToastType.success : ToastType.error);
  }

  // ── Add-product choice modal ──────────────────────────────────────────────

  void _showAddChoiceModal() {
    HapticUtils.medium();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 24, 24, 24 + MediaQuery.of(ctx).padding.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add a Product',
              style: TextStyle(
                color: AppColors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'How would you like to add this product?',
              style: TextStyle(color: AppColors.grey, fontSize: 13),
            ),
            const SizedBox(height: 20),
            AddProductChoiceTile(
              icon: CupertinoIcons.search,
              title: 'Find Existing Product',
              subtitle:
                  'Search our catalog — Samsung, Maggi, Dove and more. '
                  'Just set your price and stock.',
              badge: 'Faster',
              badgeColor: AppColors.success,
              onTap: () {
                HapticUtils.light();
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  _slideRoute(const CatalogSearchScreen()),
                );
              },
            ),
            const SizedBox(height: 12),
            AddProductChoiceTile(
              icon: CupertinoIcons.pencil_outline,
              title: 'Create Custom Product',
              subtitle:
                  'Build a product from scratch — name, photos, attributes '
                  'and variants.',
              onTap: () {
                HapticUtils.light();
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  _slideRoute(const AddProductScreen(skipChoice: true)),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static int _stockOf(dynamic p) {
    final s = (p as Map)['stock'];
    return s is num ? s.toInt() : int.tryParse(s?.toString() ?? '') ?? 0;
  }

  static double _priceOf(dynamic p) {
    final v = (p as Map)['price'];
    return v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0.0;
  }

  List<dynamic> _applyFilters(List<dynamic> raw) {
    final q = _query.toLowerCase();

    Iterable<dynamic> list = raw;

    // Search
    if (q.isNotEmpty) {
      list = list.where((p) =>
          (p['name'] as String? ?? '').toLowerCase().contains(q) ||
          (p['brand'] as String? ?? '').toLowerCase().contains(q) ||
          (p['categoryName'] as String? ?? '').toLowerCase().contains(q));
    }

    // Status
    switch (_filters.status) {
      case ProductStatusFilter.active:
        list = list.where((p) => (p as Map)['isActive'] == true);
        break;
      case ProductStatusFilter.inactive:
        list = list.where((p) => (p as Map)['isActive'] == false);
        break;
      case ProductStatusFilter.all:
        break;
    }

    // Stock
    switch (_filters.stock) {
      case ProductStockFilter.inStock:
        list = list.where((p) => _stockOf(p) > 10);
        break;
      case ProductStockFilter.lowStock:
        list = list.where((p) {
          final s = _stockOf(p);
          return s > 0 && s <= 10;
        });
        break;
      case ProductStockFilter.outOfStock:
        list = list.where((p) => _stockOf(p) == 0);
        break;
      case ProductStockFilter.all:
        break;
    }

    // Category
    if (_filters.categoryId != null) {
      list = list.where((p) =>
          (p as Map)['categoryId']?.toString() == _filters.categoryId ||
          (p)['categoryName']?.toString() == _filters.categoryName);
    }

    // Brand
    if (_filters.brandId != null) {
      list = list.where((p) =>
          (p as Map)['brandId']?.toString() == _filters.brandId ||
          (p)['brand']?.toString() == _filters.brandName);
    }

    // Price range
    if (_filters.minPrice != null) {
      list = list.where((p) => _priceOf(p) >= _filters.minPrice!);
    }
    if (_filters.maxPrice != null) {
      list = list.where((p) => _priceOf(p) <= _filters.maxPrice!);
    }

    final result = list.toList();

    // Sort
    switch (_filters.sort) {
      case ProductSortBy.nameAsc:
        result.sort((a, b) =>
            (a['name'] as String? ?? '').compareTo(b['name'] as String? ?? ''));
        break;
      case ProductSortBy.nameDesc:
        result.sort((a, b) =>
            (b['name'] as String? ?? '').compareTo(a['name'] as String? ?? ''));
        break;
      case ProductSortBy.priceAsc:
        result.sort((a, b) => _priceOf(a).compareTo(_priceOf(b)));
        break;
      case ProductSortBy.priceDesc:
        result.sort((a, b) => _priceOf(b).compareTo(_priceOf(a)));
        break;
      case ProductSortBy.stockAsc:
        result.sort((a, b) => _stockOf(a).compareTo(_stockOf(b)));
        break;
      case ProductSortBy.stockDesc:
        result.sort((a, b) => _stockOf(b).compareTo(_stockOf(a)));
        break;
      case ProductSortBy.newest:
        break;
    }

    return result;
  }

  Future<void> _openFilterSheet(ProductsState state) async {
    HapticUtils.light();
    final result = await showModalBottomSheet<ProductFilterParams>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FilterSheet(
        current: _filters,
        categories: state.categories,
        brands:     ref.read(productsPod).brands,
      ),
    );
    if (result != null) {
      final oldFilters = _filters;
      setState(() => _filters = result);
      // Re-fetch from server whenever a server-supported filter changes
      // (category, brand, price range, status, stock, or a backend-sortable order).
      final sortIsServerSide = result.sort == ProductSortBy.priceAsc ||
          result.sort == ProductSortBy.priceDesc ||
          result.sort == ProductSortBy.newest;
      final needsRefetch = result.categoryId != oldFilters.categoryId ||
          result.brandId != oldFilters.brandId ||
          result.minPrice != oldFilters.minPrice ||
          result.maxPrice != oldFilters.maxPrice ||
          result.status != oldFilters.status ||
          result.stock != oldFilters.stock ||
          (result.sort != oldFilters.sort && sortIsServerSide);
      if (needsRefetch) {
        await ref.read(productsPod.notifier).fetchProducts(filters: result, query: _query);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state    = ref.watch(productsPod);
    final products = _applyFilters(state.products);
    final lowStockCount = state.products
        .where((p) => _stockOf(p) <= 5 && (p['isActive'] as bool? ?? true))
        .length;
    final activeFilterCount = _filters.activeCount + (_query.isNotEmpty ? 1 : 0);
    final hPad = Responsive.horizontalPadding(context);

    return Scaffold(
      backgroundColor: AppColors.bg,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddChoiceModal,
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.bg,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Product', style: TextStyle(fontWeight: FontWeight.w700)),
      ).animate().slideY(begin: 1, end: 0, delay: 300.ms, curve: Curves.easeOut),
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ───────────────────────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(hPad, 20, hPad, 0),
              child: Row(
                children: [
                  const Text(
                    'Products',
                    style: TextStyle(color: AppColors.white, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.3),
                  ).animate().fadeIn(),
                  const Spacer(),
                  if (!state.isLoading)
                    Text(
                      '${products.length} items',
                      style: const TextStyle(color: AppColors.grey, fontSize: 13),
                    ).animate().fadeIn(delay: 100.ms),
                  const SizedBox(width: 12),
                  // Filter button with badge
                  GestureDetector(
                    onTap: () => _openFilterSheet(state),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _filters.hasActiveFilters ? AppColors.white : AppColors.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _filters.hasActiveFilters ? AppColors.white : AppColors.border,
                            ),
                          ),
                          child: Icon(
                            Icons.tune_rounded,
                            color: _filters.hasActiveFilters ? AppColors.bg : AppColors.grey,
                            size: 18,
                          ),
                        ),
                        if (activeFilterCount > 0)
                          Positioned(
                            top: -4, right: -4,
                            child: Container(
                              width: 16, height: 16,
                              decoration: const BoxDecoration(color: AppColors.info, shape: BoxShape.circle),
                              child: Center(
                                child: Text(
                                  '$activeFilterCount',
                                  style: const TextStyle(color: AppColors.white, fontSize: 9, fontWeight: FontWeight.w800),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 80.ms),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // ── Tab bar: Market / Traffic sources / Viewers ─────────────────
            Padding(
              padding: EdgeInsets.symmetric(horizontal: hPad),
              child: _ProductsTabBar(
                active: state.activeTab,
                onChanged: (tab) {
                  HapticUtils.light();
                  ref.read(productsPod.notifier).setTab(tab);
                },
              ),
            ).animate().fadeIn(delay: 90.ms),

            const SizedBox(height: 16),

            // ── Low-stock banner ──────────────────────────────────────────
            if (state.activeTab == ProductsTab.released && lowStockCount > 0 && _filters.stock != ProductStockFilter.lowStock)
              Padding(
                padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 12),
                child: GestureDetector(
                  onTap: () {
                    HapticUtils.light();
                    setState(() => _filters = _filters.copyWith(stock: ProductStockFilter.lowStock));
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.warning.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '$lowStockCount product${lowStockCount > 1 ? 's' : ''} low on stock (≤5) — tap to filter',
                            style: const TextStyle(color: AppColors.warning, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // ── Search bar ────────────────────────────────────────────────
            if (state.activeTab == ProductsTab.released)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: hPad),
              child: TextField(
                controller: _searchCtrl,
                onChanged: _onSearchChanged,
                style: const TextStyle(color: AppColors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search by name, brand, category…',
                  hintStyle: const TextStyle(color: AppColors.greyDark, fontSize: 14),
                  prefixIcon: const Icon(Icons.search_rounded, color: AppColors.grey, size: 20),
                  suffixIcon: _query.isNotEmpty
                      ? GestureDetector(
                          onTap: _clearSearch,
                          child: const Icon(Icons.close_rounded, color: AppColors.grey, size: 18),
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.surface,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.white, width: 1.5)),
                ),
              ),
            ).animate().fadeIn(delay: 80.ms),

            // ── Search bar (Scheduled tab) ──────────────────────────────────
            if (state.activeTab == ProductsTab.scheduled)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: hPad),
              child: TextField(
                controller: _scheduledSearchCtrl,
                onChanged: _onScheduledSearchChanged,
                style: const TextStyle(color: AppColors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search product',
                  hintStyle: const TextStyle(color: AppColors.greyDark, fontSize: 14),
                  prefixIcon: const Icon(Icons.search_rounded, color: AppColors.grey, size: 20),
                  suffixIcon: _scheduledQuery.isNotEmpty
                      ? GestureDetector(
                          onTap: _clearScheduledSearch,
                          child: const Icon(Icons.close_rounded, color: AppColors.grey, size: 18),
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.surface,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.white, width: 1.5)),
                ),
              ),
            ).animate().fadeIn(delay: 80.ms),

            // ── Active filter chips ───────────────────────────────────────
            if (state.activeTab == ProductsTab.released && _filters.hasActiveFilters) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 30,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: hPad),
                  children: [
                    _ActiveChip(
                      label: 'Clear all',
                      color: AppColors.error,
                      onRemove: () => setState(() {
                        _filters = ProductFilterParams.defaults;
                        ref.read(productsPod.notifier).fetchProducts();
                      }),
                    ),
                    if (_filters.sort != ProductSortBy.newest)
                      _ActiveChip(
                        label: _sortLabel(_filters.sort),
                        onRemove: () => setState(() => _filters = _filters.copyWith(sort: ProductSortBy.newest)),
                      ),
                    if (_filters.status != ProductStatusFilter.all)
                      _ActiveChip(
                        label: _statusLabel(_filters.status),
                        onRemove: () => setState(() => _filters = _filters.copyWith(status: ProductStatusFilter.all)),
                      ),
                    if (_filters.stock != ProductStockFilter.all)
                      _ActiveChip(
                        label: _stockLabel(_filters.stock),
                        onRemove: () => setState(() => _filters = _filters.copyWith(stock: ProductStockFilter.all)),
                      ),
                    if (_filters.categoryName != null)
                      _ActiveChip(
                        label: _filters.categoryName!,
                        onRemove: () {
                          setState(() => _filters = _filters.copyWith(clearCategory: true));
                          ref.read(productsPod.notifier).fetchProducts(filters: _filters);
                        },
                      ),
                    if (_filters.brandName != null)
                      _ActiveChip(
                        label: _filters.brandName!,
                        onRemove: () {
                          setState(() => _filters = _filters.copyWith(clearBrand: true));
                          ref.read(productsPod.notifier).fetchProducts(filters: _filters);
                        },
                      ),
                    if (_filters.minPrice != null || _filters.maxPrice != null)
                      _ActiveChip(
                        label: '₹${_filters.minPrice?.toInt() ?? 0} – ₹${_filters.maxPrice?.toInt() ?? '∞'}',
                        onRemove: () {
                          setState(() => _filters = _filters.copyWith(clearMinPrice: true, clearMaxPrice: true));
                          ref.read(productsPod.notifier).fetchProducts(filters: _filters);
                        },
                      ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),

            // ── List ──────────────────────────────────────────────────────
            Expanded(
              child: state.activeTab == ProductsTab.scheduled
                  ? _buildScheduledTab(context, state)
                  : state.activeTab != ProductsTab.released
                  ? (state.activeTab == ProductsTab.trafficSources
                      ? _TrafficSourcesTab(state: state)
                      : _ViewersTab(state: state))
                  : state.isLoading
                      ? _buildLoadingSkeleton(context)
                      : state.error != null && products.isEmpty
                          ? _ErrorRetry(
                              message: state.error!,
                              onRetry: () => ref.read(productsPod.notifier).fetchProducts(filters: _filters, query: _query),
                            )
                          : products.isEmpty
                              ? _EmptyProducts(
                                  hasFilters: activeFilterCount > 0,
                                  onClear: () {
                                    _searchDebounce?.cancel();
                                    setState(() {
                                      _filters = ProductFilterParams.defaults;
                                      _query   = '';
                                      _searchCtrl.clear();
                                    });
                                    ref.read(productsPod.notifier).fetchProducts();
                                  },
                                )
                              : Column(
                                  children: [
                                    if (state.selectedIds.isNotEmpty)
                                      _BulkActionBar(state: state),
                                    Expanded(
                                      child: RefreshIndicator(
                                        onRefresh: () async {
                                          HapticUtils.light();
                                          await ref.read(productsPod.notifier).fetchProducts(filters: _filters, query: _query);
                                        },
                                        color: AppColors.white,
                                        backgroundColor: AppColors.surface,
                                        child: Responsive.isMobile(context)
                                            ? _buildMobileList(context, products, state)
                                            : _buildDesktopTable(context, products, state),
                                      ),
                                    ),
                                  ],
                                ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Market tab: loading skeleton (mirrors the real mobile-list / desktop-
  // table shape so results don't jump-cut into a different layout) ────────

  Widget _buildLoadingSkeleton(BuildContext context) {
    final padding = Responsive.horizontalPadding(context);
    if (Responsive.isMobile(context)) {
      return ListView.separated(
        padding: EdgeInsets.fromLTRB(padding, 0, padding, 20),
        itemCount: 6,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, __) => const ProductListRowShimmer(),
      );
    }
    return Container(
      margin: EdgeInsets.symmetric(horizontal: padding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          ProductTableHeader(
            allSelected: false,
            someSelected: false,
            onSelectAllChanged: (_) {},
          ),
          ...List.generate(8, (_) => const ProductTableRowShimmer()),
        ],
      ),
    );
  }

  // ── Market tab: mobile stacked card list ────────────────────────────────

  Widget _buildMobileList(BuildContext context, List<dynamic> products, ProductsState state) {
    final showLoadMore = state.hasMore && _query.isEmpty && !_filters.hasActiveFilters;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      itemCount: products.length + (showLoadMore ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        if (i >= products.length) {
          return _LoadMoreButton(
            isLoading: state.isLoadingMore,
            onTap: () => ref.read(productsPod.notifier).fetchProducts(
              filters: _filters, query: _query, page: state.currentPage + 1, append: true),
          );
        }
        final p = products[i] as Map;
        final id = p['id'] as String? ?? '';
        return ProductListCard(
          product: p,
          index: i,
          onEdit: () => _onEdit(id),
          onShare: () => showShareProductSheet(context, p),
          onDelete: () => _onDelete(id),
          onToggleActive: () => _onToggleActive(id, p['isActive'] as bool? ?? true),
        );
      },
    );
  }

  // ── Market tab: desktop/tablet table ────────────────────────────────────

  Widget _buildDesktopTable(BuildContext context, List<dynamic> products, ProductsState state) {
    final ids = products.map((p) => (p as Map)['id'] as String? ?? '').where((id) => id.isNotEmpty).toList();
    final allSelected  = ids.isNotEmpty && ids.every(state.selectedIds.contains);
    final someSelected = ids.any(state.selectedIds.contains);
    final showLoadMore = state.hasMore && _query.isEmpty && !_filters.hasActiveFilters;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: Responsive.horizontalPadding(context)),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          ProductTableHeader(
            allSelected: allSelected,
            someSelected: someSelected,
            onSelectAllChanged: (_) {
              if (allSelected) {
                ref.read(productsPod.notifier).clearSelection();
              } else {
                ref.read(productsPod.notifier).selectAll(ids);
              }
            },
          ),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: products.length + (showLoadMore ? 1 : 0),
              itemBuilder: (_, i) {
                if (i >= products.length) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: _LoadMoreButton(
                      isLoading: state.isLoadingMore,
                      onTap: () => ref.read(productsPod.notifier).fetchProducts(
                        filters: _filters, query: _query, page: state.currentPage + 1, append: true),
                    ),
                  );
                }
                final p = products[i] as Map;
                final id = p['id'] as String? ?? '';
                return ProductTableRow(
                  product: p,
                  index: i,
                  selected: state.selectedIds.contains(id),
                  onToggleSelect: () => ref.read(productsPod.notifier).toggleSelected(id),
                  onEdit: () => _onEdit(id),
                  onShare: () => showShareProductSheet(context, p),
                  onDelete: () => _onDelete(id),
                  onToggleActive: () => _onToggleActive(id, p['isActive'] as bool? ?? true),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Scheduled tab ────────────────────────────────────────────────────────

  Widget _buildScheduledTab(BuildContext context, ProductsState state) {
    if (state.isLoadingScheduled && state.scheduledProducts.isEmpty) {
      return _buildLoadingSkeleton(context);
    }
    if (state.scheduledProducts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Icon(Icons.schedule_rounded, color: AppColors.greyDark, size: 36),
              ),
              const SizedBox(height: 16),
              Text(
                _scheduledQuery.isNotEmpty
                    ? 'No scheduled products match your search'
                    : 'No products scheduled.\nFinish a listing and schedule it to publish later.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.grey, fontSize: 14, height: 1.5),
              ),
            ],
          ),
        ).animate().fadeIn().scale(begin: const Offset(0.9, 0.9)),
      );
    }
    return Column(
      children: [
        if (state.selectedScheduledIds.isNotEmpty) _ScheduledBulkActionBar(
          count: state.selectedScheduledIds.length,
          onReschedule: _onBulkReschedule,
          onPublishNow: _onBulkPublishNow,
          onClear: () => ref.read(productsPod.notifier).clearScheduledSelection(),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              HapticUtils.light();
              await ref.read(productsPod.notifier).fetchScheduledProducts(query: _scheduledQuery);
            },
            color: AppColors.white,
            backgroundColor: AppColors.surface,
            child: Responsive.isMobile(context)
                ? _buildScheduledMobileList(context, state)
                : _buildScheduledDesktopTable(context, state),
          ),
        ),
      ],
    );
  }

  Widget _buildScheduledMobileList(BuildContext context, ProductsState state) {
    final products = state.scheduledProducts;
    final showLoadMore = state.scheduledHasMore && _scheduledQuery.isEmpty;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      itemCount: products.length + (showLoadMore ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        if (i >= products.length) {
          return _LoadMoreButton(
            isLoading: state.isLoadingMoreScheduled,
            onTap: () => ref.read(productsPod.notifier).fetchScheduledProducts(
              query: _scheduledQuery, page: state.scheduledCurrentPage + 1, append: true),
          );
        }
        final p = products[i] as Map;
        final id = p['id'] as String? ?? '';
        return ScheduledProductCard(
          product: p,
          index: i,
          selected: state.selectedScheduledIds.contains(id),
          onToggleSelect: () => ref.read(productsPod.notifier).toggleScheduledSelected(id),
          onEdit: () => _onEdit(id),
          onReschedule: () => _onRescheduleOne(id, _dateOfField(p['scheduledAt'])),
          onPublishNow: () => _onPublishNowOne(id),
          onDelete: () => _onDeleteScheduled(id),
        );
      },
    );
  }

  Widget _buildScheduledDesktopTable(BuildContext context, ProductsState state) {
    final products = state.scheduledProducts;
    final ids = products.map((p) => (p as Map)['id'] as String? ?? '').where((id) => id.isNotEmpty).toList();
    final allSelected  = ids.isNotEmpty && ids.every(state.selectedScheduledIds.contains);
    final someSelected = ids.any(state.selectedScheduledIds.contains);
    final showLoadMore = state.scheduledHasMore && _scheduledQuery.isEmpty;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: Responsive.horizontalPadding(context)),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          ScheduledProductTableHeader(
            allSelected: allSelected,
            someSelected: someSelected,
            onSelectAllChanged: (_) {
              if (allSelected) {
                ref.read(productsPod.notifier).clearScheduledSelection();
              } else {
                ref.read(productsPod.notifier).selectAllScheduled(ids);
              }
            },
          ),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: products.length + (showLoadMore ? 1 : 0),
              itemBuilder: (_, i) {
                if (i >= products.length) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: _LoadMoreButton(
                      isLoading: state.isLoadingMoreScheduled,
                      onTap: () => ref.read(productsPod.notifier).fetchScheduledProducts(
                        query: _scheduledQuery, page: state.scheduledCurrentPage + 1, append: true),
                    ),
                  );
                }
                final p = products[i] as Map;
                final id = p['id'] as String? ?? '';
                return ScheduledProductTableRow(
                  product: p,
                  index: i,
                  selected: state.selectedScheduledIds.contains(id),
                  onToggleSelect: () => ref.read(productsPod.notifier).toggleScheduledSelected(id),
                  onEdit: () => _onEdit(id),
                  onReschedule: () => _onRescheduleOne(id, _dateOfField(p['scheduledAt'])),
                  onPublishNow: () => _onPublishNowOne(id),
                  onDelete: () => _onDeleteScheduled(id),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  DateTime? _dateOfField(dynamic v) => v == null ? null : DateTime.tryParse(v.toString())?.toLocal();

  // ── Shared row action callbacks (used by both mobile card & desktop row) ─

  void _onEdit(String id) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => EditProductScreen(productId: id),
    )).then((_) => ref.read(productsPod.notifier).fetchProducts(filters: _filters));
  }

  Future<void> _onDelete(String id) async {
    HapticUtils.medium();
    final confirmed = await showConfirmModal(
      context,
      title: 'Delete Product',
      message: 'This will permanently remove the product. Orders linked to it will not be affected.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed) return;
    final ok      = await ref.read(productsPod.notifier).deleteProduct(id);
    final message = ok ? 'Product deleted' : (ref.read(productsPod).error ?? 'Cannot delete product');
    final type    = ok ? ToastType.success : ToastType.error;
    if (!mounted) return;
    AppToast.show(context, message: message, type: type);
  }

  Future<void> _onToggleActive(String id, bool isActive) async {
    HapticUtils.light();
    final ok      = await ref.read(productsPod.notifier).toggleActive(id);
    final message = ok
        ? (isActive ? 'Product deactivated' : 'Product activated')
        : (ref.read(productsPod).error ?? 'Could not update product');
    final type    = ok ? ToastType.success : ToastType.error;
    if (!mounted) return;
    AppToast.show(context, message: message, type: type);
  }

  PageRoute<dynamic> _slideRoute(Widget page) => PageRouteBuilder(
    pageBuilder: (_, anim, __) => page,
    transitionsBuilder: (_, anim, __, child) => SlideTransition(
      position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
          .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
      child: child,
    ),
  );
}

// ── Label helpers ─────────────────────────────────────────────────────────────

String _sortLabel(ProductSortBy s) {
  switch (s) {
    case ProductSortBy.nameAsc:   return 'Name A→Z';
    case ProductSortBy.nameDesc:  return 'Name Z→A';
    case ProductSortBy.priceAsc:  return 'Price ↑';
    case ProductSortBy.priceDesc: return 'Price ↓';
    case ProductSortBy.stockAsc:  return 'Stock ↑';
    case ProductSortBy.stockDesc: return 'Stock ↓';
    case ProductSortBy.newest:    return 'Newest';
  }
}

String _statusLabel(ProductStatusFilter s) {
  switch (s) {
    case ProductStatusFilter.active:   return 'Active';
    case ProductStatusFilter.inactive: return 'Inactive';
    case ProductStatusFilter.all:      return 'All';
  }
}

String _stockLabel(ProductStockFilter s) {
  switch (s) {
    case ProductStockFilter.inStock:    return 'In Stock';
    case ProductStockFilter.lowStock:   return 'Low Stock';
    case ProductStockFilter.outOfStock: return 'Out of Stock';
    case ProductStockFilter.all:        return 'All';
  }
}

// ── Active filter chip ────────────────────────────────────────────────────────

class _ActiveChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;
  final Color color;

  const _ActiveChip({required this.label, required this.onRemove, this.color = AppColors.grey});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onRemove,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
            const SizedBox(width: 4),
            Icon(Icons.close_rounded, color: color, size: 12),
          ],
        ),
      ),
    );
  }
}

// ── Products tab bar (Market / Traffic sources / Viewers) ──────────────────────

class _ProductsTabBar extends StatelessWidget {
  final ProductsTab active;
  final ValueChanged<ProductsTab> onChanged;
  const _ProductsTabBar({required this.active, required this.onChanged});

  static const _labels = {
    ProductsTab.released:       'Released',
    ProductsTab.scheduled:      'Scheduled',
    ProductsTab.trafficSources: 'Traffic sources',
    ProductsTab.viewers:        'Viewers',
  };

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: ProductsTab.values.map((tab) {
          final selected = tab == active;
          return GestureDetector(
            onTap: () => onChanged(tab),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              decoration: BoxDecoration(
                color: selected ? AppColors.white : AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: selected ? AppColors.white : AppColors.border),
              ),
              child: Text(
                _labels[tab]!,
                style: TextStyle(
                  color: selected ? AppColors.bg : AppColors.grey,
                  fontSize: 12.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Bulk action bar (shown when Market table rows are selected) ────────────────

class _BulkActionBar extends ConsumerWidget {
  final ProductsState state;
  const _BulkActionBar({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = state.selectedIds.length;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Text('$count selected', style: const TextStyle(color: AppColors.white, fontSize: 13, fontWeight: FontWeight.w700)),
          const Spacer(),
          TextButton(
            onPressed: () async {
              HapticUtils.light();
              await ref.read(productsPod.notifier).bulkToggleActive(true);
            },
            child: const Text('Activate', style: TextStyle(color: AppColors.success, fontSize: 12.5, fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () async {
              HapticUtils.light();
              await ref.read(productsPod.notifier).bulkToggleActive(false);
            },
            child: const Text('Deactivate', style: TextStyle(color: AppColors.warning, fontSize: 12.5, fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () async {
              HapticUtils.medium();
              final confirmed = await showConfirmModal(
                context,
                title: 'Delete Products',
                message: 'This will permanently remove $count selected product${count > 1 ? 's' : ''}.',
                confirmLabel: 'Delete',
                destructive: true,
              );
              if (!confirmed) return;
              await ref.read(productsPod.notifier).bulkDelete();
            },
            child: const Text('Delete', style: TextStyle(color: AppColors.error, fontSize: 12.5, fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () => ref.read(productsPod.notifier).clearSelection(),
            child: const Text('Clear', style: TextStyle(color: AppColors.grey, fontSize: 12.5, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ── Scheduled bulk action bar (Reschedule / Publish now) ───────────────────────

class _ScheduledBulkActionBar extends StatelessWidget {
  final int count;
  final VoidCallback onReschedule;
  final VoidCallback onPublishNow;
  final VoidCallback onClear;
  const _ScheduledBulkActionBar({
    required this.count,
    required this.onReschedule,
    required this.onPublishNow,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Text('$count selected', style: const TextStyle(color: AppColors.white, fontSize: 13, fontWeight: FontWeight.w700)),
          const Spacer(),
          TextButton.icon(
            onPressed: onReschedule,
            icon: const Icon(Icons.event_repeat_rounded, color: AppColors.info, size: 15),
            label: const Text('Reschedule', style: TextStyle(color: AppColors.info, fontSize: 12.5, fontWeight: FontWeight.w600)),
          ),
          FilledButton.icon(
            onPressed: onPublishNow,
            icon: const Icon(Icons.publish_rounded, size: 15),
            label: const Text('Publish now', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.white,
              foregroundColor: AppColors.bg,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          TextButton(
            onPressed: onClear,
            child: const Text('Clear', style: TextStyle(color: AppColors.grey, fontSize: 12.5, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ── Load more control ───────────────────────────────────────────────────────────

class _LoadMoreButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onTap;
  const _LoadMoreButton({required this.isLoading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: isLoading ? null : onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: isLoading
              ? const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.grey),
                )
              : const Text('Load more', style: TextStyle(color: AppColors.white, fontSize: 13, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }
}

// ── Traffic sources tab ───────────────────────────────────────────────────────

class _TrafficSourcesTab extends StatelessWidget {
  final ProductsState state;
  const _TrafficSourcesTab({required this.state});

  @override
  Widget build(BuildContext context) {
    if (state.isLoadingTrafficSources && state.trafficSources.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppColors.grey));
    }
    if (state.trafficSources.isEmpty) {
      return const Center(
        child: Text('No traffic source data yet', style: TextStyle(color: AppColors.grey, fontSize: 13)),
      );
    }
    final entries = state.trafficSources.cast<Map>();
    final maxCount = entries
        .map((e) => (e['count'] as num?) ?? 0)
        .fold<num>(0, (a, b) => a > b ? a : b)
        .toDouble()
        .clamp(1.0, double.infinity);

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      itemCount: entries.length,
      itemBuilder: (_, i) {
        final e      = entries[i];
        final source = e['source']?.toString() ?? 'Unknown';
        final count  = (e['count'] as num?)?.toDouble() ?? 0;
        final pct    = (count / maxCount).clamp(0.0, 1.0);
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(source, style: const TextStyle(color: AppColors.white, fontSize: 13, fontWeight: FontWeight.w600))),
                  Text(count.toInt().toString(), style: const TextStyle(color: AppColors.grey, fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pct,
                  backgroundColor: AppColors.surface2,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.info),
                  minHeight: 6,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Viewers tab ────────────────────────────────────────────────────────────────

class _ViewersTab extends StatelessWidget {
  final ProductsState state;
  const _ViewersTab({required this.state});

  @override
  Widget build(BuildContext context) {
    if (state.isLoadingViewers && state.viewers.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppColors.grey));
    }
    if (state.viewers.isEmpty) {
      return const Center(
        child: Text('No viewer data yet', style: TextStyle(color: AppColors.grey, fontSize: 13)),
      );
    }
    final entries = state.viewers.cast<Map>();
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      itemCount: entries.length,
      itemBuilder: (_, i) {
        final e       = entries[i];
        final name    = e['productName']?.toString() ?? 'Product';
        final viewers = (e['viewerCount'] as num?)?.toInt() ?? 0;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 30, height: 30,
                decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.visibility_rounded, color: AppColors.grey, size: 15),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.white, fontSize: 13, fontWeight: FontWeight.w600))),
              Text('$viewers viewers', style: const TextStyle(color: AppColors.grey, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        );
      },
    );
  }
}

// ── Filter bottom sheet ───────────────────────────────────────────────────────

class _FilterSheet extends StatefulWidget {
  final ProductFilterParams current;
  final List<dynamic> categories;
  final List<dynamic> brands;

  const _FilterSheet({required this.current, required this.categories, required this.brands});

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late ProductFilterParams _draft;
  final _minPriceCtrl = TextEditingController();
  final _maxPriceCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _draft = widget.current;
    if (widget.current.minPrice != null) _minPriceCtrl.text = widget.current.minPrice!.toInt().toString();
    if (widget.current.maxPrice != null) _maxPriceCtrl.text = widget.current.maxPrice!.toInt().toString();
  }

  @override
  void dispose() {
    _minPriceCtrl.dispose();
    _maxPriceCtrl.dispose();
    super.dispose();
  }

  void _apply() {
    final minP = double.tryParse(_minPriceCtrl.text.trim());
    final maxP = double.tryParse(_maxPriceCtrl.text.trim());
    Navigator.pop(context, _draft.copyWith(
      minPrice:     minP,
      maxPrice:     maxP,
      clearMinPrice: minP == null,
      clearMaxPrice: maxP == null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10),
              width: 36, height: 4,
              decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          // Title + reset
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: Row(
              children: [
                const Text('Filters & Sort', style: TextStyle(color: AppColors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                const Spacer(),
                GestureDetector(
                  onTap: () => setState(() {
                    _draft = ProductFilterParams.defaults;
                    _minPriceCtrl.clear();
                    _maxPriceCtrl.clear();
                  }),
                  child: const Text('Reset', style: TextStyle(color: AppColors.error, fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Container(height: 1, color: AppColors.divider),

          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 16, 20, bottom + 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── Sort ────────────────────────────────────────────────
                  _sectionTitle('Sort By'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: ProductSortBy.values.map((s) => _FilterChip(
                      label: _sortLabel(s),
                      selected: _draft.sort == s,
                      onTap: () => setState(() => _draft = _draft.copyWith(sort: s)),
                    )).toList(),
                  ),
                  const SizedBox(height: 20),

                  // ── Status ───────────────────────────────────────────────
                  _sectionTitle('Status'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: [
                      _FilterChip(label: 'All',      selected: _draft.status == ProductStatusFilter.all,      onTap: () => setState(() => _draft = _draft.copyWith(status: ProductStatusFilter.all))),
                      _FilterChip(label: 'Active',   selected: _draft.status == ProductStatusFilter.active,   onTap: () => setState(() => _draft = _draft.copyWith(status: ProductStatusFilter.active)), accent: AppColors.success),
                      _FilterChip(label: 'Inactive', selected: _draft.status == ProductStatusFilter.inactive, onTap: () => setState(() => _draft = _draft.copyWith(status: ProductStatusFilter.inactive)), accent: AppColors.warning),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── Stock ────────────────────────────────────────────────
                  _sectionTitle('Stock Level'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: [
                      _FilterChip(label: 'All',          selected: _draft.stock == ProductStockFilter.all,        onTap: () => setState(() => _draft = _draft.copyWith(stock: ProductStockFilter.all))),
                      _FilterChip(label: 'In Stock',     selected: _draft.stock == ProductStockFilter.inStock,    onTap: () => setState(() => _draft = _draft.copyWith(stock: ProductStockFilter.inStock)),    accent: AppColors.success),
                      _FilterChip(label: 'Low Stock',    selected: _draft.stock == ProductStockFilter.lowStock,   onTap: () => setState(() => _draft = _draft.copyWith(stock: ProductStockFilter.lowStock)),   accent: AppColors.warning),
                      _FilterChip(label: 'Out of Stock', selected: _draft.stock == ProductStockFilter.outOfStock, onTap: () => setState(() => _draft = _draft.copyWith(stock: ProductStockFilter.outOfStock)), accent: AppColors.error),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── Price range ──────────────────────────────────────────
                  _sectionTitle('Price Range (₹)'),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _PriceField(ctrl: _minPriceCtrl, hint: 'Min'),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text('–', style: TextStyle(color: AppColors.grey, fontSize: 16)),
                      ),
                      Expanded(
                        child: _PriceField(ctrl: _maxPriceCtrl, hint: 'Max'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── Category ─────────────────────────────────────────────
                  if (widget.categories.isNotEmpty) ...[
                    Row(
                      children: [
                        _sectionTitle('Category'),
                        if (_draft.categoryId != null) ...[
                          const Spacer(),
                          GestureDetector(
                            onTap: () => setState(() => _draft = _draft.copyWith(clearCategory: true)),
                            child: const Text('Clear', style: TextStyle(color: AppColors.error, fontSize: 12)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: widget.categories.map((cat) {
                        final id   = (cat as Map)['id']?.toString();
                        final name = cat['name'] as String? ?? '';
                        return _FilterChip(
                          label:    name,
                          selected: _draft.categoryId == id,
                          onTap:    () => setState(() => _draft = _draft.categoryId == id
                              ? _draft.copyWith(clearCategory: true)
                              : _draft.copyWith(categoryId: id, categoryName: name)),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ── Brand ────────────────────────────────────────────────
                  if (widget.brands.isNotEmpty) ...[
                    Row(
                      children: [
                        _sectionTitle('Brand'),
                        if (_draft.brandId != null) ...[
                          const Spacer(),
                          GestureDetector(
                            onTap: () => setState(() => _draft = _draft.copyWith(clearBrand: true)),
                            child: const Text('Clear', style: TextStyle(color: AppColors.error, fontSize: 12)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: widget.brands.map((b) {
                        final id   = (b as Map)['id']?.toString();
                        final name = b['name'] as String? ?? '';
                        return _FilterChip(
                          label:    name,
                          selected: _draft.brandId == id,
                          onTap:    () => setState(() => _draft = _draft.brandId == id
                              ? _draft.copyWith(clearBrand: true)
                              : _draft.copyWith(brandId: id, brandName: name)),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                  ],
                ],
              ),
            ),
          ),

          // ── Footer ───────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.divider)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.surface2,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Center(child: Text('Cancel', style: TextStyle(color: AppColors.grey, fontSize: 14, fontWeight: FontWeight.w600))),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: GestureDetector(
                    onTap: _apply,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Center(child: Text('Apply Filters', style: TextStyle(color: AppColors.bg, fontSize: 14, fontWeight: FontWeight.w700))),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String t) => Text(t,
      style: const TextStyle(color: AppColors.white, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.2));
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color accent;

  const _FilterChip({required this.label, required this.selected, required this.onTap, this.accent = AppColors.white});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color:  selected ? accent.withOpacity(0.15) : AppColors.surface2,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? accent : AppColors.border, width: selected ? 1.5 : 1),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? accent : AppColors.grey,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _PriceField extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  const _PriceField({required this.ctrl, required this.hint});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      style: const TextStyle(color: AppColors.white, fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.greyDark, fontSize: 13),
        prefixText: '₹ ',
        prefixStyle: const TextStyle(color: AppColors.grey, fontSize: 13),
        filled: true,
        fillColor: AppColors.surface2,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border:        OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.white, width: 1.5)),
      ),
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorRetry({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.error.withOpacity(0.4)),
              ),
              child: const Icon(Icons.cloud_off_rounded, color: AppColors.error, size: 30),
            ),
            const SizedBox(height: 16),
            const Text('Could not load products',
                style: TextStyle(color: AppColors.white, fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(message, textAlign: TextAlign.center, maxLines: 3, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.grey, fontSize: 12, height: 1.5)),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Retry', style: TextStyle(fontWeight: FontWeight.w700)),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.surface2,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ).animate().fadeIn().scale(begin: const Offset(0.9, 0.9)),
    );
  }
}

class _EmptyProducts extends StatelessWidget {
  final bool hasFilters;
  final VoidCallback onClear;
  const _EmptyProducts({required this.hasFilters, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(Icons.inventory_2_rounded, color: AppColors.greyDark, size: 36),
          ),
          const SizedBox(height: 16),
          Text(
            hasFilters
                ? 'No products match your filters'
                : 'No products yet.\nTap + to add your first product.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.grey, fontSize: 14, height: 1.5),
          ),
          if (hasFilters) ...[
            const SizedBox(height: 16),
            GestureDetector(
              onTap: onClear,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Text('Clear filters', style: TextStyle(color: AppColors.white, fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ],
      ).animate().fadeIn().scale(begin: const Offset(0.9, 0.9)),
    );
  }
}
