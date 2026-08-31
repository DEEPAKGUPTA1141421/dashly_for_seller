import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../utils/app_colors.dart';

class TotalCustomersCard extends StatelessWidget {
  final Map<String, dynamic> customerStats;

  const TotalCustomersCard({super.key, required this.customerStats});

  @override
  Widget build(BuildContext context) {
    final total  = (customerStats['totalCustomers'] as num?)?.toInt() ?? 0;
    final change = (customerStats['customersChangePercent'] as num?)?.toDouble() ?? 0.0;
    final trend  = (customerStats['monthlyTrend'] as List<dynamic>?) ?? const [];
    final isPositive = change >= 0;

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
          const Text('Total customers',
              style: TextStyle(color: AppColors.white, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          Text('$total customers',
              style: const TextStyle(color: AppColors.white, fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(isPositive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                  color: isPositive ? AppColors.success : AppColors.error, size: 15),
              const SizedBox(width: 4),
              Text('${isPositive ? '+' : ''}${change.toStringAsFixed(1)}%',
                  style: TextStyle(color: isPositive ? AppColors.success : AppColors.error, fontSize: 12, fontWeight: FontWeight.w700)),
              const SizedBox(width: 6),
              const Text('vs previous period', style: TextStyle(color: AppColors.grey, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 160,
            child: trend.isEmpty
                ? const Center(
                    child: Text('No customer data yet',
                        style: TextStyle(color: AppColors.grey, fontSize: 13)))
                : LineChart(
                    LineChartData(
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
                              if (i < 0 || i >= trend.length) return const SizedBox.shrink();
                              return Text(_monthLabel(trend[i]),
                                  style: const TextStyle(color: AppColors.greyDark, fontSize: 10));
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: trend.asMap().entries.map((e) {
                            final c = (e.value['customers'] as num?)?.toDouble() ?? 0;
                            return FlSpot(e.key.toDouble(), c);
                          }).toList(),
                          isCurved: true,
                          color: AppColors.chartPalette[0],
                          barWidth: 2.5,
                          isStrokeCapRound: true,
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                              radius: 3,
                              color: AppColors.chartPalette[0],
                              strokeWidth: 1.5,
                              strokeColor: AppColors.surface,
                            ),
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                AppColors.chartPalette[0].withOpacity(0.18),
                                AppColors.chartPalette[0].withOpacity(0.0),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    ).animate().fadeIn();
  }

  static String _monthLabel(dynamic entry) {
    final raw = entry['month'] as String? ?? '';
    if (raw.length < 7) return raw;
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    try {
      final month = int.parse(raw.substring(5, 7));
      return months[month - 1];
    } catch (_) {
      return raw;
    }
  }
}
