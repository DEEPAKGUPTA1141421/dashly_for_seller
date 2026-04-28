import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';
import '../theme/app_theme.dart';

enum StatusVariant { success, warning, error, info, pending, neutral }

class StatusBadge extends StatelessWidget {
  final String label;
  final StatusVariant variant;
  final bool small;

  const StatusBadge({
    super.key,
    required this.label,
    this.variant = StatusVariant.neutral,
    this.small = false,
  });

  factory StatusBadge.fromString(String status, {bool small = false}) {
    final v = switch (status.toUpperCase()) {
      'DELIVERED' || 'LIVE' || 'VERIFIED' || 'SUCCESS' || 'DOCUMENT_VERIFIED' =>
        StatusVariant.success,
      'CANCELLED' || 'FAILED' || 'REVERSE_FAILED' || 'ERROR' =>
        StatusVariant.error,
      'OUT_FOR_DELIVERY' || 'CONFIRMED' || 'IN_TRANSIT' =>
        StatusVariant.info,
      'PROCESSING' || 'PICKUP_SCHEDULED' || 'PICKED' || 'WAREHOUSE' || 'PENDING' ||
      'DOCUMENT_VERIFICATION_PENDING' =>
        StatusVariant.pending,
      'INITIATED' || 'CREATED' || 'DRAFT' || 'REVERSED' =>
        StatusVariant.warning,
      _ => StatusVariant.neutral,
    };
    return StatusBadge(label: _prettify(status), variant: v, small: small);
  }

  static String _prettify(String s) => s
      .replaceAll('_', ' ')
      .toLowerCase()
      .split(' ')
      .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (variant) {
      StatusVariant.success => (AppColors.success.withOpacity(0.15), AppColors.success),
      StatusVariant.warning => (AppColors.warning.withOpacity(0.15), AppColors.warning),
      StatusVariant.error   => (AppColors.error.withOpacity(0.15),   AppColors.error),
      StatusVariant.info    => (AppColors.info.withOpacity(0.15),    AppColors.info),
      StatusVariant.pending => (const Color(0xFF9B88FF).withOpacity(0.15), const Color(0xFF9B88FF)),
      StatusVariant.neutral => (AppColors.surface2, AppColors.grey),
    };

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? AppTheme.sp6 : AppTheme.sp8,
        vertical: small ? 2 : AppTheme.sp4,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppTheme.r6),
        border: Border.all(color: fg.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: small ? 10 : 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
