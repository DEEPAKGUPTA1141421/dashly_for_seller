import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/app_button.dart';
import '../../../providers/add_product_provider.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/haptic_utils.dart';

class VariantsStep extends ConsumerStatefulWidget {
  const VariantsStep({super.key});

  @override
  ConsumerState<VariantsStep> createState() => _VariantsStepState();
}

class _VariantsStepState extends ConsumerState<VariantsStep> {
  bool _showForm = false;

  // Mini-form controllers
  final _colorCtrl = TextEditingController();
  final _sizeCtrl  = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _stockCtrl = TextEditingController();

  @override
  void dispose() {
    _colorCtrl.dispose();
    _sizeCtrl.dispose();
    _priceCtrl.dispose();
    _stockCtrl.dispose();
    super.dispose();
  }

  void _addVariant() {
    if (_sizeCtrl.text.trim().isEmpty && _colorCtrl.text.trim().isEmpty) return;
    final variant = <String, dynamic>{
      if (_colorCtrl.text.trim().isNotEmpty) 'color': _colorCtrl.text.trim(),
      if (_sizeCtrl.text.trim().isNotEmpty)  'size':  _sizeCtrl.text.trim(),
      'price': double.tryParse(_priceCtrl.text) ?? 0,
      'stock': int.tryParse(_stockCtrl.text)    ?? 0,
    };
    ref.read(addProductPod.notifier).addVariant(variant);
    _colorCtrl.clear();
    _sizeCtrl.clear();
    _priceCtrl.clear();
    _stockCtrl.clear();
    setState(() => _showForm = false);
    HapticUtils.light();
  }

  @override
  Widget build(BuildContext context) {
    final variants = ref.watch(addProductPod).variants;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Add size/color variants with individual pricing and stock.',
                  style: TextStyle(color: AppColors.grey, fontSize: 14),
                ).animate().fadeIn(),

                const SizedBox(height: 20),

                // Variant list
                ...variants.asMap().entries.map((e) {
                  final v     = e.value;
                  final color = v['color'] as String?;
                  final size  = v['size']  as String?;
                  final price = v['price'];
                  final stock = v['stock'];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Wrap(
                            spacing: 8, runSpacing: 6,
                            children: [
                              if (color != null)
                                _Chip(label: '🎨 $color'),
                              if (size != null)
                                _Chip(label: '📐 $size'),
                              _Chip(label: '₹$price'),
                              _Chip(label: '${stock}pc'),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: AppColors.error, size: 18),
                          onPressed: () {
                            HapticUtils.light();
                            ref.read(addProductPod.notifier).removeVariant(e.key);
                          },
                        ),
                      ],
                    ),
                  ).animate(delay: Duration(milliseconds: e.key * 40))
                      .fadeIn().slideX(begin: 0.04, end: 0);
                }),

                // Add variant form
                if (_showForm)
                  Container(
                    margin: const EdgeInsets.only(top: 4, bottom: 10),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface2,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.white.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('NEW VARIANT',
                            style: TextStyle(color: AppColors.grey, fontSize: 11, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: _MiniField(ctrl: _colorCtrl, hint: 'Color', icon: Icons.palette_rounded)),
                            const SizedBox(width: 10),
                            Expanded(child: _MiniField(ctrl: _sizeCtrl, hint: 'Size', icon: Icons.straighten_rounded)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(child: _MiniField(ctrl: _priceCtrl, hint: '₹ Price', icon: Icons.currency_rupee_rounded, numeric: true)),
                            const SizedBox(width: 10),
                            Expanded(child: _MiniField(ctrl: _stockCtrl, hint: 'Stock', icon: Icons.inventory_2_rounded, numeric: true)),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => setState(() => _showForm = false),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: AppColors.border),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: const Text('Cancel', style: TextStyle(color: AppColors.grey)),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _addVariant,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: const Text('Add', style: TextStyle(color: AppColors.bg, fontWeight: FontWeight.w700)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ).animate().fadeIn().scale(begin: const Offset(0.97, 0.97)),

                if (!_showForm)
                  GestureDetector(
                    onTap: () {
                      HapticUtils.light();
                      setState(() => _showForm = true);
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_rounded, color: AppColors.grey, size: 18),
                          SizedBox(width: 6),
                          Text('Add Variant', style: TextStyle(color: AppColors.grey, fontSize: 13)),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(),
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
            label: variants.isEmpty ? 'Skip Variants' : 'Continue with ${variants.length} variant${variants.length > 1 ? 's' : ''}',
            onTap: () => ref.read(addProductPod.notifier).advanceFromVariants(),
            icon: Icons.arrow_forward_rounded,
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  const _Chip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(label, style: const TextStyle(color: AppColors.white, fontSize: 12)),
    );
  }
}

class _MiniField extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  final IconData icon;
  final bool numeric;

  const _MiniField({
    required this.ctrl, required this.hint, required this.icon, this.numeric = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      keyboardType: numeric ? TextInputType.number : TextInputType.text,
      style: const TextStyle(color: AppColors.white, fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.greyDark, fontSize: 13),
        prefixIcon: Icon(icon, color: AppColors.grey, size: 16),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
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
    );
  }
}
