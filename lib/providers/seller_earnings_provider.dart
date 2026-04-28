import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../core/errors/app_exception.dart';

class SellerEarningsState {
  final bool isLoading;
  final String? error;
  final Map<String, dynamic> earnings;
  // earnings keys: totalEarnedRupees, pendingRupees, recentSettlements

  const SellerEarningsState({
    this.isLoading = false,
    this.error,
    this.earnings  = const {},
  });

  SellerEarningsState copyWith({
    bool? isLoading,
    String? error,
    Map<String, dynamic>? earnings,
  }) => SellerEarningsState(
    isLoading: isLoading ?? this.isLoading,
    error:     error,
    earnings:  earnings  ?? this.earnings,
  );
}

class SellerEarningsNotifier extends StateNotifier<SellerEarningsState> {
  SellerEarningsNotifier() : super(const SellerEarningsState());

  Dio get _client => ApiClient.instance.orderClient;

  Future<void> fetchEarnings() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res  = await _client.get(ApiEndpoints.sellerEarnings);
      final body = res.data as Map<String, dynamic>;
      final data = (body['data'] as Map<String, dynamic>?) ?? {};
      state = state.copyWith(isLoading: false, earnings: data);
    } on DioException catch (e) {
      state = state.copyWith(isLoading: false, error: AppException.fromDioError(e).message);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final sellerEarningsPod = StateNotifierProvider<SellerEarningsNotifier, SellerEarningsState>(
  (ref) => SellerEarningsNotifier(),
);
