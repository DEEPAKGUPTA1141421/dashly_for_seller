import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';

class InvoiceListTile extends StatelessWidget {
  final Map invoice;
  final VoidCallback onTap;

  const InvoiceListTile({super.key, required this.invoice, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final number   = invoice['invoiceNumber'] as String? ?? 'DRAFT';
    final customer = invoice['customerName'] as String?;
    final total    = (invoice['totalRupees'] as num?)?.toDouble() ?? 0;
    final status   = (invoice['status'] as String? ?? 'DRAFT').toUpperCase();
    final channel  = invoice['lastDeliveryChannel'] as String?;
    final createdAt = invoice['createdAt'] as String?;

    return GestureDetector(
      onTap: onTap,
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
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.receipt_long_rounded, color: AppColors.grey, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(number, style: const TextStyle(color: AppColors.white, fontSize: 13.5, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(
                    customer ?? 'No customer',
                    style: const TextStyle(color: AppColors.grey, fontSize: 12),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                  if (channel != null || createdAt != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (channel != null) 'Sent via ${_channelLabel(channel)}',
                        if (createdAt != null) _formatDate(createdAt),
                      ].join(' · '),
                      style: const TextStyle(color: AppColors.greyDark, fontSize: 11),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('₹${total.toStringAsFixed(0)}',
                    style: const TextStyle(color: AppColors.white, fontSize: 14, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                _StatusChip(status: status),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _channelLabel(String c) => c == 'WHATSAPP' ? 'WhatsApp' : 'Email';

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      if (dt.year == now.year && dt.month == now.month && dt.day == now.day) return 'Today';
      final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${dt.day} ${months[dt.month - 1]}';
    } catch (_) {
      return '';
    }
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  Color get _color => switch (status) {
        'DRAFT' => AppColors.greyDark,
        'FINALIZED' => AppColors.info,
        'SENT' => AppColors.info,
        'VIEWED' => AppColors.info,
        'PAID' => AppColors.success,
        'PARTIALLY_PAID' => AppColors.warning,
        'OVERDUE' => AppColors.error,
        'CANCELLED' => AppColors.error,
        _ => AppColors.grey,
      };

  String get _label => switch (status) {
        'PARTIALLY_PAID' => 'Partial',
        _ => status[0] + status.substring(1).toLowerCase(),
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: _color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
      child: Text(_label, style: TextStyle(color: _color, fontSize: 10.5, fontWeight: FontWeight.w700)),
    );
  }
}
