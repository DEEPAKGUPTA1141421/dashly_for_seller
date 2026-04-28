import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/widgets/app_shimmer.dart';
import '../core/widgets/app_toast.dart';
import '../providers/orders_provider.dart';
import '../utils/app_colors.dart';
import '../utils/haptic_utils.dart';
import '../widgets/order_detail_sheet.dart';
import '../widgets/order_list_tile.dart';

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  // Pairs of (apiValue, displayLabel) — apiValue sent to backend, displayLabel shown in chip
  static const _filters = [
    ('ALL',              'All'),
    ('CONFIRMED',        'Confirmed'),
    ('PROCESSING',       'Processing'),
    ('OUT_FOR_DELIVERY', 'Out for Delivery'),
    ('DELIVERED',        'Delivered'),
    ('CANCELLED',        'Cancelled'),
  ];

  final _scrollCtrl  = ScrollController();
  final _searchCtrl  = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(ordersPod.notifier).fetchOrders();
      ref.read(ordersPod.notifier).fetchStatusCounts();
    });
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 200) {
      ref.read(ordersPod.notifier).loadMoreOrders();
    }
  }

  List<dynamic> _filtered(List<dynamic> orders) {
    if (_searchQuery.isEmpty) return orders;
    final q = _searchQuery.toLowerCase();
    return orders.where((o) {
      final id     = (o['bookingId'] ?? '').toString().toLowerCase();
      final label  = (o['statusLabel'] ?? '').toString().toLowerCase();
      return id.contains(q) || label.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(ordersPod);

    ref.listen(ordersPod, (prev, next) {
      if (next.error != null && next.error != prev?.error) {
        AppToast.show(context, message: next.error!, type: ToastType.error);
      }
    });

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: const Text(
                'Orders',
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ).animate().fadeIn(),
            ),
            const SizedBox(height: 16),

            // Filter chips
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _filters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final (apiValue, label) = _filters[i];
                  final selected = state.filterStatus == apiValue;
                  final count    = state.statusCounts[apiValue];
                  return GestureDetector(
                    onTap: () {
                      HapticUtils.light();
                      ref.read(ordersPod.notifier).setFilter(apiValue);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.white : AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: selected ? AppColors.white : AppColors.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            label,
                            style: TextStyle(
                              color: selected ? AppColors.bg : AppColors.grey,
                              fontSize: 12,
                              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                          if (count != null && count > 0) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: selected ? AppColors.bg.withOpacity(0.15) : AppColors.surface2,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$count',
                                style: TextStyle(
                                  color: selected ? AppColors.bg : AppColors.grey,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ).animate().fadeIn(delay: 80.ms),

            const SizedBox(height: 12),

            // Search bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _searchQuery = v),
                style: const TextStyle(color: AppColors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search by order ID or status…',
                  hintStyle: const TextStyle(color: AppColors.greyDark, fontSize: 14),
                  prefixIcon: const Icon(Icons.search_rounded, color: AppColors.grey, size: 20),
                  filled: true,
                  fillColor: AppColors.surface,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.white, width: 1.5)),
                ),
              ),
            ).animate().fadeIn(delay: 120.ms),

            const SizedBox(height: 12),

            // Orders list
            Expanded(
              child: state.isLoading
                  ? ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: 6,
                      itemBuilder: (_, __) => const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: OrderItemShimmer(),
                      ),
                    )
                  : Builder(
                      builder: (context) {
                        final orders = _filtered(state.orders);
                        if (orders.isEmpty) return _EmptyState();
                        return RefreshIndicator(
                          onRefresh: () async {
                            HapticUtils.light();
                            await ref.read(ordersPod.notifier).fetchOrders(status: state.filterStatus);
                          },
                          color: AppColors.white,
                          backgroundColor: AppColors.surface,
                          child: ListView.builder(
                            controller: _scrollCtrl,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: orders.length + (state.hasMore && _searchQuery.isEmpty ? 1 : 0),
                            itemBuilder: (_, i) {
                              if (i == orders.length) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 20),
                                  child: Center(child: SizedBox(
                                    width: 20, height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.grey),
                                  )),
                                );
                              }
                              return OrderListTile(
                                order: orders[i] as Map,
                                onTap: () => OrderDetailSheet.show(
                                  context,
                                  orders[i] as Map,
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(Icons.receipt_long_rounded, color: AppColors.greyDark, size: 36),
          ),
          const SizedBox(height: 16),
          const Text('No orders found', style: TextStyle(color: AppColors.grey, fontSize: 14)),
        ],
      ).animate().fadeIn().scale(begin: const Offset(0.9, 0.9)),
    );
  }
}
