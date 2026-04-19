import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/widgets/app_button.dart';
import '../../../providers/add_product_provider.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/haptic_utils.dart';

class ImagesStep extends ConsumerWidget {
  const ImagesStep({super.key});

  Future<void> _pick(BuildContext context, WidgetRef ref) async {
    HapticUtils.light();
    final result = await ImagePicker().pickMultiImage(imageQuality: 85);
    for (final img in result) {
      ref.read(addProductPod.notifier).addImage(img.path);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paths = ref.watch(addProductPod).imagePaths;
    final count = paths.length;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Add up to 8 product photos. First image is the cover.',
                  style: TextStyle(color: AppColors.grey, fontSize: 14),
                ).animate().fadeIn(),

                const SizedBox(height: 20),

                // Grid
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                  ),
                  itemCount: count < 8 ? count + 1 : count,
                  itemBuilder: (_, i) {
                    // Add button
                    if (i == count && count < 8) {
                      return GestureDetector(
                        onTap: () => _pick(context, ref),
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppColors.border,
                              style: BorderStyle.solid,
                            ),
                          ),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate_rounded,
                                  color: AppColors.grey, size: 28),
                              SizedBox(height: 6),
                              Text('Add', style: TextStyle(color: AppColors.grey, fontSize: 11)),
                            ],
                          ),
                        ),
                      ).animate().fadeIn();
                    }

                    // Image tile
                    return Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.file(
                            File(paths[i]),
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                        ),
                        // Cover badge
                        if (i == 0)
                          Positioned(
                            left: 6, top: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.white,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Cover',
                                style: TextStyle(
                                  color: AppColors.bg, fontSize: 9, fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        // Remove button
                        Positioned(
                          right: 4, top: 4,
                          child: GestureDetector(
                            onTap: () {
                              HapticUtils.light();
                              ref.read(addProductPod.notifier).removeImage(i);
                            },
                            child: Container(
                              width: 22, height: 22,
                              decoration: const BoxDecoration(
                                color: AppColors.error, shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close_rounded, color: Colors.white, size: 13),
                            ),
                          ),
                        ),
                      ],
                    ).animate(delay: Duration(milliseconds: i * 40)).fadeIn().scale(
                          begin: const Offset(0.9, 0.9),
                        );
                  },
                ),

                if (count == 0)
                  GestureDetector(
                    onTap: () => _pick(context, ref),
                    child: Container(
                      width: double.infinity,
                      height: 140,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_rounded,
                              color: AppColors.grey, size: 36),
                          SizedBox(height: 10),
                          Text('Tap to add product photos',
                              style: TextStyle(color: AppColors.grey, fontSize: 13)),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(delay: 60.ms),

                const SizedBox(height: 12),
                Text(
                  '$count / 8 photos added',
                  style: const TextStyle(color: AppColors.greyDark, fontSize: 12),
                ).animate().fadeIn(),
              ],
            ),
          ),
        ),

        Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: AppButton(
            label: count > 0 ? 'Continue with $count photo${count > 1 ? 's' : ''}' : 'Skip for now',
            onTap: () => ref.read(addProductPod.notifier).advanceFromImages(),
            icon: Icons.arrow_forward_rounded,
          ),
        ),
      ],
    );
  }
}
