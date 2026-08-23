import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/widgets/app_shimmer.dart';
import '../providers/reviews_provider.dart';
import '../utils/app_colors.dart';
import '../utils/haptic_utils.dart';

class ReviewsScreen extends ConsumerStatefulWidget {
  const ReviewsScreen({super.key});

  @override
  ConsumerState<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends ConsumerState<ReviewsScreen> {
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    Future.microtask(() async {
      await ref.read(reviewsPod.notifier).fetchSummary();
      await ref.read(reviewsPod.notifier).fetchReviews(refresh: true);
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 200) {
      ref.read(reviewsPod.notifier).fetchReviews();
    }
  }

  Future<void> _refresh() async {
    HapticUtils.light();
    await ref.read(reviewsPod.notifier).fetchSummary();
    await ref.read(reviewsPod.notifier).fetchReviews(refresh: true);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reviewsPod);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Customer Reviews',
          style: TextStyle(color: AppColors.white, fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.3),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.divider),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: AppColors.white,
        backgroundColor: AppColors.surface,
        child: CustomScrollView(
          controller: _scrollCtrl,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Summary card
            if (state.summary.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: _SummaryCard(summary: state.summary)
                      .animate().fadeIn().slideY(begin: -0.05, end: 0),
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // Section heading
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    const Text(
                      'All Reviews',
                      style: TextStyle(color: AppColors.white, fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    if (!state.isLoading && state.summary['totalCount'] != null)
                      Text(
                        '${state.summary['totalCount']}',
                        style: const TextStyle(color: AppColors.grey, fontSize: 13),
                      ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 12)),

            // Review list
            if (state.isLoading)
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => const Padding(
                    padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: AppShimmer(child: ShimmerBox(height: 110)),
                  ),
                  childCount: 6,
                ),
              )
            else if (state.reviews.isEmpty)
              const SliverFillRemaining(
                child: Center(
                  child: Text('No reviews yet', style: TextStyle(color: AppColors.grey, fontSize: 14)),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) {
                    if (i == state.reviews.length) {
                      return state.isLoadingMore
                          ? const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(child: SizedBox(
                                width: 20, height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.grey),
                              )),
                            )
                          : const SizedBox(height: 32);
                    }
                    final r = state.reviews[i] as Map;
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                      child: _ReviewCard(review: r, index: i),
                    );
                  },
                  childCount: state.reviews.length + 1,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Summary card ──────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final Map<String, dynamic> summary;
  const _SummaryCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final avg   = (summary['avgRating'] as num?)?.toDouble() ?? 0.0;
    final count = (summary['totalCount'] as num?)?.toInt() ?? 0;
    final dist  = summary['distribution'] as Map? ?? {};

    final maxCount = dist.values
        .map((v) => (v as num?)?.toInt() ?? 0)
        .fold<int>(1, (a, b) => b > a ? b : a);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Big avg + stars
          Column(
            children: [
              Text(
                avg.toStringAsFixed(1),
                style: const TextStyle(color: AppColors.white, fontSize: 42, fontWeight: FontWeight.w800),
              ),
              _StarRow(rating: avg, size: 14),
              const SizedBox(height: 4),
              Text(
                '$count review${count != 1 ? 's' : ''}',
                style: const TextStyle(color: AppColors.grey, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(width: 24),
          // Distribution bars
          Expanded(
            child: Column(
              children: [5, 4, 3, 2, 1].map((star) {
                final cnt = (dist[star.toString()] as num?)?.toInt() ?? 0;
                final pct = maxCount > 0 ? cnt / maxCount : 0.0;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.5),
                  child: Row(
                    children: [
                      Text('$star', style: const TextStyle(color: AppColors.grey, fontSize: 10)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: pct,
                            backgroundColor: AppColors.surface2,
                            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.warning),
                            minHeight: 6,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      SizedBox(
                        width: 22,
                        child: Text('$cnt', style: const TextStyle(color: AppColors.greyDark, fontSize: 10)),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Review card ───────────────────────────────────────────────────────────────

class _ReviewCard extends StatelessWidget {
  final Map review;
  final int index;
  const _ReviewCard({required this.review, required this.index});

  @override
  Widget build(BuildContext context) {
    final rating       = (review['rating'] as num?)?.toInt() ?? 0;
    final title        = (review['title'] as String?) ?? '';
    final body         = (review['review'] as String?) ?? '';
    final productName  = (review['productName'] as String?) ?? 'Product';
    final reviewerName = (review['reviewerName'] as String?) ?? 'Anonymous';
    final verified     = review['verifiedPurchase'] as bool? ?? false;
    final createdAt    = review['createdAt'] as String? ?? '';
    final initials     = reviewerName.trim().isNotEmpty
        ? reviewerName.trim()[0].toUpperCase()
        : '?';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product chip + date
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  productName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.grey, fontSize: 10, fontWeight: FontWeight.w600),
                ),
              ),
              const Spacer(),
              Text(_formatDate(createdAt), style: const TextStyle(color: AppColors.greyDark, fontSize: 10)),
            ],
          ),
          const SizedBox(height: 10),
          // Reviewer row
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: AppColors.surface2,
                child: Text(initials, style: const TextStyle(color: AppColors.white, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(reviewerName, style: const TextStyle(color: AppColors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                        if (verified) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.success.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('Verified', style: TextStyle(color: AppColors.success, fontSize: 9, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    _StarRow(rating: rating.toDouble(), size: 11),
                  ],
                ),
              ),
            ],
          ),
          if (title.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(color: AppColors.white, fontSize: 13, fontWeight: FontWeight.w700)),
          ],
          if (body.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              body,
              style: const TextStyle(color: AppColors.grey, fontSize: 12, height: 1.5),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: index * 30)).slideY(begin: 0.03, end: 0);
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return '';
    }
  }
}

// ── Shared star row ───────────────────────────────────────────────────────────

class _StarRow extends StatelessWidget {
  final double rating;
  final double size;
  const _StarRow({required this.rating, required this.size});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final filled = i < rating.floor();
        final half   = !filled && i < rating;
        return Icon(
          half ? Icons.star_half_rounded : filled ? Icons.star_rounded : Icons.star_outline_rounded,
          color: AppColors.warning,
          size: size,
        );
      }),
    );
  }
}
