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
    Future.microtask(() async {
      await ref.read(addProductPod.notifier).init();
      await ref.read(addProductPod.notifier).checkForDraft();
    });
  }

  void _showDraftDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Unfinished Product',
          style: TextStyle(color: AppColors.white, fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'You have an unfinished product draft. Would you like to continue where you left off?',
          style: TextStyle(color: AppColors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(addProductPod.notifier).discardDraft();
            },
            child: const Text('Discard', style: TextStyle(color: AppColors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(addProductPod.notifier).resumeDraft();
            },
            child: const Text('Continue', style: TextStyle(color: AppColors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AddProductState>(addProductPod, (_, next) {
      if (next.hasDraft && mounted) _showDraftDialog(context);
    });
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
              current:     step,
              maxReached:  state.maxReachedStep,
              total:       _stepLabels.length,
              icons:       _stepIcons,
              labels:      _stepLabels,
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
  final int maxReached;
  final int total;
  final List<IconData> icons;
  final List<String> labels;
  final void Function(int)? onStepTap;

  const _StepBar({
    required this.current,
    required this.maxReached,
    required this.total,
    required this.icons,
    required this.labels,
    this.onStepTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 108,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        itemCount: total,
        itemBuilder: (_, i) {
          // done = completed (green), tappable if within maxReached
          final done      = i < maxReached;
          final active    = i == current;
          final tappable  = i <= maxReached && !active;

          return Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: tappable ? () => onStepTap?.call(i) : null,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Circle ──────────────────────────────────────────────
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 320),
                      curve: Curves.easeOutCubic,
                      width:  active ? 54 : (done ? 48 : 44),
                      height: active ? 54 : (done ? 48 : 44),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: done
                            ? AppColors.success
                            : active
                                ? AppColors.white
                                : AppColors.surface,
                        border: Border.all(
                          color: done
                              ? AppColors.success
                              : active
                                  ? AppColors.white
                                  : AppColors.border,
                          width: active ? 2.5 : 1.5,
                        ),
                        boxShadow: active
                            ? [BoxShadow(color: Colors.white.withOpacity(0.16), blurRadius: 14, spreadRadius: 1)]
                            : done
                                ? [BoxShadow(color: AppColors.success.withOpacity(0.28), blurRadius: 8)]
                                : null,
                      ),
                      child: Center(
                        child: done
                            ? const Icon(CupertinoIcons.checkmark, color: Colors.white, size: 20)
                            : Icon(
                                icons[i],
                                color: active ? AppColors.bg : AppColors.greyDark,
                                size: active ? 24 : 20,
                              ),
                      ),
                    ),
                    const SizedBox(height: 7),
                    // ── Label ────────────────────────────────────────────────
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 280),
                      style: TextStyle(
                        color: done
                            ? AppColors.success
                            : active ? AppColors.white : AppColors.greyDark,
                        fontSize:      active ? 11.5 : 10.5,
                        fontWeight:    active ? FontWeight.w700 : (done ? FontWeight.w500 : FontWeight.w400),
                        letterSpacing: active ? 0.2 : 0,
                      ),
                      child: Text(labels[i]),
                    ),
                  ],
                ),
              )
              .animate(delay: Duration(milliseconds: i * 50))
              .fadeIn(duration: 300.ms),

              // ── Connector ────────────────────────────────────────────────
              if (i < total - 1)
                Padding(
                  padding: const EdgeInsets.only(bottom: 26),
                  child: SizedBox(
                    width: 26, height: 2,
                    child: Stack(
                      children: [
                        Container(
                          width: 26, height: 2,
                          decoration: BoxDecoration(
                            color: AppColors.border,
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                        AnimatedOpacity(
                          opacity: done ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 400),
                          child: Container(
                            width: 26, height: 2,
                            decoration: BoxDecoration(
                              color: AppColors.success,
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
