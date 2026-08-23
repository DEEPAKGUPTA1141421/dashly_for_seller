import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../utils/app_colors.dart';
import '../../utils/haptic_utils.dart';

class LocationSetupScreen extends ConsumerStatefulWidget {
  const LocationSetupScreen({super.key});
  @override
  ConsumerState<LocationSetupScreen> createState() =>
      _LocationSetupScreenState();
}

class _LocationSetupScreenState extends ConsumerState<LocationSetupScreen>
    with TickerProviderStateMixin {
  // 0 = permission  1 = fetching  2 = result
  int _phase = 0;

  String? _error;
  Map<String, dynamic> _address = {};

  late final AnimationController _pulseCtrl;
  late final AnimationController _successCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
    _successCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _successCtrl.dispose();
    super.dispose();
  }

  Future<void> _requestLocation() async {
    HapticUtils.medium();
    setState(() { _phase = 1; _error = null; });

    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        setState(() {
          _phase = 0;
          _error = 'Location permission denied. Please enable it in settings.';
        });
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      final res = await ApiClient.instance.client.post(
        ApiEndpoints.sellerProductUpdateAddress,
        data: {
          'latitude':            pos.latitude,
          'longitude':           pos.longitude,
          'stage_of_onboarding': 'LOCATION',
        },
      );

      final body = res.data as Map<String, dynamic>;
      final data = (body['data'] as Map<String, dynamic>?) ?? {};

      _address = data;
      setState(() => _phase = 2);
      HapticUtils.success();
      _successCtrl.forward();

      // Auto-navigate to home after showing the result
      await Future.delayed(const Duration(milliseconds: 2800));
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
      }
    } catch (_) {
      setState(() {
        _phase = 0;
        _error = 'Could not get location. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 450),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.06),
                end: Offset.zero,
              ).animate(anim),
              child: child,
            ),
          ),
          child: _phase == 2
              ? _ResultView(
                  key: const ValueKey('result'),
                  ctrl: _successCtrl,
                  address: _address,
                  onContinue: () => Navigator.pushNamedAndRemoveUntil(
                      context, '/home', (_) => false),
                )
              : _PermissionView(
                  key: const ValueKey('perm'),
                  pulseCtrl: _pulseCtrl,
                  isFetching: _phase == 1,
                  error: _error,
                  onAllow: _requestLocation,
                  onSkip: () => Navigator.pushNamedAndRemoveUntil(
                      context, '/home', (_) => false),
                ),
        ),
      ),
    );
  }
}

// ── Permission / Fetching view ────────────────────────────────────────────────

class _PermissionView extends StatelessWidget {
  final AnimationController pulseCtrl;
  final bool isFetching;
  final String? error;
  final VoidCallback onAllow;
  final VoidCallback onSkip;

  const _PermissionView({
    super.key,
    required this.pulseCtrl,
    required this.isFetching,
    required this.error,
    required this.onAllow,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          const Spacer(flex: 2),

          _PulsingPin(ctrl: pulseCtrl, fetching: isFetching),

          const SizedBox(height: 44),

          Text(
            isFetching ? 'Locating Your Shop...' : 'Find Your Shop',
            style: const TextStyle(
              color: AppColors.white,
              fontSize: 30,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 80.ms).slideY(begin: 0.15, end: 0),

          const SizedBox(height: 14),

          Text(
            isFetching
                ? "Fetching your address from the server..."
                : "Allow location access and we'll set up your shop address instantly.",
            style: const TextStyle(
              color: AppColors.grey,
              fontSize: 15,
              height: 1.55,
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 160.ms),

          if (error != null) ...[
            const SizedBox(height: 20),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: AppColors.error.withOpacity(0.28)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded,
                      color: AppColors.error, size: 16),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(error!,
                        style: const TextStyle(
                            color: AppColors.error,
                            fontSize: 12,
                            height: 1.4)),
                  ),
                ],
              ),
            ).animate().fadeIn().shakeX(hz: 3, amount: 2),
          ],

          const Spacer(flex: 3),

          if (isFetching)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (i) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 5),
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                      color: AppColors.grey, shape: BoxShape.circle),
                )
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .scaleXY(
                      begin: 0.5,
                      end: 1.0,
                      delay: Duration(milliseconds: i * 180),
                      duration: 500.ms,
                      curve: Curves.easeInOut,
                    );
              }),
            )
          else ...[
            GestureDetector(
              onTap: onAllow,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 17),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.white.withOpacity(0.18),
                      blurRadius: 28,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.my_location_rounded,
                        color: AppColors.bg, size: 20),
                    SizedBox(width: 10),
                    Text(
                      'Use My Current Location',
                      style: TextStyle(
                        color: AppColors.bg,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ).animate().fadeIn(delay: 260.ms).slideY(begin: 0.2, end: 0),

            const SizedBox(height: 18),

            GestureDetector(
              onTap: onSkip,
              child: const Text(
                'Skip for now',
                style: TextStyle(
                  color: AppColors.grey,
                  fontSize: 13,
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.grey,
                ),
              ),
            ).animate().fadeIn(delay: 320.ms),
          ],

          const SizedBox(height: 36),
        ],
      ),
    );
  }
}

// ── Result view ───────────────────────────────────────────────────────────────

class _ResultView extends StatelessWidget {
  final AnimationController ctrl;
  final Map<String, dynamic> address;
  final VoidCallback onContinue;

