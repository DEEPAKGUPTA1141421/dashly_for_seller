import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../core/errors/app_exception.dart';

/// Drives the "Payout history" table shared by the Payouts and Statement
/// screens — page-by-page (prev/next) browsing of the same earnings-history
/// endpoint the Earning tab uses, kept separate from [EarningsNotifier]
/// because that one accumulates pages for a "Load more" list instead.
class PayoutsState {
  final bool isLoading;
  final String? error;
  final List<dynamic> history;
  final int page;
  final bool hasMore;

  const PayoutsState({
    this.isLoading = false,
    this.error,
    this.history = const [],
    this.page = 0,
    this.hasMore = false,
  });

  PayoutsState copyWith({
    bool? isLoading,
    String? error,
    List<dynamic>? history,
    int? page,
    bool? hasMore,
  }) {
    return PayoutsState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      history: history ?? this.history,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

class PayoutsNotifier extends StateNotifier<PayoutsState> {
  PayoutsNotifier() : super(const PayoutsState());

  Dio get _client => ApiClient.instance.orderClient;

  Future<void> fetchPage(int page) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res  = await _client.get(
        ApiEndpoints.sellerEarningsHistory,
        queryParameters: {'page': page, 'size': 8},
      );
      final body = res.data as Map<String, dynamic>;
      final data = (body['data'] as Map<String, dynamic>?) ?? {};
      state = state.copyWith(
        isLoading: false,
        history: (data['history'] as List<dynamic>?) ?? [],
        page: page,
        hasMore: data['hasMore'] as bool? ?? false,
      );
    } on DioException catch (e) {
      state = state.copyWith(isLoading: false, error: AppException.fromDioError(e).message);
    }
  }

  void next() {
    if (state.hasMore) fetchPage(state.page + 1);
  }

  void previous() {
    if (state.page > 0) fetchPage(state.page - 1);
  }
}

final payoutsPod = StateNotifierProvider<PayoutsNotifier, PayoutsState>(
  (ref) => PayoutsNotifier(),
);
