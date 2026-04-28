import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/widgets/app_shimmer.dart';
import '../providers/seller_earnings_provider.dart';
import '../utils/app_colors.dart';
import '../utils/haptic_utils.dart';

class EarningsScreen extends ConsumerStatefulWidget {
  const EarningsScreen({super.key});

  @override
  ConsumerState<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends ConsumerState<EarningsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(sellerEarningsPod.notifier).fetchEarnings());
  }

  Future<void> _refresh() async {
    HapticUtils.light();
    await ref.read(sellerEarningsPod.notifier).fetchEarnings();
  }

  @override
  Widget build(BuildContext context) {
    final state    = ref.watch(sellerEarningsPod);
    final earnings = state.earnings;

    final earned  = earnings['totalEarnedRupees']?.toString() ?? '0.00';
    final pending = earnings['pendingRupees']?.toString()     ?? '0.00';
    final settlements = (earnings['recentSettlements'] as List<dynamic>?) ?? [];

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        foregroundColor: AppColors.white,
        title: const Text('Earnings', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: AppColors.white,
        backgroundColor: AppColors.surface,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Balance cards row
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: state.isLoading
                    ? const AppShimmer(child: ShimmerBox(height: 130))
                    : Row(
                        children: [
                          Expanded(child: _EarningsCard(
                            label: 'Total Earned',
                            value: '₹$earned',
                            icon: Icons.check_circle_outline_rounded,
                            color: AppColors.success,
                          )),
                          const SizedBox(width: 12),
                          Expanded(child: _EarningsCard(
                            label: 'Pending',
                            value: '₹$pending',
                            icon: Icons.schedule_rounded,
                            color: AppColors.warning,
                          )),
                        ],
                      ),
              ).animate().fadeIn(),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 8)),

            // Info note
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: AppColors.grey, size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Earnings are released after orders are delivered. Pending shows active orders.',
                          style: TextStyle(color: AppColors.grey, fontSize: 11, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ).animate().fadeIn(delay: 60.ms),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 28)),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: const Text(
                  'Recent Settlements',
                  style: TextStyle(color: AppColors.white, fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 12)),

            if (state.isLoading && settlements.isEmpty)
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, __) => const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                    child: AppShimmer(child: ShimmerBox(height: 68)),
                  ),
                  childCount: 5,
                ),
              )
            else if (settlements.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(top: 48),
                  child: Center(
                    child: Text('No delivered orders yet', style: TextStyle(color: AppColors.grey, fontSize: 14)),
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    child: _SettlementTile(settlement: settlements[i] as Map),
                  ),
                  childCount: settlements.length,
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }
}

// ── Earnings card ─────────────────────────────────────────────────────────────

class _EarningsCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _EarningsCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

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
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 12),
          Text(label, style: const TextStyle(color: AppColors.grey, fontSize: 11, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: AppColors.white, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
        ],
      ),
    );
  }
}

// ── Settlement tile ───────────────────────────────────────────────────────────

class _SettlementTile extends StatelessWidget {
  final Map settlement;
  const _SettlementTile({required this.settlement});

  @override
  Widget build(BuildContext context) {
    final shortId  = settlement['shortId'] as String? ?? '--------';
    final rupees   = settlement['totalRupees'] as String? ?? '0.00';
    final items    = settlement['itemCount'] as int? ?? 0;
    final payMode  = settlement['paymentMode'] as String? ?? '';
    final rawDate  = settlement['settledAt'] as String? ?? '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.check_rounded, color: AppColors.success, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '#$shortId',
                  style: const TextStyle(color: AppColors.white, fontSize: 13, fontWeight: FontWeight.w600),
                ),
                Text(
                  '$items item${items != 1 ? 's' : ''}${payMode.isNotEmpty ? ' · $payMode' : ''}',
                  style: const TextStyle(color: AppColors.grey, fontSize: 11),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '+₹$rupees',
                style: const TextStyle(color: AppColors.success, fontSize: 13, fontWeight: FontWeight.w700),
              ),
              if (rawDate.isNotEmpty)
                Text(_formatDate(rawDate), style: const TextStyle(color: AppColors.greyDark, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${dt.day} ${months[dt.month - 1]}';
    } catch (_) {
      return '';
    }
  }
}
