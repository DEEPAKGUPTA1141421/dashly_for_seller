import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/add_product_provider.dart';
import '../utils/app_colors.dart';
import '../utils/haptic_utils.dart';
import 'add_product/steps/category_step.dart';
import 'add_product/steps/basic_info_step.dart';
import 'add_product/steps/attributes_step.dart';
import 'add_product/steps/variants_step.dart';
import 'add_product/steps/images_step.dart';
import 'add_product/steps/tags_brand_step.dart';
import 'add_product/steps/review_step.dart';

class AddProductScreen extends ConsumerStatefulWidget {
  const AddProductScreen({super.key});

  @override
  ConsumerState<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends ConsumerState<AddProductScreen> {
  static const _stepLabels = [
    'Category', 'Basic Info', 'Attributes',
    'Variants', 'Photos', 'Brand & Tags', 'Review',
  ];

  static const _stepIcons = [
    CupertinoIcons.square_grid_2x2,
    CupertinoIcons.doc_text,
    CupertinoIcons.slider_horizontal_3,
    CupertinoIcons.rectangle_stack,
    CupertinoIcons.photo_on_rectangle,
    CupertinoIcons.heart,
    CupertinoIcons.rocket,
  ];

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(addProductPod.notifier).init());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(addProductPod);
    final step  = state.currentStep;

    final steps = <Widget>[
      const CategoryStep(),
      const BasicInfoStep(),
      const AttributesStep(),
      const VariantsStep(),
      const ImagesStep(),
      const TagsBrandStep(),
      const ReviewStep(),
    ];

    return PopScope(
      canPop: step == 0,
      onPopInvoked: (didPop) {
        if (!didPop) ref.read(addProductPod.notifier).prevStep();
      },
      child: Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          backgroundColor: AppColors.bg,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              step > 0 ? Icons.arrow_back_rounded : Icons.close_rounded,
              color: AppColors.white,
            ),
            onPressed: () {
              HapticUtils.light();
              if (step > 0) {
                ref.read(addProductPod.notifier).prevStep();
              } else {
                Navigator.pop(context);
              }
            },
          ),
          title: Column(
            children: [
              Text(
                _stepLabels[step],
                style: const TextStyle(
                  color: AppColors.white, fontSize: 16, fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'Step ${step + 1} of ${_stepLabels.length}',
                style: const TextStyle(color: AppColors.grey, fontSize: 11),
              ),
            ],
          ),
          centerTitle: true,
        ),

        body: Column(
          children: [
            _StepBar(
              current: step,
              total: _stepLabels.length,
              icons: _stepIcons,
              labels: _stepLabels,
              onStepTap: (i) {
                HapticUtils.light();
                ref.read(addProductPod.notifier).goToStep(i);
              },
            ),
            const Divider(color: AppColors.border, height: 1),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.04, 0),
                      end: Offset.zero,
                    ).animate(anim),
                    child: child,
                  ),
                ),
                child: KeyedSubtree(key: ValueKey(step), child: steps[step]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Scrollable step icon bar ──────────────────────────────────────────────────

class _StepBar extends StatelessWidget {
  final int current;
  final int total;
  final List<IconData> icons;
  final List<String> labels;
  final void Function(int)? onStepTap;

  const _StepBar({
    required this.current,
    required this.total,
    required this.icons,
    required this.labels,
    this.onStepTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: total,
        itemBuilder: (_, i) {
          final done   = i < current;
          final active = i == current;
          return Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: done ? () => onStepTap?.call(i) : null,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: done
                            ? AppColors.success
                            : active
                                ? AppColors.white
                                : AppColors.surface,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: done
                              ? AppColors.success
                              : active
                                  ? AppColors.white
                                  : AppColors.border,
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: done
                            ? const Icon(CupertinoIcons.checkmark,
                                color: Colors.white, size: 18)
                            : Icon(
                                icons[i],
                                color: active ? AppColors.bg : AppColors.greyDark,
                                size: 20,
                              ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      labels[i],
                      style: TextStyle(
                        color: done
                            ? AppColors.success
                            : active
                                ? AppColors.white
                                : AppColors.greyDark,
                        fontSize: 11,
                        fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              if (i < total - 1)
                Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 28, height: 2,
                    decoration: BoxDecoration(
                      color: done ? AppColors.success : AppColors.border,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    ).animate().fadeIn();
  }
}
