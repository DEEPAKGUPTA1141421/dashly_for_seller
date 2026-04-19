import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../core/errors/app_exception.dart';
import '../utils/storage_service.dart';

class AuthState {
  final bool isLoading;
  final String? error;
  final bool isLoggedIn;
  final String? phone;

  const AuthState({
    this.isLoading = false,
    this.error,
    this.isLoggedIn = false,
    this.phone,
  });

  AuthState copyWith({
    bool? isLoading,
    String? error,
    bool? isLoggedIn,
    String? phone,
  }) {
    return AuthState(
      isLoading:  isLoading  ?? this.isLoading,
      error:      error,
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      phone:      phone      ?? this.phone,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState());

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
        state = state.copyWith(isLoading: false, phone: phone);
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
    state = const AuthState();
  }
}

final authPod = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(),
);
