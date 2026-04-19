import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../providers/onboarding_provider.dart';
import '../../../utils/app_colors.dart';

class AadharStep extends ConsumerStatefulWidget {
  const AadharStep({super.key});

  @override
  ConsumerState<AadharStep> createState() => _AadharStepState();
}

class _AadharStepState extends ConsumerState<AadharStep> {
  final _aadharCtrl = TextEditingController();
  final _formKey    = GlobalKey<FormState>();

  @override
  void dispose() {
    _aadharCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(onboardingPod.notifier).submitAadhar({
      'aadharNumber': _aadharCtrl.text.replaceAll(' ', ''),
    });
    if (mounted && ref.read(onboardingPod).isComplete) {
      Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
    }
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
              'Verify your identity with Aadhaar',
              style: TextStyle(color: AppColors.grey, fontSize: 14),
            ).animate().fadeIn(),
            const SizedBox(height: 28),

            // 3D fingerprint card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.white.withOpacity(0.03),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.surface2,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Icon(
                      Icons.fingerprint_rounded,
                      color: AppColors.white,
                      size: 36,
                    ),
                  )
                      .animate(onPlay: (c) => c.repeat())
                      .shimmer(duration: 2000.ms, color: AppColors.white.withOpacity(0.3)),
                  const SizedBox(height: 12),
                  const Text(
                    'Aadhaar Verification',
                    style: TextStyle(color: AppColors.white, fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Required by UIDAI guidelines',
                    style: TextStyle(color: AppColors.grey, fontSize: 12),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 80.ms).scale(begin: const Offset(0.95, 0.95)),

            const SizedBox(height: 24),

            AppTextField(
              hint: 'XXXX XXXX XXXX',
              label: 'AADHAAR NUMBER',
              controller: _aadharCtrl,
              keyboardType: TextInputType.number,
              maxLength: 14,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                _AadharFormatter(),
              ],
              validator: (v) {
                final digits = v?.replaceAll(' ', '') ?? '';
                return digits.length != 12 ? 'Enter valid 12-digit Aadhaar' : null;
              },
            ).animate().fadeIn(delay: 160.ms),

            if (state.error != null) ...[
              const SizedBox(height: 16),
              Text(state.error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
            ],
            const SizedBox(height: 40),
            AppButton(
              label: 'Complete Setup',
              onTap: _submit,
              isLoading: state.isLoading,
              icon: Icons.check_rounded,
            ).animate().fadeIn(delay: 200.ms),
          ],
        ),
      ),
    );
  }
}

class _AadharFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue old, TextEditingValue next) {
    final digits = next.text.replaceAll(' ', '');
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(digits[i]);
    }
    final str = buffer.toString();
    return next.copyWith(
      text: str,
      selection: TextSelection.collapsed(offset: str.length),
    );
  }
}
