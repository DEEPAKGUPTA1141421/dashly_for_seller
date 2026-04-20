import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/app_button.dart';
import '../../../providers/add_product_provider.dart';
import '../../../providers/products_provider.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/haptic_utils.dart';

class ReviewStep extends ConsumerWidget {
  const ReviewStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s       = ref.watch(addProductPod);
    final loading = s.isSubmitting;

    // Attribute name lookup: id → name
    final attrNameMap = <String, String>{};
    for (final a in s.attributes) {
      final m  = a as Map;
      final id = m['id']?.toString() ?? '';
      if (id.isNotEmpty) attrNameMap[id] = m['name']?.toString() ?? id;
    }

    void goTo(int step) {
      HapticUtils.light();
      ref.read(addProductPod.notifier).goToStep(step);
    }

    Future<void> publish() async {
      HapticUtils.medium();
      final ok = await ref.read(addProductPod.notifier).publishProduct();
      if (!context.mounted) return;
      if (ok) {
        HapticUtils.success();
        ref.read(productsPod.notifier).fetchProducts();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 16),
                SizedBox(width: 8),
                Text('Product is now live!',
                    style: TextStyle(color: Colors.white)),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      } else {
        HapticUtils.heavy();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s.error ?? 'Failed to publish',
                style: const TextStyle(color: Colors.white)),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }

    // Collect all uploaded media paths
    final allPaths = s.imagePaths;

    // Attribute images: attrId → { value → [paths] }
    final attrImageGroups = <String, Map<String, List<String>>>{};
    for (final entry in s.attributeImages.entries) {
      final parts  = entry.key.split('::'); // "{attrId}::{value}"
      if (parts.length < 2) continue;
      final attrId = parts[0];
      final value  = parts.sublist(1).join('::');
      attrImageGroups.putIfAbsent(attrId, () => {})[value] = entry.value;
    }

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Review everything before going live.',
                  style: TextStyle(color: AppColors.grey, fontSize: 14),
                ).animate().fadeIn(),

                const SizedBox(height: 20),

                // ── PRODUCT INFO ───────────────────────────────────────────────
                _Section(
                  title:  'PRODUCT INFO',
                  onEdit: () => goTo(1),
                  children: [
                    _Row('Category',
                        s.categoryName?.isNotEmpty == true
                            ? s.categoryName! : '—'),
                    _Row('Name',
                        s.productName.isNotEmpty ? s.productName : '—'),
                    _Row('Description',
                        s.description.isNotEmpty
                            ? (s.description.length > 120
                                ? '${s.description.substring(0, 120)}…'
                                : s.description)
                            : '—'),
                  ],
                ),

                // ── ATTRIBUTES ─────────────────────────────────────────────────
                if (s.attributeValues.isNotEmpty)
                  _Section(
                    title:  'ATTRIBUTES',
                    onEdit: () => goTo(2),
                    children: s.attributeValues.entries.map((e) {
                      final name  = attrNameMap[e.key] ?? e.key;
                      final value = e.value.replaceAll(',', ', ');
                      return _Row(name, value);
                    }).toList(),
                  ),

                // ── VARIANTS ──────────────────────────────────────────────────
                if (s.variants.isNotEmpty)
                  _Section(
                    title:  'VARIANTS  (${s.variants.length} SKUs)',
                    onEdit: () => goTo(3),
                    children: s.variants.map((v) {
                      final label  = v['label']?.toString() ?? '—';
                      final price  = v['price'];
                      final stock  = v['stock'];
                      final sku    = v['sku']?.toString() ?? '';
                      final detail = [
                        if (price != null && price != 0) '₹$price',
                        if (stock != null && stock != 0) '${stock} pc',
                        if (sku.isNotEmpty) sku,
                      ].join('  ·  ');
                      return _Row(label, detail.isNotEmpty ? detail : '—');
                    }).toList(),
                  ),

                // ── PHOTOS ────────────────────────────────────────────────────
                if (allPaths.isNotEmpty || s.attributeImages.isNotEmpty) ...[
                  _SectionHeader(title: 'PHOTOS', onEdit: () => goTo(4))
                      .animate().fadeIn().slideY(begin: 0.03, end: 0),

                  // General cover images strip
                  if (allPaths.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _SubLabel(label: 'PRODUCT COVER  (${allPaths.length})'),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 80,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: allPaths.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(width: 8),
                        itemBuilder: (_, i) => _MediaThumb(
                          path: allPaths[i],
                          type: s.mediaTypes[allPaths[i]] ?? 'image',
                          isFirst: i == 0,
                        ).animate(
                          delay: Duration(milliseconds: i * 30),
                        ).fadeIn().scale(begin: const Offset(0.9, 0.9)),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Per-attribute image groups
                  for (final attrEntry in attrImageGroups.entries) ...[
                    _SubLabel(
                        label:
                            '${(attrNameMap[attrEntry.key] ?? attrEntry.key).toUpperCase()} PHOTOS'),
                    const SizedBox(height: 8),
                    for (final valEntry in attrEntry.value.entries) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 68,
                              child: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  valEntry.key,
                                  style: const TextStyle(
                                      color:      AppColors.grey,
                                      fontSize:   12,
                                      fontWeight: FontWeight.w500),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: SizedBox(
                                height: 68,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: valEntry.value.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(width: 6),
                                  itemBuilder: (_, i) {
                                    final path = valEntry.value[i];
                                    return _MediaThumb(
                                      path: path,
                                      type: s.mediaTypes[path] ?? 'image',
                                      size: 68,
                                    ).animate(
                                      delay: Duration(milliseconds: i * 25),
                                    ).fadeIn();
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color:  AppColors.success.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: AppColors.success.withOpacity(0.3)),
                              ),
                              child: Text(
                                '${valEntry.value.length}',
                                style: const TextStyle(
                                    color:      AppColors.success,
                                    fontSize:   10,
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                  ],

                  const SizedBox(height: 8),
                ],

                // ── BRAND & TAGS ──────────────────────────────────────────────
                if (s.brandName != null || s.tags.isNotEmpty)
                  _Section(
                    title:  'BRAND & TAGS',
                    onEdit: () => goTo(5),
                    children: [
                      if (s.brandName != null) _Row('Brand', s.brandName!),
                      if (s.tags.isNotEmpty)
                        _Row('Tags', s.tags.map((t) => '#$t').join('  ')),
                    ],
                  ),

                // ── Error banner ───────────────────────────────────────────────
                if (s.error != null) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border:
                          Border.all(color: AppColors.error.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            color: AppColors.error, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(s.error!,
                              style: const TextStyle(
                                  color: AppColors.error, fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 12),

                // ── Go-live notice ─────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: AppColors.success.withOpacity(0.25)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.rocket_launch_rounded,
                          color: AppColors.success, size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Your product will be visible to buyers immediately.',
                          style: TextStyle(
                              color:    AppColors.success,
                              fontSize: 12,
                              height:   1.5),
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 300.ms),
              ],
            ),
          ),
        ),

        // ── Publish button ─────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          decoration: const BoxDecoration(
            color:  AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: AppButton(
            label:     'Publish Product',
            onTap:     publish,
            isLoading: loading,
            icon:      Icons.rocket_launch_rounded,
          ),
        ),
      ],
    );
  }
}

