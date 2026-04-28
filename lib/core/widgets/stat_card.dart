import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';
import '../theme/app_theme.dart';

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String? subtitle;
  final String? subtitlePositive;
  final IconData? icon;
  final Color? accentColor;
  final VoidCallback? onTap;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.subtitle,
    this.subtitlePositive,
    this.icon,
    this.accentColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? AppColors.white;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppTheme.sp16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppTheme.r16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppTheme.r8),
                    ),
                    child: Icon(icon, color: accent, size: 17),
                  ),
                  const SizedBox(width: AppTheme.sp8),
                ],
                Expanded(
                  child: Text(label, style: AppTheme.labelLg, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                if (onTap != null)
                  const Icon(Icons.chevron_right_rounded, color: AppColors.grey, size: 16),
              ],
            ),
            const SizedBox(height: AppTheme.sp12),
            Text(
              value,
              style: AppTheme.displayMd.copyWith(fontSize: 22),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: AppTheme.sp4),
              Text(
                subtitle!,
                style: AppTheme.bodySm.copyWith(
                  color: subtitlePositive != null
                      ? (subtitlePositive == 'up' ? AppColors.success : AppColors.error)
                      : AppColors.grey,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
