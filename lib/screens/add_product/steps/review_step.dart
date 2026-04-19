import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/app_button.dart';
import '../../../providers/add_product_provider.dart';
import '../../../providers/products_provider.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/haptic_utils.dart';

class ReviewStep extends ConsumerWidget {
  const ReviewStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s       = ref.watch(addProductPod);
    final loading = s.isSubmitting;

    Future<void> publish() async {
      HapticUtils.medium();
      final ok = await ref.read(addProductPod.notifier).publishProduct();
      if (!context.mounted) return;
      if (ok) {
        HapticUtils.success();
        ref.read(productsPod.notifier).fetchProducts();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 16),
                SizedBox(width: 8),
                Text('Product is now live!', style: TextStyle(color: Colors.white)),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      } else {
        HapticUtils.heavy();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s.error ?? 'Failed to publish', style: const TextStyle(color: Colors.white)),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Review everything before going live.',
                  style: TextStyle(color: AppColors.grey, fontSize: 14),
                ).animate().fadeIn(),

                const SizedBox(height: 20),

                // ── Cover image preview ───────────────────────────────────────
                if (s.imagePaths.isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.file(
                      File(s.imagePaths.first),
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ).animate().fadeIn(),
                  if (s.imagePaths.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(top: 6, bottom: 4),
                      child: Text(
                        '+${s.imagePaths.length - 1} more photo${s.imagePaths.length > 2 ? 's' : ''}',
                        style: const TextStyle(color: AppColors.grey, fontSize: 12),
                      ),
                    ),
                  const SizedBox(height: 16),
                ],

                // ── Summary cards ─────────────────────────────────────────────
                _Section(title: 'PRODUCT', children: [
                  _Row('Category', s.categoryName ?? '-'),
                  _Row('Name',     s.productName.isNotEmpty ? s.productName : '-'),
                  _Row('Description', s.description.isNotEmpty
                      ? (s.description.length > 80
                          ? '${s.description.substring(0, 80)}…'
                          : s.description)
                      : '-'),
                ]),

                _Section(title: 'PRICING', children: [
                  _Row('Selling Price', s.price.isNotEmpty ? '₹${s.price}' : '-'),
                  _Row('MRP',           s.mrp.isNotEmpty   ? '₹${s.mrp}'   : '-'),
                  _Row('Stock',         s.stock.isNotEmpty ? s.stock        : '-'),
                  if (s.sku.isNotEmpty) _Row('SKU', s.sku),
                  _Row('Weight', s.weight),
                ]),

                if (s.attributeValues.isNotEmpty)
                  _Section(title: 'ATTRIBUTES', children: s.attributeValues.entries
                      .map((e) => _Row(e.key, e.value)).toList()),

                if (s.variants.isNotEmpty)
                  _Section(title: 'VARIANTS (${s.variants.length})', children: [
                    _Row('Items', s.variants.map((v) {
                      final parts = <String>[];
                      if (v['color'] != null) parts.add(v['color']);
                      if (v['size']  != null) parts.add(v['size']);
                      return parts.join(' / ');
                    }).join(', ')),
                  ]),

                if (s.brandName != null || s.tags.isNotEmpty)
                  _Section(title: 'BRAND & TAGS', children: [
                    if (s.brandName != null) _Row('Brand', s.brandName!),
                    if (s.tags.isNotEmpty)   _Row('Tags', s.tags.map((t) => '#$t').join(' ')),
                  ]),

                // ── Go-live notice ─────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.success.withOpacity(0.25)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.rocket_launch_rounded, color: AppColors.success, size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Your product will be visible to buyers immediately after publishing.',
                          style: TextStyle(color: AppColors.success, fontSize: 12, height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 300.ms),

                if (s.error != null) ...[
                  const SizedBox(height: 12),
                  Text(s.error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
                ],
              ],
            ),
          ),
        ),

        Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: AppButton(
            label: 'Publish Product',
            onTap: publish,
            isLoading: loading,
            icon: Icons.rocket_launch_rounded,
          ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                color: AppColors.grey, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(children: children),
        ),
        const SizedBox(height: 16),
      ],
    ).animate().fadeIn().slideY(begin: 0.03, end: 0);
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: const TextStyle(color: AppColors.grey, fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    color: AppColors.white, fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
