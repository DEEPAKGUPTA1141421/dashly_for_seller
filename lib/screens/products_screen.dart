import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/widgets/app_shimmer.dart';
import '../core/widgets/app_toast.dart';
import '../core/widgets/confirm_modal.dart';
import '../providers/products_provider.dart';
import '../utils/app_colors.dart';
import '../utils/haptic_utils.dart';
import '../widgets/quick_edit_sheet.dart';
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
  bool _showLowStockOnly = false;

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

  @override
  Widget build(BuildContext context) {
    final state    = ref.watch(productsPod);
    final products = state.products.where((p) {
      final name = (p['name'] as String? ?? '').toLowerCase();
      final matchesQuery = name.contains(_query.toLowerCase());
      final matchesFilter = !_showLowStockOnly || ((p['stock'] as int? ?? 0) <= 5 && (p['isActive'] as bool? ?? true));
      return matchesQuery && matchesFilter;
    }).toList();
    final lowStockCount = state.products
        .where((p) => (p['stock'] as int? ?? 0) <= 5 && (p['isActive'] as bool? ?? true))
        .length;

    return Scaffold(
      backgroundColor: AppColors.bg,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          HapticUtils.medium();
          Navigator.push(context, _slideRoute(const AddProductScreen()));
        },
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.bg,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Product', style: TextStyle(fontWeight: FontWeight.w700)),
      ).animate().slideY(begin: 1, end: 0, delay: 300.ms, curve: Curves.easeOut),
      body: SafeArea(
        child: Column(
          children: [
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
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Low-stock warning (tappable — toggles low-stock filter)
            if (lowStockCount > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: GestureDetector(
                  onTap: () {
                    HapticUtils.light();
                    setState(() => _showLowStockOnly = !_showLowStockOnly);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: _showLowStockOnly
                          ? AppColors.warning.withOpacity(0.18)
                          : AppColors.warning.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.warning.withOpacity(_showLowStockOnly ? 0.7 : 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _showLowStockOnly
                                ? 'Showing $lowStockCount low-stock product${lowStockCount > 1 ? 's' : ''} — tap to clear'
                                : '$lowStockCount product${lowStockCount > 1 ? 's are' : ' is'} low on stock (≤5 units) — tap to filter',
                            style: const TextStyle(color: AppColors.warning, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Search bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _query = v),
                style: const TextStyle(color: AppColors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search products…',
                  hintStyle: const TextStyle(color: AppColors.greyDark, fontSize: 14),
                  prefixIcon: const Icon(Icons.search_rounded, color: AppColors.grey, size: 20),
                  filled: true,
                  fillColor: AppColors.surface,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.white, width: 1.5),
                  ),
                ),
              ),
            ).animate().fadeIn(delay: 80.ms),

            const SizedBox(height: 16),

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
                  : products.isEmpty
                      ? _EmptyProducts(hasSearch: _query.isNotEmpty)
                      : RefreshIndicator(
                          onRefresh: () async {
                            HapticUtils.light();
                            await ref.read(productsPod.notifier).fetchProducts();
                          },
                          color: AppColors.white,
                          backgroundColor: AppColors.surface,
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: products.length,
                            itemBuilder: (_, i) => _ProductTile(
                              product: products[i] as Map,
                              index: i,
                              onEdit: () => QuickEditSheet.show(context, products[i] as Map),
                              onManageVariants: () {
                                HapticUtils.light();
                                final id   = products[i]['id']   as String? ?? '';
                                final name = products[i]['name'] as String? ?? 'Product';
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ProductVariantsScreen(
                                      productId:   id,
                                      productName: name,
                                    ),
                                  ),
                                );
                              },
                              onStockIncrease: () {
                                HapticUtils.light();
                                final id    = products[i]['id']    as String? ?? '';
                                final stock = (products[i]['stock'] as int? ?? 0);
                                ref.read(productsPod.notifier).quickUpdate(id, stock: stock + 1);
                              },
                              onStockDecrease: () {
                                HapticUtils.light();
                                final id    = products[i]['id']    as String? ?? '';
                                final stock = (products[i]['stock'] as int? ?? 0);
                                if (stock <= 0) return;
                                ref.read(productsPod.notifier).quickUpdate(id, stock: stock - 1);
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
                                final id = products[i]['id'] as String? ?? '';
                                final ok = await ref.read(productsPod.notifier).deleteProduct(id);
                                if (!context.mounted) return;
                                if (ok) {
                                  AppToast.show(context, message: 'Product deleted', type: ToastType.success);
                                } else {
                                  final err = ref.read(productsPod).error ?? 'Cannot delete product';
                                  AppToast.show(context, message: err, type: ToastType.error);
                                }
                              },
                              onToggleActive: () async {
                                HapticUtils.light();
                                final id       = products[i]['id'] as String? ?? '';
                                final isActive = products[i]['isActive'] as bool? ?? true;
                                final ok = await ref.read(productsPod.notifier).toggleActive(id);
                                if (!context.mounted) return;
                                if (ok) {
                                  AppToast.show(
                                    context,
                                    message: isActive ? 'Product deactivated' : 'Product activated',
                                    type: ToastType.success,
                                  );
                                } else {
                                  final err = ref.read(productsPod).error ?? 'Could not update product';
                                  AppToast.show(context, message: err, type: ToastType.error);
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

  PageRoute<dynamic> _slideRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (_, anim, __) => page,
      transitionsBuilder: (_, anim, __, child) => SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
            .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: child,
      ),
    );
  }
}

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
    final price    = product['price'] as num? ?? 0;
    final stock    = product['stock'] as int? ?? 0;
    final imageUrl = product['imageUrl'] as String? ?? '';
    final isActive = product['isActive'] as bool? ?? true;

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
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 40,
                  height: 40,
                  color: AppColors.surface2,
                  child: imageUrl.isNotEmpty
                      ? Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.image_rounded, color: AppColors.greyDark, size: 18))
                      : const Icon(Icons.inventory_2_rounded, color: AppColors.greyDark, size: 18),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.white, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 10),
              Text('₹$price', style: const TextStyle(color: AppColors.white, fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(width: 10),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: !isActive ? AppColors.warning : stock > 0 ? AppColors.success : AppColors.error,
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
              const PopupMenuItem(value: 'edit',     child: Text('Edit', style: TextStyle(color: AppColors.white))),
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
          // Stock ±1 controls
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                const SizedBox(width: 52), // align with name column
                Icon(Icons.inventory_2_outlined, color: stockColor, size: 12),
                const SizedBox(width: 4),
                Text(
                  '$stock in stock',
                  style: TextStyle(color: stockColor, fontSize: 11, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                _StockButton(icon: Icons.remove, onTap: onStockDecrease, enabled: stock > 0),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    '$stock',
                    style: const TextStyle(color: AppColors.white, fontSize: 12, fontWeight: FontWeight.w700),
                  ),
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
        width: 26,
        height: 26,
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

class _EmptyProducts extends StatelessWidget {
  final bool hasSearch;
  const _EmptyProducts({required this.hasSearch});

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
            hasSearch ? 'No products match your search' : 'No products yet.\nTap + to add your first product.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.grey, fontSize: 14, height: 1.5),
          ),
        ],
      ).animate().fadeIn().scale(begin: const Offset(0.9, 0.9)),
    );
  }
}
