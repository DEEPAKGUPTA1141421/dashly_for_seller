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
  final String query;

  const ReviewsState({
    this.isLoading    = false,
    this.isLoadingMore = false,
    this.error,
    this.summary  = const {},
    this.reviews  = const [],
    this.page     = 0,
    this.hasMore  = true,
    this.query    = '',
  });

  ReviewsState copyWith({
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    Map<String, dynamic>? summary,
    List<dynamic>? reviews,
    int? page,
    bool? hasMore,
    String? query,
  }) {
    return ReviewsState(
      isLoading:     isLoading     ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error:         error,
      summary:       summary   ?? this.summary,
      reviews:       reviews   ?? this.reviews,
      page:          page      ?? this.page,
      hasMore:       hasMore   ?? this.hasMore,
      query:         query     ?? this.query,
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

  Future<void> setQuery(String query) async {
    if (query == state.query) return;
    state = state.copyWith(query: query);
    await fetchReviews(refresh: true);
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
        queryParameters: {
          'page': page,
          'size': 20,
          if (state.query.trim().isNotEmpty) 'query': state.query.trim(),
        },
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
          error: body['message'] as String? ?? 'Failed to load comments',
        );
      }
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false, isLoadingMore: false,
        error: AppException.fromDioError(e).message,
      );
    }
  }

  /// Toggle helpful/"like" on a comment (generic reviews endpoint, no purchase check).
  Future<bool> toggleLike(String reviewId) async {
    try {
      final res  = await _client.post('/api/v1/reviews/$reviewId/helpful');
      final body = res.data as Map<String, dynamic>;
      if (body['success'] != true) return false;
      final added = (body['data'] as Map?)?['action'] == 'ADDED';
      _updateReview(reviewId, (r) {
        final current = (r['helpfulCount'] as num?)?.toInt() ?? 0;
        r['helpfulCount'] = added ? current + 1 : (current - 1).clamp(0, 1 << 30);
        r['likedByMe'] = added;
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> reply(String reviewId, String text) async {
    try {
      final res  = await _client.post(ApiEndpoints.sellerReviewReply(reviewId), data: {'reply': text});
      final body = res.data as Map<String, dynamic>;
      if (body['success'] != true) return false;
      final data = body['data'] as Map<String, dynamic>? ?? {};
      _updateReview(reviewId, (r) {
        r['sellerReply']   = data['sellerReply'] ?? text;
        r['sellerReplyAt'] = data['sellerReplyAt'] ?? DateTime.now().toIso8601String();
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> react(String reviewId, String emoji) async {
    try {
      final res  = await _client.post(ApiEndpoints.sellerReviewReact(reviewId), data: {'emoji': emoji});
      final body = res.data as Map<String, dynamic>;
      if (body['success'] != true) return false;
      final data = body['data'] as Map<String, dynamic>? ?? {};
      _updateReview(reviewId, (r) => r['sellerReaction'] = data['sellerReaction'] ?? '');
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteReview(String reviewId) async {
    try {
      final res  = await _client.delete(ApiEndpoints.sellerReviewDelete(reviewId));
      final body = res.data as Map<String, dynamic>;
      if (body['success'] != true) return false;
      state = state.copyWith(
        reviews: state.reviews.where((r) => (r as Map)['id'] != reviewId).toList(),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  void _updateReview(String reviewId, void Function(Map r) update) {
    final list = state.reviews.map((raw) {
      final r = Map<String, dynamic>.from(raw as Map);
      if (r['id'] == reviewId) update(r);
      return r;
    }).toList();
    state = state.copyWith(reviews: list);
  }
}

final reviewsPod = StateNotifierProvider<ReviewsNotifier, ReviewsState>(
  (ref) => ReviewsNotifier(),
);
