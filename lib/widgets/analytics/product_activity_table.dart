import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/activity_week.dart';
import '../../utils/app_colors.dart';
import '../../utils/haptic_utils.dart';

/// "Product activity" table: Week | Products | Views | Comments, with a
/// centered "Load more" button below. Plain Column/Row-based table (no
/// DataTable — no precedent for it anywhere in this app).
class ProductActivityTable extends StatelessWidget {
  final List<ActivityWeek> weeks;
  final bool isLoading;
  final VoidCallback onLoadMore;

  const ProductActivityTable({
    super.key,
    required this.weeks,
    required this.isLoading,
    required this.onLoadMore,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Expanded(flex: 3, child: Text('Week', style: TextStyle(color: AppColors.grey, fontSize: 12, fontWeight: FontWeight.w600))),
              Expanded(flex: 2, child: Text('Products', style: TextStyle(color: AppColors.grey, fontSize: 12, fontWeight: FontWeight.w600))),
              Expanded(flex: 3, child: Text('Views', style: TextStyle(color: AppColors.grey, fontSize: 12, fontWeight: FontWeight.w600))),
              Expanded(flex: 3, child: Text('Comments', style: TextStyle(color: AppColors.grey, fontSize: 12, fontWeight: FontWeight.w600))),
            ],
          ),
        ),
        const Divider(color: AppColors.border, height: 1),

        if (weeks.isEmpty && !isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text('No activity yet', style: TextStyle(color: AppColors.grey, fontSize: 13)),
            ),
          )
        else
          ...weeks.map((w) => _ActivityRow(week: w)),

        const SizedBox(height: 16),
        Center(
          child: GestureDetector(
            onTap: isLoading ? null : () { HapticUtils.light(); onLoadMore(); },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.grey),
                    )
                  : const Text(
                      'Load more',
                      style: TextStyle(color: AppColors.white, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ActivityRow extends StatelessWidget {
  final ActivityWeek week;
  const _ActivityRow({required this.week});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 3,
            child: Text(
              week.weekLabel,
              style: const TextStyle(color: AppColors.grey, fontSize: 13),
            ),
          ),
          Expanded(
            flex: 2,
            child: _Pill(value: '${week.products}'),
          ),
          Expanded(
            flex: 3,
            child: _Pill(value: '${week.views}', changePct: week.viewsChangePct),
          ),
          Expanded(
            flex: 3,
            child: _Pill(value: '${week.comments}', changePct: week.commentsChangePct),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 200.ms);
  }
}

class _Pill extends StatelessWidget {
  final String value;
  final double? changePct;
  const _Pill({required this.value, this.changePct});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.surface2,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            value,
            style: const TextStyle(color: AppColors.white, fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
        if (changePct != null)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                changePct! >= 0 ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                color: changePct! >= 0 ? AppColors.success : AppColors.error,
                size: 11,
              ),
              Text(
                '${changePct!.abs().toStringAsFixed(1)}%',
                style: TextStyle(
                  color: changePct! >= 0 ? AppColors.success : AppColors.error,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
      ],
    );
  }
}
