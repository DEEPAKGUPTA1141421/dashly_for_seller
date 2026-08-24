import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../utils/storage_service.dart';
import 'api_endpoints.dart';

class AuthInterceptor extends Interceptor {
  final Dio _dio;
  bool _isRefreshing = false;

  /// Set once in main.dart — used to navigate to /login on full session expiry.
  static GlobalKey<NavigatorState>? navigatorKey;

  final List<({RequestOptions options, ErrorInterceptorHandler handler})>
      _retryQueue = [];

  AuthInterceptor(this._dio);

  // ── Attach access token to every outgoing request ─────────────────────────
  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await StorageService.getAccessToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  // ── On 401/403: attempt token refresh once, then retry ────────────────────
  // The backend's JWT filter doesn't reject an expired/invalid access token
  // outright — it just leaves the request unauthenticated, so Spring
  // Security's @PreAuthorize check fails it as 403 (not 401). Both therefore
  // need the same refresh-and-retry handling.
  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final statusCode = err.response?.statusCode;

    if (statusCode != 401 && statusCode != 403) {
      return handler.next(err);
    }

    // Refresh endpoint itself returned 401/403 → full logout
    if (err.requestOptions.path.contains(ApiEndpoints.refresh)) {
      await _clearAndDrain(err, handler);
      return;
    }

    // Queue while a refresh is already in flight
    if (_isRefreshing) {
      _retryQueue.add((options: err.requestOptions, handler: handler));
      return;
    }

    _isRefreshing = true;

    try {
      final refreshToken = await StorageService.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        await _clearAndDrain(err, handler);
        return;
      }

      // Use a CLEAN Dio with no interceptors so the expired token is NOT
      // re-attached to the refresh request by onRequest above.
      final cleanDio = Dio(BaseOptions(
        baseUrl:        _dio.options.baseUrl,
        connectTimeout: _dio.options.connectTimeout,
        receiveTimeout: _dio.options.receiveTimeout,
        headers: const {'Content-Type': 'application/json'},
      ));

      final response = await cleanDio.post(
        ApiEndpoints.refresh,
        data: {'refreshToken': refreshToken},
      );

      final body = response.data as Map<String, dynamic>?;
      if (body?['success'] == true) {
        final inner = body!['data'] as Map<String, dynamic>? ?? {};
        final newAccess  = inner['accessToken']  as String? ?? '';
        final newRefresh = inner['refreshToken'] as String? ?? newAccess;

        if (newAccess.isEmpty) {
          await _clearAndDrain(err, handler);
          return;
        }

        await StorageService.saveTokens(
          accessToken:  newAccess,
          refreshToken: newRefresh,
        );

        // Drain queued requests with the new token — their outcome (success
        // or a genuine error) is unrelated to session validity, since the
        // refresh above already succeeded.
        for (final item in _retryQueue) {
          item.options.headers['Authorization'] = 'Bearer $newAccess';
          _dio.fetch(item.options).then(
            (r) => item.handler.resolve(r),
            onError: (e) => item.handler.next(e as DioException),
          );
        }
        _retryQueue.clear();

        // Retry the original request with the new token. A failure here
        // (e.g. a genuine 403 for lacking permission on this resource) is
        // NOT a session problem — the refresh just succeeded — so it's
        // forwarded as a normal error instead of forcing a logout.
        err.requestOptions.headers['Authorization'] = 'Bearer $newAccess';
        try {
          final retried = await _dio.fetch(err.requestOptions);
          return handler.resolve(retried);
        } on DioException catch (retryErr) {
          return handler.next(retryErr);
        }
      } else {
        await _clearAndDrain(err, handler);
      }
    } catch (_) {
      await _clearAndDrain(err, handler);
    } finally {
      _isRefreshing = false;
    }
  }

  Future<void> _clearAndDrain(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    await StorageService.clearAll();
    for (final item in _retryQueue) {
      item.handler.next(err);
    }
    _retryQueue.clear();
    handler.next(err);

    navigatorKey?.currentState
        ?.pushNamedAndRemoveUntil('/login', (_) => false);
  }
}
