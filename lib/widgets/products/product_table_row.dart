import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../utils/app_colors.dart';

/// Desktop/tablet table header row for the Products "Market" tab — checkbox,
/// Product, Status, Price, Sales, Views, Likes, and a blank trailing column
/// for the row action menu. Matches `product_table_row.dart`'s column widths.
class ProductTableHeader extends StatelessWidget {
  final bool allSelected;
  final bool someSelected;
  final ValueChanged<bool?> onSelectAllChanged;

  const ProductTableHeader({
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
          const Expanded(flex: 2, child: _HeaderLabel('Status')),
          const Expanded(flex: 2, child: _HeaderLabel('Price')),
          const Expanded(flex: 2, child: _HeaderLabel('Sales')),
          const Expanded(flex: 2, child: _HeaderLabel('Views')),
          const Expanded(flex: 2, child: _HeaderLabel('Likes')),
          const SizedBox(width: 40),
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

/// One product row in the desktop/tablet Market table — checkbox, thumbnail
/// + name + category subtitle, status pill, price, sales/views/likes counts,
/// and a trailing "..." menu (edit / activate-deactivate / delete / share).
class ProductTableRow extends StatelessWidget {
  final Map product;
  final int index;
  final bool selected;
  final VoidCallback onToggleSelect;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleActive;
  final VoidCallback onShare;

  const ProductTableRow({
    super.key,
    required this.product,
    this.index = 0,
    required this.selected,
    required this.onToggleSelect,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleActive,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final name       = product['name'] as String? ?? 'Product';
    final imageUrl   = product['imageUrl'] as String? ?? '';
    final isActive   = product['isActive'] as bool? ?? true;
    final brand      = product['brand'] as String?;
    final category   = product['categoryName'] as String?;
    final subtitle   = [if (brand != null && brand.isNotEmpty) brand, if (category != null && category.isNotEmpty) category].join(' · ');
    final price      = _numOf(product['price']);
    final sales      = _intOf(product['sales']);
    final views      = _intOf(product['views']);
    final likes      = _intOf(product['likes']);

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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                      if (subtitle.isNotEmpty)
                        Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppColors.grey, fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(flex: 2, child: _StatusPill(isActive: isActive)),
          Expanded(flex: 2, child: Text('₹${_fmtNum(price)}', style: const TextStyle(color: AppColors.white, fontSize: 13, fontWeight: FontWeight.w600))),
          Expanded(flex: 2, child: Text('$sales', style: const TextStyle(color: AppColors.white, fontSize: 13))),
          Expanded(flex: 2, child: Text('$views', style: const TextStyle(color: AppColors.white, fontSize: 13))),
          Expanded(flex: 2, child: Text('$likes', style: const TextStyle(color: AppColors.white, fontSize: 13))),
          SizedBox(
            width: 40,
            child: PopupMenuButton<String>(
              color: AppColors.surface,
              icon: const Icon(Icons.more_vert_rounded, color: AppColors.grey, size: 18),
              onSelected: (v) {
                if (v == 'edit')   onEdit();
                if (v == 'delete') onDelete();
                if (v == 'toggle') onToggleActive();
                if (v == 'share')  onShare();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'toggle', child: Text(isActive ? 'Deactivate' : 'Activate')),
                const PopupMenuItem(value: 'share', child: Text('Share')),
                const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: AppColors.error))),
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

class _StatusPill extends StatelessWidget {
  final bool isActive;
  const _StatusPill({required this.isActive});

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.success : AppColors.greyDark;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          isActive ? 'Active' : 'Inactive',
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

num _numOf(dynamic v) {
  if (v is num) return v;
  return num.tryParse(v?.toString() ?? '') ?? 0;
}

int _intOf(dynamic v) {
  if (v is num) return v.toInt();
  return int.tryParse(v?.toString() ?? '') ?? 0;
}

String _fmtNum(num n) => n == n.truncateToDouble() ? n.toInt().toString() : n.toStringAsFixed(2);
