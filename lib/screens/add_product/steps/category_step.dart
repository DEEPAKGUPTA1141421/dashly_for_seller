import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_shimmer.dart';
import '../../../providers/add_product_provider.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/haptic_utils.dart';

class CategoryStep extends ConsumerStatefulWidget {
  const CategoryStep({super.key});

  @override
  ConsumerState<CategoryStep> createState() => _CategoryStepState();
}

class _CategoryStepState extends ConsumerState<CategoryStep> {
  // Drill-down stack — each entry is the list shown at that level
  final List<List<dynamic>> _stack = [];
  final List<String>        _breadcrumb = [];
  String? _selectedId;
  String  _selectedName = '';
  String  _search = '';

  List<dynamic> get _currentList =>
      _stack.isEmpty ? ref.read(addProductPod).categories : _stack.last;

  @override
  void initState() {
    super.initState();
    final s = ref.read(addProductPod);
    _selectedId   = s.categoryId;
    _selectedName = s.categoryName ?? '';
  }

  void _onTap(Map cat) {
    HapticUtils.light();
    final children = cat['children'];
    final hasChildren = children is List && children.isNotEmpty;

    if (hasChildren) {
      // Drill deeper
      setState(() {
        _stack.add(children);
        _breadcrumb.add(cat['name'] as String? ?? '');
        _search = '';
      });
    } else {
      // Leaf — select it
      setState(() {
        _selectedId   = _id(cat);
        _selectedName = cat['name'] as String? ?? '';
      });
    }
  }

  void _goBack() {
    if (_stack.isEmpty) return;
    HapticUtils.light();
    setState(() {
      _stack.removeLast();
      _breadcrumb.removeLast();
      _selectedId   = null;
      _selectedName = '';
      _search = '';
    });
  }

  String _id(Map cat) =>
      cat['id']?.toString() ??
      cat['_id']?.toString() ??
      cat['categoryId']?.toString() ??
      '';

  List<dynamic> get _filtered {
    if (_search.isEmpty) return _currentList;
    final q = _search.toLowerCase();
    return _currentList
        .where((c) => ((c as Map)['name'] as String? ?? '').toLowerCase().contains(q))
        .toList();
  }

  Future<void> _next() async {
    if (_selectedId == null) return;
    await ref.read(addProductPod.notifier).saveCategory(_selectedId!, _selectedName);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(addProductPod);

    return Column(
      children: [
        // ── Breadcrumb / back bar ──────────────────────────────────────────
        if (_breadcrumb.isNotEmpty)
          GestureDetector(
            onTap: _goBack,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.arrow_back_ios_new_rounded,
                      color: AppColors.grey, size: 14),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _breadcrumb.join(' › '),
                      style: const TextStyle(
                        color: AppColors.grey, fontSize: 13, fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ).animate().fadeIn(),

        // ── Search ────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: TextField(
            onChanged: (v) => setState(() => _search = v),
            style: const TextStyle(color: AppColors.white),
            decoration: InputDecoration(
              hintText: _breadcrumb.isEmpty
                  ? 'Search categories…'
                  : 'Search in ${_breadcrumb.last}…',
              hintStyle: const TextStyle(color: AppColors.greyDark, fontSize: 14),
              prefixIcon: const Icon(Icons.search_rounded, color: AppColors.grey, size: 20),
              filled: true,
              fillColor: AppColors.surface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.white, width: 1.5),
              ),
            ),
          ),
        ),

        // ── List ──────────────────────────────────────────────────────────
        Expanded(
          child: state.isLoading
              ? ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: 8,
                  itemBuilder: (_, __) => const Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: AppShimmer(child: ShimmerBox(height: 52)),
                  ),
                )
              : _filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.search_off_rounded,
                              color: AppColors.greyDark, size: 36),
                          const SizedBox(height: 12),
                          Text(
                            state.categories.isEmpty
                                ? 'Could not load categories.\nCheck your connection and try again.'
                                : 'No categories match "$_search"',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: AppColors.grey, fontSize: 14, height: 1.5),
                          ),
                          if (state.categories.isEmpty) ...[
                            const SizedBox(height: 16),
                            TextButton(
                              onPressed: () =>
                                  ref.read(addProductPod.notifier).init(),
                              child: const Text('Retry',
                                  style: TextStyle(color: AppColors.white)),
                            ),
                          ],
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      itemCount: _filtered.length,
                      separatorBuilder: (_, __) =>
                          const Divider(color: AppColors.border, height: 1),
                      itemBuilder: (_, i) {
                        final cat      = _filtered[i] as Map;
                        final id       = _id(cat);
                        final name     = cat['name'] as String? ?? '';
                        final children = cat['children'];
                        final hasChildren =
                            children is List && children.isNotEmpty;
                        final isSelected = _selectedId == id;

                        return GestureDetector(
                          onTap: () => _onTap(cat),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            color: isSelected
                                ? AppColors.white.withOpacity(0.06)
                                : Colors.transparent,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    name,
                                    style: TextStyle(
                                      color: isSelected
                                          ? AppColors.white
                                          : AppColors.white,
                                      fontSize: 14,
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                    ),
                                  ),
                                ),
                                if (isSelected && !hasChildren)
                                  const Icon(Icons.check_circle_rounded,
                                      color: AppColors.success, size: 18)
                                else if (hasChildren)
                                  const Icon(Icons.chevron_right_rounded,
                                      color: AppColors.grey, size: 20),
                              ],
                            ),
                          ),
                        ).animate(delay: Duration(milliseconds: i * 20))
                            .fadeIn().slideX(begin: 0.03, end: 0);
                      },
                    ),
        ),

        // ── Bottom CTA ────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_selectedName.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          color: AppColors.success, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Selected: $_selectedName',
                          style: const TextStyle(
                              color: AppColors.grey, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              AppButton(
                label: 'Continue',
                onTap: _selectedId != null ? _next : null,
                isLoading: state.isLoading,
                icon: Icons.arrow_forward_rounded,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
