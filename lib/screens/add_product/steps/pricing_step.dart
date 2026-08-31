import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../models/discount_config.dart';
import '../../../providers/add_product_provider.dart';
import '../../../utils/app_colors.dart';
import '../../../widgets/products/discount_editor_sheet.dart';

class PricingStep extends ConsumerStatefulWidget {
  const PricingStep({super.key});

  @override
  ConsumerState<PricingStep> createState() => _PricingStepState();
}

class _PricingStepState extends ConsumerState<PricingStep> {
  final _priceCtrl = TextEditingController();
  final _mrpCtrl   = TextEditingController();
  final _stockCtrl = TextEditingController();
  final _skuCtrl   = TextEditingController();
  final _formKey   = GlobalKey<FormState>();

  String _weight = '100g';
  static const _weights = ['50g', '100g', '250g', '500g', '1kg', '2kg', '5kg', 'Custom'];

  DiscountConfig? _discountConfig;

  @override
  void initState() {
    super.initState();
    final s      = ref.read(addProductPod);
    _priceCtrl.text = s.price;
    _mrpCtrl.text   = s.mrp;
    _stockCtrl.text = s.stock;
    _skuCtrl.text   = s.sku;
    _weight         = s.weight.isNotEmpty ? s.weight : '100g';
    _discountConfig = s.discount;
  }

  @override
  void dispose() {
    _priceCtrl.dispose();
    _mrpCtrl.dispose();
    _stockCtrl.dispose();
    _skuCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (!_formKey.currentState!.validate()) return;
    ref.read(addProductPod.notifier).savePricing(
      price:    _priceCtrl.text.trim(),
      mrp:      _mrpCtrl.text.trim(),
      stock:    _stockCtrl.text.trim(),
      sku:      _skuCtrl.text.trim(),
      weight:   _weight,
      discount: _discountConfig,
    );
  }

  double? get _discount {
    final price = double.tryParse(_priceCtrl.text);
    final mrp   = double.tryParse(_mrpCtrl.text);
    if (price != null && mrp != null && mrp > 0 && price < mrp) {
      return ((mrp - price) / mrp * 100);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final disc = _discount;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Set your price, stock and shipping weight.',
              style: TextStyle(color: AppColors.grey, fontSize: 14),
            ).animate().fadeIn(),

            const SizedBox(height: 24),

            // Price + MRP row
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    hint: '0', label: 'SELLING PRICE',
                    controller: _priceCtrl,
                    keyboardType: TextInputType.number,
                    prefix: '₹ ',
                    onChanged: (_) => setState(() {}),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      if (double.tryParse(v) == null) return 'Invalid';
                      return null;
                    },
                  ).animate().fadeIn(delay: 60.ms),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppTextField(
                    hint: '0', label: 'MRP',
                    controller: _mrpCtrl,
                    keyboardType: TextInputType.number,
                    prefix: '₹ ',
                    onChanged: (_) => setState(() {}),
                  ).animate().fadeIn(delay: 100.ms),
                ),
              ],
            ),

            // Discount badge
            if (disc != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.success.withOpacity(0.3)),
                    ),
                    child: Text(
                      '${disc.toStringAsFixed(0)}% off for buyers',
                      style: const TextStyle(color: AppColors.success, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 16),

            const Text('DISCOUNT',
                style: TextStyle(color: AppColors.grey, fontSize: 13, fontWeight: FontWeight.w500))
                .animate().fadeIn(delay: 110.ms),
            const SizedBox(height: 10),
            DiscountSummaryTile(
              title: 'Discount configuration',
              discount: _discountConfig,
              mrp: double.tryParse(_mrpCtrl.text),
              onChanged: (d) => setState(() => _discountConfig = d),
            ).animate().fadeIn(delay: 120.ms),

            const SizedBox(height: 16),

            AppTextField(
              hint: '0', label: 'STOCK QUANTITY',
              controller: _stockCtrl,
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                if (int.tryParse(v) == null) return 'Invalid';
                return null;
              },
            ).animate().fadeIn(delay: 140.ms),

            const SizedBox(height: 16),

            AppTextField(
              hint: 'e.g. SKU-001 (optional)', label: 'SKU / MODEL NO.',
              controller: _skuCtrl,
            ).animate().fadeIn(delay: 180.ms),

            const SizedBox(height: 20),

            const Text('SHIPPING WEIGHT',
                style: TextStyle(color: AppColors.grey, fontSize: 13, fontWeight: FontWeight.w500))
                .animate().fadeIn(delay: 200.ms),
            const SizedBox(height: 10),

            Wrap(
              spacing: 8, runSpacing: 8,
              children: _weights.map((w) {
                final sel = _weight == w;
                return GestureDetector(
                  onTap: () => setState(() => _weight = w),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: sel ? AppColors.white : AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: sel ? AppColors.white : AppColors.border),
                    ),
                    child: Text(
                      w,
                      style: TextStyle(
                        color: sel ? AppColors.bg : AppColors.grey,
                        fontSize: 12, fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ).animate().fadeIn(delay: 220.ms),

            const SizedBox(height: 40),

            AppButton(
              label: 'Continue',
              onTap: _next,
              icon: Icons.arrow_forward_rounded,
            ).animate().fadeIn(delay: 260.ms),
          ],
        ),
      ),
    );
  }
}
