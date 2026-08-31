import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/notifications/push_notification_service.dart';
import 'core/theme/responsive.dart';
import 'providers/notifications_provider.dart';
import 'screens/dashboard_screen.dart';
import 'screens/orders_screen.dart';
import 'screens/invoices_screen.dart';
import 'screens/products_screen.dart';
import 'screens/analytics_screen.dart';
import 'screens/settings_screen.dart';
import 'widgets/bottom_nav.dart';
import 'widgets/sidebar_nav.dart';

// Global nav-index pod — any screen can read/write the active tab.
final navIndexPod = StateProvider<int>((ref) => 0);

class MainLayout extends ConsumerStatefulWidget {
  const MainLayout({super.key});

  @override
  ConsumerState<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends ConsumerState<MainLayout> with WidgetsBindingObserver {
  static const _screenBuilders = [
    DashboardScreen(),
    OrdersScreen(),
    InvoicesScreen(),
    ProductsScreen(),
    AnalyticsScreen(),
    SettingsScreen(),
  ];

  // Tracks which tabs have been opened at least once.
  // Only tab 0 (Dashboard) loads on startup.
  final Set<int> _visited = {0};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Idempotent — no-ops if already initialized (e.g. from login) or if
    // Firebase isn't configured (no --dart-define values supplied).
    PushNotificationService.instance.initialize(ref.read);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(notificationsPod.notifier).fetchUnreadCount();
    }
  }

  @override
  Widget build(BuildContext context) {
    final index = ref.watch(navIndexPod);

    // Mark this tab as visited the first time the user opens it.
    _visited.add(index);

    final content = IndexedStack(
      index: index,
      children: List.generate(
        _screenBuilders.length,
        (i) => _visited.contains(i) ? _screenBuilders[i] : const SizedBox.shrink(),
      ),
    );

    final isMobile = Responsive.isMobile(context);

    return Scaffold(
      body: isMobile
          ? content
          : Row(
              children: [
                SidebarNav(
                  currentIndex: index,
                  onTap: (i) => ref.read(navIndexPod.notifier).state = i,
                ),
                Expanded(child: content),
              ],
            ),
      bottomNavigationBar: isMobile
          ? SellerBottomNav(
              currentIndex: index,
              onTap: (i) => ref.read(navIndexPod.notifier).state = i,
            )
          : null,
    );
  }
}
