import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/widgets/empty_state.dart';
import '../../utils/app_colors.dart';

class CommentsCard extends StatelessWidget {
  final List<dynamic> reviews;
  final VoidCallback? onViewAll;

  const CommentsCard({super.key, required this.reviews, this.onViewAll});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Comments',
              style: TextStyle(color: AppColors.white, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          if (reviews.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: EmptyState(
                icon: Icons.chat_bubble_outline_rounded,
                title: 'No reviews yet',
                subtitle: 'Customer reviews on your products will appear here',
              ),
            )
          else
            ...reviews.map((r) => _CommentTile(review: r as Map)),
          if (onViewAll != null && reviews.isNotEmpty) ...[
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onViewAll,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.border),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('View all',
                    style: TextStyle(color: AppColors.white, fontSize: 13, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ],
      ),
    ).animate().fadeIn();
  }
}

class _CommentTile extends StatelessWidget {
  final Map review;
  const _CommentTile({required this.review});

  @override
  Widget build(BuildContext context) {
    final reviewer    = review['reviewerName'] as String? ?? 'Anonymous';
    final productName = review['productName'] as String? ?? 'Product';
    final body         = review['review'] as String? ?? '';
    final createdAt    = review['createdAt'] as String? ?? '';
    final initials     = reviewer.trim().isNotEmpty ? reviewer.trim()[0].toUpperCase() : '?';

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.surface2,
            child: Text(initials, style: const TextStyle(color: AppColors.white, fontSize: 13, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(reviewer, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 6),
                    Text(_formatDate(createdAt), style: const TextStyle(color: AppColors.greyDark, fontSize: 10)),
                  ],
                ),
                const SizedBox(height: 1),
                Text.rich(
                  TextSpan(
                    style: const TextStyle(color: AppColors.grey, fontSize: 12),
                    children: [
                      const TextSpan(text: 'On '),
                      TextSpan(text: productName, style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (body.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(body, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.white, fontSize: 12)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${months[dt.month - 1]} ${dt.day}';
    } catch (_) {
      return '';
    }
  }
}
