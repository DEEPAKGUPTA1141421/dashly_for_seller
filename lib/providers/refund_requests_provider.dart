import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../core/errors/app_exception.dart';

class RefundRequestsState {
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final List<dynamic> returns;
  final int page;
  final bool hasMore;
  final String bucket; // 'OPEN' | 'CLOSED'

  const RefundRequestsState({
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.returns = const [],
    this.page = 0,
    this.hasMore = true,
    this.bucket = 'OPEN',
  });

  RefundRequestsState copyWith({
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    List<dynamic>? returns,
    int? page,
    bool? hasMore,
    String? bucket,
  }) {
    return RefundRequestsState(
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: error,
      returns: returns ?? this.returns,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      bucket: bucket ?? this.bucket,
    );
  }
}

class RefundRequestsNotifier extends StateNotifier<RefundRequestsState> {
  RefundRequestsNotifier() : super(const RefundRequestsState());

  Dio get _client => ApiClient.instance.client;

  Future<void> fetchReturns({bool refresh = false}) async {
    if (refresh) {
      state = state.copyWith(isLoading: true, returns: [], page: 0, hasMore: true);
    } else {
      if (!state.hasMore || state.isLoadingMore) return;
      state = state.copyWith(isLoadingMore: true);
    }

    try {
      final page = refresh ? 0 : state.page;
      final res  = await _client.get(
        ApiEndpoints.sellerReturns,
        queryParameters: {'page': page, 'size': 20, 'status': state.bucket},
      );
      final body = res.data as Map<String, dynamic>;
      if (body['success'] == true) {
        final data     = body['data'] as Map<String, dynamic>;
        final incoming = (data['returns'] as List<dynamic>?) ?? [];
        final hasMore  = data['hasMore'] as bool? ?? false;
        final newList  = refresh ? incoming : [...state.returns, ...incoming];
        state = state.copyWith(
          isLoading: false,
          isLoadingMore: false,
          returns: newList,
          page: page + 1,
          hasMore: hasMore,
        );
      } else {
        state = state.copyWith(
          isLoading: false, isLoadingMore: false,
          error: body['message'] as String? ?? 'Failed to load refund requests',
        );
      }
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false, isLoadingMore: false,
        error: AppException.fromDioError(e).message,
      );
    }
  }

  void setBucket(String bucket) {
    if (state.bucket == bucket) return;
    state = state.copyWith(bucket: bucket);
    fetchReturns(refresh: true);
  }
}

final refundRequestsPod = StateNotifierProvider<RefundRequestsNotifier, RefundRequestsState>(
  (ref) => RefundRequestsNotifier(),
);
