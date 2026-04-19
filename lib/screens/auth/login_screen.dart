import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_text_field.dart';
import '../../providers/auth_provider.dart';
import '../../utils/app_colors.dart';
import '../../utils/haptic_utils.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _phoneController = TextEditingController();
  late AnimationController _floatController;
  late Animation<double> _floatAnimation;

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _floatAnimation = Tween<double>(begin: -8, end: 8).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  Future<void> _handleContinue() async {
    final phone = _phoneController.text.trim();
    if (phone.length < 10) {
      HapticUtils.heavy();
      _showError('Please enter a valid 10-digit phone number');
      return;
    }
    final success = await ref.read(authPod.notifier).sendOtp(phone);
    if (success && mounted) {
      HapticUtils.success();
      Navigator.pushNamed(context, '/verify', arguments: phone);
    } else if (mounted) {
      HapticUtils.heavy();
      final error = ref.read(authPod).error;
      _showError(error ?? 'Failed to send OTP');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: AppColors.white)),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authPod);
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),

              // 3D floating logo mark
              AnimatedBuilder(
                animation: _floatAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, _floatAnimation.value),
                    child: child,
                  );
                },
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.white.withOpacity(0.25),
                        blurRadius: 30,
                        spreadRadius: 4,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.storefront_rounded,
                    color: AppColors.bg,
                    size: 36,
                  ),
                ),
              ),

              const SizedBox(height: 40),

              Text(
                'Turn Products Into Profits',
                maxLines: 1,
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                  letterSpacing: -0.5,
                ),
              ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.2, end: 0),

              const SizedBox(height: 10),

              Text(
                'Enter your phone number to access your seller dashboard',
                style: const TextStyle(
                  color: AppColors.grey,
                  fontSize: 15,
                  height: 1.5,
                ),
              ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, end: 0),

              const SizedBox(height: 48),

              AppTextField(
                hint: 'Phone Number',
                label: 'MOBILE NUMBER',
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                maxLength: 10,
                prefix: '+91  ',
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2, end: 0),

              const SizedBox(height: 28),

              AppButton(
                label: 'Continue',
                onTap: _handleContinue,
                isLoading: auth.isLoading,
                icon: Icons.arrow_forward_rounded,
              ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2, end: 0),

              const SizedBox(height: 24),

              Center(
                child: Text(
                  'By continuing, you confirm that you are above\n18 years of age and agree to our Terms of Service',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.greyDark,
                    fontSize: 12,
                    height: 1.6,
                  ),
                ),
              ).animate().fadeIn(delay: 500.ms),

              const SizedBox(height: 60),

              // Feature badges
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _featureBadge(Icons.verified_rounded, 'Verified'),
                  const SizedBox(width: 16),
                  _featureBadge(Icons.lock_rounded, 'Secure'),
                  const SizedBox(width: 16),
                  _featureBadge(Icons.flash_on_rounded, 'Fast'),
                ],
              ).animate().fadeIn(delay: 600.ms),
            ],
          ),
        ),
      ),
    );
  }

  Widget _featureBadge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.grey),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: AppColors.grey, fontSize: 12)),
        ],
      ),
    );
  }
}
