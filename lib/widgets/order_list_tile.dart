import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/widgets/status_badge.dart';
import '../utils/app_colors.dart';
import '../utils/haptic_utils.dart';

class OrderListTile extends StatelessWidget {
  final Map order;
  final VoidCallback? onTap;

  const OrderListTile({super.key, required this.order, this.onTap});

  @override
  Widget build(BuildContext context) {
    final status       = order['status'] as String? ?? 'INITIATED';
    final bookingId    = (order['bookingId'] ?? '').toString();
    final shortId      = bookingId.length > 8 ? '#${bookingId.substring(0, 8).toUpperCase()}' : '#$bookingId';
    final amountStr    = order['totalAmountRupees'] as String? ?? '0.00';
    final itemCount    = (order['itemCount'] as num?)?.toInt() ?? 0;
    final payMode      = order['paymentMode'] as String? ?? '';
    final createdAt    = order['createdAt'] as String? ?? '';
    final imageUrl     = order['firstItemImageUrl'] as String?;
    final firstName    = order['firstItemName'] as String?;

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
            _ProductThumb(imageUrl: imageUrl),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    shortId,
                    style: const TextStyle(color: AppColors.white, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  if (firstName != null && firstName.isNotEmpty)
                    Text(
                      firstName,
                      style: const TextStyle(color: AppColors.white, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 2),
                  Text(
                    '$itemCount item${itemCount != 1 ? 's' : ''}${payMode.isNotEmpty ? ' · $payMode' : ''}',
                    style: const TextStyle(color: AppColors.grey, fontSize: 11),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₹$amountStr',
                  style: const TextStyle(color: AppColors.white, fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                StatusBadge.fromString(status, small: true),
                if (createdAt.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    _relativeTime(createdAt),
                    style: const TextStyle(color: AppColors.greyDark, fontSize: 10),
                  ),
                ],
              ],
            ),
          ],
        ),
      ).animate().fadeIn().slideX(begin: 0.03, end: 0),
    );
  }

  static String _relativeTime(String iso) {
    try {
      final dt   = DateTime.parse(iso).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours   < 24) return '${diff.inHours}h ago';
      if (diff.inDays    <  7) return '${diff.inDays}d ago';
      const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${dt.day} ${months[dt.month - 1]}';
    } catch (_) {
      return '';
    }
  }
}

class _ProductThumb extends StatelessWidget {
  final String? imageUrl;
  const _ProductThumb({this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: imageUrl != null && imageUrl!.isNotEmpty
          ? Image.network(
              imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.shopping_bag_rounded, color: AppColors.grey, size: 22),
            )
          : const Icon(Icons.shopping_bag_rounded, color: AppColors.grey, size: 22),
    );
  }
}
