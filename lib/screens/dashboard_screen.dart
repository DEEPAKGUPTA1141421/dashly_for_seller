import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../core/theme/responsive.dart';
import '../core/widgets/app_shimmer.dart';
import '../main_layout.dart';
import '../providers/dashboard_provider.dart';
import '../providers/notifications_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/app_colors.dart';
import '../utils/haptic_utils.dart';
import '../utils/storage_service.dart';
import '../widgets/stat_card.dart';
import '../widgets/order_list_tile.dart';
import '../widgets/dashboard/total_customers_card.dart';
import '../widgets/dashboard/new_customer_donut_card.dart';
import '../widgets/dashboard/sales_trend_card.dart';
import '../widgets/dashboard/popular_products_card.dart';
import '../widgets/dashboard/comments_card.dart';
import '../widgets/dashboard/cancelled_orders_card.dart';
import '../widgets/dashboard/pro_tips_card.dart';
import '../widgets/dashboard/share_shop_card.dart';
import 'auth/location_screen.dart';
import 'notifications_screen.dart';
import 'reviews_screen.dart';
import 'settings_screen.dart';

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
    final hPad     = Responsive.horizontalPadding(context);
    final twoCol   = !Responsive.isMobile(context);

    if (settings.isLoading && settings.personal.isEmpty) {
      return const Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(child: CircularProgressIndicator(color: AppColors.accent)),
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
          color: AppColors.accent,
          backgroundColor: AppColors.surface,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // App bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(hPad, 20, hPad, 0),
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

              if (!settings.onboardingComplete)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 0),
                    child: _OnboardingBanner(
                      onTap: () {
                        HapticUtils.light();
                        ref.read(navIndexPod.notifier).state = 4;
                      },
                    ),
                  ).animate().fadeIn(),
                ),

              if (!state.isLoading && (state.stats['pendingOrders'] as num? ?? 0) > 0)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 0),
                    child: _NeedsAttentionBanner(
                      count: (state.stats['pendingOrders'] as num).toInt(),
                      onTap: () => ref.read(navIndexPod.notifier).state = 1,
                    ),
                  ).animate().fadeIn(),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              if (!state.isLoading && state.error != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 24),
                    child: _DashboardErrorState(onRetry: _refresh),
                  ).animate().fadeIn(),
                ),

              // Stat cards (2 per row)
              if (!(!state.isLoading && state.error != null))
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: hPad),
                    child: state.isLoading
                        ? const Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(child: SizedBox(height: 110, child: StatCardShimmer())),
                                  SizedBox(width: 12),
                                  Expanded(child: SizedBox(height: 110, child: StatCardShimmer())),
                                ],
                              ),
                              SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(child: SizedBox(height: 110, child: StatCardShimmer())),
                                  SizedBox(width: 12),
                                  Expanded(child: SizedBox(height: 110, child: StatCardShimmer())),
                                ],
                              ),
                            ],
                          )
                        : Column(
                            children: [
                              IntrinsicHeight(
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                  Expanded(
                                    child: StatCard(
                                      width: null,
                                      title: 'Total Revenue',
                                      value: _formatCurrency(state.stats['totalRevenue']),
                                      change: (state.stats['revenueChange'] as num?)?.toDouble() ?? 0,
                                      icon: Icons.currency_rupee_rounded,
                                      color: AppColors.accent,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: StatCard(
                                      width: null,
                                      title: 'Total Orders',
                                      value: '${state.stats['totalOrders'] ?? 0}',
                                      change: (state.stats['ordersChange'] as num?)?.toDouble() ?? 0,
                                      icon: Icons.shopping_bag_rounded,
                                      color: AppColors.info,
                                    ),
                                  ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              IntrinsicHeight(
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                  Expanded(
                                    child: StatCard(
                                      width: null,
                                      title: 'Products',
                                      value: '${state.stats['totalProducts'] ?? 0}',
                                      change: (state.stats['productsChange'] as num?)?.toDouble() ?? 0,
                                      icon: Icons.inventory_2_rounded,
                                      color: AppColors.success,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: StatCard(
                                      width: null,
                                      title: 'Pending',
                                      value: '${state.stats['pendingOrders'] ?? 0}',
                                      change: (state.stats['pendingChange'] as num?)?.toDouble() ?? 0,
                                      icon: Icons.local_shipping_rounded,
                                      color: AppColors.warning,
                                    ),
                                  ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 28)),

              // Alerts
              if (state.alerts.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: hPad),
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

              // Figma-matched insight cards
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: hPad),
                  child: state.isLoading
                      ? const Column(
                          children: [
                            AppShimmer(child: ShimmerBox(height: 260)),
                            SizedBox(height: 16),
                            AppShimmer(child: ShimmerBox(height: 220)),
                          ],
                        )
                      : (twoCol
                          ? _TwoColumnInsights(state: state, settings: settings, onGoTo: _goTo)
                          : _SingleColumnInsights(state: state, settings: settings, onGoTo: _goTo)),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 28)),

              // Recent orders
              if (state.isLoading || state.error == null) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: hPad),
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
                            ref.read(navIndexPod.notifier).state = 1;
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
                      (_, __) => Padding(
                        padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 6),
                        child: const OrderItemShimmer(),
                      ),
                      childCount: 4,
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => Padding(
                        padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 4),
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

  void _goTo(int tabIndex) {
    ref.read(navIndexPod.notifier).state = tabIndex;
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

/// Mobile stacking order, matching the Figma reference screenshots:
/// Total customers → Sales trend → Pro tips → Get more customers →
/// New customer → Comments → Popular products → Cancelled/refunded.
class _SingleColumnInsights extends StatelessWidget {
  final DashboardState state;
  final SettingsState settings;
  final void Function(int) onGoTo;
  const _SingleColumnInsights({required this.state, required this.settings, required this.onGoTo});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TotalCustomersCard(customerStats: state.customerStats),
        const SizedBox(height: 16),
        SalesTrendCard(salesChart: state.salesChart),
        const SizedBox(height: 16),
        ProTipsCard(tips: _proTips(context, onGoTo)),
        const SizedBox(height: 16),
        ShareShopCard(
          sellerName: settings.personal['displayName'] as String? ?? settings.personal['fullName'] as String?,
          totalProducts: (state.stats['totalProducts'] as num?)?.toInt(),
          totalCustomers: (state.customerStats['totalCustomers'] as num?)?.toInt(),
          coverImageUrl: settings.personal['profile_image'] as String?,
        ),
        const SizedBox(height: 16),
        NewCustomerDonutCard(customerStats: state.customerStats),
        const SizedBox(height: 16),
        CommentsCard(
          reviews: state.recentReviews,
          onViewAll: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReviewsScreen())),
        ),
        const SizedBox(height: 16),
        PopularProductsCard(topProducts: state.topProducts, onSeeAll: () => onGoTo(3)),
        const SizedBox(height: 16),
        CancelledOrdersCard(statusCounts: state.statusCounts, onTap: () => onGoTo(1)),
      ],
    );
  }
}

