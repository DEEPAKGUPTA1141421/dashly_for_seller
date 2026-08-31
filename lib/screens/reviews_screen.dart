import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/widgets/app_shimmer.dart';
import '../core/widgets/app_toast.dart';
import '../providers/reviews_provider.dart';
import '../utils/app_colors.dart';
import '../utils/haptic_utils.dart';

const _quickEmojis = ['👍', '❤️', '😊', '🙏', '🎉'];

class ReviewsScreen extends ConsumerStatefulWidget {
  const ReviewsScreen({super.key});

  @override
  ConsumerState<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends ConsumerState<ReviewsScreen> {
  final _scrollCtrl = ScrollController();
  final _searchCtrl = TextEditingController();
  Timer? _searchDebounce;

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
    _searchCtrl.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      ref.read(reviewsPod.notifier).setQuery(value);
    });
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
          'Comments',
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

            const SliverToBoxAdapter(child: SizedBox(height: 20)),

            // Search bar
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _SearchField(
                  controller: _searchCtrl,
                  onChanged: _onSearchChanged,
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 20)),

            // Section heading
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    const Text(
                      'All Comments',
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

            // Comment list
            if (state.isLoading)
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => const Padding(
                    padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: AppShimmer(child: ShimmerBox(height: 130)),
                  ),
                  childCount: 6,
                ),
              )
            else if (state.reviews.isEmpty)
              const SliverFillRemaining(
                child: Center(
                  child: Text('No comments yet', style: TextStyle(color: AppColors.grey, fontSize: 14)),
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
                      child: _CommentCard(review: r, index: i),
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

// ── Search field ─────────────────────────────────────────────────────────────

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  const _SearchField({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: const TextStyle(color: AppColors.white, fontSize: 14),
      decoration: InputDecoration(
        hintText: 'Search product',
        hintStyle: const TextStyle(color: AppColors.greyDark, fontSize: 14),
        prefixIcon: const Icon(Icons.search_rounded, color: AppColors.greyDark, size: 20),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.white, width: 1.5),
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

// ── Comment card ──────────────────────────────────────────────────────────────

class _CommentCard extends ConsumerStatefulWidget {
  final Map review;
  final int index;
  const _CommentCard({required this.review, required this.index});

  @override
  ConsumerState<_CommentCard> createState() => _CommentCardState();
}

class _CommentCardState extends ConsumerState<_CommentCard> {
  bool _busy = false;

  Future<void> _toggleLike() async {
    final id = widget.review['id'] as String? ?? '';
    if (id.isEmpty) return;
    HapticUtils.light();
    await ref.read(reviewsPod.notifier).toggleLike(id);
  }

  Future<void> _pickReaction() async {
    final id = widget.review['id'] as String? ?? '';
    if (id.isEmpty) return;
    final current = (widget.review['sellerReaction'] as String?) ?? '';

    final emoji = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: _quickEmojis.map((e) {
            final selected = e == current;
            return GestureDetector(
              onTap: () => Navigator.of(context).pop(e),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: selected ? AppColors.surface2 : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Text(e, style: const TextStyle(fontSize: 26)),
              ),
            );
          }).toList(),
        ),
      ),
    );

    if (emoji == null || !mounted) return;
    HapticUtils.light();
    await ref.read(reviewsPod.notifier).react(id, emoji);
  }

  Future<void> _reply() async {
    final id = widget.review['id'] as String? ?? '';
    if (id.isEmpty) return;
    final existing = (widget.review['sellerReply'] as String?) ?? '';
    final ctrl = TextEditingController(text: existing);

    final text = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final bottom = MediaQuery.of(ctx).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: bottom),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const Text('Reply to comment', style: TextStyle(color: AppColors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 14),
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  maxLines: 4,
                  minLines: 2,
                  style: const TextStyle(color: AppColors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Write a reply…',
                    hintStyle: const TextStyle(color: AppColors.greyDark, fontSize: 14),
                    filled: true,
                    fillColor: AppColors.bg,
                    contentPadding: const EdgeInsets.all(14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.white, width: 1.5)),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Post Reply', style: TextStyle(color: AppColors.bg, fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (text == null || text.isEmpty || !mounted) return;
    setState(() => _busy = true);
    final ok = await ref.read(reviewsPod.notifier).reply(id, text);
    if (!mounted) return;
    setState(() => _busy = false);
    AppToast.show(
      context,
      message: ok ? 'Reply posted' : 'Could not post reply',
      type: ok ? ToastType.success : ToastType.error,
    );
  }

  Future<void> _delete() async {
    final id = widget.review['id'] as String? ?? '';
    if (id.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete comment?', style: TextStyle(color: AppColors.white, fontWeight: FontWeight.w700)),
        content: const Text(
          'This will permanently remove the comment from your product.',
          style: TextStyle(color: AppColors.grey, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    HapticUtils.medium();
    setState(() => _busy = true);
    final ok = await ref.read(reviewsPod.notifier).deleteReview(id);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) {
      AppToast.show(context, message: 'Could not delete comment', type: ToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final review = widget.review;
    final rating         = (review['rating'] as num?)?.toInt() ?? 0;
    final body           = (review['review'] as String?) ?? '';
    final productName    = (review['productName'] as String?) ?? 'Product';
    final categoryName   = (review['categoryName'] as String?) ?? '';
    final productImage   = (review['productImageUrl'] as String?) ?? '';
    final reviewerName   = (review['reviewerName'] as String?) ?? 'Anonymous';
    final reviewerAvatar = (review['reviewerAvatarUrl'] as String?) ?? '';
    final createdAt      = review['createdAt'] as String? ?? '';
    final helpfulCount   = (review['helpfulCount'] as num?)?.toInt() ?? 0;
    final likedByMe      = review['likedByMe'] as bool? ?? false;
    final sellerReply    = (review['sellerReply'] as String?) ?? '';
    final sellerReaction = (review['sellerReaction'] as String?) ?? '';
    final initials       = reviewerName.trim().isNotEmpty
        ? reviewerName.trim()[0].toUpperCase()
        : '?';

    return Opacity(
      opacity: _busy ? 0.5 : 1,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Reviewer row + date
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.surface2,
                  backgroundImage: reviewerAvatar.isNotEmpty ? NetworkImage(reviewerAvatar) : null,
                  child: reviewerAvatar.isEmpty
                      ? Text(initials, style: const TextStyle(color: AppColors.white, fontSize: 12, fontWeight: FontWeight.w700))
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(reviewerName, style: const TextStyle(color: AppColors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      _StarRow(rating: rating.toDouble(), size: 11),
                    ],
                  ),
                ),
                Text(_formatDate(createdAt), style: const TextStyle(color: AppColors.greyDark, fontSize: 11)),
              ],
            ),
            if (body.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(body, style: const TextStyle(color: AppColors.grey, fontSize: 13, height: 1.5)),
            ],
            const SizedBox(height: 12),

            // Product chip row
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: productImage.isNotEmpty
                        ? Image.network(productImage, width: 40, height: 40, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _ProductPlaceholder())
                        : _ProductPlaceholder(),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(productName, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppColors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                        if (categoryName.isNotEmpty)
                          Text(categoryName, maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: AppColors.grey, fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            if (sellerReply.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.info.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.info.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Your reply', style: TextStyle(color: AppColors.info, fontSize: 10, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(sellerReply, style: const TextStyle(color: AppColors.grey, fontSize: 12, height: 1.4)),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 8),

            // Action row
            Row(
              children: [
                _ActionIcon(icon: Icons.reply_rounded, onTap: _busy ? null : _reply),
                const SizedBox(width: 4),
                _ActionIcon(
                  icon: likedByMe ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: likedByMe ? AppColors.error : null,
                  label: helpfulCount > 0 ? '$helpfulCount' : null,
                  onTap: _busy ? null : _toggleLike,
                ),
                const SizedBox(width: 4),
                _ActionIcon(icon: Icons.delete_outline_rounded, onTap: _busy ? null : _delete),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: _busy ? null : _pickReaction,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: sellerReaction.isNotEmpty
                        ? Text(sellerReaction, style: const TextStyle(fontSize: 16))
                        : const Icon(Icons.emoji_emotions_outlined, color: AppColors.greyDark, size: 20),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: widget.index * 30)).slideY(begin: 0.03, end: 0);
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

class _ProductPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40, height: 40,
      color: AppColors.surface2,
      child: const Icon(Icons.inventory_2_outlined, color: AppColors.greyDark, size: 18),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final String? label;
  final VoidCallback? onTap;
  const _ActionIcon({required this.icon, this.color, this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color ?? AppColors.greyDark, size: 20),
            if (label != null) ...[
              const SizedBox(width: 4),
              Text(label!, style: TextStyle(color: color ?? AppColors.greyDark, fontSize: 11, fontWeight: FontWeight.w600)),
            ],
          ],
        ),
      ),
    );
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
