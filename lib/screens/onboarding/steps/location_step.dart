import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../providers/onboarding_provider.dart';
import '../../../utils/app_colors.dart';

class LocationStep extends ConsumerStatefulWidget {
  const LocationStep({super.key});

  @override
  ConsumerState<LocationStep> createState() => _LocationStepState();
}

class _LocationStepState extends ConsumerState<LocationStep> {
  final _addressCtrl  = TextEditingController();
  final _cityCtrl     = TextEditingController();
  final _stateCtrl    = TextEditingController();
  final _pincodeCtrl  = TextEditingController();
  final _formKey      = GlobalKey<FormState>();

  @override
  void dispose() {
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _pincodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(onboardingPod.notifier).submitLocation({
      'address': _addressCtrl.text.trim(),
      'city':    _cityCtrl.text.trim(),
      'state':   _stateCtrl.text.trim(),
      'pincode': _pincodeCtrl.text.trim(),
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
              'Where is your business located?',
              style: TextStyle(color: AppColors.grey, fontSize: 14),
            ).animate().fadeIn(),
            const SizedBox(height: 28),
            AppTextField(
              hint: 'Street, Area, Landmark',
              label: 'ADDRESS',
              controller: _addressCtrl,
              maxLines: 2,
              validator: (v) => (v == null || v.isEmpty) ? 'Address is required' : null,
            ).animate().fadeIn(delay: 80.ms),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    hint: 'City',
                    label: 'CITY',
                    controller: _cityCtrl,
                    validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppTextField(
                    hint: '6-digit code',
                    label: 'PINCODE',
                    controller: _pincodeCtrl,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    validator: (v) => (v == null || v.length != 6) ? 'Invalid' : null,
                  ),
                ),
              ],
            ).animate().fadeIn(delay: 120.ms),
            const SizedBox(height: 16),
            AppTextField(
              hint: 'State',
              label: 'STATE',
              controller: _stateCtrl,
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
            ).animate().fadeIn(delay: 160.ms),
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
            ).animate().fadeIn(delay: 200.ms),
          ],
        ),
      ),
    );
  }
}
