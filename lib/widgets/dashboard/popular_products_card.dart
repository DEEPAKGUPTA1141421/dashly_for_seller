import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/widgets/empty_state.dart';
import '../../utils/app_colors.dart';

class PopularProductsCard extends StatelessWidget {
  final List<dynamic> topProducts;
  final VoidCallback? onSeeAll;

  const PopularProductsCard({super.key, required this.topProducts, this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Popular products',
              style: TextStyle(color: AppColors.white, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          if (topProducts.isNotEmpty) ...[
            const Row(
              children: [
                Expanded(child: Text('Products', style: TextStyle(color: AppColors.grey, fontSize: 11))),
                Text('Earning', style: TextStyle(color: AppColors.grey, fontSize: 11)),
              ],
            ),
            const SizedBox(height: 6),
            const Divider(height: 1, color: AppColors.border),
          ],
          const SizedBox(height: 4),
          if (topProducts.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: EmptyState(
                icon: Icons.inventory_2_outlined,
                title: 'No sales yet',
                subtitle: 'Products will show up here once they start selling',
              ),
            )
          else
            ...topProducts.map((p) => _ProductRow(product: p as Map)),
          if (onSeeAll != null && topProducts.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onSeeAll,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.border),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('All products',
                    style: TextStyle(color: AppColors.white, fontSize: 13, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ],
      ),
    ).animate().fadeIn();
  }
}

class _ProductRow extends StatelessWidget {
  final Map product;
  const _ProductRow({required this.product});

  @override
  Widget build(BuildContext context) {
    final name    = product['productName'] as String? ?? 'Unknown';
    final image   = product['productImageUrl'] as String?;
    final revenue = product['revenueRupees'] as String? ?? '0.00';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(8)),
            clipBehavior: Clip.antiAlias,
            child: image != null && image.isNotEmpty
                ? Image.network(image, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(Icons.shopping_bag_rounded, color: AppColors.grey, size: 18))
                : const Icon(Icons.shopping_bag_rounded, color: AppColors.grey, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.white, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 8),
          Text('₹$revenue', style: const TextStyle(color: AppColors.white, fontSize: 13, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
