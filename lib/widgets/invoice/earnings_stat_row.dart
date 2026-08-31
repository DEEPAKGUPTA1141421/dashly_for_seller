import 'package:flutter/material.dart';
import '../../core/theme/responsive.dart';
import '../../models/balance_stat.dart';
import '../../utils/app_colors.dart';
import '../analytics/balance_stat_card.dart';

/// The Earnings tab's top row of three stat cards: Earning, Balance, Total value of sales.
class EarningsStatRow extends StatelessWidget {
  final List<BalanceStat> stats;
  const EarningsStatRow({super.key, required this.stats});

  static const _icons = {
    'Earning': (Icons.bolt_rounded, AppColors.warning),
    'Balance': (Icons.adjust_rounded, AppColors.error),
    'Total value of sales': (Icons.shopping_cart_rounded, AppColors.success),
  };

  BalanceStat? _find(String label) {
    for (final s in stats) {
      if (s.label == label) return s;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final labels = ['Earning', 'Balance', 'Total value of sales'];
    final cards = labels.map((label) {
      final stat = _find(label) ?? BalanceStat(label: label, value: '0.00', changePct: 0, sparkline: const []);
      final (icon, color) = _icons[label]!;
      return BalanceStatCard(
        stat: BalanceStat(label: label, value: '₹${stat.value}', changePct: stat.changePct, sparkline: stat.sparkline),
        icon: icon,
        color: color,
      );
    }).toList();

    if (Responsive.isDesktop(context)) {
      return Row(
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            if (i > 0) const SizedBox(width: 16),
            Expanded(child: cards[i]),
          ],
        ],
      );
    }

    return Column(
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          cards[i],
        ],
      ],
    );
  }
}
