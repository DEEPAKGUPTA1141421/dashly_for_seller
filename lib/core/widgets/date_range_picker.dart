import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';
import '../theme/app_theme.dart';
import 'app_button.dart';

class DateRangeResult {
  final DateTime start;
  final DateTime end;
  const DateRangeResult(this.start, this.end);
}

Future<DateRangeResult?> showAppDateRangePicker(BuildContext context) {
  return showModalBottomSheet<DateRangeResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.r24)),
    ),
    builder: (_) => const _DateRangeSheet(),
  );
}

class _DateRangeSheet extends StatefulWidget {
  const _DateRangeSheet();

  @override
  State<_DateRangeSheet> createState() => _DateRangeSheetState();
}

class _DateRangeSheetState extends State<_DateRangeSheet> {
  DateTime? _start;
  DateTime? _end;

  static const _presets = [
    ('Today', 0),
    ('Last 7 days', 7),
    ('Last 30 days', 30),
    ('Last 90 days', 90),
  ];

  void _applyPreset(int daysBack) {
    final now = DateTime.now();
    setState(() {
      _start = daysBack == 0 ? DateTime(now.year, now.month, now.day) : now.subtract(Duration(days: daysBack));
      _end = now;
    });
  }

  Future<DateTime?> _pickDate(DateTime initial) {
    return showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.white,
            onPrimary: AppColors.bg,
            surface: AppColors.surface2,
            onSurface: AppColors.white,
          ),
        ),
        child: child!,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppTheme.sp24,
        right: AppTheme.sp24,
        top: AppTheme.sp24,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppTheme.sp24,
      ),
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
          const Text('Select Date Range', style: AppTheme.headingMd),
          const SizedBox(height: AppTheme.sp16),
          Wrap(
            spacing: AppTheme.sp8,
            runSpacing: AppTheme.sp8,
            children: _presets.map((p) {
              final (label, days) = p;
              return GestureDetector(
                onTap: () => _applyPreset(days),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.sp12,
                    vertical: AppTheme.sp6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface2,
                    borderRadius: BorderRadius.circular(AppTheme.r8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(label, style: AppTheme.bodySm),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: AppTheme.sp20),
          _DateRow(
            label: 'From',
            date: _start,
            onTap: () async {
              final d = await _pickDate(_start ?? DateTime.now());
              if (d != null) setState(() => _start = d);
            },
          ),
          const SizedBox(height: AppTheme.sp12),
          _DateRow(
            label: 'To',
            date: _end,
            onTap: () async {
              final d = await _pickDate(_end ?? DateTime.now());
              if (d != null) setState(() => _end = d);
            },
          ),
          const SizedBox(height: AppTheme.sp24),
          AppButton(
            label: 'Apply',
            onTap: (_start != null && _end != null)
                ? () => Navigator.pop(context, DateRangeResult(_start!, _end!))
                : null,
          ),
        ],
      ),
    );
  }
}

class _DateRow extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onTap;

  const _DateRow({required this.label, this.date, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.sp16,
          vertical: AppTheme.sp12,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(AppTheme.r12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Text('$label  ', style: AppTheme.labelLg),
            Expanded(
              child: Text(
                date != null
                    ? '${date!.day.toString().padLeft(2, '0')}/${date!.month.toString().padLeft(2, '0')}/${date!.year}'
                    : 'Select date',
                style: date != null
                    ? AppTheme.bodyMd
                    : AppTheme.bodyMd.copyWith(color: AppColors.grey),
              ),
            ),
            const Icon(Icons.calendar_today_rounded, color: AppColors.grey, size: 16),
          ],
        ),
      ),
    );
  }
}
