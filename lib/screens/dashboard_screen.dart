import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../core/widgets/app_shimmer.dart';
import '../main_layout.dart';
import '../providers/dashboard_provider.dart';
import '../providers/notifications_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/app_colors.dart';
import '../utils/haptic_utils.dart';
import '../utils/storage_service.dart';
import '../widgets/stat_card.dart';
import '../widgets/mini_sales_chart.dart';
import '../widgets/order_list_tile.dart';
import 'auth/location_screen.dart';
import 'earnings_screen.dart';
import 'notifications_screen.dart';

final _displayNamePod = FutureProvider<String>((ref) async =>
    await StorageService.getDisplayName() ?? '');

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      ref.read(dashboardPod.notifier).fetchDashboard();
      ref.read(notificationsPod.notifier).fetchNotifications();
      if (ref.read(settingsPod).onboardingStage == null) {
        ref.read(settingsPod.notifier).fetchAll();
      }
    });
  }

  Future<void> _refresh() async {
    HapticUtils.light();
    await ref.read(dashboardPod.notifier).fetchDashboard();
  }

  @override
  Widget build(BuildContext context) {
    final state    = ref.watch(dashboardPod);
    final settings = ref.watch(settingsPod);

    if (settings.isLoading && settings.personal.isEmpty) {
      return const Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(child: CircularProgressIndicator(color: AppColors.white)),
      );
    }

    if (settings.onboardingStage == 'RESGISTER') {
      return const LocationSetupScreen();
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          color: AppColors.white,
          backgroundColor: AppColors.surface,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // App bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Good ${_greeting()}, ${ref.watch(_displayNamePod).valueOrNull ?? ''}',
                            style: const TextStyle(color: AppColors.grey, fontSize: 13),
                          ),
                          const Text(
                            'Dashboard',
                            style: TextStyle(
                              color: AppColors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      // Notification bell
                      _BellButton(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                        ),
                      ),
                    ],
                  ).animate().fadeIn(),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              // Onboarding incomplete banner
              if (!settings.onboardingComplete)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                    child: _OnboardingBanner(
                      onTap: () {
                        HapticUtils.light();
                        ref.read(navIndexPod.notifier).state = 4;
                      },
                    ),
                  ).animate().fadeIn(),
                ),

              // Needs-attention banner (CONFIRMED orders awaiting acceptance)
              if (!state.isLoading && (state.stats['pendingOrders'] as num? ?? 0) > 0)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                    child: _NeedsAttentionBanner(
                      count: (state.stats['pendingOrders'] as num).toInt(),
                      onTap: () => ref.read(navIndexPod.notifier).state = 1,
                    ),
                  ).animate().fadeIn(),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // Error state — don't show mock/zero stats when the fetch failed
              if (!state.isLoading && state.error != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    child: _DashboardErrorState(onRetry: _refresh),
                  ).animate().fadeIn(),
                ),

              // Stat cards
              if (!(!state.isLoading && state.error != null))
              SliverToBoxAdapter(
                child: state.isLoading
                    ? SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: List.generate(4, (i) => Padding(
                            padding: EdgeInsets.only(right: i < 3 ? 12 : 0),
                            child: const SizedBox(width: 155, child: StatCardShimmer()),
                          )),
                        ),
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              StatCard(
                                title: 'Total Revenue',
                                value: _formatCurrency(state.stats['totalRevenue']),
                                change: (state.stats['revenueChange'] as num?)?.toDouble() ?? 0,
                                icon: Icons.currency_rupee_rounded,
                                color: AppColors.white,
                              ),
                              const SizedBox(width: 12),
                              StatCard(
                                title: 'Total Orders',
                                value: '${state.stats['totalOrders'] ?? 0}',
                                change: (state.stats['ordersChange'] as num?)?.toDouble() ?? 0,
                                icon: Icons.shopping_bag_rounded,
                                color: AppColors.info,
                              ),
                              const SizedBox(width: 12),
                              StatCard(
                                title: 'Products',
                                value: '${state.stats['totalProducts'] ?? 0}',
                                change: (state.stats['productsChange'] as num?)?.toDouble() ?? 0,
                                icon: Icons.inventory_2_rounded,
                                color: AppColors.success,
                              ),
                              const SizedBox(width: 12),
                              StatCard(
                                title: 'Pending',
                                value: '${state.stats['pendingOrders'] ?? 0}',
                                change: (state.stats['pendingChange'] as num?)?.toDouble() ?? 0,
                                icon: Icons.local_shipping_rounded,
                                color: AppColors.warning,
                              ),
                            ],
                          ),
                        ),
                      ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 28)),

              // Sales chart
              if (state.isLoading || state.error == null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Sales Overview',
                          style: TextStyle(
                            color: AppColors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 16),
                        state.isLoading
                            ? const AppShimmer(child: ShimmerBox(height: 200))
                            : MiniSalesChart(data: state.salesChart),
                      ],
                    ).animate().fadeIn(delay: 100.ms),
                  ),
                ),

              if (state.isLoading || state.error == null) const SliverToBoxAdapter(child: SizedBox(height: 28)),

              // Earnings card
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _EarningsCard(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const EarningsScreen()),
                    ),
                  ),
                ).animate().fadeIn(delay: 120.ms),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 28)),

              // Alerts
              if (state.alerts.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Quick Alerts',
                          style: TextStyle(color: AppColors.white, fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 12),
                        ...state.alerts.take(3).map((a) => _AlertTile(alert: a as Map)),
                      ],
                    ).animate().fadeIn(delay: 150.ms),
                  ),
                ),

              if (state.alerts.isNotEmpty) const SliverToBoxAdapter(child: SizedBox(height: 28)),

              // Recent orders
              if (state.isLoading || state.error == null) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        const Text(
                          'Recent Orders',
                          style: TextStyle(color: AppColors.white, fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () {
                            HapticUtils.light();
                            ref.read(navIndexPod.notifier).state = 1; // Orders tab
                          },
                          child: const Text(
                            'See all',
                            style: TextStyle(color: AppColors.grey, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 12)),

                if (state.isLoading)
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, __) => const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                        child: OrderItemShimmer(),
                      ),
                      childCount: 4,
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                        child: OrderListTile(order: state.recentOrders[i] as Map),
                      ),
                      childCount: state.recentOrders.length,
                    ),
                  ),
              ],

              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'morning';
    if (hour < 17) return 'afternoon';
    return 'evening';
  }

  String _formatCurrency(dynamic value) {
    if (value == null) return '₹0';
    final amount = (value as num).toDouble();
    return '₹${NumberFormat.compact().format(amount)}';
  }
}

