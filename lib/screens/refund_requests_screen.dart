import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/responsive.dart';
import '../core/widgets/app_shimmer.dart';
import '../core/widgets/app_toast.dart';
import '../providers/refund_requests_provider.dart';
import '../utils/app_colors.dart';
import '../utils/haptic_utils.dart';

class RefundRequestsScreen extends ConsumerStatefulWidget {
  const RefundRequestsScreen({super.key});

  @override
  ConsumerState<RefundRequestsScreen> createState() => _RefundRequestsScreenState();
}

class _RefundRequestsScreenState extends ConsumerState<RefundRequestsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(refundRequestsPod.notifier).fetchReturns(refresh: true));
  }

  Future<void> _refresh() async {
    HapticUtils.light();
    await ref.read(refundRequestsPod.notifier).fetchReturns(refresh: true);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(refundRequestsPod);
    final hPad  = Responsive.horizontalPadding(context);
    final twoCol = Responsive.isDesktop(context);

    ref.listen(refundRequestsPod, (prev, next) {
      if (next.error != null && next.error != prev?.error) {
        AppToast.show(context, message: next.error!, type: ToastType.error);
      }
    });

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
          'Refund Requests',
          style: TextStyle(color: AppColors.white, fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.3),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.divider),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          color: AppColors.white,
          backgroundColor: AppColors.surface,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 16),
                  child: _BucketToggle(
                    bucket: state.bucket,
                    onChanged: (b) {
                      HapticUtils.light();
                      ref.read(refundRequestsPod.notifier).setBucket(b);
                    },
                  ),
                ).animate().fadeIn(),
              ),

              if (state.isLoading)
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, __) => Padding(
                      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 6),
                      child: const AppShimmer(child: ShimmerBox(height: 76)),
                    ),
                    childCount: 6,
                  ),
                )
              else if (state.returns.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text(
                      state.bucket == 'CLOSED' ? 'No closed refund requests' : 'No open refund requests',
                      style: const TextStyle(color: AppColors.grey, fontSize: 14),
                    ),
                  ),
                )
              else
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: hPad),
                    child: twoCol
                        ? _RefundTable(returns: state.returns)
                        : Column(
                            children: [
                              for (final (i, r) in state.returns.indexed)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _RefundRow(r: r as Map, index: i),
                                ),
                            ],
                          ),
                  ),
                ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: state.isLoadingMore
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.grey),
                          )
                        : state.hasMore && state.returns.isNotEmpty
                            ? OutlinedButton(
                                onPressed: () {
                                  HapticUtils.light();
                                  ref.read(refundRequestsPod.notifier).fetchReturns();
                                },
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: AppColors.border),
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                ),
                                child: const Text('Load more', style: TextStyle(color: AppColors.white, fontSize: 12.5, fontWeight: FontWeight.w600)),
                              )
                            : const SizedBox.shrink(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Open requests / Closed requests toggle ─────────────────────────────────────

class _BucketToggle extends StatelessWidget {
  final String bucket;
  final ValueChanged<String> onChanged;
  const _BucketToggle({required this.bucket, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Text('Refund requests', style: TextStyle(color: AppColors.white, fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
        ),
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(10)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _pill('OPEN', 'Open requests'),
              _pill('CLOSED', 'Closed requests'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _pill(String value, String label) {
    final selected = bucket == value;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: selected
              ? [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 6, offset: const Offset(0, 1))]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.bg : AppColors.grey,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ── Desktop table ───────────────────────────────────────────────────────────────

class _RefundTable extends StatelessWidget {
  final List<dynamic> returns;
  const _RefundTable({required this.returns});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(18, 16, 18, 12),
            child: Row(
              children: [
                Expanded(flex: 4, child: Text('Product', style: _headerStyle)),
                Expanded(flex: 2, child: Text('Status', style: _headerStyle)),
                Expanded(flex: 2, child: Text('Date', style: _headerStyle)),
                Expanded(flex: 3, child: Text('Customer', style: _headerStyle)),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          for (final (i, raw) in returns.indexed) _RefundTableRow(r: raw as Map, index: i),
        ],
      ),
    );
  }
}

const _headerStyle = TextStyle(color: AppColors.greyDark, fontSize: 12, fontWeight: FontWeight.w600);

class _RefundTableRow extends StatelessWidget {
  final Map r;
  final int index;
  const _RefundTableRow({required this.r, required this.index});

  @override
  Widget build(BuildContext context) {
    final productName = (r['productName'] as String?) ?? 'Unknown product';
    final category     = (r['categoryName'] as String?) ?? '';
    final imageUrl     = (r['productImageUrl'] as String?) ?? '';
    final statusLabel  = (r['boardStatusLabel'] as String?) ?? (r['statusLabel'] as String?) ?? '';
    final status       = (r['status'] as String?) ?? 'PENDING';
    final createdAt    = (r['createdAt'] as String?) ?? '';
    final customerName = (r['customerName'] as String?) ?? 'Customer';
    final avatarUrl     = (r['customerAvatarUrl'] as String?) ?? '';
    final color         = _statusColor(status);

    return Container(
      color: index.isOdd ? AppColors.surface2.withOpacity(0.4) : Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Row(
              children: [
                _ProductThumb(url: imageUrl),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(productName, maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                      if (category.isNotEmpty)
                        Text(category, style: const TextStyle(color: AppColors.greyDark, fontSize: 11.5)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                child: Text(statusLabel, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
          Expanded(flex: 2, child: Text(_formatDate(createdAt), style: const TextStyle(color: AppColors.grey, fontSize: 12.5))),
          Expanded(
            flex: 3,
            child: Row(
              children: [
                _Avatar(url: avatarUrl, name: customerName),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(customerName, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.white, fontSize: 12.5, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: index * 20));
  }
}

// ── Mobile row ────────────────────────────────────────────────────────────────

class _RefundRow extends StatelessWidget {
  final Map r;
  final int index;
  const _RefundRow({required this.r, required this.index});

  @override
  Widget build(BuildContext context) {
    final productName  = (r['productName'] as String?) ?? 'Unknown product';
    final category      = (r['categoryName'] as String?) ?? '';
    final imageUrl       = (r['productImageUrl'] as String?) ?? '';
    final createdAt       = (r['createdAt'] as String?) ?? '';
    final customerName  = (r['customerName'] as String?) ?? 'Customer';
    final avatarUrl       = (r['customerAvatarUrl'] as String?) ?? '';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _ProductThumb(url: imageUrl),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(productName, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                if (category.isNotEmpty)
                  Text(category, style: const TextStyle(color: AppColors.greyDark, fontSize: 11.5)),
                Text(_formatDate(createdAt), style: const TextStyle(color: AppColors.greyDark, fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _Avatar(url: avatarUrl, name: customerName),
              const SizedBox(height: 4),
              SizedBox(
                width: 64,
                child: Text(customerName, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.right,
                    style: const TextStyle(color: AppColors.grey, fontSize: 10.5, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: index * 30)).slideY(begin: 0.03, end: 0);
  }
}

// ── Shared bits ───────────────────────────────────────────────────────────────

class _ProductThumb extends StatelessWidget {
  final String url;
  const _ProductThumb({required this.url});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 44, height: 44,
        color: AppColors.surface2,
        child: url.isNotEmpty
            ? Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported_rounded, color: AppColors.greyDark, size: 18))
            : const Icon(Icons.image_rounded, color: AppColors.greyDark, size: 18),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String url;
  final String name;
  const _Avatar({required this.url, required this.name});

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';
    return CircleAvatar(
      radius: 15,
      backgroundColor: AppColors.surface2,
      backgroundImage: url.isNotEmpty ? NetworkImage(url) : null,
      child: url.isEmpty ? Text(initial, style: const TextStyle(color: AppColors.white, fontSize: 11, fontWeight: FontWeight.w700)) : null,
    );
  }
}

Color _statusColor(String status) {
  switch (status) {
    case 'PENDING':
      return AppColors.success; // "New request" — green, matches Figma
    case 'APPROVED':
    case 'PICKUP_SCHEDULED':
    case 'PICKED_UP':
      return AppColors.grey; // "In progress" — neutral grey, matches Figma
    case 'REFUNDED':
      return AppColors.info;
    case 'REJECTED':
      return AppColors.error;
    default:
      return AppColors.grey;
  }
}

String _formatDate(String iso) {
  final dt = DateTime.tryParse(iso);
  if (dt == null) return '';
  const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  return '${months[dt.month - 1]} ${dt.day}';
}
