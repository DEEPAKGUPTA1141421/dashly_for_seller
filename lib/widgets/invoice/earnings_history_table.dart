import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../utils/app_colors.dart';

/// The Earnings tab's history table: Date / Status / Product sales count / Earnings,
/// with a "Load more" button — matches the Figma seller-earnings reference.
class EarningsHistoryTable extends StatelessWidget {
  final List<dynamic> history;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final VoidCallback onLoadMore;

  const EarningsHistoryTable({
    super.key,
    required this.history,
    required this.isLoading,
    required this.isLoadingMore,
    required this.hasMore,
    required this.onLoadMore,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(18, 16, 18, 12),
            child: Row(
              children: [
                Expanded(flex: 3, child: Text('Date', style: _headerStyle)),
                Expanded(flex: 3, child: Text('Status', style: _headerStyle)),
                Expanded(flex: 4, child: Text('Product sales', style: _headerStyle)),
                Expanded(flex: 3, child: Text('Earnings', style: _headerStyle, textAlign: TextAlign.right)),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          if (isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.grey)),
            )
          else if (history.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: Text('No earnings yet', style: TextStyle(color: AppColors.grey, fontSize: 13))),
            )
          else ...[
            for (final (i, row) in history.indexed)
              _EarningsRow(row: row as Map, index: i),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Center(
                child: isLoadingMore
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.grey),
                      )
                    : hasMore
                        ? OutlinedButton(
                            onPressed: onLoadMore,
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.border),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            ),
                            child: const Text('Load more', style: TextStyle(color: AppColors.white, fontSize: 12.5, fontWeight: FontWeight.w600)),
                          )
                        : const SizedBox.shrink(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

const _headerStyle = TextStyle(color: AppColors.greyDark, fontSize: 12, fontWeight: FontWeight.w600);

class _EarningsRow extends StatelessWidget {
  final Map row;
  final int index;
  const _EarningsRow({required this.row, required this.index});

  @override
  Widget build(BuildContext context) {
    final date       = (row['date'] as String?) ?? '';
    final status     = (row['status'] as String?) ?? 'PENDING';
    final salesCount = (row['productSalesCount'] as num?)?.toInt() ?? 0;
    final earnings   = (row['earningsRupees'] as String?) ?? '0.00';

    final isPaid  = status == 'PAID';
    final pillColor = isPaid ? AppColors.success : AppColors.warning;

    return Container(
      color: index.isOdd ? AppColors.surface2.withOpacity(0.4) : Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(_formatDate(date), style: const TextStyle(color: AppColors.grey, fontSize: 12.5))),
          Expanded(
            flex: 3,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: pillColor.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                child: Text(
                  isPaid ? 'Paid' : 'Pending',
                  style: TextStyle(color: pillColor, fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
          Expanded(flex: 4, child: Text('$salesCount', style: const TextStyle(color: AppColors.white, fontSize: 12.5, fontWeight: FontWeight.w600))),
          Expanded(
            flex: 3,
            child: Text('₹$earnings',
                textAlign: TextAlign.right,
                style: const TextStyle(color: AppColors.white, fontSize: 12.5, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: index * 20));
  }

  String _formatDate(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[d.month - 1]} ${d.day}';
  }
}
