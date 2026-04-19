import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../providers/onboarding_provider.dart';
import '../../../utils/app_colors.dart';

class BusinessStep extends ConsumerStatefulWidget {
  const BusinessStep({super.key});

  @override
  ConsumerState<BusinessStep> createState() => _BusinessStepState();
}

class _BusinessStepState extends ConsumerState<BusinessStep> {
  final _businessNameCtrl = TextEditingController();
  final _gstCtrl          = TextEditingController();
  final _panCtrl          = TextEditingController();
  String _businessType    = 'INDIVIDUAL';
  final _formKey          = GlobalKey<FormState>();
  bool _initialized       = false;
  late Map<String, String> _original;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      final fd = ref.read(onboardingPod).formData;
      _businessNameCtrl.text = (fd['businessName'] as String?) ?? '';
      _gstCtrl.text          = (fd['gst']          as String?) ?? '';
      _panCtrl.text          = (fd['pan']          as String?) ?? '';
      final savedType = fd['businessType'] as String?;
      if (savedType != null && ['INDIVIDUAL', 'COMPANY', 'LLP'].contains(savedType)) {
        _businessType = savedType;
      }
      _original = {
        'businessName': _businessNameCtrl.text,
        'gst':          _gstCtrl.text,
        'pan':          _panCtrl.text,
        'businessType': _businessType,
      };
    }
  }

  bool get _isDirty =>
      _businessNameCtrl.text.trim() != _original['businessName'] ||
      _gstCtrl.text.trim()          != _original['gst']          ||
      _panCtrl.text.trim()          != _original['pan']          ||
      _businessType                 != _original['businessType'];

  @override
  void dispose() {
    _businessNameCtrl.dispose();
    _gstCtrl.dispose();
    _panCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_isDirty) {
      ref.read(onboardingPod.notifier).nextStep();
      return;
    }
    await ref.read(onboardingPod.notifier).submitBusiness({
      'businessName': _businessNameCtrl.text.trim(),
      'businessType': _businessType,
      'gst':          _gstCtrl.text.trim(),
      'pan':          _panCtrl.text.trim().toUpperCase(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingPod);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Business details for seller registration',
              style: TextStyle(color: AppColors.grey, fontSize: 14),
            ).animate().fadeIn(),
            const SizedBox(height: 24),

            // Business type selector
            const Text('BUSINESS TYPE', style: TextStyle(color: AppColors.grey, fontSize: 13)),
            const SizedBox(height: 10),
            Row(
              children: ['INDIVIDUAL', 'COMPANY', 'LLP'].map((type) {
                final selected = _businessType == type;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _businessType = type),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.white : AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected ? AppColors.white : AppColors.border,
                        ),
                      ),
                      child: Text(
                        type,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: selected ? AppColors.bg : AppColors.grey,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ).animate().fadeIn(delay: 80.ms),
            const SizedBox(height: 20),
            AppTextField(
              hint: 'Your business name',
              label: 'BUSINESS NAME',
              controller: _businessNameCtrl,
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
            ).animate().fadeIn(delay: 120.ms),
            const SizedBox(height: 16),
            AppTextField(
              hint: '22AAAAA0000A1Z5',
              label: 'GST NUMBER (optional)',
              controller: _gstCtrl,
            ).animate().fadeIn(delay: 160.ms),
            const SizedBox(height: 16),
            AppTextField(
              hint: 'ABCDE1234F',
              label: 'PAN NUMBER',
              controller: _panCtrl,
              validator: (v) {
                if (v == null || v.isEmpty) return 'PAN is required';
                if (v.length != 10) return 'Enter valid PAN';
                return null;
              },
            ).animate().fadeIn(delay: 200.ms),
            if (state.error != null) ...[
              const SizedBox(height: 16),
              Text(state.error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
            ],
            const SizedBox(height: 40),
            AppButton(
              label: 'Continue',
              onTap: _submit,
              isLoading: state.isLoading,
              icon: Icons.arrow_forward_rounded,
            ).animate().fadeIn(delay: 240.ms),
          ],
        ),
      ),
    );
  }
}
