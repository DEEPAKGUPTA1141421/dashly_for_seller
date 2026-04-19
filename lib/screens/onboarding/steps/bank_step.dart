import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../providers/onboarding_provider.dart';
import '../../../utils/app_colors.dart';

class BankStep extends ConsumerStatefulWidget {
  const BankStep({super.key});

  @override
  ConsumerState<BankStep> createState() => _BankStepState();
}

class _BankStepState extends ConsumerState<BankStep> {
  final _accountCtrl  = TextEditingController();
  final _ifscCtrl     = TextEditingController();
  final _holderCtrl   = TextEditingController();
  final _bankNameCtrl = TextEditingController();
  final _formKey      = GlobalKey<FormState>();
  bool _initialized   = false;
  late Map<String, String> _original;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      final fd = ref.read(onboardingPod).formData;
      _accountCtrl.text  = (fd['accountNumber'] as String?) ?? '';
      _ifscCtrl.text     = (fd['ifsc']          as String?) ?? '';
      _holderCtrl.text   = (fd['accountHolder'] as String?) ?? '';
      _bankNameCtrl.text = (fd['bankName']      as String?) ?? '';
      _original = {
        'accountNumber': _accountCtrl.text,
        'ifsc':          _ifscCtrl.text,
        'accountHolder': _holderCtrl.text,
        'bankName':      _bankNameCtrl.text,
      };
    }
  }

  bool get _isDirty =>
      _accountCtrl.text.trim()  != _original['accountNumber'] ||
      _ifscCtrl.text.trim()     != _original['ifsc']          ||
      _holderCtrl.text.trim()   != _original['accountHolder'] ||
      _bankNameCtrl.text.trim() != _original['bankName'];

  @override
  void dispose() {
    _accountCtrl.dispose();
    _ifscCtrl.dispose();
    _holderCtrl.dispose();
    _bankNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_isDirty) {
      ref.read(onboardingPod.notifier).nextStep();
      return;
    }
    await ref.read(onboardingPod.notifier).submitBank({
      'accountNumber': _accountCtrl.text.trim(),
      'ifsc':          _ifscCtrl.text.trim().toUpperCase(),
      'accountHolder': _holderCtrl.text.trim(),
      'bankName':      _bankNameCtrl.text.trim(),
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
              'Where should we send your payments?',
              style: TextStyle(color: AppColors.grey, fontSize: 14),
            ).animate().fadeIn(),
            const SizedBox(height: 28),

            // Secure badge
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lock_rounded, color: AppColors.grey, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your bank details are encrypted and securely stored.',
                      style: TextStyle(color: AppColors.grey, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 50.ms),
            const SizedBox(height: 20),

            AppTextField(
              hint: 'Account holder name',
              label: 'ACCOUNT HOLDER NAME',
              controller: _holderCtrl,
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
            ).animate().fadeIn(delay: 100.ms),
            const SizedBox(height: 16),
            AppTextField(
              hint: 'Bank name',
              label: 'BANK NAME',
              controller: _bankNameCtrl,
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
            ).animate().fadeIn(delay: 140.ms),
            const SizedBox(height: 16),
            AppTextField(
              hint: 'Account number',
              label: 'ACCOUNT NUMBER',
              controller: _accountCtrl,
              keyboardType: TextInputType.number,
              validator: (v) => (v == null || v.length < 9) ? 'Invalid account number' : null,
            ).animate().fadeIn(delay: 180.ms),
            const SizedBox(height: 16),
            AppTextField(
              hint: 'SBIN0001234',
              label: 'IFSC CODE',
              controller: _ifscCtrl,
              validator: (v) => (v == null || v.length != 11) ? 'Invalid IFSC' : null,
            ).animate().fadeIn(delay: 220.ms),
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
            ).animate().fadeIn(delay: 260.ms),
          ],
        ),
      ),
    );
  }
}
