import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';
import '../theme/app_theme.dart';

enum ToastType { success, error, warning, info }

class AppToast {
  static void show(
    BuildContext context, {
    required String message,
    ToastType type = ToastType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    final (color, icon) = switch (type) {
      ToastType.success => (AppColors.success, Icons.check_circle_rounded),
      ToastType.error   => (AppColors.error,   Icons.error_rounded),
      ToastType.warning => (AppColors.warning,  Icons.warning_rounded),
      ToastType.info    => (AppColors.info,     Icons.info_rounded),
    };

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: duration,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(AppTheme.sp16),
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.sp16,
            vertical: AppTheme.sp12,
          ),
          backgroundColor: AppColors.surface2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.r12),
            side: BorderSide(color: color.withOpacity(0.4)),
          ),
          content: Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: AppTheme.sp8),
              Expanded(
                child: Text(message, style: AppTheme.bodyMd),
              ),
            ],
          ),
        ),
      );
  }
}
