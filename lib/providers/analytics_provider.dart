import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../core/errors/app_exception.dart';
import '../models/activity_week.dart';
import '../models/balance_stat.dart';

final _commaFmt = NumberFormat('#,##0');

class AnalyticsState {
  final bool isLoading;
  final String? error;
  final List<dynamic> dailyChart;    // [{day, orders, revenuePaise, revenueRupees}]
  final Map<String, dynamic> stats;  // totalOrders, totalRevenue, statusBreakdown, deltas
  final int selectedDays;            // 7 | 30 | 90
  final List<dynamic> topProducts;   // [{productId, productName, totalQty, revenuePaise, revenueRupees}]

  // "Current balance" cards (Earning / Customer / Payouts).
  final List<BalanceStat> balanceStats;

  // "Product activity" weekly table.
  final List<ActivityWeek> activityWeeks;
  final bool isActivityLoading;
  final int activityWeeksRequested; // pagination: how many weeks we've asked the backend for

  // Customer Analytics additions.
  final List<dynamic> topCities;       // [{city, count, percent}]
  final List<dynamic> trafficSources;  // [{source, count}] — presented as "Top Sources"
  final List<dynamic> monthlyViews;    // [{month, views}]
  final Map<String, dynamic> returnSummary; // {openCount, newCount}
  final List<dynamic> recentCustomers; // proxy: recent reviewers [{reviewerId, reviewerName, reviewerAvatarUrl}]

  const AnalyticsState({
    this.isLoading    = false,
    this.error,
    this.dailyChart   = const [],
    this.stats        = const {},
    this.selectedDays = 7,
    this.topProducts  = const [],
    this.balanceStats = const [],
    this.activityWeeks = const [],
    this.isActivityLoading = false,
    this.activityWeeksRequested = 2,
    this.topCities = const [],
    this.trafficSources = const [],
    this.monthlyViews = const [],
    this.returnSummary = const {},
    this.recentCustomers = const [],
  });

  AnalyticsState copyWith({
    bool? isLoading,
    String? error,
    List<dynamic>? dailyChart,
    Map<String, dynamic>? stats,
    int? selectedDays,
    List<dynamic>? topProducts,
    List<BalanceStat>? balanceStats,
    List<ActivityWeek>? activityWeeks,
    bool? isActivityLoading,
    int? activityWeeksRequested,
    List<dynamic>? topCities,
    List<dynamic>? trafficSources,
    List<dynamic>? monthlyViews,
    Map<String, dynamic>? returnSummary,
    List<dynamic>? recentCustomers,
  }) => AnalyticsState(
    isLoading:    isLoading    ?? this.isLoading,
    error:        error,
    dailyChart:   dailyChart   ?? this.dailyChart,
    stats:        stats        ?? this.stats,
    selectedDays: selectedDays ?? this.selectedDays,
    topProducts:  topProducts  ?? this.topProducts,
    balanceStats: balanceStats ?? this.balanceStats,
    activityWeeks: activityWeeks ?? this.activityWeeks,
    isActivityLoading: isActivityLoading ?? this.isActivityLoading,
    activityWeeksRequested: activityWeeksRequested ?? this.activityWeeksRequested,
    topCities: topCities ?? this.topCities,
    trafficSources: trafficSources ?? this.trafficSources,
    monthlyViews: monthlyViews ?? this.monthlyViews,
    returnSummary: returnSummary ?? this.returnSummary,
    recentCustomers: recentCustomers ?? this.recentCustomers,
  );
}

class AnalyticsNotifier extends StateNotifier<AnalyticsState> {
  AnalyticsNotifier() : super(const AnalyticsState());

  Dio get _client => ApiClient.instance.orderClient;
  Dio get _productClient => ApiClient.instance.client;

