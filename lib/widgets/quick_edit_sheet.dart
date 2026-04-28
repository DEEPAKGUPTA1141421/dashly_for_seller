import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/widgets/app_toast.dart';
import '../providers/products_provider.dart';
import '../utils/app_colors.dart';

class QuickEditSheet extends ConsumerStatefulWidget {
  final Map product;
  const QuickEditSheet({super.key, required this.product});

  static Future<bool> show(BuildContext context, Map product) async {
    return await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => QuickEditSheet(product: product),
        ) ??
        false;
  }

  @override
  ConsumerState<QuickEditSheet> createState() => _QuickEditSheetState();
}

class _QuickEditSheetState extends ConsumerState<QuickEditSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _stockCtrl;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameCtrl  = TextEditingController(text: p['name']  as String? ?? '');
    // price from API is already in rupees for display
    final priceRaw = p['price'];
    _priceCtrl = TextEditingController(text: priceRaw != null ? '$priceRaw' : '');
    _stockCtrl = TextEditingController(text: '${p['stock'] ?? 0}');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _stockCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final id    = widget.product['id'] as String? ?? '';
    final name  = _nameCtrl.text.trim();
    final price = double.tryParse(_priceCtrl.text.trim());
    final stock = int.tryParse(_stockCtrl.text.trim());

    // Convert rupees → paise for the API
    final priceInPaise = price != null ? (price * 100).round() : null;

    final ok = await ref.read(productsPod.notifier).quickUpdate(
      id,
      name:         name.isNotEmpty ? name : null,
      priceInPaise: priceInPaise,
      stock:        stock,
    );

    if (!mounted) return;
    if (ok) {
      AppToast.show(context, message: 'Product updated', type: ToastType.success);
      Navigator.of(context).pop(true);
    } else {
      final err = ref.read(productsPod).error ?? 'Update failed';
      AppToast.show(context, message: err, type: ToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSubmitting = ref.watch(productsPod).isSubmitting;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottom),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            const Text(
              'Quick Edit',
              style: TextStyle(color: AppColors.white, fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 20),

            _Field(label: 'Product Name', controller: _nameCtrl, hint: 'Enter product name'),
            const SizedBox(height: 14),
            _Field(
              label: 'Price (₹)',
              controller: _priceCtrl,
              hint: 'e.g. 299',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
              validator: (v) {
                if (v == null || v.isEmpty) return null;
                if (double.tryParse(v) == null) return 'Enter a valid price';
                return null;
              },
            ),
            const SizedBox(height: 14),
            _Field(
              label: 'Stock',
              controller: _stockCtrl,
              hint: 'e.g. 50',
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (v) {
                if (v == null || v.isEmpty) return null;
                if (int.tryParse(v) == null) return 'Enter a valid number';
                return null;
              },
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.white,
                  disabledBackgroundColor: AppColors.surface2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: isSubmitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.bg))
                    : const Text('Save Changes', style: TextStyle(color: AppColors.bg, fontWeight: FontWeight.w700, fontSize: 15)),
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
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;

  const _Field({
    required this.label,
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.inputFormatters,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.grey, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          validator: validator,
          style: const TextStyle(color: AppColors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppColors.greyDark, fontSize: 14),
            filled: true,
            fillColor: AppColors.bg,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.error),
            ),
          ),
        ),
      ],
    );
  }
}
