import 'dart:io' show File;
import 'dart:typed_data' show Uint8List;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/widgets/app_button.dart';
import '../../../providers/add_product_provider.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/sound_utils.dart';

// ── Media action enum ─────────────────────────────────────────────────────────

enum _MediaAction { takePhoto, recordVideo, gallery }

// ── Cross-platform media display ──────────────────────────────────────────────

class _MediaDisplay extends StatelessWidget {
  final String path;
  final String type; // 'image' | 'video'
  final BoxFit fit;
  final double? width;
  final double? height;

  const _MediaDisplay({
    required this.path,
    this.type = 'image',
    this.fit = BoxFit.cover,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    if (type == 'video') {
      return _VideoPlaceholder(width: width, height: height);
    }
    if (kIsWeb) {
      return Image.network(
        path,
        fit: fit,
        width: width,
        height: height,
        errorBuilder: (_, __, ___) => const _BrokenIcon(),
      );
    }
    return Image.file(
      File(path),
      fit: fit,
      width: width,
      height: height,
      errorBuilder: (_, __, ___) => const _BrokenIcon(),
    );
  }
}

class _BrokenIcon extends StatelessWidget {
  const _BrokenIcon();
  @override
  Widget build(BuildContext context) =>
      const Center(child: Icon(Icons.broken_image_rounded, color: AppColors.grey, size: 24));
}

class _VideoPlaceholder extends StatelessWidget {
  final double? width;
  final double? height;
  const _VideoPlaceholder({this.width, this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: Colors.black87,
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.play_circle_outline_rounded, color: Colors.white70, size: 28),
          SizedBox(height: 3),
          Text('Video', style: TextStyle(color: Colors.white54, fontSize: 9)),
        ],
      ),
    );
  }
}

// ── Step widget ───────────────────────────────────────────────────────────────

class ImagesStep extends ConsumerStatefulWidget {
  const ImagesStep({super.key});

  @override
  ConsumerState<ImagesStep> createState() => _ImagesStepState();
}

class _ImagesStepState extends ConsumerState<ImagesStep> {

  // ── Pick helpers ──────────────────────────────────────────────────────────

  Future<void> _pickForAttribute(String key, int current) async {
    if (current >= 10) return;
    SoundUtils.tap();
    final action = await _showSourceSheet();
    if (action == null) return;

    final items = await _pickMedia(action, limit: 10 - current);
    for (final item in items) {
      ref.read(addProductPod.notifier).addAttributeMedia(
        key, item.path,
        type:  item.type,
        bytes: item.bytes,
      );
    }
    if (items.isNotEmpty) SoundUtils.add();
  }

  Future<void> _pickGeneral(int current) async {
    if (current >= 8) return;
    SoundUtils.tap();
    final action = await _showSourceSheet();
    if (action == null) return;

    final items = await _pickMedia(action, limit: 8 - current);
    for (final item in items) {
      ref.read(addProductPod.notifier).addMedia(
        item.path,
        type:  item.type,
        bytes: item.bytes,
      );
    }
    if (items.isNotEmpty) SoundUtils.add();
  }

