import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';
import '../theme/app_theme.dart';
import 'app_button.dart';

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.sp32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(AppTheme.r20),
              ),
              child: Icon(icon, color: AppColors.grey, size: 36),
            ),
            const SizedBox(height: AppTheme.sp20),
            Text(title, style: AppTheme.headingSm, textAlign: TextAlign.center),
            if (subtitle != null) ...[
              const SizedBox(height: AppTheme.sp8),
              Text(
                subtitle!,
                style: AppTheme.bodyMd.copyWith(color: AppColors.grey),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppTheme.sp24),
              AppButton(label: actionLabel!, onTap: onAction, width: 180),
            ],
          ],
        ),
      ),
    );
  }
}
