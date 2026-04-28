import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/dashboard_screen.dart';
import 'screens/orders_screen.dart';
import 'screens/products_screen.dart';
import 'screens/analytics_screen.dart';
import 'screens/settings_screen.dart';
import 'widgets/bottom_nav.dart';

// Global nav-index pod — any screen can read/write the active tab.
final navIndexPod = StateProvider<int>((ref) => 0);

class MainLayout extends ConsumerWidget {
  const MainLayout({super.key});

  static final _screens = <Widget>[
    const DashboardScreen(),
    const OrdersScreen(),
    const ProductsScreen(),
    const AnalyticsScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(navIndexPod);
    return Scaffold(
      body: IndexedStack(
        index: index,
        children: _screens,
      ),
      bottomNavigationBar: SellerBottomNav(
        currentIndex: index,
        onTap: (i) => ref.read(navIndexPod.notifier).state = i,
      ),
    );
  }
}