class _DashboardErrorState extends StatelessWidget {
  final Future<void> Function() onRetry;
  const _DashboardErrorState({required this.onRetry});

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
        children: [
          const Icon(Icons.cloud_off_rounded, color: AppColors.grey, size: 32),
          const SizedBox(height: 10),
          const Text(
            'Couldn\'t load dashboard data',
            style: TextStyle(color: AppColors.white, fontSize: 14, fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          const Text(
            'Check your connection and try again',
            style: TextStyle(color: AppColors.grey, fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () { HapticUtils.light(); onRetry(); },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Retry',
                style: TextStyle(color: AppColors.bg, fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NeedsAttentionBanner extends StatelessWidget {
  final int count;
  final VoidCallback onTap;
  const _NeedsAttentionBanner({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () { HapticUtils.light(); onTap(); },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.warning.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.warning.withOpacity(0.35)),
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.notifications_active_rounded, color: AppColors.warning, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$count order${count > 1 ? 's' : ''} need${count == 1 ? 's' : ''} your action',
                    style: const TextStyle(color: AppColors.white, fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Tap to review and accept',
                    style: TextStyle(color: AppColors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.warning, size: 20),
          ],
        ),
      ),
    );
  }
}

class _EarningsCard extends StatelessWidget {
  final VoidCallback onTap;
  const _EarningsCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () { HapticUtils.light(); onTap(); },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.account_balance_wallet_rounded, color: AppColors.success, size: 22),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Earnings & Wallet', style: TextStyle(color: AppColors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                  SizedBox(height: 2),
                  Text('View balance & transactions', style: TextStyle(color: AppColors.grey, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.greyDark, size: 20),
          ],
        ),
      ),
    );
  }
}

class _BellButton extends ConsumerWidget {
  final VoidCallback onTap;
  const _BellButton({required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(notificationsPod).unreadCount;
    return GestureDetector(
      onTap: () { HapticUtils.light(); onTap(); },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(Icons.notifications_outlined, color: AppColors.white, size: 20),
          ),
          if (unread > 0)
            Positioned(
              right: -4, top: -4,
              child: Container(
                width: 18, height: 18,
                decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
                child: Center(
                  child: Text(
                    unread > 9 ? '9+' : '$unread',
                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}


class _OnboardingBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _OnboardingBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.warning.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.warning.withOpacity(0.35)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.person_outline_rounded, color: AppColors.warning, size: 20),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Complete Your Profile',
                    style: TextStyle(color: AppColors.white, fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Finish onboarding to start selling on Dashly',
                    style: TextStyle(color: AppColors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.warning,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Complete',
                style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlertTile extends StatelessWidget {
  final Map alert;
  const _AlertTile({required this.alert});

  @override
  Widget build(BuildContext context) {
    final type = alert['type'] as String? ?? 'info';
    final color = type == 'warning' ? AppColors.warning
        : type == 'error' ? AppColors.error
        : AppColors.info;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              alert['message'] as String? ?? '',
              style: TextStyle(color: color, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
