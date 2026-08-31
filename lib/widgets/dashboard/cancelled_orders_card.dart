import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../utils/app_colors.dart';
import '../../utils/haptic_utils.dart';

class CancelledOrdersCard extends StatelessWidget {
  final Map<String, dynamic> statusCounts;
  final VoidCallback onTap;

  const CancelledOrdersCard({super.key, required this.statusCounts, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cancelled = (statusCounts['CANCELLED'] as num?)?.toInt() ?? 0;
    final reversed  = (statusCounts['REVERSED'] as num?)?.toInt() ?? 0;
    final total     = cancelled + reversed;

    return GestureDetector(
      onTap: () { HapticUtils.light(); onTap(); },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Cancelled & refunded orders',
                style: TextStyle(color: AppColors.white, fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: AppColors.warning.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.assignment_return_outlined, color: AppColors.warning, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: total == 0
                      ? const Text('No cancelled or refunded orders', style: TextStyle(color: AppColors.grey, fontSize: 13))
                      : Text.rich(
                          TextSpan(
                            style: const TextStyle(color: AppColors.grey, fontSize: 13),
                            children: [
                              TextSpan(text: 'You have $total order${total == 1 ? '' : 's'}',
                                  style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.w700)),
                              const TextSpan(text: ' cancelled or refunded.'),
                            ],
                          ),
                        ),
                ),
              ],
            ),
            if (total > 0) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () { HapticUtils.light(); onTap(); },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Review orders',
                      style: TextStyle(color: AppColors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ],
        ),
      ),
    ).animate().fadeIn();
  }
}
