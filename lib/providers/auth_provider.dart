import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../core/errors/app_exception.dart';
import '../main_layout.dart';
import '../utils/storage_service.dart';
import 'analytics_provider.dart';
import 'dashboard_provider.dart';
import 'notifications_provider.dart';
import 'orders_provider.dart';
import 'products_provider.dart';
import 'reviews_provider.dart';
import 'seller_earnings_provider.dart';
import 'settings_provider.dart';
import 'wallet_provider.dart';

class AuthState {
  final bool isLoading;
  final String? error;
  final bool isLoggedIn;
  final String? phone;
  final bool isSignup;

  const AuthState({
    this.isLoading = false,
    this.error,
    this.isLoggedIn = false,
    this.phone,
    this.isSignup = false,
  });

  AuthState copyWith({
    bool? isLoading,
    String? error,
    bool? isLoggedIn,
    String? phone,
    bool? isSignup,
  }) {
    return AuthState(
      isLoading:  isLoading  ?? this.isLoading,
      error:      error,
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      phone:      phone      ?? this.phone,
      isSignup:   isSignup   ?? this.isSignup,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final Ref _ref;
  AuthNotifier(this._ref) : super(const AuthState());

  Dio get _client => ApiClient.instance.client;

  // POST /api/v1/auth/login  { phone, typeOfUser }
  Future<bool> sendOtp(String phone) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res = await _client.post(
        ApiEndpoints.login,
        data: {'phone': phone, 'typeOfUser': 'SELLER'},
      );
      final body = res.data as Map<String, dynamic>;
      if (body['success'] == true) {
        final data     = body['data'] as Map<String, dynamic>? ?? {};
        final isSignup = data['isSignup']?.toString() == 'true';
        state = state.copyWith(isLoading: false, phone: phone, isSignup: isSignup);
        return true;
      }
      state = state.copyWith(isLoading: false, error: body['message'] ?? 'Failed to send OTP');
      return false;
    } on DioException catch (e) {
      state = state.copyWith(isLoading: false, error: AppException.fromDioError(e).message);
      return false;
    }
  }

  // POST /api/v1/auth/verify  { phone, otp_code, typeOfUser }
  Future<bool> verifyOtp(String phone, String otp) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res = await _client.post(
        ApiEndpoints.verifyOtp,
        data: {'phone': phone, 'otp_code': otp, 'typeOfUser': 'SELLER'},
      );
      final body = res.data as Map<String, dynamic>;
      if (body['success'] == true) {
        final data         = body['data'] as Map<String, dynamic>? ?? {};
        final accessToken  = data['accessToken']  as String? ?? '';
        final refreshToken = data['refreshToken'] as String? ?? '';
        await StorageService.saveTokens(
          accessToken:  accessToken,
          refreshToken: refreshToken,
        );
        // Seller ID lives inside data.user.id
        final user = data['user'] as Map<String, dynamic>?;
        final sellerId = user?['id']?.toString() ?? data['sellerId']?.toString();
        if (sellerId != null && sellerId.isNotEmpty) {
          await StorageService.saveSellerId(sellerId);
        }
        final displayName = user?['displayName']?.toString() ?? '';
        if (displayName.isNotEmpty) {
          await StorageService.saveDisplayName(displayName);
        }
        state = state.copyWith(isLoading: false, isLoggedIn: true);
        return true;
      }
      state = state.copyWith(isLoading: false, error: body['message'] ?? 'Invalid OTP');
      return false;
    } on DioException catch (e) {
      state = state.copyWith(isLoading: false, error: AppException.fromDioError(e).message);
      return false;
    }
  }

  // POST /api/v1/auth/logout  { refreshToken }
  Future<void> logout() async {
    try {
      final refreshToken = await StorageService.getRefreshToken();
      await _client.post(
        ApiEndpoints.logout,
        data: {'refreshToken': refreshToken},
      );
    } catch (_) {}
    await StorageService.clearAll();
    // Reset all seller-scoped data so the next login gets a clean slate
    _ref.invalidate(settingsPod);
    _ref.invalidate(dashboardPod);
    _ref.invalidate(ordersPod);
    _ref.invalidate(productsPod);
    _ref.invalidate(analyticsPod);
    _ref.invalidate(walletPod);
    _ref.invalidate(sellerEarningsPod);
    _ref.invalidate(notificationsPod);
    _ref.invalidate(reviewsPod);
    _ref.invalidate(navIndexPod);
    state = const AuthState();
  }
}

final authPod = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(ref),
);