// ── Section with edit button ──────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String       title;
  final VoidCallback onEdit;
  final List<Widget> children;

  const _Section({
    required this.title,
    required this.onEdit,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: title, onEdit: onEdit),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color:  AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(children: children),
        ),
        const SizedBox(height: 16),
      ],
    ).animate().fadeIn().slideY(begin: 0.03, end: 0);
  }
}

class _SectionHeader extends StatelessWidget {
  final String       title;
  final VoidCallback onEdit;

  const _SectionHeader({required this.title, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            color:         AppColors.grey,
            fontSize:      11,
            fontWeight:    FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const Spacer(),
        GestureDetector(
          onTap: onEdit,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color:  AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.edit_rounded,
                    color: AppColors.grey, size: 11),
                SizedBox(width: 4),
                Text('Edit',
                    style: TextStyle(
                        color:      AppColors.grey,
                        fontSize:   11,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Sub-label ─────────────────────────────────────────────────────────────────

class _SubLabel extends StatelessWidget {
  final String label;
  const _SubLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
          color:         AppColors.greyDark,
          fontSize:      10,
          fontWeight:    FontWeight.w600,
          letterSpacing: 0.6),
    );
  }
}

// ── Media thumbnail ───────────────────────────────────────────────────────────

class _MediaThumb extends StatelessWidget {
  final String  path;
  final String  type;
  final double  size;
  final bool    isFirst;

  const _MediaThumb({
    required this.path,
    required this.type,
    this.size    = 80,
    this.isFirst = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width:  size,
          height: size,
          decoration: BoxDecoration(
            color:  AppColors.surface2,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isFirst
                  ? AppColors.white.withOpacity(0.4)
                  : Colors.white12,
              width: isFirst ? 1.5 : 1,
            ),
          ),
          clipBehavior: Clip.hardEdge,
          child: type == 'video'
              ? const _VideoIcon()
              : kIsWeb
                  ? Image.network(path,
                      fit: BoxFit.cover,
                      width: size, height: size,
                      errorBuilder: (_, __, ___) =>
                          const _BrokenIcon())
                  : Image.file(File(path),
                      fit: BoxFit.cover,
                      width: size, height: size,
                      errorBuilder: (_, __, ___) =>
                          const _BrokenIcon()),
        ),
        // "Cover" badge on first image
        if (isFirst)
          Positioned(
            bottom: 4, left: 0, right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Cover',
                  style: TextStyle(
                      color:      Colors.white,
                      fontSize:   8,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        // Video indicator
        if (type == 'video')
          Positioned(
            top: 4, right: 4,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(Icons.videocam_rounded,
                  color: Colors.white, size: 10),
            ),
          ),
      ],
    );
  }
}

class _VideoIcon extends StatelessWidget {
  const _VideoIcon();
  @override
  Widget build(BuildContext context) => const ColoredBox(
        color: Colors.black87,
        child: Center(
          child: Icon(Icons.play_circle_outline_rounded,
              color: Colors.white54, size: 24),
        ),
      );
}

class _BrokenIcon extends StatelessWidget {
  const _BrokenIcon();
  @override
  Widget build(BuildContext context) => const Center(
        child: Icon(Icons.broken_image_rounded,
            color: AppColors.grey, size: 24),
      );
}

// ── Data row ──────────────────────────────────────────────────────────────────

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: const TextStyle(
                    color: AppColors.grey, fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    color:      AppColors.white,
                    fontSize:   13,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
