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

class MainLayout extends ConsumerStatefulWidget {
  const MainLayout({super.key});

  @override
  ConsumerState<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends ConsumerState<MainLayout> {
  static const _screenBuilders = [
    DashboardScreen(),
    OrdersScreen(),
    ProductsScreen(),
    AnalyticsScreen(),
    SettingsScreen(),
  ];

  // Tracks which tabs have been opened at least once.
  // Only tab 0 (Dashboard) loads on startup.
  final Set<int> _visited = {0};

  @override
  Widget build(BuildContext context) {
    final index = ref.watch(navIndexPod);

    // Mark this tab as visited the first time the user opens it.
    _visited.add(index);

    return Scaffold(
      body: IndexedStack(
        index: index,
        children: List.generate(
          _screenBuilders.length,
          (i) => _visited.contains(i) ? _screenBuilders[i] : const SizedBox.shrink(),
        ),
      ),
      bottomNavigationBar: SellerBottomNav(
        currentIndex: index,
        onTap: (i) => ref.read(navIndexPod.notifier).state = i,
      ),
    );
  }
}
