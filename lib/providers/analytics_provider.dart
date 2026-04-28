import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../core/errors/app_exception.dart';

class AnalyticsState {
  final bool isLoading;
  final String? error;
  final List<dynamic> dailyChart;    // [{day, orders, revenuePaise, revenueRupees}]
  final Map<String, dynamic> stats;  // totalOrders, totalRevenue, statusBreakdown, deltas
  final int selectedDays;            // 7 | 30 | 90
  final List<dynamic> topProducts;   // [{productId, productName, totalQty, revenuePaise, revenueRupees}]

  const AnalyticsState({
    this.isLoading    = false,
    this.error,
    this.dailyChart   = const [],
    this.stats        = const {},
    this.selectedDays = 7,
    this.topProducts  = const [],
  });

  AnalyticsState copyWith({
    bool? isLoading,
    String? error,
    List<dynamic>? dailyChart,
    Map<String, dynamic>? stats,
    int? selectedDays,
    List<dynamic>? topProducts,
  }) => AnalyticsState(
    isLoading:    isLoading    ?? this.isLoading,
    error:        error,
    dailyChart:   dailyChart   ?? this.dailyChart,
    stats:        stats        ?? this.stats,
    selectedDays: selectedDays ?? this.selectedDays,
    topProducts:  topProducts  ?? this.topProducts,
  );
}

class AnalyticsNotifier extends StateNotifier<AnalyticsState> {
  AnalyticsNotifier() : super(const AnalyticsState());

  Dio get _client => ApiClient.instance.orderClient;

  Future<void> fetchStats({int? days}) async {
    final d = days ?? state.selectedDays;
    state = state.copyWith(isLoading: true, error: null, selectedDays: d);
    try {
      final results = await Future.wait([
        _client.get(ApiEndpoints.sellerStats, queryParameters: {'days': d}),
        _client.get(ApiEndpoints.sellerTopProducts, queryParameters: {'limit': 5}),
      ]);

      final statsBody = results[0].data as Map<String, dynamic>;
      final data      = (statsBody['data'] as Map<String, dynamic>?) ?? {};

      final topBody = results[1].data as Map<String, dynamic>;
      final topList = (topBody['data'] as List<dynamic>?) ?? [];

      state = state.copyWith(
        isLoading:   false,
        dailyChart:  (data['dailyChart'] as List<dynamic>?) ?? [],
        stats:       data,
        topProducts: topList,
      );
    } on DioException catch (e) {
      state = state.copyWith(isLoading: false, error: AppException.fromDioError(e).message);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void setDays(int days) {
    if (days == state.selectedDays) return;
    fetchStats(days: days);
  }
}

final analyticsPod = StateNotifierProvider<AnalyticsNotifier, AnalyticsState>(
  (ref) => AnalyticsNotifier(),
);
