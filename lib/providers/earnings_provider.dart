import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../core/errors/app_exception.dart';
import '../models/balance_stat.dart';

class EarningsState {
  final bool isLoading;
  final String? error;

  final List<BalanceStat> stats; // Earning / Balance / Total value of sales

  final List<dynamic> history;
  final bool isHistoryLoading;
  final bool isHistoryLoadingMore;
  final int historyPage;
  final bool historyHasMore;

  const EarningsState({
    this.isLoading = false,
    this.error,
    this.stats = const [],
    this.history = const [],
    this.isHistoryLoading = false,
    this.isHistoryLoadingMore = false,
    this.historyPage = 0,
    this.historyHasMore = true,
  });

  EarningsState copyWith({
    bool? isLoading,
    String? error,
    List<BalanceStat>? stats,
    List<dynamic>? history,
    bool? isHistoryLoading,
    bool? isHistoryLoadingMore,
    int? historyPage,
    bool? historyHasMore,
  }) {
    return EarningsState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      stats: stats ?? this.stats,
      history: history ?? this.history,
      isHistoryLoading: isHistoryLoading ?? this.isHistoryLoading,
      isHistoryLoadingMore: isHistoryLoadingMore ?? this.isHistoryLoadingMore,
      historyPage: historyPage ?? this.historyPage,
      historyHasMore: historyHasMore ?? this.historyHasMore,
    );
  }
}

class EarningsNotifier extends StateNotifier<EarningsState> {
  EarningsNotifier() : super(const EarningsState());

  Dio get _client => ApiClient.instance.orderClient;

  Future<void> fetchSummary() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res  = await _client.get(ApiEndpoints.sellerEarnings);
      final body = res.data as Map<String, dynamic>;
      final data = (body['data'] as Map<String, dynamic>?) ?? {};

      final stats = [
        BalanceStat(
          label: 'Earning',
          value: (data['totalEarnedRupees'] as String?) ?? '0.00',
          changePct: (data['earnedChangePercent'] as num?)?.toDouble() ?? 0.0,
          sparkline: _toDoubleList(data['sparkline']),
        ),
        BalanceStat(
          label: 'Balance',
          value: (data['pendingRupees'] as String?) ?? '0.00',
          changePct: (data['balanceChangePercent'] as num?)?.toDouble() ?? 0.0,
          sparkline: _toDoubleList(data['balanceSparkline']),
        ),
        BalanceStat(
          label: 'Total value of sales',
          value: (data['totalSalesRupees'] as String?) ?? '0.00',
          changePct: (data['totalSalesChangePercent'] as num?)?.toDouble() ?? 0.0,
          sparkline: _toDoubleList(data['totalSalesSparkline']),
        ),
      ];

      state = state.copyWith(isLoading: false, stats: stats);
    } on DioException catch (e) {
      state = state.copyWith(isLoading: false, error: AppException.fromDioError(e).message);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  List<double> _toDoubleList(dynamic raw) {
    if (raw is List) {
      return raw.map((e) => (e as num?)?.toDouble() ?? 0.0).toList();
    }
    return const [];
  }

  Future<void> fetchHistory({bool refresh = false}) async {
    if (refresh) {
      state = state.copyWith(isHistoryLoading: true, history: [], historyPage: 0, historyHasMore: true);
    } else {
      if (!state.historyHasMore || state.isHistoryLoadingMore) return;
      state = state.copyWith(isHistoryLoadingMore: true);
    }

    try {
      final page = refresh ? 0 : state.historyPage;
      final res  = await _client.get(
        ApiEndpoints.sellerEarningsHistory,
        queryParameters: {'page': page, 'size': 20},
      );
      final body = res.data as Map<String, dynamic>;
      final data = (body['data'] as Map<String, dynamic>?) ?? {};
      final incoming = (data['history'] as List<dynamic>?) ?? [];
      final hasMore  = data['hasMore'] as bool? ?? false;
      final newList  = refresh ? incoming : [...state.history, ...incoming];

      state = state.copyWith(
        isHistoryLoading: false,
        isHistoryLoadingMore: false,
        history: newList,
        historyPage: page + 1,
        historyHasMore: hasMore,
      );
    } on DioException catch (e) {
      state = state.copyWith(
        isHistoryLoading: false,
        isHistoryLoadingMore: false,
        error: AppException.fromDioError(e).message,
      );
    }
  }
}

final earningsPod = StateNotifierProvider<EarningsNotifier, EarningsState>(
  (ref) => EarningsNotifier(),
);
