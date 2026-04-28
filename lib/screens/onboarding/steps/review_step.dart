import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/app_button.dart';
import '../../../providers/onboarding_provider.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/haptic_utils.dart';
import '../../../utils/storage_service.dart';

class ReviewStep extends ConsumerWidget {
  const ReviewStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingPod);
    final data  = state.formData;

    Future<void> goToHome() async {
      await StorageService.saveOnboardingComplete(true);
      HapticUtils.success();
      if (!context.mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Review your information',
            style: TextStyle(color: AppColors.grey, fontSize: 14),
          ).animate().fadeIn(),
          const SizedBox(height: 24),

          // Success card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.success.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_rounded, color: Colors.white, size: 32),
                )
                    .animate()
                    .scale(begin: const Offset(0, 0), end: const Offset(1, 1), duration: 600.ms, curve: Curves.elasticOut),
                const SizedBox(height: 16),
                const Text(
                  'All Set!',
                  style: TextStyle(color: AppColors.white, fontSize: 22, fontWeight: FontWeight.w700),
                ).animate().fadeIn(delay: 300.ms),
                const SizedBox(height: 8),
                const Text(
                  'Your seller account is being reviewed.\nYou can start exploring the dashboard.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.grey, fontSize: 13, height: 1.5),
                ).animate().fadeIn(delay: 400.ms),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Summary tiles
          _ReviewTile(label: 'Name',         value: data['name']          ?? '-'),
          _ReviewTile(label: 'Email',        value: data['email']         ?? '-'),
          _ReviewTile(label: 'Business',     value: data['businessName']  ?? '-'),
          _ReviewTile(label: 'Type',         value: data['businessType']  ?? '-'),
          _ReviewTile(label: 'City',         value: data['city']          ?? '-'),
          _ReviewTile(label: 'Bank',         value: data['bankName']      ?? '-'),

          const SizedBox(height: 40),

          AppButton(
            label: 'Go to Dashboard',
            onTap: goToHome,
            icon: Icons.dashboard_rounded,
          ).animate().fadeIn(delay: 500.ms),
        ],
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  final String label;
  final String value;

  const _ReviewTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: const TextStyle(color: AppColors.grey, fontSize: 13)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: AppColors.white, fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideX(begin: 0.05, end: 0);
  }
}
