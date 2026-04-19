import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../core/widgets/app_shimmer.dart';
import '../providers/dashboard_provider.dart';
import '../providers/onboarding_provider.dart';
import '../utils/app_colors.dart';
import '../utils/haptic_utils.dart';
import '../widgets/stat_card.dart';
import '../widgets/mini_sales_chart.dart';
import '../widgets/order_list_tile.dart';

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
      await ref.read(onboardingPod.notifier).checkOnboardingStatus();
      ref.read(dashboardPod.notifier).fetchDashboard();
    });
  }

  Future<void> _refresh() async {
    HapticUtils.light();
    await ref.read(dashboardPod.notifier).fetchDashboard();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dashboardPod);
    final onboarding = ref.watch(onboardingPod);
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
                            'Good ${_greeting()},',
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
                      _IconButton(
                        icon: Icons.notifications_outlined,
                        onTap: () {},
                        badge: (state.alerts.isNotEmpty) ? state.alerts.length : null,
                      ),
                    ],
                  ).animate().fadeIn(),
                ),
              ),

              // Profile incomplete banner
              if (!onboarding.isComplete)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: _ProfileIncompleteBanner(
                      onTap: () => Navigator.pushNamed(context, '/onboarding'),
                    ),
                  ).animate().fadeIn(),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // Stat cards
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 120,
                  child: state.isLoading
                      ? ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: 4,
                          separatorBuilder: (_, __) => const SizedBox(width: 12),
                          itemBuilder: (_, __) => const SizedBox(width: 160, child: StatCardShimmer()),
                        )
                      : ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
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

              const SliverToBoxAdapter(child: SizedBox(height: 28)),

              // Sales chart
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
                        onTap: () => HapticUtils.light(),
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

class _IconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final int? badge;

  const _IconButton({required this.icon, required this.onTap, this.badge});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticUtils.light();
        onTap();
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(icon, color: AppColors.white, size: 20),
          ),
          if (badge != null)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                width: 18,
                height: 18,
                decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
                child: Center(
                  child: Text(
                    '$badge',
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProfileIncompleteBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _ProfileIncompleteBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
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
                  'Profile Incomplete',
                  style: TextStyle(color: AppColors.white, fontSize: 14, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 2),
                Text(
                  'Complete your profile to start selling',
                  style: TextStyle(color: AppColors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              HapticUtils.light();
              onTap();
            },
            child: Container(
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
          ),
        ],
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
