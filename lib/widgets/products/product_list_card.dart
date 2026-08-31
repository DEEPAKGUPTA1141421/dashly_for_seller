import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../utils/app_colors.dart';

/// Mobile stacked product card — image thumbnail, name + price + category
/// subtitle, then Status/Sales/Views/Likes as label-value rows, plus a "..."
/// menu top-right (edit / activate-deactivate / delete / share).
class ProductListCard extends StatelessWidget {
  final Map product;
  final int index;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleActive;
  final VoidCallback onShare;

  const ProductListCard({
    super.key,
    required this.product,
    required this.index,
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 56, height: 56,
                  color: AppColors.surface2,
                  child: imageUrl.isNotEmpty
                      ? Image.network(imageUrl, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(Icons.image_rounded, color: AppColors.greyDark, size: 22))
                      : const Icon(Icons.inventory_2_rounded, color: AppColors.greyDark, size: 22),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text('₹${_fmtNum(price)}', style: const TextStyle(color: AppColors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.grey, fontSize: 11)),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<String>(
                color: AppColors.surface2,
                padding: EdgeInsets.zero,
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
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _StatRow(label: 'Status', child: _StatusPill(isActive: isActive))),
              Expanded(child: _StatRow(label: 'Sales',  value: '$sales')),
              Expanded(child: _StatRow(label: 'Views',  value: '$views')),
              Expanded(child: _StatRow(label: 'Likes',  value: '$likes')),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: index * 30)).slideY(begin: 0.03, end: 0);
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String? value;
  final Widget? child;
  const _StatRow({required this.label, this.value, this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.grey, fontSize: 10.5)),
        const SizedBox(height: 3),
        child ?? Text(value ?? '', style: const TextStyle(color: AppColors.white, fontSize: 12.5, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  final bool isActive;
  const _StatusPill({required this.isActive});

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.success : AppColors.greyDark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isActive ? 'Active' : 'Inactive',
        style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w700),
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
