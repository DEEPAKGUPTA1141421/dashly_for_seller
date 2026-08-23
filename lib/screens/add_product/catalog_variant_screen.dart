import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/catalog_listing_provider.dart';
import '../../models/catalog_product.dart';
import '../../utils/app_colors.dart';
import '../../utils/haptic_utils.dart';

class CatalogVariantScreen extends ConsumerWidget {
  const CatalogVariantScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(catalogListingPod);
    final notifier = ref.read(catalogListingPod.notifier);
    final product = state.selectedProduct!;

    // Navigate away on success
    ref.listen<CatalogListingState>(catalogListingPod, (_, next) {
      if (next.successProductId != null) {
        _showSuccessSheet(context, ref, next, product.name);
      }
    });

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Add Your Listing',
          style: TextStyle(color: AppColors.white, fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.3),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.divider),
        ),
      ),

      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              children: [
                // ── Product preview ─────────────────────────────────────────
                _ProductPreviewCard(product: product),
                const SizedBox(height: 20),

                // ── Section header ──────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Your Variants',
                      style: TextStyle(
                        color: AppColors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${state.variants.length} / 20',
                      style: const TextStyle(color: AppColors.grey, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Set your price and stock for each variant. '
                  'Leave Label blank if you only have one type.',
                  style: TextStyle(color: AppColors.grey, fontSize: 12, height: 1.4),
                ),
                const SizedBox(height: 12),

                // ── Variant cards ───────────────────────────────────────────
                ...state.variants.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final v   = entry.value;
                  return _VariantCard(
                    key: ValueKey(v.localId),
                    variant: v,
                    index: idx,
                    canRemove: state.variants.length > 1,
                    onRemove: () {
                      HapticUtils.light();
                      notifier.removeVariant(v.localId);
                    },
                    onLabelChanged: (s) => notifier.updateVariantLabel(v.localId, s),
                    onPriceChanged: (s) => notifier.updateVariantPrice(v.localId, s),
                    onMrpChanged:   (s) => notifier.updateVariantMrp(v.localId, s),
                    onStockChanged: (s) => notifier.updateVariantStock(v.localId, s),
                    onSkuChanged:   (s) => notifier.updateVariantSku(v.localId, s),
                  );
                }),

                const SizedBox(height: 8),

                // ── Add variant button ──────────────────────────────────────
                if (state.variants.length < 20)
                  OutlinedButton.icon(
                    onPressed: () {
                      HapticUtils.light();
                      notifier.addVariant();
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Another Variant'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.white,
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),

                if (state.error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.error.withOpacity(0.3)),
                    ),
                    child: Text(
                      state.error!,
                      style: const TextStyle(color: AppColors.error, fontSize: 13),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),

      // ── Sticky bottom action ──────────────────────────────────────────────
      bottomNavigationBar: _BottomBar(
        isValid: state.allVariantsValid,
        isCreating: state.isCreating,
        onTap: () async {
          HapticUtils.medium();
          await notifier.createListing();
        },
      ),
    );
  }

  void _showSuccessSheet(
      BuildContext context, WidgetRef ref, CatalogListingState state, String productName) {
    showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Green check
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: AppColors.success,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                CupertinoIcons.checkmark_alt,
                color: Colors.white,
                size: 36,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Product Listed!',
              style: TextStyle(
                color: AppColors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$productName is now live and visible to buyers.',
              style: const TextStyle(
                color: AppColors.grey,
                fontSize: 14,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.white,
                  foregroundColor: AppColors.bg,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  // Pop the bottom sheet + both catalog screens → back to products list
                  Navigator.popUntil(
                    context,
                    (route) => route.isFirst || route.settings.name == '/home',
                  );
                },
                child: const Text(
                  'Done',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                Navigator.pop(context); // close success sheet
                ref.read(catalogListingPod.notifier).reset();
                Navigator.pop(context); // back to catalog search
              },
              child: const Text(
                'List another product',
                style: TextStyle(color: AppColors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Product preview card ──────────────────────────────────────────────────────

class _ProductPreviewCard extends StatelessWidget {
  final CatalogProduct product;
  const _ProductPreviewCard({required this.product});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // Image
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            clipBehavior: Clip.hardEdge,
            child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                ? Image.network(
                    product.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const Icon(CupertinoIcons.photo, color: AppColors.greyDark),
                  )
                : const Icon(CupertinoIcons.photo, color: AppColors.greyDark, size: 28),
          ),
          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Catalog Product',
                    style: TextStyle(
                      color: AppColors.success,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  product.name,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (product.brandName != null) ...[
                      Text(product.brandName!,
                          style: const TextStyle(color: AppColors.grey, fontSize: 12)),
                      const Text(' · ',
                          style: TextStyle(color: AppColors.greyDark, fontSize: 12)),
                    ],
                    if (product.categoryName != null)
                      Flexible(
                        child: Text(product.categoryName!,
                            style: const TextStyle(color: AppColors.grey, fontSize: 12),
                            overflow: TextOverflow.ellipsis),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Variant card ──────────────────────────────────────────────────────────────

class _VariantCard extends StatelessWidget {
  final CatalogVariantEntry variant;
  final int index;
  final bool canRemove;
  final VoidCallback onRemove;
  final ValueChanged<String> onLabelChanged;
  final ValueChanged<String> onPriceChanged;
  final ValueChanged<String> onMrpChanged;
  final ValueChanged<String> onStockChanged;
  final ValueChanged<String> onSkuChanged;

  const _VariantCard({
    super.key,
    required this.variant,
    required this.index,
    required this.canRemove,
    required this.onRemove,
    required this.onLabelChanged,
    required this.onPriceChanged,
    required this.onMrpChanged,
    required this.onStockChanged,
    required this.onSkuChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isComplete = variant.isValid;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isComplete ? AppColors.success.withOpacity(0.4) : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 0),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isComplete
                        ? AppColors.success
                        : AppColors.surface2,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: isComplete
                        ? const Icon(CupertinoIcons.checkmark, color: Colors.white, size: 12)
                        : Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: AppColors.grey,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Variant',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (canRemove)
                  IconButton(
                    onPressed: onRemove,
                    icon: const Icon(CupertinoIcons.trash, color: AppColors.error, size: 16),
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(),
                    splashRadius: 20,
                  ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
            child: Column(
              children: [
                // Label (optional)
                _Field(
                  label: 'Label (optional)',
                  hint: 'e.g. 64GB Black, Large Blue',
                  initialValue: variant.label,
                  onChanged: onLabelChanged,
                  inputType: TextInputType.text,
                ),
                const SizedBox(height: 10),

                // Price + MRP row
                Row(
                  children: [
                    Expanded(
                      child: _Field(
                        label: 'Sell Price ₹ *',
                        hint: '0.00',
                        initialValue: variant.price,
                        onChanged: onPriceChanged,
                        inputType: const TextInputType.numberWithOptions(decimal: true),
                        formatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                        ],
                        isError: variant.price.isNotEmpty &&
                            (double.tryParse(variant.price) == null ||
                                double.tryParse(variant.price)! <= 0),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _Field(
                        label: 'MRP ₹',
                        hint: '0.00',
                        initialValue: variant.mrp,
                        onChanged: onMrpChanged,
                        inputType: const TextInputType.numberWithOptions(decimal: true),
                        formatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Stock
                _Field(
                  label: 'Stock Quantity *',
                  hint: '0',
                  initialValue: variant.stock,
                  onChanged: onStockChanged,
                  inputType: TextInputType.number,
                  formatters: [FilteringTextInputFormatter.digitsOnly],
                  isError: variant.stock.isNotEmpty && int.tryParse(variant.stock) == null,
                ),
                const SizedBox(height: 10),

                // SKU (optional)
                _Field(
                  label: 'SKU / Barcode (optional)',
                  hint: 'Leave blank to auto-generate',
                  initialValue: variant.sku,
                  onChanged: onSkuChanged,
                  inputType: TextInputType.text,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Single field ──────────────────────────────────────────────────────────────

class _Field extends StatefulWidget {
  final String label;
  final String hint;
  final String initialValue;
  final ValueChanged<String> onChanged;
  final TextInputType inputType;
  final List<TextInputFormatter> formatters;
  final bool isError;

  const _Field({
    required this.label,
    required this.hint,
    required this.initialValue,
    required this.onChanged,
    this.inputType = TextInputType.text,
    this.formatters = const [],
    this.isError = false,
  });

  @override
  State<_Field> createState() => _FieldState();
}

class _FieldState extends State<_Field> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: const TextStyle(
            color: AppColors.grey,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: _ctrl,
          onChanged: widget.onChanged,
          keyboardType: widget.inputType,
          inputFormatters: widget.formatters,
          style: const TextStyle(color: AppColors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: const TextStyle(color: AppColors.greyDark, fontSize: 13),
            filled: true,
            fillColor: AppColors.surface2,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: widget.isError ? AppColors.error : AppColors.border,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: widget.isError ? AppColors.error : AppColors.border,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: widget.isError ? AppColors.error : AppColors.white,
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Bottom action bar ─────────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  final bool isValid;
  final bool isCreating;
  final VoidCallback onTap;

  const _BottomBar({
    required this.isValid,
    required this.isCreating,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        color: AppColors.bg,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SizedBox(
        height: 52,
        child: ElevatedButton(
          onPressed: (isValid && !isCreating) ? onTap : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.white,
            disabledBackgroundColor: AppColors.surface2,
            foregroundColor: AppColors.bg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: isCreating
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppColors.bg,
                  ),
                )
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(CupertinoIcons.rocket, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'List Product Now',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
