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
      // Fetch recent bookings from order service + seller draft products from product service
      final results = await Future.wait([
        // GET /api/v1/booking?page=0&size=5  (recent orders)
        _orderClient.get(ApiEndpoints.bookings, queryParameters: {'page': 0, 'size': 5}),
        // GET /api/v1/seller/product/draft-product  (seller's products for count)
        _productClient.get(ApiEndpoints.sellerProductDraft),
      ]);

      final bookingBody  = results[0].data as Map<String, dynamic>;
      final productBody  = results[1].data as Map<String, dynamic>;

      final orders   = (bookingBody['data'] as List<dynamic>?)  ?? [];
      final products = (productBody['data'] as List<dynamic>?)  ?? [];

      // Derive stats from the raw data since there is no dedicated dashboard endpoint
      final totalRevenue = orders.fold<double>(
        0,
        (sum, o) => sum + ((o['totalAmount'] as num?) ?? 0).toDouble(),
      );

      state = state.copyWith(
        isLoading: false,
        recentOrders: orders,
        stats: {
          'totalOrders':    bookingBody['totalElements'] ?? orders.length,
          'totalProducts':  products.length,
          'totalRevenue':   totalRevenue,
          'pendingOrders':  orders.where((o) => o['status'] == 'PENDING').length,
          'revenueChange':  0,
          'ordersChange':   0,
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
}

final dashboardPod = StateNotifierProvider<DashboardNotifier, DashboardState>(
  (ref) => DashboardNotifier(),
);
