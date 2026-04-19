import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../utils/app_colors.dart';

class MiniSalesChart extends StatelessWidget {
  final List<dynamic> data;

  const MiniSalesChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final spots = _buildSpots();
    return Container(
      height: 200,
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: spots.isEmpty
          ? const Center(child: Text('No data', style: TextStyle(color: AppColors.greyDark, fontSize: 13)))
          : LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => const FlLine(
                    color: AppColors.border,
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, _) => _bottomTitle(v),
                      reservedSize: 24,
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: AppColors.white,
                    barWidth: 2.5,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                        radius: 3,
                        color: AppColors.white,
                        strokeWidth: 1.5,
                        strokeColor: AppColors.bg,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.white.withOpacity(0.15),
                          AppColors.white.withOpacity(0.0),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  List<FlSpot> _buildSpots() {
    if (data.isEmpty) return _demoSpots();
    return data.asMap().entries.map((e) {
      final val = (e.value['sales'] as num?)?.toDouble() ?? 0;
      return FlSpot(e.key.toDouble(), val);
    }).toList();
  }

  List<FlSpot> _demoSpots() {
    return const [
      FlSpot(0, 40), FlSpot(1, 65), FlSpot(2, 50),
      FlSpot(3, 80), FlSpot(4, 70), FlSpot(5, 95),
      FlSpot(6, 85),
    ];
  }

  Widget _bottomTitle(double value) {
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final i = value.toInt();
    if (i < 0 || i >= labels.length) return const SizedBox.shrink();
    return Text(
      labels[i],
      style: const TextStyle(color: AppColors.greyDark, fontSize: 10),
    );
  }
}
