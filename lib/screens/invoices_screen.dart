import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/widgets/app_shimmer.dart';
import '../core/widgets/app_toast.dart';
import '../providers/invoices_provider.dart';
import '../utils/app_colors.dart';
import '../utils/haptic_utils.dart';
import '../widgets/invoice/invoice_detail_sheet.dart';
import '../widgets/invoice/invoice_list_tile.dart';
import 'create_invoice_screen.dart';
import 'earnings_tab.dart';

class InvoicesScreen extends ConsumerStatefulWidget {
  const InvoicesScreen({super.key});

  @override
  ConsumerState<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends ConsumerState<InvoicesScreen> {
  static const _filters = [
    ('ALL', 'All'),
    ('DRAFT', 'Draft'),
    ('FINALIZED', 'Finalized'),
    ('SENT', 'Sent'),
    ('PAID', 'Paid'),
    ('CANCELLED', 'Cancelled'),
  ];

  final _scrollCtrl = ScrollController();
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  int _tabIndex = 0; // 0 = Invoice, 1 = Earning

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(invoicesPod.notifier).fetchInvoices());
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
      ref.read(invoicesPod.notifier).loadMore();
    }
  }

  void _onSearchChanged(String v) {
    setState(() => _searchQuery = v);
    ref.read(invoicesPod.notifier).fetchInvoices(query: v.isEmpty ? null : v);
  }

  Future<void> _openCreateInvoice() async {
    HapticUtils.medium();
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CreateInvoiceScreen()));
    ref.read(invoicesPod.notifier).fetchInvoices(status: ref.read(invoicesPod).filterStatus);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(invoicesPod);

    ref.listen(invoicesPod, (prev, next) {
      if (next.error != null && next.error != prev?.error) {
        AppToast.show(context, message: next.error!, type: ToastType.error);
      }
    });

    return Scaffold(
      backgroundColor: AppColors.bg,
      floatingActionButton: _tabIndex == 0
          ? FloatingActionButton.extended(
              onPressed: _openCreateInvoice,
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create Invoice', style: TextStyle(fontWeight: FontWeight.w700)),
            )
          : null,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: const Text(
                'Invoices',
                style: TextStyle(color: AppColors.white, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.3),
              ).animate().fadeIn(),
            ),
            const SizedBox(height: 16),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _InvoiceEarningTabs(
                index: _tabIndex,
                onChanged: (i) {
                  HapticUtils.light();
                  setState(() => _tabIndex = i);
                },
              ),
            ).animate().fadeIn(delay: 40.ms),

            const SizedBox(height: 16),

            if (_tabIndex == 1)
              const Expanded(child: EarningsTab())
            else ...[
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
                  return GestureDetector(
                    onTap: () {
                      HapticUtils.light();
                      ref.read(invoicesPod.notifier).setFilter(apiValue);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.white : AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: selected ? AppColors.white : AppColors.border),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          color: selected ? AppColors.bg : AppColors.grey,
                          fontSize: 12,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ).animate().fadeIn(delay: 80.ms),

            const SizedBox(height: 12),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _searchCtrl,
                onChanged: _onSearchChanged,
                style: const TextStyle(color: AppColors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search invoice #, customer, phone…',
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
                        final invoices = state.invoices;
                        if (invoices.isEmpty) return const _EmptyState();
                        return RefreshIndicator(
                          onRefresh: () async {
                            HapticUtils.light();
                            await ref.read(invoicesPod.notifier).fetchInvoices(status: state.filterStatus);
                          },
                          color: AppColors.white,
                          backgroundColor: AppColors.surface,
                          child: ListView.builder(
                            controller: _scrollCtrl,
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 90),
                            itemCount: invoices.length + (state.hasMore && _searchQuery.isEmpty ? 1 : 0),
                            itemBuilder: (_, i) {
                              if (i == invoices.length) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 20),
                                  child: Center(child: SizedBox(
                                    width: 20, height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.grey),
                                  )),
                                );
                              }
                              return InvoiceListTile(
                                invoice: invoices[i] as Map,
                                onTap: () => InvoiceDetailSheet.show(context, (invoices[i] as Map)['id'].toString()),
                              );
                            },
                          ),
                        );
                      },
                    ),
            ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InvoiceEarningTabs extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;
  const _InvoiceEarningTabs({required this.index, required this.onChanged});

  static const _labels = ['Invoice', 'Earning'];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          for (var i = 0; i < _labels.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: index == i ? AppColors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                    boxShadow: index == i
                        ? [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 6, offset: const Offset(0, 1))]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _labels[i],
                    style: TextStyle(
                      color: index == i ? AppColors.bg : AppColors.grey,
                      fontSize: 13,
                      fontWeight: index == i ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(Icons.receipt_long_rounded, color: AppColors.greyDark, size: 36),
          ),
          const SizedBox(height: 16),
          const Text('No invoices yet', style: TextStyle(color: AppColors.grey, fontSize: 14)),
          const SizedBox(height: 4),
          const Text('Tap "Create Invoice" to bill a walk-in customer',
              style: TextStyle(color: AppColors.greyDark, fontSize: 12)),
        ],
      ).animate().fadeIn().scale(begin: const Offset(0.9, 0.9)),
    );
  }
}
