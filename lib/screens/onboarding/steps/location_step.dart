import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/theme/app_theme.dart';
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
  final _addressCtrl = TextEditingController();
  final _cityCtrl    = TextEditingController();
  final _stateCtrl   = TextEditingController();
  final _pincodeCtrl = TextEditingController();
  final _formKey     = GlobalKey<FormState>();
  bool _initialized  = false;
  late Map<String, String> _original;

  double? _latitude;
  double? _longitude;
  _GpsStatus _gpsStatus = _GpsStatus.idle;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      final fd = ref.read(onboardingPod).formData;
      _addressCtrl.text = (fd['address'] as String?) ?? '';
      _cityCtrl.text    = (fd['city']    as String?) ?? '';
      _stateCtrl.text   = (fd['state']   as String?) ?? '';
      _pincodeCtrl.text = (fd['pincode'] as String?) ?? '';
      _original = {
        'address': _addressCtrl.text,
        'city':    _cityCtrl.text,
        'state':   _stateCtrl.text,
        'pincode': _pincodeCtrl.text,
      };
      // Auto-detect location on step load
      _detectLocation();
    }
  }

  bool get _isDirty =>
      _addressCtrl.text.trim() != _original['address'] ||
      _cityCtrl.text.trim()    != _original['city']    ||
      _stateCtrl.text.trim()   != _original['state']   ||
      _pincodeCtrl.text.trim() != _original['pincode'];

  @override
  void dispose() {
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _pincodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _detectLocation() async {
    setState(() => _gpsStatus = _GpsStatus.detecting);
    try {
      final position = await _acquirePosition();
      if (position != null) {
        setState(() {
          _latitude  = position.latitude;
          _longitude = position.longitude;
          _gpsStatus = _GpsStatus.found;
        });
      } else {
        setState(() => _gpsStatus = _GpsStatus.denied);
      }
    } catch (_) {
      setState(() => _gpsStatus = _GpsStatus.error);
    }
  }

  Future<Position?> _acquirePosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }
    if (permission == LocationPermission.deniedForever) return null;

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );
    } catch (_) {
      return Geolocator.getLastKnownPosition();
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_isDirty) {
      ref.read(onboardingPod.notifier).nextStep();
      return;
    }
    await ref.read(onboardingPod.notifier).submitLocation({
      'address':   _addressCtrl.text.trim(),
      'city':      _cityCtrl.text.trim(),
      'state':     _stateCtrl.text.trim(),
      'pincode':   _pincodeCtrl.text.trim(),
      'latitude':  _latitude,
      'longitude': _longitude,
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingPod);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.sp24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Where is your business located?',
              style: TextStyle(color: AppColors.grey, fontSize: 14),
            ).animate().fadeIn(),
            const SizedBox(height: AppTheme.sp20),

            // ── GPS status card ──────────────────────────────────────────────
            _GpsStatusCard(
              status: _gpsStatus,
              latitude: _latitude,
              longitude: _longitude,
              onRetry: _detectLocation,
            ).animate().fadeIn(delay: 60.ms),
            const SizedBox(height: AppTheme.sp20),

            // ── Address fields ───────────────────────────────────────────────
            AppTextField(
              hint: 'Street, Area, Landmark',
              label: 'ADDRESS',
              controller: _addressCtrl,
              maxLines: 2,
              validator: (v) => (v == null || v.isEmpty) ? 'Address is required' : null,
            ).animate().fadeIn(delay: 100.ms),
            const SizedBox(height: AppTheme.sp16),
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
                const SizedBox(width: AppTheme.sp12),
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
            ).animate().fadeIn(delay: 140.ms),
            const SizedBox(height: AppTheme.sp16),
            AppTextField(
              hint: 'State',
              label: 'STATE',
              controller: _stateCtrl,
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
            ).animate().fadeIn(delay: 170.ms),

            if (state.error != null) ...[
              const SizedBox(height: AppTheme.sp16),
              Text(state.error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
            ],

            const SizedBox(height: AppTheme.sp40),
            AppButton(
              label: 'Continue',
              onTap: _submit,
              isLoading: state.isLoading,
              icon: Icons.arrow_forward_rounded,
            ).animate().fadeIn(delay: 210.ms),
          ],
        ),
      ),
    );
  }
}

// ── GPS status display ────────────────────────────────────────────────────────

enum _GpsStatus { idle, detecting, found, denied, error }

class _GpsStatusCard extends StatelessWidget {
  final _GpsStatus status;
  final double? latitude;
  final double? longitude;
  final VoidCallback onRetry;

  const _GpsStatusCard({
    required this.status,
    this.latitude,
    this.longitude,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.sp16,
        vertical: AppTheme.sp12,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppTheme.r12),
        border: Border.all(
          color: status == _GpsStatus.found ? AppColors.success.withOpacity(0.5) : AppColors.border,
        ),
      ),
      child: switch (status) {
        _GpsStatus.detecting => const Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white),
              ),
              SizedBox(width: AppTheme.sp10),
              Text('Detecting your location...', style: TextStyle(color: AppColors.grey, fontSize: 13)),
            ],
          ),
        _GpsStatus.found => Row(
            children: [
              const Icon(Icons.gps_fixed_rounded, color: AppColors.success, size: 18),
              const SizedBox(width: AppTheme.sp10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('GPS location captured',
                        style: TextStyle(color: AppColors.success, fontSize: 13, fontWeight: FontWeight.w600)),
                    Text(
                      '${latitude?.toStringAsFixed(5)}, ${longitude?.toStringAsFixed(5)}',
                      style: const TextStyle(color: AppColors.grey, fontSize: 11, fontFamily: 'monospace'),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onRetry,
                child: const Icon(Icons.refresh_rounded, color: AppColors.grey, size: 16),
              ),
            ],
          ),
        _GpsStatus.denied => Row(
            children: [
              const Icon(Icons.location_off_rounded, color: AppColors.warning, size: 18),
              const SizedBox(width: AppTheme.sp10),
              const Expanded(
                child: Text(
                  'Location permission denied. Coordinates won\'t be saved.',
                  style: TextStyle(color: AppColors.grey, fontSize: 12),
                ),
              ),
              GestureDetector(
                onTap: onRetry,
                child: const Text('Grant',
                    style: TextStyle(
                      color: AppColors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    )),
              ),
            ],
          ),
        _GpsStatus.error => Row(
            children: [
              const Icon(Icons.location_off_rounded, color: AppColors.grey, size: 18),
              const SizedBox(width: AppTheme.sp10),
              const Expanded(
                child: Text('Could not get location. Address saved without GPS coordinates.',
                    style: TextStyle(color: AppColors.grey, fontSize: 12)),
              ),
              GestureDetector(
                onTap: onRetry,
                child: const Text('Retry',
                    style: TextStyle(color: AppColors.white, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        _GpsStatus.idle => const Row(
            children: [
              Icon(Icons.location_searching_rounded, color: AppColors.grey, size: 18),
              SizedBox(width: AppTheme.sp10),
              Text('Tap to detect GPS location', style: TextStyle(color: AppColors.grey, fontSize: 13)),
            ],
          ),
      },
    );
  }
}
