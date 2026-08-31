import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../utils/app_colors.dart';

/// Desktop/tablet table header row for the Products "Scheduled" tab —
/// checkbox, Product, Price, Scheduled for, and a blank trailing column for
/// the row actions (edit / reschedule / delete).
class ScheduledProductTableHeader extends StatelessWidget {
  final bool allSelected;
  final bool someSelected;
  final ValueChanged<bool?> onSelectAllChanged;

  const ScheduledProductTableHeader({
    super.key,
    required this.allSelected,
    required this.someSelected,
    required this.onSelectAllChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Checkbox(
              value: someSelected && !allSelected ? null : allSelected,
              tristate: true,
              activeColor: AppColors.accent,
              onChanged: onSelectAllChanged,
            ),
          ),
          const Expanded(flex: 4, child: _HeaderLabel('Product')),
          const Expanded(flex: 2, child: _HeaderLabel('Price')),
          const Expanded(flex: 2, child: _HeaderLabel('Scheduled for')),
          const SizedBox(width: 96),
        ],
      ),
    );
  }
}

class _HeaderLabel extends StatelessWidget {
  final String text;
  const _HeaderLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(color: AppColors.grey, fontSize: 12, fontWeight: FontWeight.w600),
    );
  }
}

/// One product row in the desktop/tablet Scheduled table.
class ScheduledProductTableRow extends StatelessWidget {
  final Map product;
  final int index;
  final bool selected;
  final VoidCallback onToggleSelect;
  final VoidCallback onEdit;
  final VoidCallback onReschedule;
  final VoidCallback onPublishNow;
  final VoidCallback onDelete;

  const ScheduledProductTableRow({
    super.key,
    required this.product,
    this.index = 0,
    required this.selected,
    required this.onToggleSelect,
    required this.onEdit,
    required this.onReschedule,
    required this.onPublishNow,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final name        = product['name'] as String? ?? 'Product';
    final imageUrl    = product['imageUrl'] as String? ?? '';
    final price       = _numOf(product['price']);
    final scheduledAt = _dateOf(product['scheduledAt']);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: selected ? AppColors.surface2 : Colors.transparent,
        border: const Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Checkbox(
              value: selected,
              activeColor: AppColors.accent,
              onChanged: (_) => onToggleSelect(),
            ),
          ),
          Expanded(
            flex: 4,
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 40, height: 40,
                    color: AppColors.surface2,
                    child: imageUrl.isNotEmpty
                        ? Image.network(imageUrl, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(Icons.image_rounded, color: AppColors.greyDark, size: 18))
                        : const Icon(Icons.inventory_2_rounded, color: AppColors.greyDark, size: 18),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
          Expanded(flex: 2, child: Text('₹${_fmtNum(price)}', style: const TextStyle(color: AppColors.white, fontSize: 13, fontWeight: FontWeight.w600))),
          Expanded(flex: 2, child: Text(_fmtDate(scheduledAt), style: const TextStyle(color: AppColors.grey, fontSize: 12.5))),
          SizedBox(
            width: 96,
            child: PopupMenuButton<String>(
              color: AppColors.surface,
              icon: const Icon(Icons.more_vert_rounded, color: AppColors.grey, size: 18),
              onSelected: (v) {
                if (v == 'edit')        onEdit();
                if (v == 'reschedule')  onReschedule();
                if (v == 'publish_now') onPublishNow();
                if (v == 'delete')      onDelete();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'reschedule', child: Text('Reschedule')),
                PopupMenuItem(value: 'publish_now', child: Text('Publish now')),
                PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: AppColors.error))),
              ],
            ),
          ),
        ],
      ),
    ).animate(delay: Duration(milliseconds: (index * 20).clamp(0, 400)))
        .fadeIn(duration: 200.ms)
        .slideX(begin: 0.02, end: 0);
  }
}

/// Mobile stacked card for the Products "Scheduled" tab.
class ScheduledProductCard extends StatelessWidget {
  final Map product;
  final int index;
  final bool selected;
  final VoidCallback onToggleSelect;
  final VoidCallback onEdit;
  final VoidCallback onReschedule;
  final VoidCallback onPublishNow;
  final VoidCallback onDelete;

  const ScheduledProductCard({
    super.key,
    required this.product,
    required this.index,
    required this.selected,
    required this.onToggleSelect,
    required this.onEdit,
    required this.onReschedule,
    required this.onPublishNow,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final name        = product['name'] as String? ?? 'Product';
    final imageUrl    = product['imageUrl'] as String? ?? '';
    final price       = _numOf(product['price']);
    final scheduledAt = _dateOf(product['scheduledAt']);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: selected ? AppColors.surface2 : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: selected ? AppColors.accent : AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: selected,
            activeColor: AppColors.accent,
            onChanged: (_) => onToggleSelect(),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 52, height: 52,
              color: AppColors.surface2,
              child: imageUrl.isNotEmpty
                  ? Image.network(imageUrl, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.image_rounded, color: AppColors.greyDark, size: 20))
                  : const Icon(Icons.inventory_2_rounded, color: AppColors.greyDark, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text('₹${_fmtNum(price)}', style: const TextStyle(color: AppColors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.schedule_rounded, color: AppColors.info, size: 12),
                    const SizedBox(width: 4),
                    Text('Scheduled for ${_fmtDate(scheduledAt)}', style: const TextStyle(color: AppColors.grey, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            color: AppColors.surface2,
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.more_vert_rounded, color: AppColors.grey, size: 18),
            onSelected: (v) {
              if (v == 'edit')        onEdit();
              if (v == 'reschedule')  onReschedule();
              if (v == 'publish_now') onPublishNow();
              if (v == 'delete')      onDelete();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(value: 'reschedule', child: Text('Reschedule')),
              PopupMenuItem(value: 'publish_now', child: Text('Publish now')),
              PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: AppColors.error))),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: index * 30)).slideY(begin: 0.03, end: 0);
  }
}

num _numOf(dynamic v) {
  if (v is num) return v;
  return num.tryParse(v?.toString() ?? '') ?? 0;
}

DateTime? _dateOf(dynamic v) {
  if (v == null) return null;
  return DateTime.tryParse(v.toString())?.toLocal();
}

String _fmtNum(num n) => n == n.truncateToDouble() ? n.toInt().toString() : n.toStringAsFixed(2);

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String _fmtDate(DateTime? d) {
  if (d == null) return '—';
  final hour12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final ampm   = d.hour < 12 ? 'AM' : 'PM';
  final minute = d.minute.toString().padLeft(2, '0');
  return '${_months[d.month - 1]} ${d.day}, $hour12:$minute $ampm';
}