  Future<_MediaAction?> _showSourceSheet() => showModalBottomSheet<_MediaAction>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (_) => const _SourceSheet(),
      );

  Future<List<_PickedItem>> _pickMedia(_MediaAction action, {int limit = 10}) async {
    final picker = ImagePicker();
    final result = <_PickedItem>[];

    if (action == _MediaAction.gallery) {
      final files = await picker.pickMultipleMedia(imageQuality: 85, limit: limit);
      for (final f in files) {
        final isVideo = _isVideo(f);
        final bytes   = await f.readAsBytes();
        result.add(_PickedItem(
          path:  f.path,
          type:  isVideo ? 'video' : 'image',
          bytes: bytes,
        ));
      }
    } else if (action == _MediaAction.takePhoto) {
      final f = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
      if (f != null) {
        result.add(_PickedItem(
          path:  f.path,
          type:  'image',
          bytes: await f.readAsBytes(),
        ));
      }
    } else {
      final f = await picker.pickVideo(source: ImageSource.camera);
      if (f != null) {
        result.add(_PickedItem(
          path:  f.path,
          type:  'video',
          bytes: await f.readAsBytes(),
        ));
      }
    }
    return result;
  }

  bool _isVideo(XFile f) {
    final mime = f.mimeType?.toLowerCase() ?? '';
    if (mime.startsWith('video/')) return true;
    final ext = f.path.toLowerCase();
    return ext.endsWith('.mp4') || ext.endsWith('.mov') ||
           ext.endsWith('.avi') || ext.endsWith('.mkv') ||
           ext.endsWith('.webm') || ext.endsWith('.3gp');
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(addProductPod);

    // Build sections for image attributes (isImageAttribute: true)
    final imageAttrSections = <_AttrSection>[];
    for (final a in s.attributes) {
      final attr = a as Map;
      if (attr['isImageAttribute'] != true) continue;
      final attrId   = attr['id']?.toString() ?? '';
      final attrName = attr['name']?.toString() ?? 'Attribute';
      final selected = (s.attributeValues[attrId] ?? '')
          .split(',')
          .map((v) => v.trim())
          .where((v) => v.isNotEmpty)
          .toList();
      if (selected.isEmpty) continue;
      imageAttrSections.add(_AttrSection(id: attrId, name: attrName, values: selected));
    }

    final hasAttrSections = imageAttrSections.isNotEmpty;
    final paths           = s.imagePaths;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Attribute-based media sections ─────────────────────────
                if (hasAttrSections) ...[
                  for (var i = 0; i < imageAttrSections.length; i++) ...[
                    _AttrImageBlock(
                      section:         imageAttrSections[i],
                      attributeImages: s.attributeImages,
                      mediaTypes:      s.mediaTypes,
                      onPick:   (key, count) => _pickForAttribute(key, count),
                      onRemove: (key, idx) {
                        SoundUtils.remove();
                        ref.read(addProductPod.notifier).removeAttributeMedia(key, idx);
                      },
                    ).animate(delay: Duration(milliseconds: i * 80)).fadeIn(),
                  ],
                  Container(
                    height: 8,
                    color: AppColors.surface2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                  ),
                ],

                // ── General product media ──────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'PRODUCT COVER',
                            style: TextStyle(
                              color:         AppColors.grey,
                              fontSize:      10,
                              fontWeight:    FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const Spacer(),
                          Text('${paths.length} / 8',
                              style: const TextStyle(color: AppColors.greyDark, fontSize: 11)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'First photo or video is the main listing media.',
                        style: TextStyle(color: AppColors.greyDark, fontSize: 11),
                      ),
                      const SizedBox(height: 14),

                      // Cover slot
                      _CoverSlot(
                        path:      paths.isNotEmpty ? paths[0] : null,
                        mediaType: paths.isNotEmpty ? (s.mediaTypes[paths[0]] ?? 'image') : 'image',
                        onTap:     () => _pickGeneral(paths.length),
                        onRemove:  paths.isNotEmpty
                            ? () {
                                SoundUtils.remove();
                                ref.read(addProductPod.notifier).removeMedia(0);
                              }
                            : null,
                      ).animate(delay: hasAttrSections ? 200.ms : 60.ms).fadeIn(),

                      // Additional media row
                      if (paths.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        const Row(
                          children: [
                            Text(
                              'MORE PHOTOS / VIDEOS',
                              style: TextStyle(
                                color:         AppColors.grey,
                                fontSize:      10,
                                fontWeight:    FontWeight.w600,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 90,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount:
                                (paths.length - 1) + (paths.length < 8 ? 1 : 0),
                            separatorBuilder: (_, __) => const SizedBox(width: 10),
                            itemBuilder: (_, i) {
                              final idx = i + 1;
                              if (idx >= paths.length) {
                                return _AddTile(
                                  onTap: () => _pickGeneral(paths.length),
                                ).animate().fadeIn();
                              }
                              final path = paths[idx];
                              final type = s.mediaTypes[path] ?? 'image';
                              return _ThumbTile(
                                path:     path,
                                type:     type,
                                onRemove: () {
                                  SoundUtils.remove();
                                  ref.read(addProductPod.notifier).removeMedia(idx);
                                },
                              ).animate(
                                delay: Duration(milliseconds: i * 40),
                              ).fadeIn().slideX(begin: 0.1, end: 0);
                            },
                          ),
                        ),
                      ] else ...[
                        const SizedBox(height: 12),
                        const _TipRow(
                            icon: Icons.wb_sunny_outlined,
                            text: 'Use natural lighting for best results'),
                        const SizedBox(height: 8),
                        const _TipRow(
                            icon: Icons.videocam_outlined,
                            text: 'Short product videos boost conversions'),
                        const SizedBox(height: 8),
                        const _TipRow(
                            icon: Icons.photo_size_select_large_outlined,
                            text: 'Square images (1:1 ratio) are ideal'),
                      ],
                    ],
                  ),
                ).animate(delay: hasAttrSections ? 120.ms : 0.ms).fadeIn(),
              ],
            ),
          ),
        ),

        // ── Continue button ────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          decoration: const BoxDecoration(
            color:  AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: AppButton(
            isLoading: s.isCreating,
            label: paths.isNotEmpty
                ? 'Upload & Continue (${paths.length} file${paths.length > 1 ? 's' : ''})'
                : 'Skip for now',
            onTap: () => ref.read(addProductPod.notifier).uploadImagesAndContinue(),
            icon:  Icons.arrow_forward_rounded,
          ),
        ),
      ],
    );
  }
}

