import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../core/errors/app_exception.dart';

class WalletState {
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final Map<String, dynamic> balance;       // walletId, balanceRupees, balancePaise, frozen, frozenReason
  final List<dynamic> transactions;         // [{id, type, source, amountRupees, closingBalanceRupees, ...}]
  final int currentPage;
  final bool hasMore;

  const WalletState({
    this.isLoading     = false,
    this.isLoadingMore = false,
    this.error,
    this.balance       = const {},
    this.transactions  = const [],
    this.currentPage   = 0,
    this.hasMore       = true,
  });

  WalletState copyWith({
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    Map<String, dynamic>? balance,
    List<dynamic>? transactions,
    int? currentPage,
    bool? hasMore,
  }) => WalletState(
    isLoading:     isLoading     ?? this.isLoading,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    error:         error,
    balance:       balance       ?? this.balance,
    transactions:  transactions  ?? this.transactions,
    currentPage:   currentPage   ?? this.currentPage,
    hasMore:       hasMore       ?? this.hasMore,
  );
}

class WalletNotifier extends StateNotifier<WalletState> {
  WalletNotifier() : super(const WalletState());

  Dio get _client => ApiClient.instance.orderClient;

  Future<void> fetchBalance() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res  = await _client.get(ApiEndpoints.wallet);
      final body = res.data as Map<String, dynamic>;
      final data = (body['data'] as Map<String, dynamic>?) ?? {};
      state = state.copyWith(isLoading: false, balance: data);
    } on DioException catch (e) {
      state = state.copyWith(isLoading: false, error: AppException.fromDioError(e).message);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> fetchTransactions({bool refresh = false}) async {
    if (refresh) {
      state = state.copyWith(isLoading: true, error: null, currentPage: 0, hasMore: true, transactions: []);
    } else {
      if (!state.hasMore || state.isLoadingMore) return;
      state = state.copyWith(isLoadingMore: true, error: null);
    }

    try {
      final page = refresh ? 0 : state.currentPage;
      final res  = await _client.get(
        ApiEndpoints.walletTransactions,
        queryParameters: {'page': page, 'size': 20},
      );
      final body = res.data as Map<String, dynamic>;
      final data = body['data'] as Map<String, dynamic>? ?? {};
      final list = (data['transactions'] as List<dynamic>?) ?? (data['content'] as List<dynamic>?) ?? [];
      final totalPages = (data['totalPages'] as num?)?.toInt() ?? 1;
      final newPage    = page + 1;

      state = state.copyWith(
        isLoading:     false,
        isLoadingMore: false,
        transactions:  refresh ? list : [...state.transactions, ...list],
        currentPage:   newPage,
        hasMore:       newPage < totalPages,
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

  Future<void> refresh() async {
    await Future.wait([fetchBalance(), fetchTransactions(refresh: true)]);
  }
}

final walletPod = StateNotifierProvider<WalletNotifier, WalletState>(
  (ref) => WalletNotifier(),
);
