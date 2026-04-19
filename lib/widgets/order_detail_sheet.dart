import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/orders_provider.dart';
import '../utils/app_colors.dart';
import '../utils/haptic_utils.dart';

class OrderDetailSheet extends ConsumerStatefulWidget {
  final Map order;

  const OrderDetailSheet({super.key, required this.order});

  static Future<void> show(BuildContext context, Map order) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => OrderDetailSheet(order: order),
    );
  }

  @override
  ConsumerState<OrderDetailSheet> createState() => _OrderDetailSheetState();
}

class _OrderDetailSheetState extends ConsumerState<OrderDetailSheet> {
  bool _updating = false;

  String get _bookingId =>
      (widget.order['bookingId'] ?? widget.order['orderId'] ?? '').toString();

  String get _status =>
      (widget.order['status'] as String? ?? 'PENDING').toUpperCase();

  Future<void> _updateStatus(String newStatus) async {
    if (_bookingId.isEmpty) return;
    HapticUtils.medium();
    setState(() => _updating = true);
    final ok = await ref.read(ordersPod.notifier).updateOrderStatus(_bookingId, newStatus);
    setState(() => _updating = false);
    if (ok && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final order    = widget.order;
    final customer = order['customerName'] as String? ?? 'Customer';
    final amount   = order['amount'] as num? ?? 0;
    final items    = (order['items'] as List<dynamic>?) ?? [];
    final address  = order['deliveryAddress'] as String? ?? '';
    final phone    = order['customerPhone'] as String? ?? '';
    final date     = order['createdAt'] as String? ?? '';

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize:     0.4,
      maxChildSize:     0.92,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Drag handle
            const SizedBox(height: 10),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            // Scrollable body
            Expanded(
              child: SingleChildScrollView(
                controller: scrollCtrl,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Order ID + status
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _bookingId.isNotEmpty ? '#$_bookingId' : 'Order',
                            style: const TextStyle(
                              color: AppColors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        _StatusChip(status: _status),
                      ],
                    ),
                    if (date.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(date, style: const TextStyle(color: AppColors.grey, fontSize: 12)),
                    ],
                    const SizedBox(height: 20),

                    // Customer info
                    _Section(title: 'Customer', children: [
                      _Row('Name',  customer),
                      if (phone.isNotEmpty)   _Row('Phone', phone),
                      if (address.isNotEmpty) _Row('Address', address),
                    ]),
                    const SizedBox(height: 16),

                    // Items
                    if (items.isNotEmpty) ...[
                      _Section(title: 'Items', children: [
                        ...items.map((item) {
                          final i = item as Map;
                          return _Row(
                            i['productName']?.toString() ?? 'Item',
                            '${i['quantity'] ?? 1} × ₹${i['price'] ?? 0}',
                          );
                        }),
                      ]),
                      const SizedBox(height: 16),
                    ],

                    // Total
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surface2,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Text('Total', style: TextStyle(color: AppColors.grey, fontSize: 14)),
                          const Spacer(),
                          Text(
                            '₹$amount',
                            style: const TextStyle(
                              color: AppColors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Action buttons
                    _ActionButtons(
                      status:   _status,
                      updating: _updating,
                      onAction: _updateStatus,
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, bg) = _colors(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(status, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }

  (Color, Color) _colors(String s) {
    switch (s) {
      case 'DELIVERED':  return (AppColors.success, AppColors.success.withOpacity(0.12));
      case 'SHIPPED':    return (AppColors.info,    AppColors.info.withOpacity(0.12));
      case 'PROCESSING': return (AppColors.warning, AppColors.warning.withOpacity(0.12));
      case 'CANCELLED':  return (AppColors.error,   AppColors.error.withOpacity(0.12));
      default:           return (AppColors.grey,    AppColors.surface2);
    }
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(color: AppColors.grey, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.2),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface2,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: const TextStyle(color: AppColors.grey, fontSize: 12)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: AppColors.white, fontSize: 12, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  final String status;
  final bool updating;
  final Future<void> Function(String) onAction;

  const _ActionButtons({required this.status, required this.updating, required this.onAction});

  @override
  Widget build(BuildContext context) {
    final actions = _actionsFor(status);
    if (actions.isEmpty) return const SizedBox.shrink();

    return Column(
      children: actions.map((a) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: updating ? null : () => onAction(a.status),
              style: FilledButton.styleFrom(
                backgroundColor: a.color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: updating
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(a.label, style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        );
      }).toList(),
    );
  }

  List<_Action> _actionsFor(String status) {
    switch (status) {
      case 'PENDING':
        return [
          const _Action('Accept Order',    'PROCESSING', AppColors.success),
          const _Action('Reject Order',    'CANCELLED',  AppColors.error),
        ];
      case 'PROCESSING':
        return [
          const _Action('Mark as Packed',  'SHIPPED',    AppColors.info),
          const _Action('Cancel Order',    'CANCELLED',  AppColors.error),
        ];
      case 'SHIPPED':
        return [
          const _Action('Mark Delivered',  'DELIVERED',  AppColors.success),
        ];
      default:
        return [];
    }
  }
}

class _Action {
  final String label;
  final String status;
  final Color color;
  const _Action(this.label, this.status, this.color);
}