/// Desktop/tablet two-column layout, matching the Figma reference screenshots:
/// left column = Total customers, Sales trend, Pro tips, Get more customers.
/// right column = New customer, Comments, Popular products, Cancelled/refunded.
class _TwoColumnInsights extends StatelessWidget {
  final DashboardState state;
  final SettingsState settings;
  final void Function(int) onGoTo;
  const _TwoColumnInsights({required this.state, required this.settings, required this.onGoTo});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: Column(
            children: [
              TotalCustomersCard(customerStats: state.customerStats),
              const SizedBox(height: 16),
              SalesTrendCard(salesChart: state.salesChart),
              const SizedBox(height: 16),
              ProTipsCard(tips: _proTips(context, onGoTo)),
              const SizedBox(height: 16),
              ShareShopCard(
                sellerName: settings.personal['displayName'] as String? ?? settings.personal['fullName'] as String?,
                totalProducts: (state.stats['totalProducts'] as num?)?.toInt(),
                totalCustomers: (state.customerStats['totalCustomers'] as num?)?.toInt(),
                coverImageUrl: settings.personal['profile_image'] as String?,
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: Column(
            children: [
              NewCustomerDonutCard(customerStats: state.customerStats),
              const SizedBox(height: 16),
              CommentsCard(
                reviews: state.recentReviews,
                onViewAll: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReviewsScreen())),
              ),
              const SizedBox(height: 16),
              PopularProductsCard(topProducts: state.topProducts, onSeeAll: () => onGoTo(3)),
              const SizedBox(height: 16),
              CancelledOrdersCard(statusCounts: state.statusCounts, onTap: () => onGoTo(1)),
            ],
          ),
        ),
      ],
    );
  }
}

List<ProTip> _proTips(BuildContext context, void Function(int) onGoTo) => [
      ProTip(
        icon: Icons.verified_user_outlined,
        title: 'Complete your KYC to unlock full payouts',
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
      ),
      ProTip(
        icon: Icons.photo_camera_outlined,
        title: 'Add clear product photos to boost conversions',
        onTap: () => onGoTo(3),
      ),
      ProTip(
        icon: Icons.inventory_2_outlined,
        title: 'Restock low-inventory products before you run out',
        onTap: () => onGoTo(3),
      ),
      ProTip(
        icon: Icons.reviews_outlined,
        title: 'Respond to customer reviews to build trust',
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReviewsScreen())),
      ),
    ];

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
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Retry',
                style: TextStyle(color: AppColors.surface, fontSize: 13, fontWeight: FontWeight.w700),
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
