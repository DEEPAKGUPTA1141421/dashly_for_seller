import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';

/// "Did you miss a zero?" confirmation — shown when an invoice line's entered
/// price deviates a lot (≥50% and ≥₹100) from the catalog price. This is
/// advisory, never a hard block: the seller can always confirm and continue
/// (legitimate discounts/markups exist), but a fat-fingered price shouldn't
/// silently go out on an invoice.
Future<bool> showPriceWarningDialog(
  BuildContext context, {
  required double catalogPrice,
  required double enteredPrice,
}) async {
  final higher = enteredPrice > catalogPrice;
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    higher ? 'Price looks much higher than catalog' : 'Price looks significantly lower than catalog',
                    style: const TextStyle(color: AppColors.white, fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _row('Catalog price', catalogPrice),
            const SizedBox(height: 4),
            _row('Entered price', enteredPrice),
            const SizedBox(height: 12),
            Text(
              higher
                  ? 'Double-check this isn\'t an extra digit.'
                  : 'Did you miss a zero?',
              style: const TextStyle(color: AppColors.grey, fontSize: 12.5),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.white,
                      side: const BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Go Back & Edit'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Continue Anyway'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  return result ?? false;
}

Widget _row(String label, double value) {
  return Row(
    children: [
      Text(label, style: const TextStyle(color: AppColors.grey, fontSize: 13)),
      const Spacer(),
      Text('₹${value.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.white, fontSize: 13, fontWeight: FontWeight.w700)),
    ],
  );
}
