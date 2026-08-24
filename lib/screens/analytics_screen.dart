import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/widgets/app_shimmer.dart';
import '../providers/analytics_provider.dart';
import '../providers/reviews_provider.dart';
import '../utils/app_colors.dart';
import '../utils/haptic_utils.dart';
import 'reviews_screen.dart';

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

    // Build chart bars from dailyChart data
    final chart  = state.dailyChart;
    final maxRev = chart.isEmpty ? 1.0 : chart
        .map((e) => (e as Map)['revenuePaise'] as num? ?? 0)
        .reduce((a, b) => a > b ? a : b)
        .toDouble()
        .clamp(1.0, double.infinity);

    final totalOrdersStr  = '${state.stats['totalOrders'] ?? 0}';
    final pendingStr      = '${state.stats['pendingOrders'] ?? 0}';
    final totalRevStr     = '₹${state.stats['totalRevenueRupees'] ?? '0.00'}';
    final ordersChange    = (state.stats['ordersChange']  as num?)?.toDouble() ?? 0;
    final revenueChange   = (state.stats['revenueChange'] as num?)?.toDouble() ?? 0;

    return Scaffold(
      backgroundColor: AppColors.bg,
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
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
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
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [7, 30, 90].map((d) {
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
                            color: selected ? AppColors.white : AppColors.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: selected ? AppColors.white : AppColors.border),
                          ),
                          child: Text(
                            '${d}d',
                            style: TextStyle(
                              color: selected ? AppColors.bg : AppColors.grey,
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

              // Error state — don't show mock/zero stats when the fetch failed
              if (!state.isLoading && state.error != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    child: _AnalyticsErrorState(onRetry: _refresh),
                  ).animate().fadeIn(),
                ),

              // Summary cards
              if (state.isLoading || state.error == null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: state.isLoading
                        ? Row(children: [
                            Expanded(child: AppShimmer(child: ShimmerBox(height: 88))),
                            const SizedBox(width: 12),
                            Expanded(child: AppShimmer(child: ShimmerBox(height: 88))),
                            const SizedBox(width: 12),
                            Expanded(child: AppShimmer(child: ShimmerBox(height: 88))),
                          ])
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: _SummaryCard(label: 'Total Revenue', value: totalRevStr, change: revenueChange)),
                              const SizedBox(width: 10),
                              Expanded(child: _SummaryCard(label: 'Total Orders',  value: totalOrdersStr, change: ordersChange)),
                              const SizedBox(width: 10),
                              Expanded(child: _SummaryCard(label: 'Pending',       value: pendingStr)),
                            ],
                          ),
                  ).animate().fadeIn(delay: 80.ms),
                ),

              if (state.isLoading || state.error == null) const SliverToBoxAdapter(child: SizedBox(height: 28)),

              // Revenue trend
              if (state.isLoading || state.error == null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Revenue — Last ${state.selectedDays} Days',
                          style: const TextStyle(color: AppColors.white, fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 16),
                        state.isLoading
                            ? const AppShimmer(child: ShimmerBox(height: 220))
                            : chart.isEmpty
                                ? _EmptyChart()
                                : _RevenueChart(data: chart, maxPaise: maxRev),
                      ],
                    ).animate().fadeIn(delay: 120.ms),
                  ),
                ),

              // Status breakdown
              if (!state.isLoading && (state.stats['statusBreakdown'] as Map?)?.isNotEmpty == true)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
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
                    padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
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
                    padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
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
                    padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
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

              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ),
        ),
      ),
    );
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
                color: AppColors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Retry',
                style: TextStyle(color: AppColors.bg, fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RevenueChart extends StatelessWidget {
  final List<dynamic> data;
  final double maxPaise;
  const _RevenueChart({required this.data, required this.maxPaise});

  @override
  Widget build(BuildContext context) {
    final chartMax = (maxPaise / 100).ceilToDouble() * 1.15; // rupees, 15% headroom

    return Container(
      height: 220,
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: chartMax,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (_, __, rod, ___) => BarTooltipItem(
                '₹${rod.toY.toStringAsFixed(0)}',
                const TextStyle(color: AppColors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, _) {
                  final idx = v.toInt();
                  if (idx < 0 || idx >= data.length) return const SizedBox.shrink();
                  final day = (data[idx] as Map)['day']?.toString() ?? '';
                  final label = day.length >= 10 ? day.substring(5) : day; // "04-20"
                  return Text(label, style: const TextStyle(color: AppColors.greyDark, fontSize: 9));
                },
              ),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.border, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          barGroups: data.asMap().entries.map((e) {
            final paise   = ((e.value as Map)['revenuePaise'] as num? ?? 0).toDouble();
            final rupees  = paise / 100;
            return BarChartGroupData(
              x: e.key,
              barRods: [
                BarChartRodData(
                  toY: rupees,
                  color: AppColors.white,
                  width: 20,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: chartMax,
                    color: AppColors.surface2,
                  ),
                ),
              ],
            );
          }).toList(),
        ),
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

class _EmptyChart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: const Center(
        child: Text('No order data yet', style: TextStyle(color: AppColors.grey, fontSize: 13)),
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

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final double? change; // percentage vs previous period; null = no delta shown

  const _SummaryCard({required this.label, required this.value, this.change});

  @override
  Widget build(BuildContext context) {
    final showChange = change != null && change != 0;
    final isUp       = (change ?? 0) >= 0;
    final changeStr  = showChange ? '${isUp ? '+' : ''}${change!.toStringAsFixed(1)}%' : '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.grey, fontSize: 11),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.white, fontSize: 17, fontWeight: FontWeight.w800),
          ),
          if (showChange) ...[
            const SizedBox(height: 4),
            Text(
              changeStr,
              maxLines: 1,
              style: TextStyle(
                color: isUp ? AppColors.success : AppColors.error,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