// ── Data ──────────────────────────────────────────────────────────────────────

class _PickedItem {
  final String     path;
  final String     type; // 'image' | 'video'
  final Uint8List  bytes;
  const _PickedItem({required this.path, required this.type, required this.bytes});
}

class _AttrSection {
  final String       id;
  final String       name;
  final List<String> values;
  const _AttrSection({required this.id, required this.name, required this.values});
}

// ── Attribute image block ─────────────────────────────────────────────────────

class _AttrImageBlock extends StatelessWidget {
  final _AttrSection                           section;
  final Map<String, List<String>>              attributeImages;
  final Map<String, String>                    mediaTypes;
  final Future<void> Function(String, int)     onPick;
  final void Function(String, int)             onRemove;

  const _AttrImageBlock({
    required this.section,
    required this.attributeImages,
    required this.mediaTypes,
    required this.onPick,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          color: AppColors.surface2,
          child: Row(
            children: [
              const Icon(Icons.perm_media_outlined, color: AppColors.info, size: 14),
              const SizedBox(width: 8),
              Text(
                '${section.name.toUpperCase()} MEDIA',
                style: const TextStyle(
                  color:         AppColors.white,
                  fontSize:      12,
                  fontWeight:    FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(width: 8),
              const Text('up to 10 per option',
                  style: TextStyle(color: AppColors.grey, fontSize: 10)),
            ],
          ),
        ),

        ...section.values.asMap().entries.map((e) {
          final value = e.value;
          final key   = '${section.id}::$value';
          final imgs  = attributeImages[key] ?? [];
          return _AttrValueRow(
            value:      value,
            images:     imgs,
            mediaTypes: mediaTypes,
            onPick:     () => onPick(key, imgs.length),
            onRemove:   (idx) => onRemove(key, idx),
          ).animate(delay: Duration(milliseconds: e.key * 40)).fadeIn();
        }),
      ],
    );
  }
}

// ── Single attribute-value media row ─────────────────────────────────────────

class _AttrValueRow extends StatelessWidget {
  final String              value;
  final List<String>        images;
  final Map<String, String> mediaTypes;
  final VoidCallback        onPick;
  final void Function(int)  onRemove;

