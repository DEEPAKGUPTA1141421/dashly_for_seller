import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/responsive.dart';
import '../../utils/app_colors.dart';

/// "Payout history" table shared by the Payouts and Statement screens:
/// Date / Status / Method / Earnings / Amount withdrawn, with prev/next
/// page controls — matches the Figma reference.
class PayoutHistoryTable extends StatelessWidget {
  final List<dynamic> history;
  final bool isLoading;
  final int page;
  final bool hasMore;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const PayoutHistoryTable({
    super.key,
    required this.history,
    required this.isLoading,
    required this.page,
    required this.hasMore,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final twoCol = Responsive.isDesktop(context);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          if (twoCol)
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 16, 18, 12),
              child: Row(
                children: [
                  Expanded(flex: 2, child: Text('Date', style: _headerStyle)),
                  Expanded(flex: 2, child: Text('Status', style: _headerStyle)),
                  Expanded(flex: 2, child: Text('Method', style: _headerStyle)),
                  Expanded(flex: 3, child: Text('Earnings', style: _headerStyle)),
                  Expanded(flex: 3, child: Text('Amount withdrawn', style: _headerStyle)),
                ],
              ),
            ),
          if (twoCol) const Divider(height: 1, color: AppColors.border),
          if (isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.grey)),
            )
          else if (history.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: Text('No payout history yet', style: TextStyle(color: AppColors.grey, fontSize: 13))),
            )
          else
            for (final (i, row) in history.indexed)
              twoCol
                  ? _PayoutTableRow(row: row as Map, index: i)
                  : _PayoutCard(row: row as Map, index: i),

          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _ArrowButton(icon: Icons.chevron_left_rounded, enabled: page > 0, onTap: onPrevious),
                const SizedBox(width: 12),
                _ArrowButton(icon: Icons.chevron_right_rounded, enabled: hasMore, onTap: onNext),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

const _headerStyle = TextStyle(color: AppColors.greyDark, fontSize: 12, fontWeight: FontWeight.w600);

class _ArrowButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  const _ArrowButton({required this.icon, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 34, height: 34,
        decoration: BoxDecoration(
          color: enabled ? AppColors.surface2 : AppColors.surface2.withOpacity(0.4),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: enabled ? AppColors.white : AppColors.greyDark, size: 20),
      ),
    );
  }
}

(String, Color) _methodChip(String method) {
  switch (method) {
    case 'ONLINE':
      return ('Online', AppColors.info);
    case 'COD':
      return ('Cash on delivery', const Color(0xFFA78BFA));
    case 'POINTS':
      return ('Wallet points', AppColors.success);
    case 'MIXED':
      return ('Mixed', AppColors.grey);
    default:
      return ('Unknown', AppColors.greyDark);
  }
}

class _MethodPill extends StatelessWidget {
  final String method;
  const _MethodPill({required this.method});

  @override
  Widget build(BuildContext context) {
    final (label, color) = _methodChip(method);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String status;
  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final isPaid = status == 'PAID';
    final color = isPaid ? AppColors.success : AppColors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
      child: Text(isPaid ? 'Paid' : 'Pending', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

String _formatDate(String iso) {
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  return '${months[d.month - 1]} ${d.day}';
}

class _PayoutTableRow extends StatelessWidget {
  final Map row;
  final int index;
  const _PayoutTableRow({required this.row, required this.index});

  @override
  Widget build(BuildContext context) {
    final date       = (row['date'] as String?) ?? '';
    final status     = (row['status'] as String?) ?? 'PENDING';
    final method     = (row['method'] as String?) ?? 'UNKNOWN';
    final earnings   = (row['earningsRupees'] as String?) ?? '0.00';
    final withdrawn  = (row['amountWithdrawnRupees'] as String?) ?? '0.00';

    return Container(
      color: index.isOdd ? AppColors.surface2.withOpacity(0.4) : Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(_formatDate(date), style: const TextStyle(color: AppColors.grey, fontSize: 12.5))),
          Expanded(flex: 2, child: Align(alignment: Alignment.centerLeft, child: _StatusPill(status: status))),
          Expanded(flex: 2, child: Align(alignment: Alignment.centerLeft, child: _MethodPill(method: method))),
          Expanded(flex: 3, child: Text('₹$earnings', style: const TextStyle(color: AppColors.white, fontSize: 12.5, fontWeight: FontWeight.w700))),
          Expanded(flex: 3, child: Text('₹$withdrawn', style: const TextStyle(color: AppColors.white, fontSize: 12.5, fontWeight: FontWeight.w600))),
        ],
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: index * 20));
  }
}

class _PayoutCard extends StatelessWidget {
  final Map row;
  final int index;
  const _PayoutCard({required this.row, required this.index});

  @override
  Widget build(BuildContext context) {
    final date       = (row['date'] as String?) ?? '';
    final status     = (row['status'] as String?) ?? 'PENDING';
    final method     = (row['method'] as String?) ?? 'UNKNOWN';
    final earnings   = (row['earningsRupees'] as String?) ?? '0.00';
    final withdrawn  = (row['amountWithdrawnRupees'] as String?) ?? '0.00';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: index > 0 ? const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _kv('Date', Text(_formatDate(date), style: const TextStyle(color: AppColors.white, fontSize: 12.5, fontWeight: FontWeight.w600))),
          const SizedBox(height: 8),
          _kv('Status', _StatusPill(status: status)),
          const SizedBox(height: 8),
          _kv('Method', _MethodPill(method: method)),
          const SizedBox(height: 8),
          _kv('Earnings', Text('₹$earnings', style: const TextStyle(color: AppColors.white, fontSize: 12.5, fontWeight: FontWeight.w700))),
          const SizedBox(height: 8),
          _kv('Amount withdrawn', Text('₹$withdrawn', style: const TextStyle(color: AppColors.white, fontSize: 12.5, fontWeight: FontWeight.w600))),
        ],
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: index * 30));
  }

  Widget _kv(String label, Widget value) {
    return Row(
      children: [
        SizedBox(width: 90, child: Text(label, style: const TextStyle(color: AppColors.greyDark, fontSize: 12))),
        value,
      ],
    );
  }
}
