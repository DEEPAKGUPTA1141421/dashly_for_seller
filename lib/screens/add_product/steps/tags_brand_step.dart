import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/app_button.dart';
import '../../../providers/add_product_provider.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/haptic_utils.dart';

class TagsBrandStep extends ConsumerStatefulWidget {
  const TagsBrandStep({super.key});

  @override
  ConsumerState<TagsBrandStep> createState() => _TagsBrandStepState();
}

class _TagsBrandStepState extends ConsumerState<TagsBrandStep> {
  final _tagCtrl    = TextEditingController();
  final _brandSearch = TextEditingController();

  List<String> _tags        = [];
  String?      _brandId;
  String?      _brandName;
  String       _brandQuery  = '';

  @override
  void initState() {
    super.initState();
    final s  = ref.read(addProductPod);
    _tags      = [...s.tags];
    _brandId   = s.brandId;
    _brandName = s.brandName;
    _brandSearch.text = s.brandName ?? '';
  }

  @override
  void dispose() {
    _tagCtrl.dispose();
    _brandSearch.dispose();
    super.dispose();
  }

  void _addTag() {
    final tag = _tagCtrl.text.trim().toLowerCase().replaceAll(' ', '-');
    if (tag.isEmpty || _tags.contains(tag) || _tags.length >= 10) return;
    setState(() => _tags.add(tag));
    _tagCtrl.clear();
    HapticUtils.light();
  }

  void _removeTag(String tag) {
    setState(() => _tags.remove(tag));
    HapticUtils.light();
  }

  void _next() {
    ref.read(addProductPod.notifier).saveBrandAndTags(
      brandId:   _brandId,
      brandName: _brandName,
      tags:      _tags,
    );
  }

  @override
  Widget build(BuildContext context) {
    final brands = ref.watch(addProductPod).brands
        .where((b) => (b['name'] as String? ?? '')
            .toLowerCase()
            .contains(_brandQuery.toLowerCase()))
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Help buyers discover your product with brand and tags.',
            style: TextStyle(color: AppColors.grey, fontSize: 14),
          ).animate().fadeIn(),

          const SizedBox(height: 24),

          // ── Brand ──────────────────────────────────────────────────────────
          const Text('BRAND', style: TextStyle(color: AppColors.grey, fontSize: 13, fontWeight: FontWeight.w500))
              .animate().fadeIn(delay: 60.ms),
          const SizedBox(height: 8),

          TextField(
            controller: _brandSearch,
            onChanged: (v) => setState(() => _brandQuery = v),
            style: const TextStyle(color: AppColors.white),
            decoration: InputDecoration(
              hintText: 'Search brand…',
              hintStyle: const TextStyle(color: AppColors.greyDark, fontSize: 14),
              prefixIcon: const Icon(Icons.search_rounded, color: AppColors.grey, size: 18),
              suffixIcon: _brandId != null
                  ? const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 18)
                  : null,
              filled: true,
              fillColor: AppColors.surface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: _brandId != null ? AppColors.success : AppColors.border,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.white, width: 1.5),
              ),
            ),
          ).animate().fadeIn(delay: 80.ms),

          if (_brandQuery.isNotEmpty && brands.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: brands.take(5).map((b) {
                  final id   = b['id']?.toString() ?? b['brandId']?.toString() ?? '';
                  final name = b['name'] as String? ?? '';
                  return ListTile(
                    dense: true,
                    title: Text(name, style: const TextStyle(color: AppColors.white, fontSize: 13)),
                    trailing: _brandId == id
                        ? const Icon(Icons.check_rounded, color: AppColors.success, size: 16)
                        : null,
                    onTap: () {
                      HapticUtils.light();
                      setState(() {
                        _brandId   = id;
                        _brandName = name;
                        _brandSearch.text = name;
                        _brandQuery = '';
                      });
                    },
                  );
                }).toList(),
              ),
            ),

          if (_brandId != null && _brandQuery.isEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 14),
                const SizedBox(width: 6),
                Text('Brand: $_brandName', style: const TextStyle(color: AppColors.grey, fontSize: 12)),
                const Spacer(),
                GestureDetector(
                  onTap: () => setState(() { _brandId = null; _brandName = null; _brandSearch.clear(); }),
                  child: const Text('Clear', style: TextStyle(color: AppColors.error, fontSize: 12)),
                ),
              ],
            ),
          ],

          const SizedBox(height: 24),

          // ── Tags ───────────────────────────────────────────────────────────
          Row(
            children: [
              const Text('TAGS', style: TextStyle(color: AppColors.grey, fontSize: 13, fontWeight: FontWeight.w500)),
              const Spacer(),
              Text('${_tags.length}/10', style: const TextStyle(color: AppColors.greyDark, fontSize: 12)),
            ],
          ).animate().fadeIn(delay: 120.ms),
          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _tagCtrl,
                  onSubmitted: (_) => _addTag(),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9\s\-]'))],
                  style: const TextStyle(color: AppColors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'e.g. cotton, summer, casual',
                    hintStyle: const TextStyle(color: AppColors.greyDark, fontSize: 13),
                    filled: true,
                    fillColor: AppColors.surface,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _addTag,
                child: Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.add_rounded, color: AppColors.bg, size: 22),
                ),
              ),
            ],
          ).animate().fadeIn(delay: 140.ms),

          const SizedBox(height: 12),

          if (_tags.isNotEmpty)
            Wrap(
              spacing: 8, runSpacing: 8,
              children: _tags.map((t) => _TagChip(
                label: t,
                onRemove: () => _removeTag(t),
              )).toList(),
            ).animate().fadeIn(),

          if (_tags.isEmpty)
            const Text(
              'Type a tag and press Enter or + to add',
              style: TextStyle(color: AppColors.greyDark, fontSize: 12),
            ).animate().fadeIn(),

          const SizedBox(height: 40),

          AppButton(
            label: 'Continue to Review',
            onTap: _next,
            icon: Icons.arrow_forward_rounded,
          ).animate().fadeIn(delay: 200.ms),
        ],
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;
  const _TagChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('#$label', style: const TextStyle(color: AppColors.white, fontSize: 12)),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close_rounded, color: AppColors.grey, size: 14),
          ),
        ],
      ),
    );
  }
}