  const _AttrValueRow({
    required this.value,
    required this.images,
    required this.mediaTypes,
    required this.onPick,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final count = images.length;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 68,
            child: Text(
              value,
              style: const TextStyle(
                  color: AppColors.white, fontSize: 13, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 10),

          Expanded(
            child: SizedBox(
              height: 68,
              child: ListView.separated(
                scrollDirection:  Axis.horizontal,
                physics:          const BouncingScrollPhysics(),
                itemCount:        count + (count < 10 ? 1 : 0),
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  if (i == count) {
                    return _SmallAddTile(onTap: onPick).animate().fadeIn();
                  }
                  final path = images[i];
                  final type = mediaTypes[path] ?? 'image';
                  return _SmallThumbTile(
                    path:     path,
                    type:     type,
                    onRemove: () => onRemove(i),
                  ).animate(
                    delay: Duration(milliseconds: i * 30),
                  ).fadeIn().scale(begin: const Offset(0.8, 0.8));
                },
              ),
            ),
          ),
          const SizedBox(width: 10),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color:  count > 0
                  ? AppColors.success.withOpacity(0.12)
                  : AppColors.surface2,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: count > 0
                    ? AppColors.success.withOpacity(0.3)
                    : AppColors.border,
              ),
            ),
            child: Text(
              '$count/10',
              style: TextStyle(
                color:      count > 0 ? AppColors.success : AppColors.greyDark,
                fontSize:   10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Small add tile ────────────────────────────────────────────────────────────

class _SmallAddTile extends StatelessWidget {
  final VoidCallback onTap;
  const _SmallAddTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 68, height: 68,
        decoration: BoxDecoration(
          color:  AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_rounded, color: AppColors.grey, size: 20),
            SizedBox(height: 2),
            Text('Add', style: TextStyle(color: AppColors.greyDark, fontSize: 9)),
          ],
        ),
      ),
    );
  }
}

// ── Small thumbnail tile (68×68) ──────────────────────────────────────────────

class _SmallThumbTile extends StatelessWidget {
  final String       path;
  final String       type;
  final VoidCallback onRemove;

