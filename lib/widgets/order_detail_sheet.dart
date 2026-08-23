import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/widgets/app_toast.dart';
import '../core/widgets/confirm_modal.dart';
import '../core/widgets/status_badge.dart';
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
  bool _loadingDetail = false;
  Map<String, dynamic> _detail = {};

  String get _bookingId => (widget.order['bookingId'] ?? '').toString();
  String get _status    => (widget.order['status'] as String? ?? 'INITIATED').toUpperCase();

  String get _shortId {
    final id = _bookingId;
    return id.length > 8 ? '#${id.substring(0, 8).toUpperCase()}' : '#$id';
  }

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    if (_bookingId.isEmpty) return;
    setState(() => _loadingDetail = true);
    final detail = await ref.read(ordersPod.notifier).fetchSellerOrderDetail(_bookingId);
    if (mounted) setState(() { _detail = detail; _loadingDetail = false; });
  }

  Future<void> _updateStatus(String newStatus) async {
    if (_bookingId.isEmpty) return;
    if (newStatus == 'CANCELLED') {
      final confirmed = await showConfirmModal(
        context,
        title: 'Cancel Order',
        message: 'Are you sure you want to cancel this order? This cannot be undone.',
        confirmLabel: 'Yes, Cancel',
        destructive: true,
      );
      if (!confirmed || !mounted) return;
    }
    if (newStatus == 'REVERSED') {
      final confirmed = await showConfirmModal(
        context,
        title: 'Initiate Return',
        message: 'This will mark the order as returned. Proceed only after the buyer has returned the item.',
        confirmLabel: 'Initiate Return',
        destructive: false,
      );
      if (!confirmed || !mounted) return;
    }
    HapticUtils.medium();
    setState(() => _updating = true);
    final ok = await ref.read(ordersPod.notifier).updateOrderStatus(_bookingId, newStatus);
    setState(() => _updating = false);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      final err = ref.read(ordersPod).error ?? 'Failed to update status';
      AppToast.show(context, message: err, type: ToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final order      = widget.order;
    final amountStr  = order['totalAmountRupees'] as String? ?? '0.00';
    final itemCount  = (order['itemCount'] as num?)?.toInt() ?? 0;
    final payMode    = order['paymentMode'] as String? ?? '';
    final createdAt  = order['createdAt'] as String? ?? '';
    final deliveryId = (_detail['deliveryAddress'] ?? order['deliveryAddress'])?.toString() ?? '';
    final shortAddr  = deliveryId.length >= 8 ? deliveryId.substring(0, 8).toUpperCase() : deliveryId;

    final items = (_detail['items'] as List<dynamic>?) ?? [];

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),

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
                            _shortId,
                            style: const TextStyle(
                              color: AppColors.white, fontSize: 18, fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        StatusBadge.fromString(_status),
                      ],
                    ),
                    if (createdAt.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        _formatDate(createdAt),
                        style: const TextStyle(color: AppColors.grey, fontSize: 12),
                      ),
                    ],
                    const SizedBox(height: 20),

                    // Order summary
                    _Section(title: 'Order Info', children: [
                      _Row('Items',   '$itemCount item${itemCount != 1 ? 's' : ''}'),
                      if (payMode.isNotEmpty)   _Row('Payment',  payMode),
                      if (shortAddr.isNotEmpty) _Row('Deliver to', '#$shortAddr'),
                    ]),
                    const SizedBox(height: 16),

                    // Line items
                    if (_loadingDetail)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Center(child: SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.grey),
                        )),
                      )
                    else if (items.isNotEmpty) ...[
                      _Section(
                        title: 'Items Ordered',
                        children: items.map((item) {
                          final m        = item as Map<String, dynamic>;
                          final qty      = (m['quantity'] as num?)?.toInt() ?? 1;
                          final price    = m['unitPriceRupees'] as String? ?? '0.00';
                          final total    = m['lineTotalRupees'] as String? ?? '0.00';
                          final prodId   = (m['productId'] ?? '').toString();
                          final shortPid = prodId.length > 8 ? prodId.substring(0, 8).toUpperCase() : prodId;
                          final name     = (m['productName'] as String?)?.isNotEmpty == true
                              ? m['productName'] as String
                              : 'Product $shortPid';
                          final imageUrl = m['productImageUrl'] as String?;
                          return _ItemRow(
                            label: name,
                            imageUrl: imageUrl,
                            qty: qty,
                            unitPrice: price,
                            lineTotal: total,
                          );
                        }).toList(),
                      ),
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
                            '₹$amountStr',
                            style: const TextStyle(color: AppColors.white, fontSize: 16, fontWeight: FontWeight.w800),
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

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}, ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
    } catch (_) {
      return iso;
    }
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

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
          decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(12)),
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

class _ItemRow extends StatelessWidget {
  final String  label;
  final String? imageUrl;
  final int     qty;
  final String  unitPrice;
  final String  lineTotal;
  const _ItemRow({
    required this.label,
    this.imageUrl,
    required this.qty,
    required this.unitPrice,
    required this.lineTotal,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            clipBehavior: Clip.antiAlias,
            child: imageUrl != null && imageUrl!.isNotEmpty
                ? Image.network(
                    imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.inventory_2_rounded, color: AppColors.grey, size: 18),
                  )
                : const Icon(Icons.inventory_2_rounded, color: AppColors.grey, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: AppColors.white, fontSize: 12, fontWeight: FontWeight.w500)),
                Text('×$qty  @  ₹$unitPrice each', style: const TextStyle(color: AppColors.grey, fontSize: 11)),
              ],
            ),
          ),
          Text('₹$lineTotal', style: const TextStyle(color: AppColors.white, fontSize: 12, fontWeight: FontWeight.w700)),
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
      case 'CONFIRMED':
        return [
          const _Action('Accept Order',          'PROCESSING',       AppColors.success),
          const _Action('Cancel Order',           'CANCELLED',        AppColors.error),
        ];
      case 'PROCESSING':
        return [
          const _Action('Mark Out for Delivery',  'OUT_FOR_DELIVERY', AppColors.info),
          const _Action('Cancel Order',           'CANCELLED',        AppColors.error),
        ];
      case 'OUT_FOR_DELIVERY':
        return [
          const _Action('Mark Delivered',         'DELIVERED',        AppColors.success),
        ];
      case 'DELIVERED':
        return [
          const _Action('Initiate Return',        'REVERSED',         AppColors.warning),
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
