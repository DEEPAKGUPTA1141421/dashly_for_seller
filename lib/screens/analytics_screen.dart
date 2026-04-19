import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../utils/app_colors.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  int _selectedPeriod = 0; // 0=Week, 1=Month, 2=Year

  // Demo data — will be replaced by API
  static const _weekRevenue = [40.0, 65.0, 50.0, 80.0, 70.0, 95.0, 85.0];
  static const _weekLabels  = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  static const _categoryData = [
    MapEntry('Electronics', 35.0),
    MapEntry('Clothing',    25.0),
    MapEntry('Home',        20.0),
    MapEntry('Books',       12.0),
    MapEntry('Others',       8.0),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: CustomScrollView(
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

            // Period toggle
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: ['Week', 'Month', 'Year'].asMap().entries.map((e) {
                      final selected = e.key == _selectedPeriod;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedPeriod = e.key),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: selected ? AppColors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              e.value,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: selected ? AppColors.bg : AppColors.grey,
                                fontSize: 13,
                                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ).animate().fadeIn(delay: 80.ms),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // Revenue summary cards
            SliverToBoxAdapter(
              child: SizedBox(
                height: 100,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    _SummaryCard(label: 'Revenue',   value: '₹2.4L', change: '+12%', positive: true),
                    const SizedBox(width: 12),
                    _SummaryCard(label: 'Orders',    value: '1,234',  change: '+8%',  positive: true),
                    const SizedBox(width: 12),
                    _SummaryCard(label: 'Avg. Order', value: '₹198',  change: '-2%',  positive: false),
                    const SizedBox(width: 12),
                    _SummaryCard(label: 'Returns',   value: '23',     change: '-5%',  positive: true),
                  ],
                ),
              ).animate().fadeIn(delay: 100.ms),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 28)),

            // Revenue chart
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Revenue Trend', style: TextStyle(color: AppColors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 16),
                    Container(
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
                          maxY: 120,
                          barTouchData: BarTouchData(
                            touchTooltipData: BarTouchTooltipData(
                              getTooltipItem: (_, __, rod, ___) => BarTooltipItem(
                                '₹${rod.toY.toInt()}k',
                                const TextStyle(color: AppColors.white, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                          titlesData: FlTitlesData(
                            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (v, _) => Text(
                                  _weekLabels[v.toInt()],
                                  style: const TextStyle(color: AppColors.greyDark, fontSize: 10),
                                ),
                              ),
                            ),
                          ),
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.border, strokeWidth: 1),
                          ),
                          borderData: FlBorderData(show: false),
                          barGroups: _weekRevenue.asMap().entries.map((e) {
                            return BarChartGroupData(
                              x: e.key,
                              barRods: [
                                BarChartRodData(
                                  toY: e.value,
                                  color: AppColors.white,
                                  width: 20,
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                                  backDrawRodData: BackgroundBarChartRodData(
                                    show: true,
                                    toY: 120,
                                    color: AppColors.surface2,
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ).animate().fadeIn(delay: 120.ms),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 28)),

            // Category breakdown
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Category Breakdown', style: TextStyle(color: AppColors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: _categoryData.asMap().entries.map((e) {
                          final pct   = e.value.value;
                          final color = AppColors.chartPalette[e.key % AppColors.chartPalette.length];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(e.value.key, style: const TextStyle(color: AppColors.white, fontSize: 13))),
                                    Text('${pct.toInt()}%', style: const TextStyle(color: AppColors.grey, fontSize: 12)),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: pct / 100,
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
                    ),
                  ],
                ).animate().fadeIn(delay: 150.ms),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final String change;
  final bool positive;

  const _SummaryCard({required this.label, required this.value, required this.change, required this.positive});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 130,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.grey, fontSize: 11)),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(color: AppColors.white, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(change, style: TextStyle(color: positive ? AppColors.success : AppColors.error, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
