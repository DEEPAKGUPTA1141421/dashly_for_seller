import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';

/// "Product views" card: a monthly bar chart of view counts. Shared by the
/// Analytics screen and the Earnings tab.
class ProductViewsCard extends StatelessWidget {
  final List<dynamic> monthlyViews;
  const ProductViewsCard({super.key, required this.monthlyViews});

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Product views',
            style: TextStyle(color: AppColors.white, fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          monthlyViews.isEmpty ? const _EmptyChart() : _ViewsChart(data: monthlyViews),
        ],
      ),
    );
  }
}

class _ViewsChart extends StatelessWidget {
  final List<dynamic> data;
  const _ViewsChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final maxViews = data
        .map((e) => ((e as Map)['views'] as num? ?? 0).toDouble())
        .fold<double>(1, (a, b) => b > a ? b : a);
    final chartMax = maxViews * 1.15;

    return SizedBox(
      height: 220,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: chartMax,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (_, __, rod, ___) => BarTooltipItem(
                '${rod.toY.toStringAsFixed(0)} views',
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
                  final month = (data[idx] as Map)['month']?.toString() ?? '';
                  final label = _monthLabel(month);
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
            final views = ((e.value as Map)['views'] as num? ?? 0).toDouble();
            return BarChartGroupData(
              x: e.key,
              barRods: [
                BarChartRodData(
                  toY: views,
                  color: AppColors.chartPalette[0],
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

  String _monthLabel(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return months[d.month - 1];
  }
}

class _EmptyChart extends StatelessWidget {
  const _EmptyChart();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 220,
      child: Center(
        child: Text('No order data yet', style: TextStyle(color: AppColors.grey, fontSize: 13)),
      ),
    );
  }
}
