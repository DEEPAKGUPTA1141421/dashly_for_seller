import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../utils/app_colors.dart';
import '../utils/haptic_utils.dart';

class OrderListTile extends StatelessWidget {
  final Map order;
  final VoidCallback? onTap;

  const OrderListTile({super.key, required this.order, this.onTap});

  @override
  Widget build(BuildContext context) {
    final status   = order['status'] as String? ?? 'PENDING';
    final orderId  = order['orderId'] as String? ?? '#----';
    final amount   = order['amount'] as num? ?? 0;
    final customer = order['customerName'] as String? ?? 'Customer';
    final items    = order['itemCount'] as int? ?? 0;

    final (statusColor, statusBg) = _statusColors(status);

    return GestureDetector(
      onTap: () {
        HapticUtils.light();
        onTap?.call();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            // Order icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.shopping_bag_rounded, color: AppColors.grey, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    orderId,
                    style: const TextStyle(color: AppColors.white, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$customer · $items item${items != 1 ? 's' : ''}',
                    style: const TextStyle(color: AppColors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₹$amount',
                  style: const TextStyle(color: AppColors.white, fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
        ),
      ).animate().fadeIn().slideX(begin: 0.03, end: 0),
    );
  }

  (Color, Color) _statusColors(String status) {
    switch (status.toUpperCase()) {
      case 'DELIVERED':  return (AppColors.success, AppColors.success.withOpacity(0.12));
      case 'SHIPPED':    return (AppColors.info,    AppColors.info.withOpacity(0.12));
      case 'PROCESSING': return (AppColors.warning, AppColors.warning.withOpacity(0.12));
      case 'CANCELLED':  return (AppColors.error,   AppColors.error.withOpacity(0.12));
      default:           return (AppColors.grey,    AppColors.surface2);
    }
  }
}
