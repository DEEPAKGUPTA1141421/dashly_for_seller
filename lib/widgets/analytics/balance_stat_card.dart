import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/balance_stat.dart';
import '../../utils/app_colors.dart';

/// A single "Current balance" tile (Earning / Customer / Payouts): icon chip,
/// label, big value, %-change line, and an axis-less sparkline on the right.
/// Matches the Figma "Bredar" reference cards.
class BalanceStatCard extends StatelessWidget {
  final BalanceStat stat;
  final IconData icon;
  final Color color;

  const BalanceStatCard({
    super.key,
    required this.stat,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isUp = stat.changePct >= 0;
    final changeColor = isUp ? AppColors.success : AppColors.error;

    return Container(
      constraints: const BoxConstraints(minWidth: 220),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  child: Icon(icon, color: Colors.white, size: 17),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      stat.label,
                      style: const TextStyle(color: AppColors.grey, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.info_outline_rounded, color: AppColors.greyDark, size: 12),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  stat.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isUp ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                      color: changeColor,
                      size: 12,
                    ),
                    const SizedBox(width: 2),
                    Flexible(
                      child: Text(
                        '${stat.changePct.abs().toStringAsFixed(1)}% this week',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: changeColor, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 64,
            height: 34,
            child: _Sparkline(values: stat.sparkline, color: color),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.05, end: 0, duration: 300.ms, curve: Curves.easeOut);
  }
}

class _Sparkline extends StatelessWidget {
  final List<double> values;
  final Color color;
  const _Sparkline({required this.values, required this.color});

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty || values.every((v) => v == 0)) {
      return const SizedBox.shrink();
    }
    final spots = values.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList();

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        minY: values.reduce((a, b) => a < b ? a : b) * 0.9,
        maxY: values.reduce((a, b) => a > b ? a : b) * 1.1,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: color,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: false),
          ),
        ],
      ),
    );
  }
}
