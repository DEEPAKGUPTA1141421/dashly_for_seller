import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/widgets/app_shimmer.dart';
import '../core/widgets/app_toast.dart';
import '../models/discount_config.dart';
import '../providers/product_variants_provider.dart';
import '../utils/app_colors.dart';
import '../utils/haptic_utils.dart';
import '../widgets/products/discount_editor_sheet.dart';

class ProductVariantsScreen extends ConsumerStatefulWidget {
  final String productId;
  final String productName;

  const ProductVariantsScreen({
    super.key,
    required this.productId,
    required this.productName,
  });

  @override
  ConsumerState<ProductVariantsScreen> createState() => _ProductVariantsScreenState();
}

class _ProductVariantsScreenState extends ConsumerState<ProductVariantsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(productVariantsPod.notifier).fetchVariants(widget.productId),
    );
  }

  Future<void> _refresh() async {
    HapticUtils.light();
    await ref.read(productVariantsPod.notifier).fetchVariants(widget.productId);
  }

  @override
  Widget build(BuildContext context) {
    final state    = ref.watch(productVariantsPod);
    final variants = state.variants;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Variants',
              style: TextStyle(color: AppColors.white, fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.3),
            ),
            Text(
              widget.productName,
              style: const TextStyle(color: AppColors.grey, fontSize: 11, fontWeight: FontWeight.w400),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.divider),
        ),
      ),
      body: state.isLoading
          ? ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: 5,
              itemBuilder: (_, __) => const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: AppShimmer(child: ShimmerBox(height: 80)),
              ),
            )
          : variants.isEmpty
              ? const _EmptyVariants()
              : RefreshIndicator(
                  onRefresh: _refresh,
                  color: AppColors.white,
                  backgroundColor: AppColors.surface,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: variants.length,
                    itemBuilder: (_, i) => _VariantTile(
                      variant: variants[i],
                      index: i,
                      onEdit: () => _showEditSheet(context, variants[i]),
                    ),
                  ),
                ),
    );
  }

  void _showEditSheet(BuildContext context, Map<String, dynamic> variant) {
    HapticUtils.medium();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _VariantEditSheet(
        variant: variant,
        productId: widget.productId,
      ),
    );
  }
}

// ── Variant Tile ──────────────────────────────────────────────────────────────

class _VariantTile extends StatelessWidget {
  final Map<String, dynamic> variant;
  final int index;
  final VoidCallback onEdit;

  const _VariantTile({required this.variant, required this.index, required this.onEdit});

  static String _fmt(double v) => v == v.truncateToDouble() ? v.toInt().toString() : v.toString();

  @override
  Widget build(BuildContext context) {
    final label       = variant['label'] as String? ?? '';
    final sku         = variant['sku']   as String? ?? '';
    final priceRupees = variant['priceRupees'] as String? ?? '0.00';
    final mrpRupees   = variant['mrpRupees']   as String? ?? '0.00';
    final stock       = (variant['stock'] as num?)?.toInt() ?? 0;
    final combination = (variant['combination'] as Map?)?.cast<String, String>() ?? {};
    final discountRaw = variant['discount'] as Map<String, dynamic>?;
    final discount     = discountRaw != null ? DiscountConfig.fromJson(discountRaw) : null;
    final isDiscountLive = discount?.currentlyEffective == true;

    final bool lowStock = stock <= 5;

    return GestureDetector(
      onTap: onEdit,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: lowStock && stock == 0 ? AppColors.error.withOpacity(0.4)
                : lowStock ? AppColors.warning.withOpacity(0.4)
                : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (label.isNotEmpty)
                    Text(
                      label,
                      style: const TextStyle(color: AppColors.white, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  if (combination.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      combination.entries.map((e) => '${e.key}: ${e.value}').join(' · '),
                      style: const TextStyle(color: AppColors.grey, fontSize: 11),
                    ),
                  ],
                  if (sku.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text('SKU: $sku', style: const TextStyle(color: AppColors.greyDark, fontSize: 10)),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        '₹$priceRupees',
                        style: const TextStyle(color: AppColors.white, fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                      if (mrpRupees != priceRupees) ...[
                        const SizedBox(width: 6),
                        Text(
                          '₹$mrpRupees',
                          style: const TextStyle(
                            color: AppColors.greyDark,
                            fontSize: 11,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ],
                      if (isDiscountLive) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.success.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            discount!.type == DiscountType.percentage
                                ? '${_fmt(discount.value)}% OFF'
                                : '₹${_fmt(discount.value)} OFF',
                            style: const TextStyle(color: AppColors.success, fontSize: 10, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: stock == 0
                        ? AppColors.error.withOpacity(0.12)
                        : lowStock
                            ? AppColors.warning.withOpacity(0.12)
                            : AppColors.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    stock == 0 ? 'Out of stock' : '$stock in stock',
                    style: TextStyle(
                      color: stock == 0 ? AppColors.error : lowStock ? AppColors.warning : AppColors.success,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Icon(Icons.edit_rounded, color: AppColors.grey, size: 16),
              ],
            ),
          ],
        ),
      ).animate().fadeIn(delay: Duration(milliseconds: index * 40)).slideX(begin: 0.03, end: 0),
    );
  }
}

// ── Edit sheet ────────────────────────────────────────────────────────────────

class _VariantEditSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> variant;
  final String productId;

  const _VariantEditSheet({required this.variant, required this.productId});

  @override
  ConsumerState<_VariantEditSheet> createState() => _VariantEditSheetState();
}

class _VariantEditSheetState extends ConsumerState<_VariantEditSheet> {
  late final TextEditingController _priceCtrl;
  late final TextEditingController _stockCtrl;

