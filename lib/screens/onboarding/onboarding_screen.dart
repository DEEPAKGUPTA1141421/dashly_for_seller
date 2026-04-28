import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/onboarding_provider.dart';
import '../../utils/app_colors.dart';
import '../../utils/storage_service.dart';
import 'steps/basic_info_step.dart';
import 'steps/business_step.dart';
import 'steps/location_step.dart';
import 'steps/bank_step.dart';
import 'steps/aadhar_step.dart';
import 'steps/review_step.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(onboardingPod.notifier).checkOnboardingStatus());
  }

  static const List<String> _stepTitles = [
    'Basic Info',
    'Business',
    'Location',
    'Bank Account',
    'Aadhaar',
    'Review',
  ];

  static const List<IconData> _stepIcons = [
    Icons.person_rounded,
    Icons.business_rounded,
    Icons.location_on_rounded,
    Icons.account_balance_rounded,
    Icons.fingerprint_rounded,
    Icons.check_circle_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    // If the settings check finds onboarding already complete, skip to home.
    ref.listen(onboardingPod.select((s) => s.isComplete), (_, complete) {
      if (complete && mounted) {
        StorageService.saveOnboardingComplete(true); // fire-and-forget; navigation is instant
        Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
      }
    });

    final state = ref.watch(onboardingPod);
    final step  = state.currentStep;

    final steps = <Widget>[
      const BasicInfoStep(),
      const BusinessStep(),
      const LocationStep(),
      const BankStep(),
      const AadharStep(),
      const ReviewStep(),
    ];

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          'Step ${step + 1} of ${_stepTitles.length}',
                          style: const TextStyle(color: AppColors.grey, fontSize: 12),
                        ),
                      ),
                      const Spacer(),
                      // Skip button (only for non-mandatory steps)
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Step indicator
                  _StepProgressBar(current: step, total: _stepTitles.length),
                  const SizedBox(height: 20),

                  // Step title
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(_stepIcons[step], color: AppColors.bg, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _stepTitles[step],
                        style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),
            const Divider(color: AppColors.border, height: 1),

            // Step content
            Expanded(
              child: state.isLoadingSettings
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                            color: AppColors.white,
                            strokeWidth: 2,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Loading your profile...',
                            style: TextStyle(color: AppColors.grey, fontSize: 13),
                          ),
                        ],
                      ),
                    ).animate().fadeIn()
                  : AnimatedSwitcher(
                      duration: const Duration(milliseconds: 350),
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0.05, 0),
                            end: Offset.zero,
                          ).animate(anim),
                          child: child,
                        ),
                      ),
                      child: KeyedSubtree(
                        key: ValueKey(step),
                        child: steps[step],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepProgressBar extends StatelessWidget {
  final int current;
  final int total;

  const _StepProgressBar({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (i) {
        final isActive   = i <= current;
        final isCurrent  = i == current;
        return Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 2),
            height: isCurrent ? 4 : 3,
            decoration: BoxDecoration(
              color: isActive ? AppColors.white : AppColors.surface2,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        );
      }),
    );
  }
}
