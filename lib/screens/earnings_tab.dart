import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/responsive.dart';
import '../core/widgets/app_shimmer.dart';
import '../core/widgets/app_toast.dart';
import '../providers/analytics_provider.dart';
import '../providers/earnings_provider.dart';
import '../utils/app_colors.dart';
import '../utils/haptic_utils.dart';
import '../widgets/analytics/product_views_card.dart';
import '../widgets/analytics/refund_requests_card.dart';
import '../widgets/analytics/top_cities_card.dart';
import '../widgets/invoice/earnings_history_table.dart';
import '../widgets/invoice/earnings_stat_row.dart';
import 'payouts_screen.dart';
import 'statement_screen.dart';

/// The "Earning" tab on the Invoices screen — seller earnings overview:
/// stat cards, a product-views chart, top cities, and a paginated earnings
/// history table. Matches the Figma seller-earnings reference.
class EarningsTab extends ConsumerStatefulWidget {
  const EarningsTab({super.key});

  @override
  ConsumerState<EarningsTab> createState() => _EarningsTabState();
}

class _EarningsTabState extends ConsumerState<EarningsTab> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(earningsPod.notifier).fetchSummary();
      ref.read(earningsPod.notifier).fetchHistory(refresh: true);
      if (ref.read(analyticsPod).monthlyViews.isEmpty) {
        ref.read(analyticsPod.notifier).fetchStats();
      }
    });
  }

  Future<void> _refresh() async {
    HapticUtils.light();
    await Future.wait([
      ref.read(earningsPod.notifier).fetchSummary(),
      ref.read(earningsPod.notifier).fetchHistory(refresh: true),
      ref.read(analyticsPod.notifier).fetchStats(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final state    = ref.watch(earningsPod);
    final extras   = ref.watch(analyticsPod);
    final hPad     = Responsive.horizontalPadding(context);
    final twoCol   = Responsive.isDesktop(context);

    ref.listen(earningsPod, (prev, next) {
      if (next.error != null && next.error != prev?.error) {
        AppToast.show(context, message: next.error!, type: ToastType.error);
      }
    });

    return RefreshIndicator(
      onRefresh: _refresh,
      color: AppColors.white,
      backgroundColor: AppColors.surface,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 20),
              child: state.isLoading
                  ? const Column(
                      children: [
                        AppShimmer(child: ShimmerBox(height: 130)),
                      ],
                    )
                  : EarningsStatRow(stats: state.stats).animate().fadeIn(),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 20),
              child: Row(
                children: [
                  Expanded(
                    child: _QuickLinkCard(
                      icon: Icons.account_balance_wallet_rounded,
                      label: 'Payouts',
                      onTap: () {
                        HapticUtils.light();
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const PayoutsScreen()));
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _QuickLinkCard(
                      icon: Icons.description_rounded,
                      label: 'Statement',
                      onTap: () {
                        HapticUtils.light();
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const StatementScreen()));
                      },
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 40.ms),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 20),
              child: twoCol
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: ProductViewsCard(monthlyViews: extras.monthlyViews)),
                        const SizedBox(width: 16),
                        Expanded(flex: 2, child: TopCitiesCard(cities: extras.topCities)),
                      ],
                    )
                  : Column(
                      children: [
                        ProductViewsCard(monthlyViews: extras.monthlyViews),
                        const SizedBox(height: 16),
                        TopCitiesCard(cities: extras.topCities),
                      ],
                    ),
            ).animate().fadeIn(delay: 80.ms),
          ),

          if (!extras.isLoading && extras.returnSummary.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 20),
                child: RefundRequestsCard(summary: extras.returnSummary),
              ).animate().fadeIn(delay: 100.ms),
            ),

          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 32),
              child: EarningsHistoryTable(
                history: state.history,
                isLoading: state.isHistoryLoading,
                isLoadingMore: state.isHistoryLoadingMore,
                hasMore: state.historyHasMore,
                onLoadMore: () {
                  HapticUtils.light();
                  ref.read(earningsPod.notifier).fetchHistory();
                },
              ),
            ).animate().fadeIn(delay: 120.ms),
          ),
        ],
      ),
    );
  }
}

class _QuickLinkCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickLinkCard({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: AppColors.white, size: 17),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label, style: const TextStyle(color: AppColors.white, fontSize: 13, fontWeight: FontWeight.w700)),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.greyDark, size: 18),
          ],
        ),
      ),
    );
  }
}
