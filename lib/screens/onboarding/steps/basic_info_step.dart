import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../providers/onboarding_provider.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/haptic_utils.dart';

class BasicInfoStep extends ConsumerStatefulWidget {
  const BasicInfoStep({super.key});

  @override
  ConsumerState<BasicInfoStep> createState() => _BasicInfoStepState();
}

class _BasicInfoStepState extends ConsumerState<BasicInfoStep> {
  final _nameCtrl        = TextEditingController();
  final _emailCtrl       = TextEditingController();
  final _phoneCtrl       = TextEditingController();
  final _displayNameCtrl = TextEditingController();
  final _formKey         = GlobalKey<FormState>();
  bool _initialized      = false;

  // Snapshot of server values for dirty checking
  late Map<String, String> _original;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      final fd = ref.read(onboardingPod).formData;
      _nameCtrl.text        = (fd['name']        as String?) ?? '';
      _emailCtrl.text       = (fd['email']       as String?) ?? '';
      _phoneCtrl.text       = (fd['phone']       as String?) ?? '';
      _displayNameCtrl.text = (fd['displayName'] as String?) ?? '';
      _original = {
        'name':        _nameCtrl.text,
        'email':       _emailCtrl.text,
        'phone':       _phoneCtrl.text,
        'displayName': _displayNameCtrl.text,
      };
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _displayNameCtrl.dispose();
    super.dispose();
  }

  bool get _isDirty {
    final notifier = ref.read(onboardingPod);
    return _nameCtrl.text.trim()        != _original['name']        ||
           _emailCtrl.text.trim()       != _original['email']       ||
           _phoneCtrl.text.trim()       != _original['phone']       ||
           _displayNameCtrl.text.trim() != _original['displayName'] ||
           notifier.profileImagePath    != null                      ||
           notifier.mediaFilePaths.isNotEmpty;
  }

  Future<void> _pickProfileImage() async {
    HapticUtils.light();
    final source = await _imageSourceSheet();
    if (source == null) return;
    final picked = await ImagePicker().pickImage(source: source, imageQuality: 80);
    if (picked != null) ref.read(onboardingPod.notifier).setProfileImage(picked.path);
  }

  Future<ImageSource?> _imageSourceSheet() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('Profile Photo',
                  style: TextStyle(color: AppColors.white, fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: AppColors.white),
              title: const Text('Camera', style: TextStyle(color: AppColors.white)),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: AppColors.white),
              title: const Text('Gallery', style: TextStyle(color: AppColors.white)),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _pickMedia() async {
    HapticUtils.light();
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: [
        'jpg', 'jpeg', 'png', 'webp',
        'mp4', 'mov', 'avi', 'mkv',
        'mp3', 'wav', 'aac', 'm4a',
      ],
    );
    if (result == null) return;
    for (final f in result.files) {
      if (f.path != null) ref.read(onboardingPod.notifier).addMediaFile(f.path!);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_isDirty) {
      // Nothing changed — skip API, just advance.
      ref.read(onboardingPod.notifier).nextStep();
      return;
    }

    await ref.read(onboardingPod.notifier).submitBasicInfo({
      'name':        _nameCtrl.text.trim(),
      'email':       _emailCtrl.text.trim(),
      'phone':       _phoneCtrl.text.trim(),
      'displayName': _displayNameCtrl.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final state          = ref.watch(onboardingPod);
    final localImage     = state.profileImagePath;
    final remoteImageUrl = state.formData['profileImageUrl'] as String?;
    final mediaPaths     = state.mediaFilePaths;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tell us about yourself',
                style: TextStyle(color: AppColors.grey, fontSize: 14)).animate().fadeIn(),

            const SizedBox(height: 28),

            // ── Profile image ──────────────────────────────────────────────
            Center(
              child: GestureDetector(
                onTap: _pickProfileImage,
                child: Stack(
                  children: [
                    Container(
                      width: 90, height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.surface2,
                        border: Border.all(color: AppColors.border, width: 2),
                      ),
                      child: ClipOval(
                        child: localImage != null
                            ? Image.file(File(localImage), fit: BoxFit.cover)
                            : remoteImageUrl != null
                                ? Image.network(remoteImageUrl, fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const _AvatarPlaceholder())
                                : const _AvatarPlaceholder(),
                      ),
                    ),
                    Positioned(
                      right: 0, bottom: 0,
                      child: Container(
                        width: 28, height: 28,
                        decoration: BoxDecoration(
                          color: AppColors.white, shape: BoxShape.circle,
                          border: Border.all(color: AppColors.bg, width: 2),
                        ),
                        child: const Icon(Icons.camera_alt_rounded, color: AppColors.bg, size: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ).animate().fadeIn(delay: 60.ms),

            const SizedBox(height: 8),
            const Center(
              child: Text('Tap to add profile photo',
                  style: TextStyle(color: AppColors.grey, fontSize: 12)),
            ),

            const SizedBox(height: 28),

            // ── Fields ────────────────────────────────────────────────────
            AppTextField(
              hint: 'Your full name', label: 'FULL NAME',
              controller: _nameCtrl,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
            ).animate().fadeIn(delay: 100.ms),
            const SizedBox(height: 16),

            AppTextField(
              hint: 'Display name (optional)', label: 'DISPLAY NAME',
              controller: _displayNameCtrl,
            ).animate().fadeIn(delay: 130.ms),
            const SizedBox(height: 16),

            AppTextField(
              hint: 'you@example.com', label: 'EMAIL ADDRESS',
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Email is required';
                if (!v.contains('@')) return 'Enter a valid email';
                return null;
              },
            ).animate().fadeIn(delay: 160.ms),
            const SizedBox(height: 16),

            AppTextField(
              hint: '9876543210', label: 'PHONE NUMBER',
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              prefix: '+91 ', maxLength: 10,
              validator: (v) {
                if (v == null || v.isEmpty) return null;
                if (v.length != 10) return 'Enter valid 10-digit number';
                return null;
              },
            ).animate().fadeIn(delay: 190.ms),

            const SizedBox(height: 28),

            // ── Shop media upload ──────────────────────────────────────────
            Row(
              children: [
                const Text('SHOP MEDIA',
                    style: TextStyle(color: AppColors.grey, fontSize: 13, fontWeight: FontWeight.w500)),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.surface2,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Text('optional',
                      style: TextStyle(color: AppColors.grey, fontSize: 10)),
                ),
              ],
            ).animate().fadeIn(delay: 210.ms),
            const SizedBox(height: 4),
            const Text(
              'Add photos, videos or audio to showcase your shop',
              style: TextStyle(color: AppColors.greyDark, fontSize: 12),
            ).animate().fadeIn(delay: 220.ms),
            const SizedBox(height: 12),

            SizedBox(
              height: 88,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  // Add button
                  GestureDetector(
                    onTap: _pickMedia,
                    child: Container(
                      width: 80, height: 80,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border, style: BorderStyle.solid),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_rounded, color: AppColors.grey, size: 24),
                          SizedBox(height: 4),
                          Text('Add', style: TextStyle(color: AppColors.grey, fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
                  // Picked media items
                  ...mediaPaths.asMap().entries.map((e) =>
                      _MediaTile(
                        path: e.value,
                        onRemove: () => ref.read(onboardingPod.notifier).removeMediaFile(e.key),
                      ),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 230.ms),

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

// ── Helpers ──────────────────────────────────────────────────────────────────

class _AvatarPlaceholder extends StatelessWidget {
  const _AvatarPlaceholder();
  @override
  Widget build(BuildContext context) =>
      const Center(child: Icon(Icons.person_rounded, color: AppColors.grey, size: 40));
}

class _MediaTile extends StatelessWidget {
  final String path;
  final VoidCallback onRemove;
  const _MediaTile({required this.path, required this.onRemove});

  static const _imageExts = {'jpg', 'jpeg', 'png', 'webp', 'gif'};
  static const _videoExts = {'mp4', 'mov', 'avi', 'mkv', 'm4v'};

  String get _ext => path.split('.').last.toLowerCase();
  bool get _isImage => _imageExts.contains(_ext);
  bool get _isVideo => _videoExts.contains(_ext);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: 80, height: 80,
          margin: const EdgeInsets.only(right: 10),
          decoration: BoxDecoration(
            color: AppColors.surface2,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: _isImage
                ? Image.file(File(path), fit: BoxFit.cover)
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _isVideo ? Icons.videocam_rounded : Icons.audiotrack_rounded,
                        color: AppColors.grey, size: 26,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _ext.toUpperCase(),
                        style: const TextStyle(color: AppColors.greyDark, fontSize: 10),
                      ),
                    ],
                  ),
          ),
        ),
        Positioned(
          right: 14, top: 4,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 20, height: 20,
              decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
              child: const Icon(Icons.close_rounded, color: Colors.white, size: 12),
            ),
          ),
        ),
      ],
    );
  }
}