  const _SmallThumbTile({required this.path, required this.type, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 68, height: 68,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white12),
            color: AppColors.surface2,
          ),
          clipBehavior: Clip.hardEdge,
          child: _MediaDisplay(path: path, type: type, width: 68, height: 68),
        ),
        Positioned(
          top: -5, right: -5,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 20, height: 20,
              decoration: BoxDecoration(
                color:  AppColors.error,
                shape:  BoxShape.circle,
                border: Border.all(color: AppColors.bg, width: 1.5),
              ),
              child: const Icon(Icons.close_rounded, color: Colors.white, size: 11),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Cover photo / video slot ──────────────────────────────────────────────────

class _CoverSlot extends StatelessWidget {
  final String?      path;
  final String       mediaType;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  const _CoverSlot({
    required this.path,
    required this.mediaType,
    required this.onTap,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: path == null ? onTap : null,
      child: Container(
        width:  double.infinity,
        height: 200,
        decoration: BoxDecoration(
          color:  AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: path != null ? Colors.white24 : AppColors.border,
            width: 1.5,
          ),
        ),
        clipBehavior: Clip.hardEdge,
        child: path != null
            ? Stack(
                fit: StackFit.expand,
                children: [
                  _MediaDisplay(path: path!, type: mediaType),
                  // Gradient overlay (only for images)
                  if (mediaType == 'image')
                    Positioned(
                      left: 0, right: 0, bottom: 0,
                      child: Container(
                        height: 60,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end:   Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.6),
                            ],
                          ),
                        ),
                      ),
                    ),
                  // Cover badge
                  Positioned(
                    left: 12, bottom: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            mediaType == 'video'
                                ? Icons.play_circle_filled_rounded
                                : Icons.star_rounded,
                            size: 11, color: AppColors.bg,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            mediaType == 'video' ? 'Cover Video' : 'Cover',
                            style: const TextStyle(
                                color:      AppColors.bg,
                                fontSize:   11,
                                fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Change + remove actions
                  Positioned(
                    top: 10, right: 10,
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: onTap,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.perm_media_outlined, size: 13, color: Colors.white),
                                SizedBox(width: 4),
                                Text('Change',
                                    style: TextStyle(
                                        color:      Colors.white,
                                        fontSize:   11,
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        if (onRemove != null)
                          GestureDetector(
                            onTap: onRemove,
                            child: Container(
                              width: 28, height: 28,
                              decoration: BoxDecoration(
                                color:  Colors.black54,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Icon(Icons.close_rounded,
                                  color: Colors.white, size: 15),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 56, height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.surface2,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Icon(Icons.perm_media_outlined,
                        color: AppColors.grey, size: 26),
                  ),
                  const SizedBox(height: 12),
                  const Text('Tap to add photo or video',
                      style: TextStyle(
                          color:      AppColors.white,
                          fontSize:   14,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  const Text('Camera · Gallery · Video',
                      style: TextStyle(color: AppColors.grey, fontSize: 12)),
                ],
              ),
      ),
    );
  }
}

// ── Thumbnail tile (90×90) ────────────────────────────────────────────────────

class _ThumbTile extends StatelessWidget {
  final String       path;
  final String       type;
  final VoidCallback onRemove;

  const _ThumbTile({required this.path, required this.type, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 90, height: 90,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
            color: AppColors.surface2,
          ),
          clipBehavior: Clip.hardEdge,
          child: _MediaDisplay(path: path, type: type, width: 90, height: 90),
        ),
        Positioned(
          top: -5, right: -5,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 22, height: 22,
              decoration: BoxDecoration(
                color:  AppColors.error,
                shape:  BoxShape.circle,
                border: Border.all(color: AppColors.bg, width: 1.5),
              ),
              child: const Icon(Icons.close_rounded, color: Colors.white, size: 12),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Add more tile ─────────────────────────────────────────────────────────────

class _AddTile extends StatelessWidget {
  final VoidCallback onTap;
  const _AddTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 90, height: 90,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_rounded, color: AppColors.grey, size: 24),
            SizedBox(height: 4),
            Text('Add', style: TextStyle(color: AppColors.greyDark, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

// ── Source picker sheet ───────────────────────────────────────────────────────

class _SourceSheet extends StatelessWidget {
  const _SourceSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            _Option(
              icon:  Icons.photo_library_outlined,
              label: 'Photo & Video Library',
              sub:   'Choose images or videos',
              onTap: () => Navigator.pop(context, _MediaAction.gallery),
            ),
            _Option(
              icon:  Icons.camera_alt_outlined,
              label: 'Take Photo',
              sub:   'Use camera',
              onTap: () => Navigator.pop(context, _MediaAction.takePhoto),
            ),
            _Option(
              icon:  Icons.videocam_outlined,
              label: 'Record Video',
              sub:   'Use camera',
              onTap: () => Navigator.pop(context, _MediaAction.recordVideo),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _Option extends StatelessWidget {
  final IconData     icon;
  final String       label;
  final String?      sub;
  final VoidCallback onTap;

  const _Option({required this.icon, required this.label, this.sub, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.white, size: 20),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color:      AppColors.white,
                        fontSize:   14,
                        fontWeight: FontWeight.w600)),
                if (sub != null)
                  Text(sub!, style: const TextStyle(
                      color: AppColors.grey, fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tip row ───────────────────────────────────────────────────────────────────

class _TipRow extends StatelessWidget {
  final IconData icon;
  final String   text;

  const _TipRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.grey, size: 16),
          const SizedBox(width: 12),
          Text(text, style: const TextStyle(color: AppColors.grey, fontSize: 12)),
        ],
      ),
    );
  }
}
