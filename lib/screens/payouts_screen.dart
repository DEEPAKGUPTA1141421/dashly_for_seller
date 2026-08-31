import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/responsive.dart';
import '../core/widgets/app_shimmer.dart';
import '../core/widgets/app_toast.dart';
import '../models/balance_stat.dart';
import '../providers/earnings_provider.dart';
import '../providers/payouts_provider.dart';
import '../utils/app_colors.dart';
import '../utils/haptic_utils.dart';
import '../widgets/invoice/payout_history_table.dart';

class PayoutsScreen extends ConsumerStatefulWidget {
  const PayoutsScreen({super.key});

  @override
  ConsumerState<PayoutsScreen> createState() => _PayoutsScreenState();
}

class _PayoutsScreenState extends ConsumerState<PayoutsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (ref.read(earningsPod).stats.isEmpty) {
        ref.read(earningsPod.notifier).fetchSummary();
      }
      ref.read(payoutsPod.notifier).fetchPage(0);
    });
  }

  BalanceStat? _find(List<BalanceStat> stats, String label) {
    for (final s in stats) {
      if (s.label == label) return s;
    }
    return null;
  }

  void _withdraw() {
    HapticUtils.light();
    AppToast.show(context, message: 'Withdrawals aren\'t available yet — check back soon.', type: ToastType.info);
  }

  @override
  Widget build(BuildContext context) {
    final earnings = ref.watch(earningsPod);
    final payouts  = ref.watch(payoutsPod);
    final hPad     = Responsive.horizontalPadding(context);

    final earned  = _find(earnings.stats, 'Earning')?.value ?? '0.00';
    final balance = _find(earnings.stats, 'Balance')?.value ?? '0.00';

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Payouts', style: TextStyle(color: AppColors.white, fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.3)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.divider),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 32),
          children: [
            earnings.isLoading
                ? const AppShimmer(child: ShimmerBox(height: 120))
                : _CurrentBalanceCard(earned: earned, balance: balance, onWithdraw: _withdraw).animate().fadeIn(),
            const SizedBox(height: 24),
            const Text('Payout history', style: TextStyle(color: AppColors.white, fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            PayoutHistoryTable(
              history: payouts.history,
              isLoading: payouts.isLoading,
              page: payouts.page,
              hasMore: payouts.hasMore,
              onPrevious: () {
                HapticUtils.light();
                ref.read(payoutsPod.notifier).previous();
              },
              onNext: () {
                HapticUtils.light();
                ref.read(payoutsPod.notifier).next();
              },
            ).animate().fadeIn(delay: 80.ms),
          ],
        ),
      ),
    );
  }
}

class _CurrentBalanceCard extends StatelessWidget {
  final String earned;
  final String balance;
  final VoidCallback onWithdraw;
  const _CurrentBalanceCard({required this.earned, required this.balance, required this.onWithdraw});

  @override
  Widget build(BuildContext context) {
    final twoCol = Responsive.isDesktop(context);

    final stats = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _StatBlock(icon: Icons.bolt_rounded, color: AppColors.success, label: 'Current account balance', value: '₹$earned')),
        Container(width: 1, height: 44, color: AppColors.border, margin: const EdgeInsets.symmetric(horizontal: 12)),
        Expanded(child: _StatBlock(icon: Icons.adjust_rounded, color: AppColors.warning, label: 'Available for withdrawal', value: '₹$balance')),
      ],
    );

    final button = SizedBox(
      width: twoCol ? null : double.infinity,
      child: ElevatedButton(
        onPressed: onWithdraw,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: const Text('Withdraw balance', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      ),
    );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Current balance', style: TextStyle(color: AppColors.white, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          if (twoCol)
            Row(
              children: [
                Expanded(child: stats),
                const SizedBox(width: 20),
                button,
              ],
            )
          else ...[
            stats,
            const SizedBox(height: 18),
            button,
          ],
        ],
      ),
    );
  }
}

class _StatBlock extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  const _StatBlock({required this.icon, required this.color, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 30, height: 30,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Icon(icon, color: Colors.white, size: 15),
        ),
        const SizedBox(height: 10),
        Text(label, style: const TextStyle(color: AppColors.grey, fontSize: 11.5, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(value, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.white, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
      ],
    );
  }
}
