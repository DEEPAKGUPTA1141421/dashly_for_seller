import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../providers/add_product_provider.dart';
import '../../../utils/app_colors.dart';

class BasicInfoStep extends ConsumerStatefulWidget {
  const BasicInfoStep({super.key});

  @override
  ConsumerState<BasicInfoStep> createState() => _BasicInfoStepState();
}

class _BasicInfoStepState extends ConsumerState<BasicInfoStep> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _formKey  = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final s = ref.read(addProductPod);
    _nameCtrl.text = s.productName;
    _descCtrl.text = s.description;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (!_formKey.currentState!.validate()) return;
    ref.read(addProductPod.notifier).saveBasicInfo(
      _nameCtrl.text.trim(),
      _descCtrl.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Give your product a clear name and description.',
              style: TextStyle(color: AppColors.grey, fontSize: 14),
            ).animate().fadeIn(),

            const SizedBox(height: 24),

            AppTextField(
              hint: 'e.g. Cotton Kurta – Navy Blue',
              label: 'PRODUCT NAME',
              controller: _nameCtrl,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
            ).animate().fadeIn(delay: 80.ms),

            const SizedBox(height: 16),

            AppTextField(
              hint: 'Describe material, fit, occasion…',
              label: 'DESCRIPTION',
              controller: _descCtrl,
              maxLines: 5,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Description is required' : null,
            ).animate().fadeIn(delay: 140.ms),

            const SizedBox(height: 12),

            // Tip
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.info.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.info.withOpacity(0.25)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb_outline_rounded, color: AppColors.info, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Good descriptions include: material, size guide, care instructions, and use cases.',
                      style: TextStyle(color: AppColors.info, fontSize: 12, height: 1.5),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 200.ms),

            const SizedBox(height: 40),

            AppButton(
              label: 'Continue',
              onTap: _next,
              icon: Icons.arrow_forward_rounded,
            ).animate().fadeIn(delay: 240.ms),
          ],
        ),
      ),
    );
  }
}
