import 'package:flutter/material.dart';
import '../../screens/refund_requests_screen.dart';
import '../../utils/app_colors.dart';
import '../../utils/haptic_utils.dart';

/// "Refund requests" summary card with a button to the full Refund Requests
/// screen. Lives on the Earnings tab of the Invoices page.
class RefundRequestsCard extends StatelessWidget {
  final Map<String, dynamic> summary;
  const RefundRequestsCard({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final open = (summary['openCount'] as num?)?.toInt() ?? 0;
    final fresh = (summary['newCount'] as num?)?.toInt() ?? 0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Refund requests', style: TextStyle(color: AppColors.white, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(color: AppColors.warning.withOpacity(0.15), shape: BoxShape.circle),
                child: const Icon(Icons.shopping_bag_rounded, color: AppColors.warning, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    style: const TextStyle(color: AppColors.grey, fontSize: 12.5, height: 1.5),
                    children: [
                      const TextSpan(text: 'You have '),
                      TextSpan(text: '$open open refund requests', style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.w700)),
                      const TextSpan(text: ' to action. This includes '),
                      TextSpan(text: '$fresh new requests', style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.w700)),
                      const TextSpan(text: '.'),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                HapticUtils.light();
                Navigator.push(context, MaterialPageRoute(builder: (_) => const RefundRequestsScreen()));
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.border),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Review refund requests', style: TextStyle(color: AppColors.white, fontSize: 13, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}
