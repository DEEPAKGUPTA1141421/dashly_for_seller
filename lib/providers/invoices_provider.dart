import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../core/errors/app_exception.dart';

class InvoicesState {
  final bool isLoading;
  final String? error;
  final List<dynamic> invoices;
  final String filterStatus; // 'ALL' | 'DRAFT' | 'FINALIZED' | 'SENT' | 'PAID' | ...
  final int currentPage;
  final bool hasMore;
  final List<dynamic> customers;

  const InvoicesState({
    this.isLoading = false,
    this.error,
    this.invoices = const [],
    this.filterStatus = 'ALL',
    this.currentPage = 0,
    this.hasMore = true,
    this.customers = const [],
  });

  InvoicesState copyWith({
    bool? isLoading,
    String? error,
    List<dynamic>? invoices,
    String? filterStatus,
    int? currentPage,
    bool? hasMore,
    List<dynamic>? customers,
  }) {
    return InvoicesState(
      isLoading:    isLoading    ?? this.isLoading,
      error:        error,
      invoices:     invoices     ?? this.invoices,
      filterStatus: filterStatus ?? this.filterStatus,
      currentPage:  currentPage  ?? this.currentPage,
      hasMore:      hasMore      ?? this.hasMore,
      customers:    customers    ?? this.customers,
    );
  }
}

class InvoiceDownload {
  final Uint8List bytes;
  final String filename;
  const InvoiceDownload({required this.bytes, required this.filename});
}

class InvoicesNotifier extends StateNotifier<InvoicesState> {
  InvoicesNotifier() : super(const InvoicesState());

  Dio get _client => ApiClient.instance.orderClient;

  Future<void> fetchInvoices({String? status, String? query, bool reset = true}) async {
    final s = status ?? state.filterStatus;
    if (reset) state = state.copyWith(isLoading: true, error: null, currentPage: 0);
    try {
      final params = <String, dynamic>{'page': 0, 'size': 20};
      if (query != null && query.trim().isNotEmpty) {
        params['query'] = query.trim();
      } else if (s != 'ALL') {
        params['status'] = s;
      }
      final res  = await _client.get(ApiEndpoints.invoices, queryParameters: params);
      final body = res.data as Map<String, dynamic>;
      final data = (body['data'] as Map<String, dynamic>?)?['invoices'] as List<dynamic>? ?? [];
      state = state.copyWith(isLoading: false, invoices: data, hasMore: data.length >= 20);
    } on DioException catch (e) {
      state = state.copyWith(isLoading: false, error: AppException.fromDioError(e).message);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoading) return;
    try {
      final nextPage = state.currentPage + 1;
      final params = <String, dynamic>{'page': nextPage, 'size': 20};
      if (state.filterStatus != 'ALL') params['status'] = state.filterStatus;
      final res  = await _client.get(ApiEndpoints.invoices, queryParameters: params);
      final body = res.data as Map<String, dynamic>;
      final data = (body['data'] as Map<String, dynamic>?)?['invoices'] as List<dynamic>? ?? [];
      state = state.copyWith(
        invoices: [...state.invoices, ...data],
        currentPage: nextPage,
        hasMore: data.length >= 20,
      );
    } on DioException catch (e) {
      state = state.copyWith(error: AppException.fromDioError(e).message);
    }
  }

  void setFilter(String status) {
    if (state.filterStatus == status) return;
    state = state.copyWith(filterStatus: status);
    fetchInvoices(status: status);
  }

  Future<Map<String, dynamic>> fetchDetail(String invoiceId) async {
    try {
      final res  = await _client.get('${ApiEndpoints.invoices}/$invoiceId');
      final body = res.data as Map<String, dynamic>;
      return (body['data'] as Map<String, dynamic>?) ?? {};
    } on DioException catch (e) {
      state = state.copyWith(error: AppException.fromDioError(e).message);
      return {};
    }
  }

  Future<void> fetchCustomers() async {
    try {
      final res  = await _client.get(ApiEndpoints.invoiceCustomers);
      final body = res.data as Map<String, dynamic>;
      state = state.copyWith(customers: (body['data'] as List<dynamic>?) ?? []);
    } catch (_) {}
  }

  /// Retries finalizing an invoice stuck in DRAFT (e.g. the app closed
  /// between create and finalize) — completes the same invoiceId instead
  /// of creating a duplicate draft.
  Future<bool> finalizeInvoice(String invoiceId) async {
    try {
      final res  = await _client.post('${ApiEndpoints.invoices}/$invoiceId/finalize');
      final body = res.data as Map<String, dynamic>;
      return body['success'] == true;
    } on DioException catch (e) {
      state = state.copyWith(error: AppException.fromDioError(e).message);
      return false;
    }
  }

  Future<bool> cancelInvoice(String invoiceId) async {
    try {
      final res  = await _client.post('${ApiEndpoints.invoices}/$invoiceId/cancel');
      final body = res.data as Map<String, dynamic>;
      return body['success'] == true;
    } on DioException catch (e) {
      state = state.copyWith(error: AppException.fromDioError(e).message);
      return false;
    }
  }

  /// channel: 'WHATSAPP' | 'EMAIL'. destination overrides the customer's stored phone/email.
  Future<bool> sendInvoice(String invoiceId, String channel, {String? destination}) async {
    try {
      final res = await _client.post(
        '${ApiEndpoints.invoices}/$invoiceId/send',
        data: {'channel': channel, if (destination != null) 'destination': destination},
      );
      final body = res.data as Map<String, dynamic>;
      return body['success'] == true;
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    }
  }

  Future<InvoiceDownload> downloadPdf(String invoiceId, {String? invoiceNumber}) async {
    try {
      final res = await _client.get<List<int>>(
        '${ApiEndpoints.invoices}/$invoiceId/download',
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes = Uint8List.fromList(res.data ?? const []);
      if (bytes.isEmpty) {
        throw const AppException(message: 'Invoice PDF is empty. Please try again.');
      }
      final disposition = res.headers.value('content-disposition') ?? '';
      final match = RegExp(r'filename="?([^";]+)"?').firstMatch(disposition);
      final rawFilename = match?.group(1) ?? '${invoiceNumber ?? invoiceId}.pdf';
      // Invoice numbers (e.g. GST format "1/2026-27") can contain characters
      // that are illegal or path separators on the filesystem — strip them
      // so the local file write below doesn't fail on a "successful" download.
      final filename = rawFilename.replaceAll(RegExp(r'[\\/:*?"<>|]'), '-');
      return InvoiceDownload(bytes: bytes, filename: filename);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 404) {
        throw const AppException(message: 'This invoice has not been finalized yet.', statusCode: 404);
      }
      throw AppException.fromDioError(e);
    }
  }
}

final invoicesPod = StateNotifierProvider<InvoicesNotifier, InvoicesState>(
  (ref) => InvoicesNotifier(),
);
