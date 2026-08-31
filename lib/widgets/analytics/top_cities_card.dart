import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';

/// "Top cities" card — the Figma reference's "Top countries" adapted to a
/// domestic marketplace. Shared by the Analytics screen and the Earnings tab.
class TopCitiesCard extends StatelessWidget {
  final List<dynamic> cities;
  const TopCitiesCard({super.key, required this.cities});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Top cities', style: TextStyle(color: AppColors.white, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          if (cities.isEmpty)
            const Center(child: Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Text('No location data yet', style: TextStyle(color: AppColors.grey, fontSize: 12)),
            ))
          else
            ...cities.map((raw) {
              final c = raw as Map;
              final city = (c['city'] as String?) ?? 'Unknown';
              final pct  = (c['percent'] as num?)?.toDouble() ?? 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(city, style: const TextStyle(color: AppColors.white, fontSize: 12.5))),
                        Text('${pct.toStringAsFixed(1)}%', style: const TextStyle(color: AppColors.grey, fontSize: 11)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct / 100,
                        backgroundColor: AppColors.surface2,
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.info),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
