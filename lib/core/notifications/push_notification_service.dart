import 'dart:io';

import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../main_layout.dart';
import '../../providers/notifications_provider.dart';
import '../../screens/reviews_screen.dart';
import '../../utils/storage_service.dart';
import '../api/api_client.dart';
import '../api/api_endpoints.dart';
import '../api/auth_interceptor.dart';

/// Matches the shape of `ref.read` / `WidgetRef.read`, so this service can be
/// called from either a `Ref` (StateNotifier) or `WidgetRef` (ConsumerState)
/// context without those two unrelated Riverpod types needing to unify.
typedef Reader = T Function<T>(ProviderListenable<T> provider);

/// Firebase Cloud Messaging integration.
///
/// On **Android**, Firebase is configured natively via
/// `android/app/google-services.json` (applied through the
/// `com.google.gms.google-services` Gradle plugin) — `Firebase.initializeApp()`
/// is called with no explicit options and reads that file automatically.
///
/// On **iOS/other platforms** without a native config file yet,
/// `FirebaseOptions` can instead be supplied via --dart-define (FIREBASE_API_KEY
/// / FIREBASE_APP_ID / FIREBASE_MESSAGING_SENDER_ID / FIREBASE_PROJECT_ID) —
/// get these from Firebase Console → Project settings → your app:
///   flutter run --dart-define=FIREBASE_API_KEY=... \
///     --dart-define=FIREBASE_APP_ID=... \
///     --dart-define=FIREBASE_MESSAGING_SENDER_ID=... \
///     --dart-define=FIREBASE_PROJECT_ID=...
///
/// Without a google-services.json (Android) or those dart-define values
/// (other platforms), `initialize()` no-ops — matches the backend's
/// `fcm.enabled=false` graceful-degradation behavior.
///
/// iOS additionally needs the "Push Notifications" + "Background Modes →
/// Remote notifications" capabilities enabled in Xcode (Runner target), plus
/// its own GoogleService-Info.plist — manual, one-time Xcode steps this
/// service can't automate.
class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  static const _apiKey            = String.fromEnvironment('FIREBASE_API_KEY');
  static const _appId             = String.fromEnvironment('FIREBASE_APP_ID');
  static const _messagingSenderId = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  static const _projectId         = String.fromEnvironment('FIREBASE_PROJECT_ID');

  static bool get _hasDartDefineOptions =>
      _apiKey.isNotEmpty && _appId.isNotEmpty && _messagingSenderId.isNotEmpty && _projectId.isNotEmpty;

  /// Android always attempts native init (google-services.json, if present);
  /// other platforms need the dart-define values until they get their own
  /// native config file.
  static bool get isConfigured => Platform.isAndroid || _hasDartDefineOptions;

  bool _initialized = false;

  /// [read] should be `ref.read` — accepted as a plain function (rather than
  /// typing the parameter as `Ref`) so this can be called from both a
  /// `WidgetRef` (ConsumerState) and a plain `Ref` (StateNotifier) context.
  Future<void> initialize(Reader read) async {
    if (_initialized || !isConfigured) return;
    _initialized = true;

    try {
      if (Platform.isAndroid) {
        // Reads android/app/google-services.json via the Gradle plugin.
        await Firebase.initializeApp();
      } else if (_hasDartDefineOptions) {
        await Firebase.initializeApp(
          options: const FirebaseOptions(
            apiKey: _apiKey,
            appId: _appId,
            messagingSenderId: _messagingSenderId,
            projectId: _projectId,
          ),
        );
      } else {
        _initialized = false;
        return;
      }

      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);

      final token = await messaging.getToken();
      if (token != null) {
        await _registerToken(token);
      }
      messaging.onTokenRefresh.listen(_registerToken);

      FirebaseMessaging.onMessage.listen((message) => _handleForegroundMessage(read, message));
      FirebaseMessaging.onMessageOpenedApp.listen((message) => _handleTap(read, message));

      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        // App was launched from a terminated state by tapping a push —
        // defer until the navigator is attached (post-splash).
        WidgetsBinding.instance.addPostFrameCallback((_) => _handleTap(read, initialMessage));
      }
    } catch (e) {
      debugPrint('[Push] Initialization failed (continuing without push): $e');
    }
  }

  Future<void> _registerToken(String token) async {
    try {
      final res = await ApiClient.instance.orderClient.post(
        ApiEndpoints.deviceTokens,
        data: {
          'deviceToken': token,
          'platform': Platform.isIOS ? 'IOS' : 'ANDROID',
          'appVersion': '1.0.0',
        },
      );
      final body = res.data as Map<String, dynamic>?;
      final data = body?['data'] as Map<String, dynamic>?;
      final id = data?['id']?.toString();
      if (id != null && id.isNotEmpty) {
        await StorageService.saveDeviceId(id);
      }
    } on DioException catch (e) {
      debugPrint('[Push] Device token registration failed: ${e.message}');
    } catch (_) {}
  }

  /// Best-effort deregistration on logout.
  Future<void> deregister() async {
    try {
      final deviceId = await StorageService.getDeviceId();
      if (deviceId != null && deviceId.isNotEmpty) {
        await ApiClient.instance.orderClient.delete('${ApiEndpoints.deviceTokens}/$deviceId');
      }
    } catch (_) {}
    await StorageService.clearDeviceId();
    _initialized = false;
  }

  void _handleForegroundMessage(Reader read, RemoteMessage message) {
    final data = _extractData(message);
    read(notificationsPod.notifier).receivePush(data);
    read(notificationsPod.notifier).fetchUnreadCount();

    final context = AuthInterceptor.navigatorKey?.currentState?.context;
    final title = message.notification?.title ?? data['title'] as String?;
    final body  = message.notification?.body  ?? data['body']  as String?;
    if (context != null && title != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(body != null ? '$title — $body' : title, maxLines: 2, overflow: TextOverflow.ellipsis),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _handleTap(Reader read, RemoteMessage message) {
    // Refetch fresh data rather than trusting the (possibly stale) push
    // payload for what to display.
    read(notificationsPod.notifier).fetchUnreadCount();

    final data = _extractData(message);
    final category = (data['category'] as String?)?.toUpperCase() ?? '';
    final navState = AuthInterceptor.navigatorKey;
    if (navState == null) return;

    switch (category) {
      case 'ORDER_UPDATES':
      case 'PAYMENT_UPDATES':
        read(navIndexPod.notifier).state = 1; // Orders tab
        break;
      case 'PRODUCT_UPDATES':
        read(navIndexPod.notifier).state = 2; // Products tab
        break;
      case 'REVIEW_REMINDERS':
        navState.currentState?.push(MaterialPageRoute(builder: (_) => const ReviewsScreen()));
        break;
      default:
        break;
    }
  }

  Map<String, dynamic> _extractData(RemoteMessage message) {
    final data = Map<String, dynamic>.from(message.data);
    data.putIfAbsent('title', () => message.notification?.title);
    data.putIfAbsent('body', () => message.notification?.body);
    return data;
  }
}
