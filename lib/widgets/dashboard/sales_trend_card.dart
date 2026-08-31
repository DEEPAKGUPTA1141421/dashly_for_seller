import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../utils/app_colors.dart';

/// Daily orders + revenue bar chart. Repurposes the Figma "Product views"
/// slot — there's no real product-view analytics pipeline in the backend,
/// so this shows real Sales Trend data instead (orders vs revenue/day).
class SalesTrendCard extends StatelessWidget {
  final List<dynamic> salesChart;

  const SalesTrendCard({super.key, required this.salesChart});

  @override
  Widget build(BuildContext context) {
    final maxRevenue = salesChart.isEmpty
        ? 0.0
        : salesChart
            .map((e) => ((e['revenuePaise'] as num?)?.toDouble() ?? 0) / 100)
            .reduce((a, b) => a > b ? a : b);

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
          const Text('Sales trend',
              style: TextStyle(color: AppColors.white, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 18),
          SizedBox(
            height: 160,
            child: salesChart.isEmpty
                ? const Center(
                    child: Text('No sales data available for this period',
                        style: TextStyle(color: AppColors.grey, fontSize: 13)))
                : BarChart(
                    BarChartData(
                      maxY: maxRevenue == 0 ? 10 : maxRevenue * 1.2,
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.border, strokeWidth: 1),
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 22,
                            getTitlesWidget: (v, _) {
                              final i = v.toInt();
                              if (i < 0 || i >= salesChart.length) return const SizedBox.shrink();
                              return Text(_dayLabel(salesChart[i]),
                                  style: const TextStyle(color: AppColors.greyDark, fontSize: 10));
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: salesChart.asMap().entries.map((e) {
                        final revenue = ((e.value['revenuePaise'] as num?)?.toDouble() ?? 0) / 100;
                        return BarChartGroupData(
                          x: e.key,
                          barRods: [
                            BarChartRodData(
                              toY: revenue,
                              color: AppColors.chartPalette[0],
                              width: 14,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
          ),
        ],
      ),
    ).animate().fadeIn();
  }

  static String _dayLabel(dynamic entry) {
    final day = entry['day'] as String? ?? '';
    if (day.length < 10) return day;
    try {
      final dt = DateTime.parse(day);
      const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${dt.day} ${months[dt.month - 1]}';
    } catch (_) {
      return day.length >= 10 ? day.substring(5) : day;
    }
  }
}
