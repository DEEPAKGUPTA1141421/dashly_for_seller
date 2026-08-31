import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';

/// Notification categories, matching NotificationPreference.NotificationCategory
/// on the backend exactly (OrderPaymentNotificationService).
const List<String> kNotificationCategories = [
  'ORDER_UPDATES',
  'PAYMENT_UPDATES',
  'PRODUCT_UPDATES',
  'REVIEW_REMINDERS',
  'WALLET_UPDATES',
  'LOYALTY_UPDATES',
  'PROMOTIONS',
  'ACCOUNT_SECURITY',
  'SYSTEM_ALERTS',
];

String notificationCategoryLabel(String category) => switch (category) {
      'ORDER_UPDATES'    => 'Order Updates',
      'PAYMENT_UPDATES'  => 'Payment Updates',
      'PRODUCT_UPDATES'  => 'Product Updates',
      'REVIEW_REMINDERS' => 'Reviews',
      'WALLET_UPDATES'   => 'Wallet',
      'LOYALTY_UPDATES'  => 'Loyalty',
      'PROMOTIONS'       => 'Promotions',
      'ACCOUNT_SECURITY' => 'Account Security',
      'SYSTEM_ALERTS'    => 'System Alerts',
      _ => category,
    };

class NotificationPreferencesState {
  final bool isLoading;
  final String? error;
  // category -> IN_APP enabled
  final Map<String, bool> inAppEnabled;

  const NotificationPreferencesState({
    this.isLoading = false,
    this.error,
    this.inAppEnabled = const {},
  });

  NotificationPreferencesState copyWith({
    bool? isLoading,
    String? error,
    Map<String, bool>? inAppEnabled,
  }) => NotificationPreferencesState(
    isLoading:     isLoading     ?? this.isLoading,
    error:         error,
    inAppEnabled:  inAppEnabled  ?? this.inAppEnabled,
  );
}

class NotificationPreferencesNotifier extends StateNotifier<NotificationPreferencesState> {
  NotificationPreferencesNotifier() : super(const NotificationPreferencesState());

  Dio get _client => ApiClient.instance.orderClient;

  // GET /api/v1/users/notification-preferences
  Future<void> fetch() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res  = await _client.get(ApiEndpoints.notificationPreferences);
      final body = res.data as Map<String, dynamic>;
      final data = (body['data'] as Map<String, dynamic>?) ?? {};
      final prefsByCategory = (data['preferences'] as Map<String, dynamic>?) ?? {};

      final inApp = <String, bool>{};
      for (final category in kNotificationCategories) {
        final channels = prefsByCategory[category] as List<dynamic>? ?? [];
        final inAppEntry = channels.cast<Map<String, dynamic>>().firstWhere(
              (c) => c['channel'] == 'IN_APP',
              orElse: () => const {'enabled': true},
            );
        inApp[category] = inAppEntry['enabled'] as bool? ?? true;
      }

      state = state.copyWith(isLoading: false, inAppEnabled: inApp);
    } on DioException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  // PATCH /api/v1/users/notification-preferences/{category}
  Future<void> setEnabled(String category, bool enabled) async {
    final prev = Map<String, bool>.from(state.inAppEnabled);
    state = state.copyWith(inAppEnabled: {...prev, category: enabled});
    try {
      await _client.patch(
        '${ApiEndpoints.notificationPreferences}/$category',
        data: {'channel': 'IN_APP', 'enabled': enabled},
      );
    } catch (_) {
      // Revert on failure
      state = state.copyWith(inAppEnabled: prev);
    }
  }

  Future<void> setAll(bool enabled) async {
    for (final category in kNotificationCategories) {
      await setEnabled(category, enabled);
    }
  }
}

final notificationPreferencesPod =
    StateNotifierProvider<NotificationPreferencesNotifier, NotificationPreferencesState>(
  (ref) => NotificationPreferencesNotifier(),
);
