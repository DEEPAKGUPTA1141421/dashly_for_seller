import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../utils/app_colors.dart';

class AppShimmer extends StatelessWidget {
  final Widget child;

  const AppShimmer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor:  AppColors.surface2,
      highlightColor: AppColors.surface3,
      child: child,
    );
  }
}

class ShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ShimmerBox({
    super.key,
    this.width = double.infinity,
    required this.height,
    this.borderRadius = 10,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

// Stat card shimmer
class StatCardShimmer extends StatelessWidget {
  const StatCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: Container(
        height: 110,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const ShimmerBox(width: 80, height: 14),
                ShimmerBox(width: 32, height: 32, borderRadius: 8),
              ],
            ),
            const SizedBox(height: 12),
            const ShimmerBox(width: 100, height: 22),
            const SizedBox(height: 6),
            const ShimmerBox(width: 60, height: 12),
          ],
        ),
      ),
    );
  }
}

// Order list item shimmer
class OrderItemShimmer extends StatelessWidget {
  const OrderItemShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            ShimmerBox(width: 48, height: 48, borderRadius: 10),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  ShimmerBox(width: double.infinity, height: 14),
                  SizedBox(height: 8),
                  ShimmerBox(width: 120, height: 12),
                  SizedBox(height: 6),
                  ShimmerBox(width: 80, height: 12),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const ShimmerBox(width: 60, height: 24, borderRadius: 20),
          ],
        ),
      ),
    );
  }
}

// Mobile product list-card shimmer — mirrors ProductListCard's exact shape
// (56×56 thumb, name + price + subtitle, then a 4-up stat row) so the loading
// state doesn't jump-cut into a different layout once data arrives.
class ProductListRowShimmer extends StatelessWidget {
  const ProductListRowShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ShimmerBox(width: 56, height: 56, borderRadius: 10),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      ShimmerBox(width: double.infinity, height: 14),
                      SizedBox(height: 6),
                      ShimmerBox(width: 70, height: 13),
                      SizedBox(height: 6),
                      ShimmerBox(width: 100, height: 11),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: const [
                Expanded(child: ShimmerBox(width: 40, height: 20, borderRadius: 20)),
                Expanded(child: ShimmerBox(width: 24, height: 12)),
                Expanded(child: ShimmerBox(width: 24, height: 12)),
                Expanded(child: ShimmerBox(width: 24, height: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Desktop/tablet table-row shimmer — mirrors ProductTableRow's column widths
// (checkbox / product / status / price / sales / views / likes) so the table
// keeps its shape while the first page of results is loading.
class ProductTableRowShimmer extends StatelessWidget {
  const ProductTableRowShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.divider)),
        ),
        child: Row(
          children: [
            const SizedBox(width: 36, child: ShimmerBox(width: 18, height: 18, borderRadius: 4)),
            Expanded(
              flex: 4,
              child: Row(
                children: [
                  const ShimmerBox(width: 40, height: 40, borderRadius: 8),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        ShimmerBox(width: double.infinity, height: 12),
                        SizedBox(height: 6),
                        ShimmerBox(width: 70, height: 10),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Expanded(flex: 2, child: ShimmerBox(width: 50, height: 18, borderRadius: 20)),
            const Expanded(flex: 2, child: ShimmerBox(width: 40, height: 12)),
            const Expanded(flex: 2, child: ShimmerBox(width: 24, height: 12)),
            const Expanded(flex: 2, child: ShimmerBox(width: 24, height: 12)),
            const Expanded(flex: 2, child: ShimmerBox(width: 24, height: 12)),
            const SizedBox(width: 40),
          ],
        ),
      ),
    );
  }
}
