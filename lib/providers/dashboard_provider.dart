import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../core/errors/app_exception.dart';

class DashboardState {
  final bool isLoading;
  final String? error;
  final Map<String, dynamic> stats;
  final List<dynamic> recentOrders;
  final List<dynamic> alerts;
  final List<dynamic> salesChart;

  const DashboardState({
    this.isLoading    = false,
    this.error,
    this.stats        = const {},
    this.recentOrders = const [],
    this.alerts       = const [],
    this.salesChart   = const [],
  });

  DashboardState copyWith({
    bool? isLoading,
    String? error,
    Map<String, dynamic>? stats,
    List<dynamic>? recentOrders,
    List<dynamic>? alerts,
    List<dynamic>? salesChart,
  }) {
    return DashboardState(
      isLoading:    isLoading    ?? this.isLoading,
      error:        error,
      stats:        stats        ?? this.stats,
      recentOrders: recentOrders ?? this.recentOrders,
      alerts:       alerts       ?? this.alerts,
      salesChart:   salesChart   ?? this.salesChart,
    );
  }
}

class DashboardNotifier extends StateNotifier<DashboardState> {
  DashboardNotifier() : super(const DashboardState());

  Dio get _productClient => ApiClient.instance.client;
  Dio get _orderClient   => ApiClient.instance.orderClient;

  Future<void> fetchDashboard() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      // Parallel: seller stats + recent orders (5) + product count
      final results = await Future.wait([
        _orderClient.get(ApiEndpoints.sellerStats, queryParameters: {'days': 7}),
        _orderClient.get(ApiEndpoints.sellerOrders, queryParameters: {'page': 0, 'size': 5}),
        _productClient.get(ApiEndpoints.sellerProducts, queryParameters: {'page': 0, 'size': 1}),
      ]);

      final statsBody   = results[0].data as Map<String, dynamic>;
      final ordersBody  = results[1].data as Map<String, dynamic>;
      final productBody = results[2].data as Map<String, dynamic>;

      final statsData  = (statsBody['data'] as Map<String, dynamic>?) ?? {};
      final ordersData = (ordersBody['data'] as Map<String, dynamic>?)?['orders'] as List<dynamic>? ?? [];
      final productCount = ((productBody['data'] as List<dynamic>?)?.length) ?? 0;

      // Daily chart: [{day, orders, revenuePaise, revenueRupees}]
      final chart = (statsData['dailyChart'] as List<dynamic>?) ?? [];

      final pendingOrders = (statsData['pendingOrders'] as num?)?.toInt() ?? 0;
      final alerts = _buildAlerts(statsData, pendingOrders);

      state = state.copyWith(
        isLoading:    false,
        recentOrders: ordersData,
        salesChart:   chart,
        alerts:       alerts,
        stats: {
          'totalOrders':    statsData['totalOrders']    ?? 0,
          'pendingOrders':  pendingOrders,
          'totalProducts':  productCount,
          'totalRevenue':   double.tryParse(statsData['totalRevenueRupees']?.toString() ?? '0') ?? 0,
          'revenueChange':  (statsData['revenueChange'] as num?)?.toDouble() ?? 0.0,
          'ordersChange':   (statsData['ordersChange']  as num?)?.toDouble() ?? 0.0,
          'productsChange': 0,
          'pendingChange':  0,
        },
      );
    } on DioException catch (e) {
      state = state.copyWith(isLoading: false, error: AppException.fromDioError(e).message);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  List<Map<String, String>> _buildAlerts(Map<String, dynamic> stats, int pendingOrders) {
    final alerts = <Map<String, String>>[];

    if (pendingOrders >= 10) {
      alerts.add({'type': 'warning', 'message': '$pendingOrders orders are waiting for confirmation'});
    } else if (pendingOrders > 0) {
      alerts.add({'type': 'info', 'message': '$pendingOrders order${pendingOrders > 1 ? 's' : ''} pending your action'});
    }

    final breakdown = stats['statusBreakdown'] as Map<String, dynamic>? ?? {};
    final processing = (breakdown['PROCESSING'] as num?)?.toInt() ?? 0;
    if (processing >= 5) {
      alerts.add({'type': 'info', 'message': '$processing orders are currently being processed'});
    }

    return alerts;
  }
}

final dashboardPod = StateNotifierProvider<DashboardNotifier, DashboardState>(
  (ref) => DashboardNotifier(),
);
