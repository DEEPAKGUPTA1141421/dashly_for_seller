import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/widgets/app_shimmer.dart';
import '../providers/products_provider.dart';
import '../utils/app_colors.dart';
import '../utils/haptic_utils.dart';
import 'add_product_screen.dart';

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

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
      return name.contains(_query.toLowerCase());
    }).toList();

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
                              onDelete: () async {
                                HapticUtils.medium();
                                final id = products[i]['_id'] as String? ?? '';
                                await ref.read(productsPod.notifier).deleteProduct(id);
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
  final VoidCallback onDelete;

  const _ProductTile({required this.product, required this.index, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final name     = product['name'] as String? ?? 'Product';
    final price    = product['price'] as num? ?? 0;
    final stock    = product['stock'] as int? ?? 0;
    final imageUrl = product['imageUrl'] as String? ?? '';
    final isActive = product['isActive'] as bool? ?? true;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
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
              if (v == 'delete') onDelete();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit',   child: Text('Edit',   style: TextStyle(color: AppColors.white))),
              const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: AppColors.error))),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: index * 40)).slideX(begin: 0.03, end: 0);
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
