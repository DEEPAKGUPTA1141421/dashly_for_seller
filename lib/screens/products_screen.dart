import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/widgets/app_shimmer.dart';
import '../core/widgets/app_toast.dart';
import '../core/widgets/confirm_modal.dart';
import '../providers/products_provider.dart';
import '../utils/app_colors.dart';
import '../utils/haptic_utils.dart';
import '../widgets/product_edit_sheet.dart';
import 'add_product/catalog_search_screen.dart';
import 'add_product_screen.dart';
import 'product_variants_screen.dart';

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  ProductFilterParams _filters = ProductFilterParams.defaults;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(productsPod.notifier).fetchProducts());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
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
        brands:     state.brands,
      ),
    );
    if (result != null) {
      setState(() => _filters = result);
      // Re-fetch from server when server-side filters change
      final needsRefetch = result.categoryId != _filters.categoryId ||
          result.brandId != _filters.brandId ||
          result.minPrice != _filters.minPrice ||
          result.maxPrice != _filters.maxPrice;
      if (needsRefetch) {
        await ref.read(productsPod.notifier).fetchProducts(filters: result);
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
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
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

            const SizedBox(height: 16),

            // ── Low-stock banner ──────────────────────────────────────────
            if (lowStockCount > 0 && _filters.stock != ProductStockFilter.lowStock)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _query = v),
                style: const TextStyle(color: AppColors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search by name, brand, category…',
                  hintStyle: const TextStyle(color: AppColors.greyDark, fontSize: 14),
                  prefixIcon: const Icon(Icons.search_rounded, color: AppColors.grey, size: 20),
                  suffixIcon: _query.isNotEmpty
                      ? GestureDetector(
                          onTap: () { setState(() { _query = ''; _searchCtrl.clear(); }); },
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
            if (_filters.hasActiveFilters) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 30,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
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
              child: state.isLoading
                  ? ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: 8,
                      itemBuilder: (_, __) => const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: ProductCardShimmer(),
                      ),
                    )
                  : state.error != null && products.isEmpty
                      ? _ErrorRetry(
                          message: state.error!,
                          onRetry: () => ref.read(productsPod.notifier).fetchProducts(),
                        )
                      : products.isEmpty
                          ? _EmptyProducts(
                              hasFilters: activeFilterCount > 0,
                              onClear: () => setState(() {
                                _filters = ProductFilterParams.defaults;
                                _query   = '';
                                _searchCtrl.clear();
                              }),
                            )
                          : RefreshIndicator(
                              onRefresh: () async {
                                HapticUtils.light();
                                await ref.read(productsPod.notifier).fetchProducts(filters: _filters);
                              },
                              color: AppColors.white,
                              backgroundColor: AppColors.surface,
                              child: ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                itemCount: products.length,
                                itemBuilder: (_, i) => _ProductTile(
                                  product: products[i] as Map,
                                  index: i,
                                  onEdit: () => ProductEditSheet.show(context, products[i] as Map),
                                  onManageVariants: () {
                                    HapticUtils.light();
                                    Navigator.push(context, MaterialPageRoute(
                                      builder: (_) => ProductVariantsScreen(
                                        productId:   products[i]['id']   as String? ?? '',
                                        productName: products[i]['name'] as String? ?? 'Product',
                                      ),
                                    ));
                                  },
                                  onStockIncrease: () {
                                    HapticUtils.light();
                                    final id        = products[i]['id'] as String? ?? '';
                                    final variantId = products[i]['variantId']?.toString() ?? '';
                                    final stock     = _stockOf(products[i]);
                                    ref.read(productsPod.notifier).updateVariant(id, variantId, stock: stock + 1);
                                  },
                                  onStockDecrease: () {
                                    HapticUtils.light();
                                    final id        = products[i]['id'] as String? ?? '';
                                    final variantId = products[i]['variantId']?.toString() ?? '';
                                    final stock     = _stockOf(products[i]);
                                    if (stock <= 0) return;
                                    ref.read(productsPod.notifier).updateVariant(id, variantId, stock: stock - 1);
                                  },
                                  onDelete: () async {
                                    HapticUtils.medium();
                                    final confirmed = await showConfirmModal(
                                      context,
                                      title: 'Delete Product',
                                      message: 'This will permanently remove the product. Orders linked to it will not be affected.',
                                      confirmLabel: 'Delete',
                                      destructive: true,
                                    );
                                    if (!confirmed || !context.mounted) return;
                                    final ok = await ref.read(productsPod.notifier).deleteProduct(products[i]['id'] as String? ?? '');
                                    if (!context.mounted) return;
                                    AppToast.show(context,
                                      message: ok ? 'Product deleted' : (ref.read(productsPod).error ?? 'Cannot delete product'),
                                      type: ok ? ToastType.success : ToastType.error,
                                    );
                                  },
                                  onToggleActive: () async {
                                    HapticUtils.light();
                                    final id       = products[i]['id'] as String? ?? '';
                                    final isActive = products[i]['isActive'] as bool? ?? true;
                                    final ok = await ref.read(productsPod.notifier).toggleActive(id);
                                    if (!context.mounted) return;
                                    if (ok) {
                                      AppToast.show(context,
                                        message: isActive ? 'Product deactivated' : 'Product activated',
                                        type: ToastType.success,
                                      );
                                    } else {
                                      AppToast.show(context,
                                        message: ref.read(productsPod).error ?? 'Could not update product',
                                        type: ToastType.error,
                                      );
                                    }
                                  },
                                ),
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
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

// ── Product tile ──────────────────────────────────────────────────────────────

class _ProductTile extends StatelessWidget {
  final Map product;
  final int index;
  final VoidCallback onEdit;
  final VoidCallback onManageVariants;
  final VoidCallback onStockIncrease;
  final VoidCallback onStockDecrease;
  final VoidCallback onDelete;
  final VoidCallback onToggleActive;

  const _ProductTile({
    required this.product,
    required this.index,
    required this.onEdit,
    required this.onManageVariants,
    required this.onStockIncrease,
    required this.onStockDecrease,
    required this.onDelete,
    required this.onToggleActive,
  });

  @override
  Widget build(BuildContext context) {
    final name     = product['name'] as String? ?? 'Product';
    final priceRaw = product['price'];
    final priceNum = priceRaw is num
        ? priceRaw.toDouble()
        : double.tryParse(priceRaw?.toString() ?? '') ?? 0.0;
    final priceStr = priceNum == priceNum.truncateToDouble()
        ? priceNum.toInt().toString()
        : priceNum.toStringAsFixed(2);
    final stockRaw = product['stock'];
    final stock    = stockRaw is num
        ? stockRaw.toInt()
        : int.tryParse(stockRaw?.toString() ?? '') ?? 0;
    final imageUrl  = product['imageUrl'] as String? ?? '';
    final isActive  = product['isActive'] as bool? ?? true;
    final brand     = product['brand']        as String?;
    final category  = product['categoryName'] as String?;
    final discount  = product['discountPercent'] as num?;
    final rating    = product['rating'] as num?;
    final subtitle  = [if (brand != null) brand, if (category != null) category].join(' · ');

    final stockColor = stock > 10
        ? AppColors.success
        : stock > 0
            ? AppColors.warning
            : AppColors.error;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 44, height: 44,
                  color: AppColors.surface2,
                  child: imageUrl.isNotEmpty
                      ? Image.network(imageUrl, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(Icons.image_rounded, color: AppColors.greyDark, size: 18))
                      : const Icon(Icons.inventory_2_rounded, color: AppColors.greyDark, size: 18),
                ),
              ),
              const SizedBox(width: 12),
              // Name + subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                    if (subtitle.isNotEmpty)
                      Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.grey, fontSize: 11)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Price + discount
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('₹$priceStr', style: const TextStyle(color: AppColors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                  if (discount != null && discount > 0)
                    Text('${discount.toInt()}% off', style: const TextStyle(color: AppColors.success, fontSize: 10, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(width: 6),
              // Status dot
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(
                  color: !isActive ? AppColors.greyDark : stock > 0 ? AppColors.success : AppColors.error,
                  shape: BoxShape.circle,
                ),
              ),
              PopupMenuButton<String>(
                color: AppColors.surface2,
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.more_vert_rounded, color: AppColors.grey, size: 18),
                onSelected: (v) {
                  if (v == 'edit')     onEdit();
                  if (v == 'variants') onManageVariants();
                  if (v == 'delete')   onDelete();
                  if (v == 'toggle')   onToggleActive();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit',     child: Text('Edit',            style: TextStyle(color: AppColors.white))),
                  const PopupMenuItem(value: 'variants', child: Text('Manage Variants', style: TextStyle(color: AppColors.white))),
                  PopupMenuItem(
                    value: 'toggle',
                    child: Text(
                      isActive ? 'Deactivate' : 'Activate',
                      style: TextStyle(color: isActive ? AppColors.warning : AppColors.success),
                    ),
                  ),
                  const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: AppColors.error))),
                ],
              ),
            ],
          ),

          // Stock controls + rating
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                const SizedBox(width: 56),
                Icon(Icons.inventory_2_outlined, color: stockColor, size: 12),
                const SizedBox(width: 4),
                Text('$stock in stock', style: TextStyle(color: stockColor, fontSize: 11, fontWeight: FontWeight.w600)),
                if (rating != null && rating > 0) ...[
                  const SizedBox(width: 10),
                  const Icon(Icons.star_rounded, color: AppColors.warning, size: 11),
                  const SizedBox(width: 2),
                  Text(rating.toStringAsFixed(1), style: const TextStyle(color: AppColors.grey, fontSize: 11)),
                ],
                const Spacer(),
                _StockButton(icon: Icons.remove, onTap: onStockDecrease, enabled: stock > 0),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text('$stock', style: const TextStyle(color: AppColors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                ),
                _StockButton(icon: Icons.add, onTap: onStockIncrease, enabled: true),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: index * 40)).slideX(begin: 0.03, end: 0);
  }
}

class _StockButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;
  const _StockButton({required this.icon, required this.onTap, required this.enabled});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 26, height: 26,
        decoration: BoxDecoration(
          color: enabled ? AppColors.surface2 : AppColors.surface2.withOpacity(0.4),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(icon, size: 14, color: enabled ? AppColors.white : AppColors.greyDark),
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
