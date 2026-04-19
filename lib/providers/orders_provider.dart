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
  final String filterStatus; // 'ALL' | 'PENDING' | 'PROCESSING' | 'SHIPPED' | 'DELIVERED'
  final int currentPage;
  final bool hasMore;

  const OrdersState({
    this.isLoading    = false,
    this.error,
    this.orders       = const [],
    this.orderDetail  = const {},
    this.filterStatus = 'ALL',
    this.currentPage  = 0,
    this.hasMore      = true,
  });

  OrdersState copyWith({
    bool? isLoading,
    String? error,
    List<dynamic>? orders,
    Map<String, dynamic>? orderDetail,
    String? filterStatus,
    int? currentPage,
    bool? hasMore,
  }) {
    return OrdersState(
      isLoading:    isLoading    ?? this.isLoading,
      error:        error,
      orders:       orders       ?? this.orders,
      orderDetail:  orderDetail  ?? this.orderDetail,
      filterStatus: filterStatus ?? this.filterStatus,
      currentPage:  currentPage  ?? this.currentPage,
      hasMore:      hasMore      ?? this.hasMore,
    );
  }
}

class OrdersNotifier extends StateNotifier<OrdersState> {
  OrdersNotifier() : super(const OrdersState());

  // Orders live on OrderPaymentNotificationService (port 8082)
  Dio get _client => ApiClient.instance.orderClient;

  // GET /api/v1/booking?page=0&size=10
  Future<void> fetchOrders({String? status, bool reset = true}) async {
    if (reset) state = state.copyWith(isLoading: true, error: null, currentPage: 0);
    try {
      final params = <String, dynamic>{'page': 0, 'size': 20};
      if (status != null && status != 'ALL') params['status'] = status;

      final res  = await _client.get(ApiEndpoints.bookings, queryParameters: params);
      final body = res.data as Map<String, dynamic>;
      final data = (body['data'] as List<dynamic>?) ?? [];

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

  // GET /api/v1/booking/{bookingId}
  Future<void> fetchOrderDetail(String bookingId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res  = await _client.get('${ApiEndpoints.bookings}/$bookingId');
      final body = res.data as Map<String, dynamic>;
      final data = (body['data'] as Map<String, dynamic>?) ?? {};
      state = state.copyWith(isLoading: false, orderDetail: data);
    } on DioException catch (e) {
      state = state.copyWith(isLoading: false, error: AppException.fromDioError(e).message);
    }
  }

  // GET /api/v1/booking/{bookingId}/tracking
  Future<Map<String, dynamic>> fetchOrderTracking(String bookingId) async {
    try {
      final res  = await _client.get('${ApiEndpoints.bookings}/$bookingId/tracking');
      final body = res.data as Map<String, dynamic>;
      return (body['data'] as Map<String, dynamic>?) ?? {};
    } catch (_) {
      return {};
    }
  }

  void setFilter(String status) {
    state = state.copyWith(filterStatus: status);
    fetchOrders(status: status);
  }

  // PUT /api/v1/booking/{bookingId}/status  body: { status }
  Future<bool> updateOrderStatus(String bookingId, String newStatus) async {
    try {
      final res  = await _client.put(
        '${ApiEndpoints.bookings}/$bookingId/status',
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