  Future<void> fetchStats({int? days}) async {
    final d = days ?? state.selectedDays;
    state = state.copyWith(isLoading: true, error: null, selectedDays: d);
    try {
      final results = await Future.wait([
        _client.get(ApiEndpoints.sellerStats, queryParameters: {'days': d}),
        _client.get(ApiEndpoints.sellerTopProducts, queryParameters: {'limit': 5}),
        _client.get(ApiEndpoints.sellerCustomerStats, queryParameters: {'days': d}),
        _client.get(ApiEndpoints.sellerEarnings),
      ]);

      final statsBody = results[0].data as Map<String, dynamic>;
      final data      = (statsBody['data'] as Map<String, dynamic>?) ?? {};

      final topBody = results[1].data as Map<String, dynamic>;
      final topList = (topBody['data'] as List<dynamic>?) ?? [];

      final customerBody = results[2].data as Map<String, dynamic>;
      final customerData = (customerBody['data'] as Map<String, dynamic>?) ?? {};

      final earningsBody = results[3].data as Map<String, dynamic>;
      final earningsData = (earningsBody['data'] as Map<String, dynamic>?) ?? {};

      state = state.copyWith(
        isLoading:   false,
        dailyChart:  (data['dailyChart'] as List<dynamic>?) ?? [],
        stats:       data,
        topProducts: topList,
        balanceStats: _buildBalanceStats(data, customerData, earningsData),
      );

      // Kick off independent fetches without blocking the primary stats render.
      unawaited(fetchActivity());
      unawaited(fetchCustomerAnalyticsExtras());
    } on DioException catch (e) {
      state = state.copyWith(isLoading: false, error: AppException.fromDioError(e).message);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  List<BalanceStat> _buildBalanceStats(
    Map<String, dynamic> stats,
    Map<String, dynamic> customerStats,
    Map<String, dynamic> earnings,
  ) {
    final revenueRupees = double.tryParse(stats['totalRevenueRupees']?.toString() ?? '0') ?? 0.0;
    final earningSparkline = _toDoubleList(stats['earningSparkline']);

    final totalCustomers = (customerStats['totalCustomers'] as num?)?.toInt() ?? 0;
    final customerChange = (customerStats['customersChangePercent'] as num?)?.toDouble() ?? 0.0;
    final customerSparkline = _toDoubleList(customerStats['sparkline']);

    final payoutsRupees = double.tryParse(earnings['totalEarnedRupees']?.toString() ?? '0') ?? 0.0;
    final payoutsSparkline = _toDoubleList(earnings['sparkline']);

    return [
      BalanceStat(
        label: 'Earning',
        value: _commaFmt.format(revenueRupees.round()),
        changePct: (stats['revenueChange'] as num?)?.toDouble() ?? 0.0,
        sparkline: earningSparkline,
      ),
      BalanceStat(
        label: 'Customer',
        value: _commaFmt.format(totalCustomers),
        changePct: customerChange,
        sparkline: customerSparkline,
      ),
      BalanceStat(
        label: 'Payouts',
        // No week-over-week delta exposed by the earnings endpoint yet — 0 means
        // "no change" per the plan's fallback instruction.
        value: _commaFmt.format(payoutsRupees.round()),
        changePct: 0.0,
        sparkline: payoutsSparkline,
      ),
    ];
  }

  List<double> _toDoubleList(dynamic raw) {
    if (raw is List) {
      return raw.map((e) => (e as num?)?.toDouble() ?? 0.0).toList();
    }
    return const [];
  }

  /// Fetches the "Product activity" weekly table independently of [fetchStats]
  /// so the table's own "Load more" button doesn't refetch everything else.
  /// Pagination is simple: the backend's `weeks` param is a total count anchored
  /// to the current week, so "load more" just asks for more total weeks and
  /// replaces the (now-longer) list.
  Future<void> fetchActivity({bool loadMore = false}) async {
    final weeks = loadMore ? state.activityWeeksRequested + 2 : state.activityWeeksRequested;
    state = state.copyWith(isActivityLoading: true, activityWeeksRequested: weeks);
    try {
      final res  = await _productClient.get(
        ApiEndpoints.sellerProductActivity,
        queryParameters: {'weeks': weeks},
      );
      final body = res.data as Map<String, dynamic>;
      final rows = (body['data'] as List<dynamic>?) ?? [];

      // Rows come back oldest-first; compute week-over-week % deltas for the
      // Figma pill display since the backend only returns raw counts.
      final parsed = <ActivityWeek>[];
      for (var i = 0; i < rows.length; i++) {
        final row = Map<String, dynamic>.from(rows[i] as Map);
        final products = _toInt(row['products']);
        final views    = _toInt(row['views']);
        final comments = _toInt(row['comments']);

        double? productsDelta;
        double? viewsDelta;
        double? commentsDelta;
        if (i > 0) {
          final prev = Map<String, dynamic>.from(rows[i - 1] as Map);
          productsDelta = _pctDelta(_toInt(prev['products']), products);
          viewsDelta    = _pctDelta(_toInt(prev['views']), views);
          commentsDelta = _pctDelta(_toInt(prev['comments']), comments);
        }

        parsed.add(ActivityWeek(
          weekLabel: _formatWeekLabel(row['week']?.toString() ?? ''),
          products: products,
          productsChangePct: productsDelta,
          views: views,
          viewsChangePct: viewsDelta,
          comments: comments,
          commentsChangePct: commentsDelta,
        ));
      }

      // Most-recent-first for display, matching the Figma table.
      state = state.copyWith(isActivityLoading: false, activityWeeks: parsed.reversed.toList());
    } on DioException catch (e) {
      state = state.copyWith(isActivityLoading: false, error: AppException.fromDioError(e).message);
    } catch (e) {
      state = state.copyWith(isActivityLoading: false, error: e.toString());
    }
  }

  /// Fetches the Customer Analytics extras (top cities, traffic sources,
  /// monthly views, refund summary, recent reviewers-as-customers) — all
  /// independent of the primary stats fetch so a slow one doesn't block the page.
  Future<void> fetchCustomerAnalyticsExtras() async {
    try {
      final results = await Future.wait([
        _productClient.get(ApiEndpoints.sellerTopCities, queryParameters: {'days': 30}),
        _productClient.get(ApiEndpoints.sellerProductTrafficSources, queryParameters: {'days': 30}),
        _productClient.get(ApiEndpoints.sellerMonthlyViews, queryParameters: {'months': 6}),
        _productClient.get(ApiEndpoints.sellerReturnSummary),
        _productClient.get(ApiEndpoints.sellerReviews, queryParameters: {'page': 0, 'size': 5}),
      ]);

      List<dynamic> listAt(int i) {
        final body = results[i].data as Map<String, dynamic>;
        return (body['data'] as List<dynamic>?) ?? [];
      }

      final returnBody = results[3].data as Map<String, dynamic>;
      final returnData = (returnBody['data'] as Map<String, dynamic>?) ?? {};

      final reviewsBody = results[4].data as Map<String, dynamic>;
      final reviewsData = (reviewsBody['data'] as Map<String, dynamic>?) ?? {};
      final recentReviews = (reviewsData['reviews'] as List<dynamic>?) ?? [];

      state = state.copyWith(
        topCities: listAt(0),
        trafficSources: listAt(1),
        monthlyViews: listAt(2),
        returnSummary: returnData,
        recentCustomers: recentReviews,
      );
    } catch (_) {
      // Non-fatal — these are supplementary cards, main analytics already rendered.
    }
  }

  Future<bool> notifyCustomers(List<String> userIds, String message) async {
    try {
      final res  = await _productClient.post(
        ApiEndpoints.sellerCustomersNotify,
        data: {'userIds': userIds, 'message': message},
      );
      final body = res.data as Map<String, dynamic>;
      return body['success'] == true;
    } catch (_) {
      return false;
    }
  }

  double? _pctDelta(int prev, int curr) {
    if (prev == 0) return curr == 0 ? 0.0 : null; // undefined % change from zero
    return ((curr - prev) / prev) * 100;
  }

  int _toInt(dynamic v) {
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  String _formatWeekLabel(String isoDate) {
    final d = DateTime.tryParse(isoDate);
    if (d == null) return isoDate;
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${d.day} ${months[d.month - 1]}';
  }

  void setDays(int days) {
    if (days == state.selectedDays) return;
    fetchStats(days: days);
  }
}

final analyticsPod = StateNotifierProvider<AnalyticsNotifier, AnalyticsState>(
  (ref) => AnalyticsNotifier(),
);