  @override
  void initState() {
    super.initState();
    final priceRupees = widget.variant['priceRupees'] as String? ?? '0.00';
    final stock       = (widget.variant['stock'] as num?)?.toInt() ?? 0;
    _priceCtrl = TextEditingController(text: priceRupees);
    _stockCtrl = TextEditingController(text: stock.toString());
  }

  @override
  void dispose() {
    _priceCtrl.dispose();
    _stockCtrl.dispose();
    super.dispose();
  }

  Future<void> _manageDiscount(DiscountConfig? config) async {
    final variantId = widget.variant['id'] as String? ?? '';
    if (variantId.isEmpty) return;

    HapticUtils.medium();
    final notifier = ref.read(productVariantsPod.notifier);
    final ok = config == null
        ? await notifier.removeVariantDiscount(widget.productId, variantId)
        : await notifier.setVariantDiscount(widget.productId, variantId, config);

    if (!mounted) return;
    if (ok) {
      AppToast.show(context,
          message: config == null ? 'Discount removed' : 'Discount updated',
          type: ToastType.success);
    } else {
      final err = ref.read(productVariantsPod).error ?? 'Failed to update discount';
      AppToast.show(context, message: err, type: ToastType.error);
    }
  }

  Future<void> _save() async {
    final price  = double.tryParse(_priceCtrl.text.trim());
    final stock  = int.tryParse(_stockCtrl.text.trim());

    if (price == null || price < 0) {
      AppToast.show(context, message: 'Enter a valid price', type: ToastType.error);
      return;
    }
    if (stock == null || stock < 0) {
      AppToast.show(context, message: 'Enter a valid stock quantity', type: ToastType.error);
      return;
    }

    HapticUtils.medium();
    final priceInPaise = (price * 100).round();
    final variantId    = widget.variant['id'] as String? ?? '';

    final ok = await ref.read(productVariantsPod.notifier).updateVariant(
      widget.productId,
      variantId,
      priceInPaise: priceInPaise,
      stock: stock,
    );

    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
      AppToast.show(context, message: 'Variant updated', type: ToastType.success);
    } else {
      final err = ref.read(productVariantsPod).error ?? 'Failed to update variant';
      AppToast.show(context, message: err, type: ToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state  = ref.watch(productVariantsPod);
    final label  = widget.variant['label'] as String? ?? 'Variant';

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              label.isNotEmpty ? 'Edit "$label"' : 'Edit Variant',
              style: const TextStyle(color: AppColors.white, fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 20),
            _Field(label: 'Price (₹)', controller: _priceCtrl, hint: '0.00', isDecimal: true),
            const SizedBox(height: 14),
            _Field(label: 'Stock',     controller: _stockCtrl, hint: '0'),
            const SizedBox(height: 20),
            const Text('DISCOUNT', style: TextStyle(color: AppColors.grey, fontSize: 11, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            DiscountSummaryTile(
              title: 'Manage discount',
              discount: widget.variant['discount'] is Map<String, dynamic>
                  ? DiscountConfig.fromJson(widget.variant['discount'] as Map<String, dynamic>)
                  : null,
              mrp: double.tryParse(widget.variant['mrpRupees'] as String? ?? ''),
              onChanged: _manageDiscount,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: state.isSubmitting ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.white,
                  foregroundColor: AppColors.bg,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: state.isSubmitting
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.bg),
                      )
                    : const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final bool isDecimal;

  const _Field({
    required this.label,
    required this.controller,
    required this.hint,
    this.isDecimal = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.grey, fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: isDecimal
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.number,
          inputFormatters: isDecimal
              ? [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))]
              : [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(color: AppColors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppColors.greyDark, fontSize: 14),
            filled: true,
            fillColor: AppColors.surface2,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.white, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyVariants extends StatelessWidget {
  const _EmptyVariants();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(Icons.tune_rounded, color: AppColors.greyDark, size: 32),
          ),
          const SizedBox(height: 14),
          const Text(
            'No variants for this product',
            style: TextStyle(color: AppColors.grey, fontSize: 14),
          ),
        ],
      ).animate().fadeIn().scale(begin: const Offset(0.9, 0.9)),
    );
  }
}
