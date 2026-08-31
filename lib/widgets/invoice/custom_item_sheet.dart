import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/invoice_draft.dart';
import '../../utils/app_colors.dart';
import '../../utils/haptic_utils.dart';

/// "Add as Custom Item" — for a product that isn't in the seller's Dashly
/// catalog. No catalog price exists to validate against, so this item is
/// never subject to the price-deviation warning.
class CustomItemSheet extends StatefulWidget {
  final String? prefillBarcode;
  const CustomItemSheet({super.key, this.prefillBarcode});

  static Future<InvoiceDraftItem?> show(BuildContext context, {String? prefillBarcode}) {
    return showModalBottomSheet<InvoiceDraftItem?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CustomItemSheet(prefillBarcode: prefillBarcode),
    );
  }

  @override
  State<CustomItemSheet> createState() => _CustomItemSheetState();
}

class _CustomItemSheetState extends State<CustomItemSheet> {
  final _nameCtrl  = TextEditingController();
  final _skuCtrl   = TextEditingController();
  late final TextEditingController _barcodeCtrl;
  final _priceCtrl = TextEditingController();
  final _taxCtrl   = TextEditingController(text: '0');
  int _qty = 1;

  @override
  void initState() {
    super.initState();
    _barcodeCtrl = TextEditingController(text: widget.prefillBarcode ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _skuCtrl.dispose();
    _barcodeCtrl.dispose();
    _priceCtrl.dispose();
    _taxCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameCtrl.text.trim();
    final price = double.tryParse(_priceCtrl.text.trim());
    if (name.isEmpty || price == null || price <= 0) return;
    HapticUtils.medium();
    Navigator.of(context).pop(InvoiceDraftItem(
      id: 'local-${DateTime.now().microsecondsSinceEpoch}',
      type: 'CUSTOM',
      name: name,
      sku: _skuCtrl.text.trim().isEmpty ? null : _skuCtrl.text.trim(),
      barcode: _barcodeCtrl.text.trim().isEmpty ? null : _barcodeCtrl.text.trim(),
      catalogPrice: null,
      unitPrice: price,
      quantity: _qty,
      taxRate: double.tryParse(_taxCtrl.text.trim()) ?? 0,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: EdgeInsets.fromLTRB(20, 16, 20, bottom + 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 36, height: 4,
                decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Add Custom Item', style: TextStyle(color: AppColors.white, fontSize: 17, fontWeight: FontWeight.w800)),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: AppColors.surface2, shape: BoxShape.circle),
                    child: const Icon(Icons.close_rounded, color: AppColors.grey, size: 18),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text("Not in your catalog yet? Bill it anyway.", style: TextStyle(color: AppColors.grey, fontSize: 12)),
            const SizedBox(height: 18),

            _field(
              'Product Name *',
              _nameCtrl,
              hint: 'e.g. Wireless Charger',
              formatters: [FilteringTextInputFormatter.deny(RegExp(r'[\n\t]'))],
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _field(
                'SKU',
                _skuCtrl,
                hint: 'Optional',
                formatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9\-_]'))],
              )),
              const SizedBox(width: 10),
              Expanded(child: _field(
                'Barcode',
                _barcodeCtrl,
                hint: 'Optional',
                keyboard: TextInputType.number,
                formatters: [FilteringTextInputFormatter.digitsOnly],
              )),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _field(
                'Price *',
                _priceCtrl,
                hint: '₹',
                keyboard: const TextInputType.numberWithOptions(decimal: true),
                formatters: [_DecimalInputFormatter(decimalRange: 2)],
              )),
              const SizedBox(width: 10),
              Expanded(child: _field(
                'Tax %',
                _taxCtrl,
                hint: '0',
                keyboard: const TextInputType.numberWithOptions(decimal: true),
                formatters: [_DecimalInputFormatter(decimalRange: 2, maxValue: 100)],
              )),
            ]),
            const SizedBox(height: 14),

            Row(
              children: [
                const Text('Quantity', style: TextStyle(color: AppColors.grey, fontSize: 12, fontWeight: FontWeight.w600)),
                const Spacer(),
                _QtyStepper(qty: _qty, onChanged: (v) => setState(() => _qty = v)),
              ],
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Add Item', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl,
      {String? hint, TextInputType? keyboard, List<TextInputFormatter>? formatters}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.grey, fontSize: 11.5, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          keyboardType: keyboard,
          inputFormatters: formatters,
          style: const TextStyle(color: AppColors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppColors.greyDark, fontSize: 13),
            filled: true,
            fillColor: AppColors.surface2,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }
}

class _QtyStepper extends StatelessWidget {
  final int qty;
  final ValueChanged<int> onChanged;
  const _QtyStepper({required this.qty, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _btn(Icons.remove_rounded, () => onChanged((qty - 1).clamp(1, 9999))),
        SizedBox(width: 32, child: Center(child: Text('$qty', style: const TextStyle(color: AppColors.white, fontSize: 14, fontWeight: FontWeight.w700)))),
        _btn(Icons.add_rounded, () => onChanged((qty + 1).clamp(1, 9999))),
      ],
    );
  }

  Widget _btn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28, height: 28,
        decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 16, color: AppColors.white),
      ),
    );
  }
}

/// Restricts input to a non-negative decimal number with at most
/// [decimalRange] digits after the point, optionally capped at [maxValue].
class _DecimalInputFormatter extends TextInputFormatter {
  final int decimalRange;
  final double? maxValue;
  _DecimalInputFormatter({this.decimalRange = 2, this.maxValue});

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;

    final regExp = RegExp(r'^\d*\.?\d*$');
    if (!regExp.hasMatch(text)) return oldValue;

    final parts = text.split('.');
    if (parts.length > 2) return oldValue;
    if (parts.length == 2 && parts[1].length > decimalRange) return oldValue;

    if (maxValue != null) {
      final value = double.tryParse(text);
      if (value != null && value > maxValue!) return oldValue;
    }

    return newValue;
  }
}
