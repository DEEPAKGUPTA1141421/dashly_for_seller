import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/responsive.dart';
import '../core/widgets/app_shimmer.dart';
import '../models/balance_stat.dart';
import '../providers/analytics_provider.dart';
import '../providers/reviews_provider.dart';
import '../utils/app_colors.dart';
import '../utils/haptic_utils.dart';
import '../widgets/analytics/balance_stat_card.dart';
import '../widgets/analytics/product_activity_table.dart';
import '../widgets/analytics/product_views_card.dart';
import '../widgets/analytics/top_cities_card.dart';
import 'reviews_screen.dart';
import 'share_product_sheet.dart';

/// Shared period options for every date-range selector on this screen —
/// 3650 is the "All time" sentinel the backend treats as its effective ceiling.
const List<int> kPeriodOptions = [7, 30, 90, 3650];

String periodLabel(int days) => days >= 3650 ? 'All time' : '${days}d';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(analyticsPod.notifier).fetchStats();
      ref.read(reviewsPod.notifier).fetchSummary();
    });
  }

  Future<void> _refresh() async {
    HapticUtils.light();
    await ref.read(analyticsPod.notifier).fetchStats();
    ref.read(reviewsPod.notifier).fetchSummary();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(analyticsPod);
    final hPad  = Responsive.horizontalPadding(context);
    final twoCol = Responsive.isDesktop(context);

    // Build chart bars from dailyChart data
    final chart  = state.dailyChart;
    final maxRev = chart.isEmpty ? 1.0 : chart
        .map((e) => (e as Map)['revenuePaise'] as num? ?? 0)
        .reduce((a, b) => a > b ? a : b)
        .toDouble()
        .clamp(1.0, double.infinity);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          color: AppColors.accent,
          backgroundColor: AppColors.surface,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(hPad, 20, hPad, 24),
                  child: const Text(
                    'Analytics',
                    style: TextStyle(color: AppColors.white, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.3),
                  ).animate().fadeIn(),
                ),
              ),

              // Date range tabs: 7d / 30d / 90d
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.symmetric(horizontal: hPad),
                    children: kPeriodOptions.map((d) {
                      final selected = state.selectedDays == d;
                      return GestureDetector(
                        onTap: () {
                          HapticUtils.light();
                          ref.read(analyticsPod.notifier).setDays(d);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
                          decoration: BoxDecoration(
                            color: selected ? AppColors.accent : AppColors.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: selected ? AppColors.accent : AppColors.border),
                          ),
                          child: Text(
                            periodLabel(d),
                            style: TextStyle(
                              color: selected ? Colors.white : AppColors.grey,
                              fontSize: 12,
                              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ).animate().fadeIn(delay: 60.ms),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 20)),

              // Overview — customers, income, recent customers, send message
              if (!state.isLoading && state.error == null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 24),
                    child: _OverviewCard(state: state).animate().fadeIn(delay: 90.ms),
                  ),
                ),

              // Error state — don't show mock/zero stats when the fetch failed
              if (!state.isLoading && state.error != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 24),
                    child: _AnalyticsErrorState(onRetry: _refresh),
                  ).animate().fadeIn(),
                ),

              // Current balance + Product activity + Product views
              if (state.isLoading || state.error == null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: hPad),
                    child: state.isLoading
                        ? const Column(
                            children: [
                              AppShimmer(child: ShimmerBox(height: 130)),
                              SizedBox(height: 16),
                              AppShimmer(child: ShimmerBox(height: 260)),
                            ],
                          )
                        : (twoCol
                            ? _TwoColumnAnalytics(state: state, chart: chart, maxRev: maxRev)
                            : _SingleColumnAnalytics(state: state, chart: chart, maxRev: maxRev)),
                  ),
                ),

              // Status breakdown
              if (!state.isLoading && (state.stats['statusBreakdown'] as Map?)?.isNotEmpty == true)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(hPad, 28, hPad, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Order Status Breakdown',
                          style: TextStyle(color: AppColors.white, fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 16),
                        _StatusBreakdown(
                          breakdown: Map<String, dynamic>.from(state.stats['statusBreakdown'] as Map? ?? {}),
                        ),
                      ],
                    ).animate().fadeIn(delay: 150.ms),
                  ),
                ),

              // Performance metrics
              if (!state.isLoading && (state.stats['statusBreakdown'] as Map?)?.isNotEmpty == true)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(hPad, 28, hPad, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Performance Metrics',
                          style: TextStyle(color: AppColors.white, fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 16),
                        _PerformanceMetrics(
                          breakdown: Map<String, dynamic>.from(state.stats['statusBreakdown'] as Map? ?? {}),
                        ),
                      ],
                    ).animate().fadeIn(delay: 170.ms),
                  ),
                ),

              // Top products
              if (!state.isLoading && state.topProducts.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(hPad, 28, hPad, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Top Products by Revenue',
                          style: TextStyle(color: AppColors.white, fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 16),
                        _TopProducts(products: state.topProducts),
                      ],
                    ).animate().fadeIn(delay: 180.ms),
                  ),
                ),

              // Customer reviews summary
              SliverToBoxAdapter(
                child: Builder(builder: (context) {
                  final reviewState = ref.watch(reviewsPod);
                  final summary     = reviewState.summary;
                  if (summary.isEmpty) return const SizedBox.shrink();
                  final avg   = (summary['avgRating'] as num?)?.toDouble() ?? 0.0;
                  final count = (summary['totalCount'] as num?)?.toInt() ?? 0;
                  return Padding(
                    padding: EdgeInsets.fromLTRB(hPad, 28, hPad, 0),
                    child: GestureDetector(
                      onTap: () {
                        HapticUtils.light();
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const ReviewsScreen()));
                      },
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.star_rounded, color: AppColors.warning, size: 28),
                            const SizedBox(width: 14),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Customer Reviews',
                                    style: TextStyle(color: AppColors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                                const SizedBox(height: 2),
                                Text(
                                  '$count review${count != 1 ? 's' : ''} · avg ${avg.toStringAsFixed(1)} ★',
                                  style: const TextStyle(color: AppColors.grey, fontSize: 12),
                                ),
                              ],
                            ),
                            const Spacer(),
                            const Icon(Icons.chevron_right_rounded, color: AppColors.greyDark, size: 20),
                          ],
                        ),
                      ).animate().fadeIn(delay: 200.ms),
                    ),
                  );
                }),
              ),

              // Top sources + Top cities
              if (!state.isLoading)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(hPad, 28, hPad, 0),
                    child: twoCol
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: _TopSourcesCard(sources: state.trafficSources)),
                              const SizedBox(width: 16),
                              Expanded(child: TopCitiesCard(cities: state.topCities)),
                            ],
                          )
                        : Column(
                            children: [
                              _TopSourcesCard(sources: state.trafficSources),
                              const SizedBox(height: 16),
                              TopCitiesCard(cities: state.topCities),
                            ],
                          ),
                  ).animate().fadeIn(delay: 220.ms),
                ),

              // Share your products
              if (!state.isLoading && state.topProducts.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(hPad, 28, hPad, 0),
                    child: _ShareProductsCard(products: state.topProducts).animate().fadeIn(delay: 230.ms),
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Overview: customers, income, recent customers, send message ──────────────

class _OverviewCard extends StatelessWidget {
  final AnalyticsState state;
  const _OverviewCard({required this.state});

  BalanceStat? _find(String label) {
    for (final s in state.balanceStats) {
      if (s.label == label) return s;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final customers = _find('Customer');
    final income     = _find('Earning');
    final recent     = state.recentCustomers;

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
          const Text('Overview', style: TextStyle(color: AppColors.white, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(14)),
            child: Row(
              children: [
                Expanded(child: _OverviewStat(icon: Icons.person_rounded, iconColor: AppColors.warning,
                    label: 'Customers', value: customers?.value ?? '0', changePct: customers?.changePct ?? 0)),
                Container(width: 1, height: 40, color: AppColors.border),
                const SizedBox(width: 12),
                Expanded(child: _OverviewStat(icon: Icons.shopping_cart_rounded, iconColor: AppColors.info,
                    label: 'Income', value: '₹${income?.value ?? '0'}', changePct: income?.changePct ?? 0)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text.rich(
            TextSpan(
              style: const TextStyle(color: AppColors.grey, fontSize: 12.5, height: 1.4),
              children: [
                const TextSpan(text: 'Welcome '),
                TextSpan(text: '${customers?.value ?? '0'} customers', style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.w700)),
                const TextSpan(text: ' this month 😊'),
              ],
            ),
          ),
          if (recent.isNotEmpty) ...[
            const SizedBox(height: 16),
            SizedBox(
              height: 60,
              child: Row(
                children: [
                  for (final c in recent.take(3))
                    Padding(
                      padding: const EdgeInsets.only(right: 14),
                      child: _CustomerAvatar(c: c as Map),
                    ),
                  GestureDetector(
                    onTap: () {
                      HapticUtils.light();
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const ReviewsScreen()));
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 40, height: 40,
                          decoration: const BoxDecoration(color: AppColors.surface2, shape: BoxShape.circle),
                          child: const Icon(Icons.arrow_forward_rounded, color: AppColors.grey, size: 18),
                        ),
                        const SizedBox(height: 4),
                        const Text('View all', style: TextStyle(color: AppColors.grey, fontSize: 10)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

}

class _OverviewStat extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final double changePct;
  const _OverviewStat({required this.icon, required this.iconColor, required this.label, required this.value, required this.changePct});

  @override
  Widget build(BuildContext context) {
    final up = changePct >= 0;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(color: iconColor.withOpacity(0.15), shape: BoxShape.circle),
          child: Icon(icon, color: iconColor, size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: AppColors.grey, fontSize: 11)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(color: AppColors.white, fontSize: 18, fontWeight: FontWeight.w800),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              Text('${up ? '↑' : '↓'} ${changePct.abs().toStringAsFixed(1)}%',
                  style: TextStyle(color: up ? AppColors.success : AppColors.error, fontSize: 10, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ],
    );
  }
}

class _CustomerAvatar extends StatelessWidget {
  final Map c;
  const _CustomerAvatar({required this.c});

  @override
  Widget build(BuildContext context) {
    final name   = (c['reviewerName'] as String?) ?? 'Customer';
    final avatar = (c['reviewerAvatarUrl'] as String?) ?? '';
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: AppColors.surface2,
          backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
          child: avatar.isEmpty ? Text(initial, style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.w700)) : null,
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: 56,
          child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.grey, fontSize: 10)),
        ),
      ],
    );
  }
}

// ── Refund requests ───────────────────────────────────────────────────────────

// ── Top sources (device-equivalent) + Top cities ──────────────────────────────

class _TopSourcesCard extends StatelessWidget {
  final List<dynamic> sources;
  const _TopSourcesCard({required this.sources});

  static const _labels = {
    'home': 'Home', 'search': 'Search', 'pdp': 'Product Page', 'push': 'Push', 'cart': 'Cart',
  };

  @override
  Widget build(BuildContext context) {
    final total = sources.fold<num>(0, (s, e) => s + ((e as Map)['count'] as num? ?? 0));
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Top sources', style: TextStyle(color: AppColors.white, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          if (sources.isEmpty || total == 0)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: Text('No traffic data yet', style: TextStyle(color: AppColors.grey, fontSize: 12))),
            )
          else ...[
            SizedBox(
              height: 160,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 45,
                  sections: sources.asMap().entries.map((e) {
                    final s = e.value as Map;
                    final count = (s['count'] as num?)?.toDouble() ?? 0;
                    final pct = total > 0 ? count / total * 100 : 0.0;
                    return PieChartSectionData(
                      value: count,
                      color: AppColors.chartPalette[e.key % AppColors.chartPalette.length],
                      title: '${pct.toStringAsFixed(0)}%',
                      radius: 30,
                      titleStyle: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 14,
              runSpacing: 8,
              children: sources.asMap().entries.map((e) {
                final s = e.value as Map;
                final key = (s['source'] as String?) ?? 'unknown';
                final count = (s['count'] as num?)?.toInt() ?? 0;
                final pct = total > 0 ? count / total * 100 : 0.0;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: AppColors.chartPalette[e.key % AppColors.chartPalette.length], shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text('${_labels[key] ?? key}  ${pct.toStringAsFixed(1)}%', style: const TextStyle(color: AppColors.grey, fontSize: 11, fontWeight: FontWeight.w600)),
                  ],
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Share your products ───────────────────────────────────────────────────────

class _ShareProductsCard extends StatefulWidget {
  final List<dynamic> products;
  const _ShareProductsCard({required this.products});

  @override
  State<_ShareProductsCard> createState() => _ShareProductsCardState();
}

class _ShareProductsCardState extends State<_ShareProductsCard> {
  final Set<int> _selected = {0};

  @override
  Widget build(BuildContext context) {
    final products = widget.products;
    if (products.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Share your products', style: TextStyle(color: AppColors.white, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          Row(
            children: products.asMap().entries.take(4).map((e) {
              final i = e.key;
              final p = e.value as Map;
              final selected = _selected.contains(i);
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i < products.length - 1 ? 10 : 0),
                  child: GestureDetector(
                    onTap: () => setState(() => selected ? _selected.remove(i) : _selected.add(i)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: AspectRatio(
                                aspectRatio: 1,
                                child: Container(
                                  color: AppColors.surface2,
                                  child: const Icon(Icons.inventory_2_outlined, color: AppColors.greyDark, size: 28),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 6, left: 6,
                              child: Container(
                                width: 20, height: 20,
                                decoration: BoxDecoration(
                                  color: selected ? AppColors.info : AppColors.surface,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: selected ? const Icon(Icons.check_rounded, color: Colors.white, size: 14) : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text((p['productName'] as String?) ?? 'Product', maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppColors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _selected.isEmpty ? null : () {
                HapticUtils.light();
                final first = products[_selected.first] as Map;
                showShareProductSheet(context, {
                  'name': first['productName'] ?? 'Product',
                  'price': 0,
                });
              },
              icon: const Icon(Icons.share_rounded, size: 16),
              label: Text('Share ${_selected.length} product${_selected.length != 1 ? 's' : ''}'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.white,
                foregroundColor: AppColors.bg,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Current balance / Product activity / Product views layout ────────────────

class _CurrentBalanceRow extends ConsumerWidget {
  final List<BalanceStat> balanceStats;
  const _CurrentBalanceRow({required this.balanceStats});

  static const _icons = [Icons.show_chart_rounded, Icons.person_rounded, Icons.podcasts_rounded];
  static const _colors = [AppColors.success, Color(0xFFF59E0B), Color(0xFF38BDF8)];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (balanceStats.isEmpty) return const SizedBox.shrink();
    final selectedDays = ref.watch(analyticsPod).selectedDays;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Current balance',
              style: TextStyle(color: AppColors.white, fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            _PeriodDropdown(
              selectedDays: selectedDays,
              onSelected: (d) => ref.read(analyticsPod.notifier).setDays(d),
            ),
          ],
        ),
        const SizedBox(height: 14),
        LayoutBuilder(builder: (context, constraints) {
          final cards = List.generate(balanceStats.length, (i) => BalanceStatCard(
                stat: balanceStats[i],
                icon: _icons[i % _icons.length],
                color: _colors[i % _colors.length],
              ));
          if (Responsive.isMobile(context)) {
            return Column(
              children: [
                for (var i = 0; i < cards.length; i++) ...[
                  if (i > 0) const SizedBox(height: 12),
                  cards[i],
                ],
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(child: cards[i]),
              ],
            ],
          );
        }),
      ],
    );
  }
}

/// The period chip shown above "Current balance" and "Product activity" —
/// previously static decoration (always read "All time" with a chevron but
/// had no menu attached), so tapping it did nothing. Now a real popup menu
/// that drives the same [analyticsPod] period used by the page's 7d/30d/90d
/// tabs, so picking an option here actually changes what's displayed.
class _PeriodDropdown extends StatelessWidget {
  final int selectedDays;
  final ValueChanged<int> onSelected;
  const _PeriodDropdown({required this.selectedDays, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      initialValue: selectedDays,
      onSelected: (d) {
        HapticUtils.light();
        onSelected(d);
      },
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.border)),
      itemBuilder: (context) => kPeriodOptions.map((d) => PopupMenuItem<int>(
            value: d,
            child: Text(
              periodLabel(d),
              style: TextStyle(
                color: d == selectedDays ? AppColors.accent : AppColors.white,
                fontSize: 13,
                fontWeight: d == selectedDays ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          )).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(periodLabel(selectedDays), style: const TextStyle(color: AppColors.grey, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.grey, size: 16),
          ],
        ),
      ),
    );
  }
}

class _ProductActivityCard extends ConsumerWidget {
  final AnalyticsState state;
  const _ProductActivityCard({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Product activity',
                style: TextStyle(color: AppColors.white, fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              _PeriodDropdown(
                selectedDays: state.selectedDays,
                onSelected: (d) => ref.read(analyticsPod.notifier).setDays(d),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ProductActivityTable(
            weeks: state.activityWeeks,
            isLoading: state.isActivityLoading,
            onLoadMore: () => ref.read(analyticsPod.notifier).fetchActivity(loadMore: true),
          ),
        ],
      ),
    );
  }
}

class _TwoColumnAnalytics extends StatelessWidget {
  final AnalyticsState state;
  final List<dynamic> chart;
  final double maxRev;
  const _TwoColumnAnalytics({required this.state, required this.chart, required this.maxRev});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: Column(
            children: [
              _CurrentBalanceRow(balanceStats: state.balanceStats),
              const SizedBox(height: 20),
              _ProductActivityCard(state: state),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: ProductViewsCard(monthlyViews: state.monthlyViews),
        ),
      ],
    ).animate().fadeIn(delay: 80.ms);
  }
}

class _SingleColumnAnalytics extends StatelessWidget {
  final AnalyticsState state;
  final List<dynamic> chart;
  final double maxRev;
  const _SingleColumnAnalytics({required this.state, required this.chart, required this.maxRev});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _CurrentBalanceRow(balanceStats: state.balanceStats),
        const SizedBox(height: 20),
        _ProductActivityCard(state: state),
        const SizedBox(height: 20),
        ProductViewsCard(monthlyViews: state.monthlyViews),
      ],
    ).animate().fadeIn(delay: 80.ms);
  }
}

// ── Revenue bar chart ─────────────────────────────────────────────────────────

class _AnalyticsErrorState extends StatelessWidget {
  final Future<void> Function() onRetry;
  const _AnalyticsErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_rounded, color: AppColors.grey, size: 32),
          const SizedBox(height: 10),
          const Text(
            'Couldn\'t load analytics data',
            style: TextStyle(color: AppColors.white, fontSize: 14, fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          const Text(
            'Check your connection and try again',
            style: TextStyle(color: AppColors.grey, fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () { HapticUtils.light(); onRetry(); },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Retry',
                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Status breakdown ──────────────────────────────────────────────────────────

class _StatusBreakdown extends StatelessWidget {
  final Map<String, dynamic> breakdown;
  const _StatusBreakdown({required this.breakdown});

  @override
  Widget build(BuildContext context) {
    final total = breakdown.values.fold<num>(0, (s, v) => s + ((v as num?) ?? 0));
    if (total == 0) return const SizedBox.shrink();

    final entries = breakdown.entries.toList()
      ..sort((a, b) => (b.value as num).compareTo(a.value as num));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: entries.asMap().entries.map((e) {
          final status = e.value.key;
          final count  = (e.value.value as num).toDouble();
          final pct    = count / total;
          final color  = AppColors.chartPalette[e.key % AppColors.chartPalette.length];
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(status, style: const TextStyle(color: AppColors.white, fontSize: 13))),
                    Text('${count.toInt()} (${(pct * 100).toStringAsFixed(0)}%)',
                        style: const TextStyle(color: AppColors.grey, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    backgroundColor: AppColors.surface2,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    minHeight: 4,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Performance metrics ───────────────────────────────────────────────────────

class _PerformanceMetrics extends StatelessWidget {
  final Map<String, dynamic> breakdown;
  const _PerformanceMetrics({required this.breakdown});

  double _get(String key) => ((breakdown[key] as num?) ?? 0).toDouble();

  @override
  Widget build(BuildContext context) {
    final delivered   = _get('DELIVERED');
    final cancelled   = _get('CANCELLED');
    final processing  = _get('PROCESSING');
    final ofDelivery  = _get('OUT_FOR_DELIVERY');
    final reversed    = _get('REVERSED');
    final confirmed   = _get('CONFIRMED');
    final total       = breakdown.values.fold<double>(0, (s, v) => s + ((v as num?)?.toDouble() ?? 0));

    // Completion rate: delivered / (delivered + cancelled)
    final terminalTotal = delivered + cancelled;
    final completionRate = terminalTotal > 0 ? (delivered / terminalTotal * 100) : null;

    // Cancellation rate: cancelled / total
    final cancellationRate = total > 0 ? (cancelled / total * 100) : null;

    // Acceptance rate: orders accepted past CONFIRMED / orders received
    final accepted  = processing + ofDelivery + delivered + reversed;
    final received  = confirmed + processing + ofDelivery + delivered + reversed + cancelled;
    final acceptanceRate = received > 0 ? (accepted / received * 100) : null;

    return Row(
      children: [
        _MetricCard(
          label: 'Acceptance',
          value: acceptanceRate,
          icon: Icons.thumb_up_rounded,
          color: AppColors.success,
        ),
        const SizedBox(width: 10),
        _MetricCard(
          label: 'Completion',
          value: completionRate,
          icon: Icons.check_circle_rounded,
          color: AppColors.info,
        ),
        const SizedBox(width: 10),
        _MetricCard(
          label: 'Cancellation',
          value: cancellationRate,
          icon: Icons.cancel_rounded,
          color: AppColors.error,
          invert: true,
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final double? value;
  final IconData icon;
  final Color color;
  final bool invert;
  const _MetricCard({required this.label, required this.value, required this.icon, required this.color, this.invert = false});

  @override
  Widget build(BuildContext context) {
    final pct = value != null ? '${value!.toStringAsFixed(1)}%' : 'N/A';
    final isGood = invert ? (value == null || value! < 10) : (value == null || value! >= 70);
    final indicatorColor = value == null ? AppColors.greyDark : (isGood ? color : AppColors.warning);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: indicatorColor, size: 18),
            const SizedBox(height: 8),
            Text(pct, style: const TextStyle(color: AppColors.white, fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: AppColors.grey, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}


// ── Top products ──────────────────────────────────────────────────────────────

class _TopProducts extends StatelessWidget {
  final List<dynamic> products;
  const _TopProducts({required this.products});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: products.asMap().entries.map((e) {
          final i    = e.key;
          final p    = e.value as Map;
          final name = p['productName'] as String? ?? 'Unknown';
          final qty  = p['totalQty'] as num? ?? 0;
          final rev  = p['revenueRupees'] as String? ?? '0.00';
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              children: [
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.surface2,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '#${i + 1}',
                      style: const TextStyle(color: AppColors.grey, fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                      Text('$qty sold', style: const TextStyle(color: AppColors.grey, fontSize: 11)),
                    ],
                  ),
                ),
                Text(
                  '₹$rev',
                  style: const TextStyle(color: AppColors.white, fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
