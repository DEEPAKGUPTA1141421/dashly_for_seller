import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/widgets/app_button.dart';
import '../../providers/auth_provider.dart';
import '../../utils/app_colors.dart';
import '../../utils/haptic_utils.dart';

class VerifyOtpScreen extends ConsumerStatefulWidget {
  const VerifyOtpScreen({super.key});

  @override
  ConsumerState<VerifyOtpScreen> createState() => _VerifyOtpScreenState();
}

class _VerifyOtpScreenState extends ConsumerState<VerifyOtpScreen>
    with TickerProviderStateMixin {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;
  int _resendSeconds = 30;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );
    _startResendTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_focusNodes[0]);
    });
  }

  void _startResendTimer() {
    setState(() => _resendSeconds = 30);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_resendSeconds == 0) {
        t.cancel();
      } else {
        setState(() => _resendSeconds--);
      }
    });
  }

  @override
  void dispose() {
    for (final c in _controllers) { c.dispose(); }
    for (final f in _focusNodes) { f.dispose(); }
    _shakeController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  String get _otp => _controllers.map((c) => c.text).join();

  void _onOtpChanged(int index, String value) {
    HapticUtils.light();
    if (value.isNotEmpty && index < 5) {
      FocusScope.of(context).requestFocus(_focusNodes[index + 1]);
    } else if (value.isEmpty && index > 0) {
      FocusScope.of(context).requestFocus(_focusNodes[index - 1]);
    }
    if (_otp.length == 6) _handleVerify();
  }

  Future<void> _handleVerify() async {
    final phone = ModalRoute.of(context)!.settings.arguments as String? ?? '';
    final success = await ref.read(authPod.notifier).verifyOtp(phone, _otp);
    if (success && mounted) {
      HapticUtils.success();
      final isSignup = ref.read(authPod).isSignup;
      Navigator.pushNamedAndRemoveUntil(
        context,
        isSignup ? '/location-setup' : '/home',
        (_) => false,
      );
    } else if (mounted) {
      HapticUtils.heavy();
      _shakeController.forward(from: 0);
      for (final c in _controllers) { c.clear(); }
      FocusScope.of(context).requestFocus(_focusNodes[0]);
    }
  }

  Future<void> _handleResend() async {
    final phone = ModalRoute.of(context)!.settings.arguments as String? ?? '';
    final success = await ref.read(authPod.notifier).sendOtp(phone);
    if (success) {
      HapticUtils.success();
      _startResendTimer();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth  = ref.watch(authPod);
    final phone = ModalRoute.of(context)!.settings.arguments as String? ?? '';

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.divider),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),

              const Text(
                'Verify OTP',
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ).animate().fadeIn(delay: 50.ms).slideY(begin: 0.2, end: 0),

              const SizedBox(height: 8),

              Text(
                'We sent a 6-digit code to +91 $phone',
                style: const TextStyle(color: AppColors.grey, fontSize: 14),
              ).animate().fadeIn(delay: 100.ms),

              const SizedBox(height: 48),

              // OTP boxes with shake animation on error
              AnimatedBuilder(
                animation: _shakeAnimation,
                builder: (context, child) {
                  final shake = _shakeController.isAnimating
                      ? ((_shakeAnimation.value * 8) % 2 - 1) * 8
                      : 0.0;
                  return Transform.translate(
                    offset: Offset(shake, 0),
                    child: child,
                  );
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(6, (i) => _buildOtpBox(i)),
                ),
              ).animate().fadeIn(delay: 200.ms),

              if (auth.error != null) ...[
                const SizedBox(height: 16),
                Text(
                  auth.error!,
                  style: const TextStyle(color: AppColors.error, fontSize: 13),
                ).animate().fadeIn(),
              ],

              const SizedBox(height: 40),

              AppButton(
                label: 'Verify',
                onTap: _otp.length == 6 ? _handleVerify : null,
                isLoading: auth.isLoading,
              ).animate().fadeIn(delay: 300.ms),

              const SizedBox(height: 28),

              Center(
                child: _resendSeconds > 0
                    ? Text(
                        'Resend OTP in ${_resendSeconds}s',
                        style: const TextStyle(color: AppColors.grey, fontSize: 13),
                      )
                    : GestureDetector(
                        onTap: _handleResend,
                        child: const Text(
                          'Resend OTP',
                          style: TextStyle(
                            color: AppColors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                            decorationColor: AppColors.white,
                          ),
                        ),
                      ),
              ).animate().fadeIn(delay: 400.ms),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOtpBox(int index) {
    return SizedBox(
      width: 48,
      height: 56,
      child: TextField(
        controller: _controllers[index],
        focusNode:  _focusNodes[index],
        keyboardType:  TextInputType.number,
        textAlign:     TextAlign.center,
        maxLength:     1,
        style: const TextStyle(
          color: AppColors.white,
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
        decoration: InputDecoration(
          counterText: '',
          filled:      true,
          fillColor:   AppColors.surface,
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.white, width: 2),
          ),
        ),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: (v) => _onOtpChanged(index, v),
      ),
    );
  }
}
