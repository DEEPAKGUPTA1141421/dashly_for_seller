import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../core/errors/app_exception.dart';

class DashboardState {
  final bool isLoading;
  final String? error;
  final Map<String, dynamic> stats;
  final Map<String, dynamic> customerStats;
  final Map<String, dynamic> productSummary;
  final List<dynamic> recentOrders;
  final List<dynamic> alerts;
  final List<dynamic> salesChart;
  final List<dynamic> topProducts;
  final List<dynamic> recentReviews;
  final Map<String, dynamic> statusCounts;

  const DashboardState({
    this.isLoading      = false,
    this.error,
    this.stats           = const {},
    this.customerStats    = const {},
    this.productSummary   = const {},
    this.recentOrders    = const [],
    this.alerts          = const [],
    this.salesChart      = const [],
    this.topProducts     = const [],
    this.recentReviews   = const [],
    this.statusCounts    = const {},
  });

  DashboardState copyWith({
    bool? isLoading,
    String? error,
    Map<String, dynamic>? stats,
    Map<String, dynamic>? customerStats,
    Map<String, dynamic>? productSummary,
    List<dynamic>? recentOrders,
    List<dynamic>? alerts,
    List<dynamic>? salesChart,
    List<dynamic>? topProducts,
    List<dynamic>? recentReviews,
    Map<String, dynamic>? statusCounts,
  }) {
    return DashboardState(
      isLoading:      isLoading      ?? this.isLoading,
      error:          error,
      stats:          stats          ?? this.stats,
      customerStats:  customerStats  ?? this.customerStats,
      productSummary: productSummary ?? this.productSummary,
      recentOrders:   recentOrders   ?? this.recentOrders,
      alerts:         alerts         ?? this.alerts,
      salesChart:     salesChart     ?? this.salesChart,
      topProducts:    topProducts    ?? this.topProducts,
      recentReviews:  recentReviews  ?? this.recentReviews,
      statusCounts:   statusCounts   ?? this.statusCounts,
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
      final results = await Future.wait([
        _orderClient.get(ApiEndpoints.sellerStats, queryParameters: {'days': 7}),
        _orderClient.get(ApiEndpoints.sellerOrders, queryParameters: {'page': 0, 'size': 5}),
        _productClient.get(ApiEndpoints.sellerProductDashboardSummary),
        _orderClient.get(ApiEndpoints.sellerCustomerStats, queryParameters: {'days': 7}),
        _orderClient.get(ApiEndpoints.sellerTopProducts, queryParameters: {'limit': 5}),
        _orderClient.get(ApiEndpoints.sellerOrderStatusCounts),
        _productClient.get(ApiEndpoints.sellerReviews, queryParameters: {'page': 0, 'size': 3}),
      ]);

      final statsBody         = results[0].data as Map<String, dynamic>;
      final ordersBody        = results[1].data as Map<String, dynamic>;
      final productBody       = results[2].data as Map<String, dynamic>;
      final customerStatsBody = results[3].data as Map<String, dynamic>;
      final topProductsBody   = results[4].data as Map<String, dynamic>;
      final statusCountsBody  = results[5].data as Map<String, dynamic>;
      final reviewsBody       = results[6].data as Map<String, dynamic>;

      final statsData          = (statsBody['data'] as Map<String, dynamic>?) ?? {};
      final ordersData         = (ordersBody['data'] as Map<String, dynamic>?)?['orders'] as List<dynamic>? ?? [];
      final productSummaryData = (productBody['data'] as Map<String, dynamic>?) ?? {};
      final customerStatsData  = (customerStatsBody['data'] as Map<String, dynamic>?) ?? {};
      final topProductsData    = (topProductsBody['data'] as List<dynamic>?) ?? [];
      final statusCountsData   = (statusCountsBody['data'] as Map<String, dynamic>?) ?? {};
      final reviewsData        = (reviewsBody['data'] as Map<String, dynamic>?)?['reviews'] as List<dynamic>? ?? [];

      final chart = (statsData['dailyChart'] as List<dynamic>?) ?? [];

      final pendingOrders = (statsData['pendingOrders'] as num?)?.toInt() ?? 0;
      final alerts = _buildAlerts(statsData, pendingOrders);

      state = state.copyWith(
        isLoading:      false,
        recentOrders:   ordersData,
        salesChart:     chart,
        alerts:         alerts,
        customerStats:  customerStatsData,
        productSummary: productSummaryData,
        topProducts:    topProductsData,
        recentReviews:  reviewsData,
        statusCounts:   statusCountsData,
        stats: {
          'totalOrders':    statsData['totalOrders']    ?? 0,
          'pendingOrders':  pendingOrders,
          'totalProducts':  productSummaryData['totalProducts'] ?? 0,
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
