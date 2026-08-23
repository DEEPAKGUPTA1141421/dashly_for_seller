import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../core/errors/app_exception.dart';

class ReviewsState {
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final Map<String, dynamic> summary;
  final List<dynamic> reviews;
  final int page;
  final bool hasMore;

  const ReviewsState({
    this.isLoading    = false,
    this.isLoadingMore = false,
    this.error,
    this.summary  = const {},
    this.reviews  = const [],
    this.page     = 0,
    this.hasMore  = true,
  });

  ReviewsState copyWith({
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    Map<String, dynamic>? summary,
    List<dynamic>? reviews,
    int? page,
    bool? hasMore,
  }) {
    return ReviewsState(
      isLoading:     isLoading     ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error:         error,
      summary:       summary   ?? this.summary,
      reviews:       reviews   ?? this.reviews,
      page:          page      ?? this.page,
      hasMore:       hasMore   ?? this.hasMore,
    );
  }
}

class ReviewsNotifier extends StateNotifier<ReviewsState> {
  ReviewsNotifier() : super(const ReviewsState());

  Dio get _client => ApiClient.instance.client;

  Future<void> fetchSummary() async {
    try {
      final res  = await _client.get(ApiEndpoints.sellerReviewSummary);
      final body = res.data as Map<String, dynamic>;
      if (body['success'] == true) {
        state = state.copyWith(summary: Map<String, dynamic>.from(body['data'] as Map? ?? {}));
      }
    } catch (_) {}
  }

  Future<void> fetchReviews({bool refresh = false}) async {
    if (refresh) {
      state = state.copyWith(isLoading: true, reviews: [], page: 0, hasMore: true);
    } else {
      if (!state.hasMore || state.isLoadingMore) return;
      state = state.copyWith(isLoadingMore: true);
    }

    try {
      final page = refresh ? 0 : state.page;
      final res  = await _client.get(
        ApiEndpoints.sellerReviews,
        queryParameters: {'page': page, 'size': 20},
      );
      final body = res.data as Map<String, dynamic>;
      if (body['success'] == true) {
        final data     = body['data'] as Map<String, dynamic>;
        final incoming = (data['reviews'] as List<dynamic>?) ?? [];
        final hasMore  = data['hasMore'] as bool? ?? false;
        final newList  = refresh ? incoming : [...state.reviews, ...incoming];
        state = state.copyWith(
          isLoading:     false,
          isLoadingMore: false,
          reviews:       newList,
          page:          page + 1,
          hasMore:       hasMore,
        );
      } else {
        state = state.copyWith(
          isLoading: false, isLoadingMore: false,
          error: body['message'] as String? ?? 'Failed to load reviews',
        );
      }
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false, isLoadingMore: false,
        error: AppException.fromDioError(e).message,
      );
    }
  }
}

final reviewsPod = StateNotifierProvider<ReviewsNotifier, ReviewsState>(
  (ref) => ReviewsNotifier(),
);
