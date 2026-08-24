import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/add_product_provider.dart';
import '../utils/app_colors.dart';
import '../utils/haptic_utils.dart';
import 'add_product/steps/basic_info_step.dart';
import 'add_product/steps/attributes_step.dart';
import 'add_product/steps/variants_step.dart';
import 'add_product/steps/images_step.dart';
import 'add_product/steps/tags_brand_step.dart';
import 'add_product_screen.dart' show StepBar;

// Reuses the create-wizard's step widgets/provider to edit an existing,
// already-live product. Every step is independently reachable and saves
// itself via an "Update" action — there's no linear publish flow here.
class EditProductScreen extends ConsumerStatefulWidget {
  final String productId;
  const EditProductScreen({super.key, required this.productId});

  @override
  ConsumerState<EditProductScreen> createState() => _EditProductScreenState();
}

class _EditProductScreenState extends ConsumerState<EditProductScreen> {
  static const _stepLabels = [
    'Basic Info', 'Attributes', 'Variants', 'Photos', 'Brand & Tags',
  ];

  static const _stepIcons = [
    CupertinoIcons.doc_text,
    CupertinoIcons.slider_horizontal_3,
    CupertinoIcons.rectangle_stack,
    CupertinoIcons.photo_on_rectangle,
    CupertinoIcons.heart,
  ];

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(addProductPod.notifier).loadForEdit(widget.productId));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(addProductPod);
    final step  = state.currentStep.clamp(0, _stepLabels.length - 1);

    final steps = <Widget>[
      const BasicInfoStep(),
      const AttributesStep(),
      const VariantsStep(),
      const ImagesStep(),
      const TagsBrandStep(),
    ];

    if (state.isLoading && state.createdProductId == null) {
      return const Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(child: CircularProgressIndicator(color: AppColors.white)),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: AppColors.white, size: 20),
          onPressed: () {
            HapticUtils.light();
            Navigator.pop(context);
          },
        ),
        title: Column(
          children: [
            Text(
              _stepLabels[step],
              style: const TextStyle(
                color: AppColors.white, fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.3,
              ),
            ),
            const Text(
              'Edit Product',
              style: TextStyle(color: AppColors.grey, fontSize: 11),
            ),
          ],
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.divider),
        ),
      ),
      body: Column(
        children: [
          StepBar(
            current:    step,
            maxReached: state.maxReachedStep.clamp(0, _stepLabels.length - 1),
            total:      _stepLabels.length,
            icons:      _stepIcons,
            labels:     _stepLabels,
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
    );
  }
}
