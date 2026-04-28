import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';
import '../theme/app_theme.dart';

class AppSearchBar extends StatefulWidget {
  final String hint;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;
  final TextEditingController? controller;
  final bool autofocus;

  const AppSearchBar({
    super.key,
    this.hint = 'Search...',
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.controller,
    this.autofocus = false,
  });

  @override
  State<AppSearchBar> createState() => _AppSearchBarState();
}

class _AppSearchBarState extends State<AppSearchBar> {
  late final TextEditingController _ctrl;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _ctrl = widget.controller ?? TextEditingController();
    _ctrl.addListener(() {
      final has = _ctrl.text.isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
  }

  @override
  void dispose() {
    if (widget.controller == null) _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppTheme.r12),
        border: Border.all(color: AppColors.border),
      ),
      child: TextField(
        controller: _ctrl,
        autofocus: widget.autofocus,
        style: AppTheme.bodyMd,
        onChanged: widget.onChanged,
        onSubmitted: widget.onSubmitted,
        decoration: InputDecoration(
          hintText: widget.hint,
          hintStyle: AppTheme.bodyMd.copyWith(color: AppColors.grey),
          prefixIcon: const Icon(Icons.search_rounded, color: AppColors.grey, size: 20),
          suffixIcon: _hasText
              ? GestureDetector(
                  onTap: () {
                    _ctrl.clear();
                    widget.onClear?.call();
                    widget.onChanged?.call('');
                  },
                  child: const Icon(Icons.close_rounded, color: AppColors.grey, size: 18),
                )
              : null,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}