  const _ResultView({
    super.key,
    required this.ctrl,
    required this.address,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final line1   = address['line1']   as String? ?? '';
    final city    = address['city']    as String? ?? '';
    final state   = address['state']   as String? ?? '';
    final pincode = address['pincode'] as String? ?? '';

    final hasAddress = line1.isNotEmpty || city.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          const Spacer(flex: 2),

          // Success ring + tick
          _SuccessBadge(ctrl: ctrl),

          const SizedBox(height: 36),

          const Text(
            'Shop Located!',
            style: TextStyle(
              color: AppColors.white,
              fontSize: 30,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
            ),
          )
              .animate()
              .fadeIn(delay: 200.ms)
              .slideY(begin: 0.2, end: 0),

          const SizedBox(height: 10),

          const Text(
            'Your shop address has been saved.',
            style: TextStyle(color: AppColors.grey, fontSize: 15),
          ).animate().fadeIn(delay: 300.ms),

          const SizedBox(height: 36),

          if (hasAddress)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: AppColors.success.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.location_on_rounded,
                            color: AppColors.success, size: 16),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'SHOP ADDRESS',
                        style: TextStyle(
                          color: AppColors.success,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (line1.isNotEmpty)
                    _AddressRow(icon: Icons.home_rounded, text: line1),
                  if (city.isNotEmpty || state.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _AddressRow(
                      icon: Icons.location_city_rounded,
                      text: [city, state]
                          .where((s) => s.isNotEmpty)
                          .join(', '),
                    ),
                  ],
                  if (pincode.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _AddressRow(
                        icon: Icons.pin_rounded, text: pincode),
                  ],
                ],
              ),
            )
                .animate()
                .fadeIn(delay: 400.ms)
                .slideY(begin: 0.15, end: 0, curve: Curves.easeOut),

          const Spacer(flex: 3),

          // Auto-redirect indicator
          const _RedirectingDots(),

          const SizedBox(height: 16),

          GestureDetector(
            onTap: onContinue,
            child: const Text(
              'Continue to Dashboard →',
              style: TextStyle(
                color: AppColors.grey,
                fontSize: 13,
                decoration: TextDecoration.underline,
                decorationColor: AppColors.grey,
              ),
            ),
          ).animate().fadeIn(delay: 600.ms),

          const SizedBox(height: 36),
        ],
      ),
    );
  }
}

// ── Success badge ─────────────────────────────────────────────────────────────

class _SuccessBadge extends StatelessWidget {
  final AnimationController ctrl;
  const _SuccessBadge({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: CurvedAnimation(parent: ctrl, curve: Curves.elasticOut),
      child: Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          color: AppColors.success.withOpacity(0.12),
          shape: BoxShape.circle,
          border: Border.all(
              color: AppColors.success.withOpacity(0.35), width: 2),
          boxShadow: [
            BoxShadow(
              color: AppColors.success.withOpacity(0.25),
              blurRadius: 32,
              spreadRadius: 4,
            ),
          ],
        ),
        child: const Icon(Icons.check_rounded,
            color: AppColors.success, size: 44),
      ),
    );
  }
}

// ── Pulsing pin ───────────────────────────────────────────────────────────────

class _PulsingPin extends StatelessWidget {
  final AnimationController ctrl;
  final bool fetching;
  const _PulsingPin({required this.ctrl, required this.fetching});

  @override
  Widget build(BuildContext context) {
    final color = fetching ? AppColors.info : AppColors.white;
    return SizedBox(
      width: 200,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (int i = 0; i < 3; i++)
            AnimatedBuilder(
              animation: ctrl,
              builder: (_, __) {
                final t = ((ctrl.value + i / 3.0) % 1.0);
                final size = 64.0 + t * 120;
                final opacity = (1 - t) * 0.28;
                return Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: color.withOpacity(opacity), width: 1.8),
                  ),
                );
              },
            ),
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: color.withOpacity(0.38),
                    blurRadius: 28,
                    spreadRadius: 5),
              ],
            ),
            child: Icon(
              fetching ? Icons.gps_fixed_rounded : Icons.location_on_rounded,
              color: fetching ? AppColors.white : AppColors.bg,
              size: 32,
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scaleXY(
                  begin: 1.0,
                  end: 1.06,
                  duration: 1000.ms,
                  curve: Curves.easeInOut),
        ],
      ),
    );
  }
}

// ── Address row ───────────────────────────────────────────────────────────────

class _AddressRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _AddressRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.grey, size: 15),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
                color: AppColors.white, fontSize: 14, height: 1.4),
          ),
        ),
      ],
    );
  }
}

// ── Auto-redirecting dots ─────────────────────────────────────────────────────

class _RedirectingDots extends StatelessWidget {
  const _RedirectingDots();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('Redirecting to dashboard',
            style: TextStyle(color: AppColors.greyDark, fontSize: 12)),
        const SizedBox(width: 6),
        ...List.generate(
          3,
          (i) => Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            width: 4,
            height: 4,
            decoration: const BoxDecoration(
                color: AppColors.greyDark, shape: BoxShape.circle),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scaleXY(
                begin: 0.4,
                end: 1.0,
                delay: Duration(milliseconds: i * 200),
                duration: 600.ms,
                curve: Curves.easeInOut,
              ),
        ),
      ],
    ).animate().fadeIn(delay: 500.ms);
  }
}
