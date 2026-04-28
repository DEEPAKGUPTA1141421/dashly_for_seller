import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';
import '../theme/app_theme.dart';
import 'app_button.dart';

Future<bool> showConfirmModal(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool destructive = false,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.r24)),
    ),
    builder: (_) => _ConfirmSheet(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      destructive: destructive,
    ),
  );
  return result ?? false;
}

class _ConfirmSheet extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool destructive;

  const _ConfirmSheet({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.destructive,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.sp24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppTheme.sp20),
            Text(title, style: AppTheme.headingMd),
            const SizedBox(height: AppTheme.sp8),
            Text(message, style: AppTheme.bodyMd.copyWith(color: AppColors.grey)),
            const SizedBox(height: AppTheme.sp24),
            AppButton(
              label: confirmLabel,
              backgroundColor: destructive ? AppColors.error : AppColors.white,
              foregroundColor: AppColors.bg,
              onTap: () => Navigator.pop(context, true),
            ),
            const SizedBox(height: AppTheme.sp12),
            AppOutlineButton(
              label: cancelLabel,
              onTap: () => Navigator.pop(context, false),
            ),
          ],
        ),
      ),
    );
  }
}
