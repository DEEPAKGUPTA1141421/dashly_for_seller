import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../core/errors/app_exception.dart';

class NotificationsState {
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final List<dynamic> notifications;
  final int unreadCount;
  final bool hasMore;
  final int currentPage;
  final String? categoryFilter;

  const NotificationsState({
    this.isLoading     = false,
    this.isLoadingMore = false,
    this.error,
    this.notifications = const [],
    this.unreadCount   = 0,
    this.hasMore       = true,
    this.currentPage   = 0,
    this.categoryFilter,
  });

  NotificationsState copyWith({
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    List<dynamic>? notifications,
    int? unreadCount,
    bool? hasMore,
    int? currentPage,
    String? categoryFilter,
    bool clearCategoryFilter = false,
  }) => NotificationsState(
    isLoading:      isLoading     ?? this.isLoading,
    isLoadingMore:  isLoadingMore ?? this.isLoadingMore,
    error:          error,
    notifications:  notifications ?? this.notifications,
    unreadCount:    unreadCount   ?? this.unreadCount,
    hasMore:        hasMore       ?? this.hasMore,
    currentPage:    currentPage   ?? this.currentPage,
    categoryFilter: clearCategoryFilter ? null : (categoryFilter ?? this.categoryFilter),
  );
}

class NotificationsNotifier extends StateNotifier<NotificationsState> {
  NotificationsNotifier() : super(const NotificationsState());

  Dio get _client => ApiClient.instance.orderClient;

  static const int _pageSize = 20;

  // GET /api/v1/users/notifications?page=0&size=20&category=ORDER_UPDATES
  Future<void> fetchNotifications({bool reset = true}) async {
    if (reset) {
      state = state.copyWith(isLoading: true, error: null, currentPage: 0);
    } else {
      if (!state.hasMore || state.isLoadingMore) return;
      state = state.copyWith(isLoadingMore: true, error: null);
    }

    try {
      final page = reset ? 0 : state.currentPage;
      final res  = await _client.get(
        ApiEndpoints.notifications,
        queryParameters: {
          'page': page,
          'size': _pageSize,
          if (state.categoryFilter != null) 'category': state.categoryFilter,
        },
      );
      final body  = res.data as Map<String, dynamic>;
      final data  = (body['data'] as Map<String, dynamic>?) ?? {};
      final list  = (data['notifications'] as List<dynamic>?) ?? (body['data'] is List ? body['data'] as List : []);
      final total = (data['unreadCount'] as num?)?.toInt() ?? _countUnread(list);
      final hasNext = list.length >= _pageSize;

      state = state.copyWith(
        isLoading:     false,
        isLoadingMore: false,
        notifications: reset ? list : [...state.notifications, ...list],
        unreadCount:   total,
        hasMore:       hasNext,
        currentPage:   page + 1,
      );
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false, isLoadingMore: false,
        error: AppException.fromDioError(e).message,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, isLoadingMore: false, error: e.toString());
    }
  }

  /// Sets (or clears, if null) the active category filter and reloads the feed.
  Future<void> setCategoryFilter(String? category) async {
    state = state.copyWith(categoryFilter: category, clearCategoryFilter: category == null);
    await fetchNotifications();
  }

  // GET /api/v1/users/notifications/unread-count
  // Cheap bell-badge refresh — used on app resume / foreground push arrival,
  // without paging through the full feed.
  Future<void> fetchUnreadCount() async {
    try {
      final res  = await _client.get(ApiEndpoints.notificationUnreadCount);
      final body = res.data as Map<String, dynamic>;
      final data = (body['data'] as Map<String, dynamic>?) ?? {};
      final count = (data['unreadCount'] as num?)?.toInt();
      if (count != null) {
        state = state.copyWith(unreadCount: count);
      }
    } catch (_) {}
  }

  /// Called by PushNotificationService when an FCM message arrives while the
  /// app is in the foreground — bumps the badge and prepends the item to the
  /// feed immediately, without waiting for the next fetch.
  void receivePush(Map<String, dynamic> data) {
    final notif = <String, dynamic>{
      'id':          data['notificationId'] ?? data['id'],
      'category':    data['category'],
      'title':       data['title'],
      'body':        data['body'],
      'actionUrl':   data['actionUrl'] ?? data['click_action'],
      'referenceId': data['referenceId'],
      'read':        false,
      'createdAt':   DateTime.now().toIso8601String(),
    };
    state = state.copyWith(
      notifications: [notif, ...state.notifications],
      unreadCount: state.unreadCount + 1,
    );
  }

  // PATCH /api/v1/users/notifications/{id}/read
  Future<void> markRead(String notifId) async {
    try {
      await _client.patch('${ApiEndpoints.notifications}/$notifId/read');
      final updated = state.notifications.map((n) {
        final m = n as Map<String, dynamic>;
        if (m['id']?.toString() == notifId) return {...m, 'read': true};
        return m;
      }).toList();
      state = state.copyWith(
        notifications: updated,
        unreadCount: (state.unreadCount - 1).clamp(0, 999),
      );
    } catch (_) {}
  }

  // PATCH /api/v1/users/notifications/read-all
  Future<void> markAllRead() async {
    try {
      await _client.patch(ApiEndpoints.notificationReadAll);
      final updated = state.notifications.map((n) {
        return {...(n as Map<String, dynamic>), 'read': true};
      }).toList();
      state = state.copyWith(notifications: updated, unreadCount: 0);
    } catch (_) {}
  }

  // DELETE /api/v1/users/notifications/{id}
  Future<void> deleteNotification(String notifId) async {
    try {
      await _client.delete('${ApiEndpoints.notifications}/$notifId');
      final updated = state.notifications.where((n) => (n as Map)['id']?.toString() != notifId).toList();
      state = state.copyWith(notifications: updated);
    } catch (_) {}
  }

  int _countUnread(List<dynamic> list) =>
      list.where((n) => (n as Map)['read'] != true).length;
}

final notificationsPod = StateNotifierProvider<NotificationsNotifier, NotificationsState>(
  (ref) => NotificationsNotifier(),
);
