import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../utils/app_colors.dart';

class NewCustomerDonutCard extends StatelessWidget {
  final Map<String, dynamic> customerStats;

  const NewCustomerDonutCard({super.key, required this.customerStats});

  @override
  Widget build(BuildContext context) {
    final newC = (customerStats['newCustomers'] as num?)?.toInt() ?? 0;
    final retC = (customerStats['returningCustomers'] as num?)?.toInt() ?? 0;
    final total = newC + retC;

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
          const Text('New customer',
              style: TextStyle(color: AppColors.white, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 18),
          SizedBox(
            height: 160,
            child: total == 0
                ? const Center(
                    child: Text('No customers yet this period',
                        style: TextStyle(color: AppColors.grey, fontSize: 13)))
                : Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          sectionsSpace: 3,
                          centerSpaceRadius: 46,
                          sections: [
                            PieChartSectionData(
                              value: newC.toDouble(),
                              color: AppColors.chartPalette[2],
                              showTitle: false,
                              radius: 26,
                            ),
                            PieChartSectionData(
                              value: retC.toDouble(),
                              color: AppColors.chartPalette[3],
                              showTitle: false,
                              radius: 26,
                            ),
                          ],
                        ),
                      ),
                      Text('$newC',
                          style: const TextStyle(color: AppColors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                    ],
                  ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _Legend(color: AppColors.chartPalette[2], label: 'New customer'),
              const SizedBox(width: 18),
              _Legend(color: AppColors.chartPalette[3], label: 'Returning customer'),
            ],
          ),
        ],
      ),
    ).animate().fadeIn();
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: AppColors.grey, fontSize: 12)),
      ],
    );
  }
}
