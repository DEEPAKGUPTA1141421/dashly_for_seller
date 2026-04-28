import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../core/errors/app_exception.dart';

class OrdersState {
  final bool isLoading;
  final String? error;
  final List<dynamic> orders;
  final Map<String, dynamic> orderDetail;
  final String filterStatus; // 'ALL' | 'CONFIRMED' | 'PROCESSING' | 'OUT_FOR_DELIVERY' | 'DELIVERED' | 'CANCELLED'
  final int currentPage;
  final bool hasMore;
  final Map<String, int> statusCounts; // {'ALL': 50, 'CONFIRMED': 3, ...}

  const OrdersState({
    this.isLoading    = false,
    this.error,
    this.orders       = const [],
    this.orderDetail  = const {},
    this.filterStatus = 'ALL',
    this.currentPage  = 0,
    this.hasMore      = true,
    this.statusCounts = const {},
  });

  OrdersState copyWith({
    bool? isLoading,
    String? error,
    List<dynamic>? orders,
    Map<String, dynamic>? orderDetail,
    String? filterStatus,
    int? currentPage,
    bool? hasMore,
    Map<String, int>? statusCounts,
  }) {
    return OrdersState(
      isLoading:    isLoading    ?? this.isLoading,
      error:        error,
      orders:       orders       ?? this.orders,
      orderDetail:  orderDetail  ?? this.orderDetail,
      filterStatus: filterStatus ?? this.filterStatus,
      currentPage:  currentPage  ?? this.currentPage,
      hasMore:      hasMore      ?? this.hasMore,
      statusCounts: statusCounts ?? this.statusCounts,
    );
  }
}

class OrdersNotifier extends StateNotifier<OrdersState> {
  OrdersNotifier() : super(const OrdersState());

  // Orders live on OrderPaymentNotificationService (port 8082)
  Dio get _client => ApiClient.instance.orderClient;

  // GET /api/v1/seller/orders?page=0&size=20&status=ALL
  Future<void> fetchOrders({String? status, bool reset = true}) async {
    if (reset) state = state.copyWith(isLoading: true, error: null, currentPage: 0);
    try {
      final params = <String, dynamic>{'page': 0, 'size': 20, 'status': status ?? 'ALL'};

      final res  = await _client.get(ApiEndpoints.sellerOrders, queryParameters: params);
      final body = res.data as Map<String, dynamic>;
      final data = (body['data'] as Map<String, dynamic>?)?['orders'] as List<dynamic>? ?? [];

      state = state.copyWith(
        isLoading: false,
        orders:    data,
        hasMore:   data.length >= 20,
      );
    } on DioException catch (e) {
      state = state.copyWith(isLoading: false, error: AppException.fromDioError(e).message);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  // GET /api/v1/seller/orders/{bookingId} — seller-scoped detail with items
  Future<Map<String, dynamic>> fetchSellerOrderDetail(String bookingId) async {
    try {
      final res  = await _client.get('${ApiEndpoints.sellerOrders}/$bookingId');
      final body = res.data as Map<String, dynamic>;
      return (body['data'] as Map<String, dynamic>?) ?? {};
    } on DioException catch (e) {
      state = state.copyWith(error: AppException.fromDioError(e).message);
      return {};
    }
  }

  // Load next page and append — used by infinite scroll
  Future<void> loadMoreOrders() async {
    if (!state.hasMore || state.isLoading) return;
    try {
      final nextPage = state.currentPage + 1;
      final params   = <String, dynamic>{
        'page': nextPage, 'size': 20, 'status': state.filterStatus,
      };
      final res  = await _client.get(ApiEndpoints.sellerOrders, queryParameters: params);
      final body = res.data as Map<String, dynamic>;
      final data = (body['data'] as Map<String, dynamic>?)?['orders'] as List<dynamic>? ?? [];
      state = state.copyWith(
        orders:      [...state.orders, ...data],
        currentPage: nextPage,
        hasMore:     data.length >= 20,
      );
    } on DioException catch (e) {
      state = state.copyWith(error: AppException.fromDioError(e).message);
    }
  }

  void setFilter(String status) {
    state = state.copyWith(filterStatus: status);
    fetchOrders(status: status);
  }

  // GET /api/v1/seller/orders/status-counts
  Future<void> fetchStatusCounts() async {
    try {
      final res  = await _client.get(ApiEndpoints.sellerOrderStatusCounts);
      final body = res.data as Map<String, dynamic>;
      final data = body['data'] as Map<String, dynamic>? ?? {};
      final counts = data.map((k, v) => MapEntry(k, (v as num).toInt()));
      state = state.copyWith(statusCounts: counts);
    } catch (_) {}
  }

  // PUT /api/v1/booking/{bookingId}/status  body: { status }
  Future<bool> updateOrderStatus(String bookingId, String newStatus) async {
    try {
      final res  = await _client.put(
        '/api/v1/booking/$bookingId/status',
        data: {'status': newStatus},
      );
      final body = res.data as Map<String, dynamic>;
      if (body['success'] == true) {
        final updatedOrders = state.orders.map((o) {
          final order = o as Map<String, dynamic>;
          if ((order['bookingId'] ?? order['orderId'])?.toString() == bookingId) {
            return {...order, 'status': newStatus};
          }
          return order;
        }).toList();
        state = state.copyWith(orders: updatedOrders);
        return true;
      }
      return false;
    } on DioException catch (e) {
      state = state.copyWith(error: AppException.fromDioError(e).message);
      return false;
    }
  }
}

final ordersPod = StateNotifierProvider<OrdersNotifier, OrdersState>(
  (ref) => OrdersNotifier(),
);
