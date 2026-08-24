import 'dart:convert';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../core/widgets/app_shimmer.dart';
import '../core/widgets/app_toast.dart';
import '../core/widgets/confirm_modal.dart';
import '../core/widgets/fullscreen_image_viewer.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/app_colors.dart';
import '../utils/haptic_utils.dart';

// ─── Tabs ─────────────────────────────────────────────────────────────────────

enum _Tab { personal, business, kyc, bank, notifications }

// ─── Screen ───────────────────────────────────────────────────────────────────

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  _Tab _tab = _Tab.personal;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(settingsPod.notifier).fetchAll());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(settingsPod);

    // Show success / error toasts
    ref.listen(settingsPod, (prev, next) {
      if (next.successMessage != null && next.successMessage != prev?.successMessage) {
        AppToast.show(context, message: next.successMessage!, type: ToastType.success);
        ref.read(settingsPod.notifier).clearMessages();
      }
      if (next.error != null && next.error != prev?.error) {
        AppToast.show(context, message: next.error!, type: ToastType.error);
        ref.read(settingsPod.notifier).clearMessages();
      }
    });

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── App Bar ──────────────────────────────────────────────────
            SliverAppBar(
              pinned: true,
              backgroundColor: AppColors.surface,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              automaticallyImplyLeading: false,
              title: const Text(
                'Settings',
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.3,
                ),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: GestureDetector(
                    onTap: () async {
                      HapticUtils.medium();
                      final confirm = await showConfirmModal(
                        context,
                        title: 'Log Out',
                        message: 'Are you sure you want to log out?',
                        confirmLabel: 'Log Out',
                        destructive: true,
                      );
                      if (confirm) {
                        await ref.read(authPod.notifier).logout();
                        if (context.mounted) {
                          Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
                        }
                      }
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.error.withOpacity(0.3)),
                      ),
                      child: const Icon(Icons.logout_rounded, color: AppColors.error, size: 18),
                    ),
                  ),
                ),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Container(height: 1, color: AppColors.divider),
              ),
            ),

            // ── Tab bar ──────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 4),
                child: SizedBox(
                  height: 38,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: _Tab.values.map((t) {
                      final selected = t == _tab;
                      return GestureDetector(
                        onTap: () { HapticUtils.light(); setState(() => _tab = t); },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: selected ? AppColors.white : AppColors.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: selected ? AppColors.white : AppColors.border),
                          ),
                          child: Text(
                            _tabLabel(t),
                            style: TextStyle(
                              color: selected ? AppColors.bg : AppColors.grey,
                              fontSize: 12,
                              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ).animate().fadeIn(delay: 80.ms),
            ),

            // ── Content ──────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: state.isLoading
                  ? const Padding(
                      padding: EdgeInsets.only(top: 80),
                      child: Center(child: CircularProgressIndicator(color: AppColors.white)),
                    )
                  : Padding(
                      padding: const EdgeInsets.all(20),
                      child: _buildTab(state),
                    ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(SettingsState state) {
    switch (_tab) {
      case _Tab.personal:      return _PersonalTab(data: state.personal);
      case _Tab.business:      return _BusinessTab(data: state.business);
      case _Tab.kyc:           return _KycTab(data: state.kyc);
      case _Tab.bank:          return _BankTab(data: state.bank);
      case _Tab.notifications: return _NotificationsTab(data: state.notifications);
    }
  }

  String _tabLabel(_Tab t) {
    switch (t) {
      case _Tab.personal:      return 'Personal';
      case _Tab.business:      return 'Business';
      case _Tab.kyc:           return 'Documents';
      case _Tab.bank:          return 'Bank';
      case _Tab.notifications: return 'Notifications';
    }
  }

}

// ─── Personal Tab ─────────────────────────────────────────────────────────────

class _PersonalTab extends ConsumerStatefulWidget {
  final Map<String, dynamic> data;
  const _PersonalTab({required this.data});

  @override
  ConsumerState<_PersonalTab> createState() => _PersonalTabState();
}

// (name, bytes, isVideo)
typedef _LocalMedia = ({String name, Uint8List bytes, bool isVideo});

class _PersonalTabState extends ConsumerState<_PersonalTab> {
  final _fullName    = TextEditingController();
  final _displayName = TextEditingController();
  final _email       = TextEditingController();
  final _phone       = TextEditingController();
  final _emailOtp    = TextEditingController();

  Uint8List? _profilePhotoBytes;
  String     _profilePhotoName  = 'profile.jpg';
  List<String>      _existingMediaUrls = [];
  List<_LocalMedia> _newMediaItems     = [];
  bool _initialized  = false;
  bool _emailOtpSent = false;

  @override
  void initState() {
    super.initState();
    if (widget.data.isNotEmpty) _populate();
  }

  @override
  void didUpdateWidget(_PersonalTab old) {
    super.didUpdateWidget(old);
    if (!_initialized && widget.data.isNotEmpty) _populate();
  }

  void _populate() {
    _initialized      = true;
    _fullName.text    = widget.data['fullName']    as String? ?? '';
    _displayName.text = widget.data['displayName'] as String? ?? '';
    _email.text       = widget.data['email']       as String? ?? '';
    _phone.text       = widget.data['phone']       as String? ?? '';
    final raw = widget.data['media_files'];
    if (raw is List) {
      _existingMediaUrls = raw.map((e) => e.toString()).toList();
    } else if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) _existingMediaUrls = decoded.map((e) => e.toString()).toList();
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _fullName.dispose(); _displayName.dispose();
    _email.dispose();    _phone.dispose();
    _emailOtp.dispose();
    super.dispose();
  }

  Future<void> _pickProfilePhoto() async {
    final xfile = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (xfile == null) return;
    final bytes = await xfile.readAsBytes();
    setState(() {
      _profilePhotoBytes = bytes;
      _profilePhotoName  = xfile.name;
    });
  }

  Future<void> _pickMedia() async {
    HapticUtils.light();
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'mp4', 'mov', 'avi'],
      withData: true,
    );
    if (result == null) return;
    final items = result.files
        .where((f) => f.bytes != null)
        .map<_LocalMedia>((f) => (name: f.name, bytes: f.bytes!, isVideo: _isVideo(f.name)))
        .toList();
    if (items.isNotEmpty) setState(() => _newMediaItems.addAll(items));
  }

  Future<void> _save() async {
    HapticUtils.medium();
    await ref.read(settingsPod.notifier).updatePersonalInfo(
      fullName:          _fullName.text.trim(),
      displayName:       _displayName.text.trim(),
      phone:             _phone.text.trim(),
      profilePhotoBytes: _profilePhotoBytes,
      profilePhotoName:  _profilePhotoName,
      mediaFiles: _newMediaItems.map((m) => MapEntry(m.name, m.bytes)).toList(),
    );
    if (mounted) setState(() => _newMediaItems = []);
  }

  bool _isVideo(String name) {
    final ext = name.split('.').last.toLowerCase();
    return ['mp4', 'mov', 'avi', 'mkv'].contains(ext);
  }

  // ── Email OTP flow ──────────────────────────────────────────────────────
  Future<void> _requestEmailOtp() async {
    final email = _email.text.trim();
    if (!email.contains('@') || !email.contains('.')) {
      AppToast.show(context, message: 'Enter a valid email', type: ToastType.error);
      return;
    }
    HapticUtils.medium();
    final ok = await ref.read(settingsPod.notifier).requestEmailUpdate(email);
    if (ok && mounted) setState(() => _emailOtpSent = true);
  }

  Future<void> _verifyEmailOtp() async {
    if (_emailOtp.text.trim().length != 6) {
      AppToast.show(context, message: 'Enter the 6-digit OTP', type: ToastType.error);
      return;
    }
    HapticUtils.medium();
    final ok = await ref.read(settingsPod.notifier).verifyEmailUpdate(_emailOtp.text.trim());
    if (ok && mounted) setState(() { _emailOtpSent = false; _emailOtp.clear(); });
  }

  void _cancelEmailOtp() {
    HapticUtils.light();
    setState(() { _emailOtpSent = false; _emailOtp.clear(); });
  }

  @override
  Widget build(BuildContext context) {
    final saving   = ref.watch(settingsPod).savingSection == 'personal';
    final photoUrl = widget.data['profile_image'] as String?
                  ?? widget.data['profilePhotoUrl'] as String?;
    final totalMedia = _existingMediaUrls.length + _newMediaItems.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Profile photo ─────────────────────────────────────────────────
        Row(
          children: [
            Stack(
              children: [
                GestureDetector(
                  onTap: () {
                    if (_profilePhotoBytes != null) {
                      HapticUtils.light();
                      showFullScreenImage(context, Image.memory(_profilePhotoBytes!, fit: BoxFit.contain));
                    } else if (photoUrl != null) {
                      HapticUtils.light();
                      showFullScreenImage(context, CachedNetworkImage(imageUrl: photoUrl, fit: BoxFit.contain));
                    } else {
                      _pickProfilePhoto();
                    }
                  },
                  child: Container(
                    width: 72, height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.surface2,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.border, width: 2),
                    ),
                    child: ClipOval(
                      child: _profilePhotoBytes != null
                          ? Image.memory(_profilePhotoBytes!, fit: BoxFit.cover)
                          : photoUrl != null
                              ? CachedNetworkImage(imageUrl: photoUrl, fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => const Icon(Icons.person_rounded, color: AppColors.grey, size: 32))
                              : const Icon(Icons.person_rounded, color: AppColors.grey, size: 32),
                    ),
                  ),
                ),
                Positioned(
                  right: 0, bottom: 0,
                  child: GestureDetector(
                    onTap: _pickProfilePhoto,
                    child: Container(
                      width: 24, height: 24,
                      decoration: const BoxDecoration(color: AppColors.white, shape: BoxShape.circle),
                      child: const Icon(Icons.camera_alt_rounded, color: AppColors.bg, size: 14),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Outlet Image', style: TextStyle(color: AppColors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                SizedBox(height: 4),
                Text('JPG or PNG, max 2 MB', style: TextStyle(color: AppColors.grey, fontSize: 12)),
              ],
            ),
          ],
        ).animate().fadeIn(),

        const SizedBox(height: 24),

        // ── Store media ───────────────────────────────────────────────────
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Store Media', style: TextStyle(color: AppColors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                  SizedBox(height: 2),
                  Text('Photos & videos shown on your store', style: TextStyle(color: AppColors.grey, fontSize: 12)),
                ],
              ),
            ),
            GestureDetector(
              onTap: _pickMedia,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded, color: AppColors.white, size: 16),
                    SizedBox(width: 4),
                    Text('Add', style: TextStyle(color: AppColors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ],
        ),

        if (totalMedia > 0) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 90,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                ..._existingMediaUrls.asMap().entries.map((e) {
                  final isVid = _isVideo(e.value);
                  return _MediaThumb(
                    isVideo: isVid,
                    onRemove: () => setState(() => _existingMediaUrls.removeAt(e.key)),
                    onView: isVid
                        ? null
                        : () => showFullScreenImage(
                            context,
                            CachedNetworkImage(imageUrl: e.value, fit: BoxFit.contain)),
                    child: isVid
                        ? const Icon(Icons.videocam_rounded, color: AppColors.grey, size: 28)
                        : CachedNetworkImage(
                            imageUrl: e.value, fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => const Icon(Icons.broken_image_rounded, color: AppColors.grey),
                          ),
                  );
                }),
                ..._newMediaItems.asMap().entries.map((e) {
                  final item = e.value;
                  return _MediaThumb(
                    isVideo: item.isVideo,
                    isNew: true,
                    onRemove: () => setState(() => _newMediaItems.removeAt(e.key)),
                    onView: item.isVideo
                        ? null
                        : () => showFullScreenImage(
                            context,
                            Image.memory(item.bytes, fit: BoxFit.contain)),
                    child: item.isVideo
                        ? const Icon(Icons.videocam_rounded, color: AppColors.grey, size: 28)
                        : Image.memory(item.bytes, fit: BoxFit.cover),
                  );
                }),
              ],
            ),
          ),
        ] else ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: const Center(
              child: Text('No media added yet', style: TextStyle(color: AppColors.greyDark, fontSize: 12)),
            ),
          ),
        ],

        const SizedBox(height: 24),

        _Field(label: 'FULL NAME',    ctrl: _fullName,    hint: 'Enter full name',      icon: Icons.person_outline),
        _Field(label: 'DISPLAY NAME', ctrl: _displayName, hint: 'Store / display name', icon: Icons.storefront_outlined),

        // ── Email (OTP verified) ──────────────────────────────────────────
        _EmailVerificationField(
          emailCtrl:    _email,
          otpCtrl:      _emailOtp,
          emailVerified: widget.data['emailVerified'] as bool? ?? false,
          otpSent:      _emailOtpSent,
          loading:      ref.watch(settingsPod).savingSection == 'email',
          onSendOtp:    _requestEmailOtp,
          onVerify:     _verifyEmailOtp,
          onCancel:     _cancelEmailOtp,
        ),

        _Field(label: 'PHONE', ctrl: _phone, hint: '10-digit number', icon: Icons.phone_outlined, keyboardType: TextInputType.phone, enabled: false),

        const SizedBox(height: 8),

        _SaveButton(label: 'Save Personal Info', onTap: _save, isSaving: saving),
      ],
    );
  }
}

// ─── Email verification field (OTP flow) ───────────────────────────────────

class _EmailVerificationField extends StatelessWidget {
  final TextEditingController emailCtrl;
  final TextEditingController otpCtrl;
  final bool emailVerified;
  final bool otpSent;
  final bool loading;
  final VoidCallback onSendOtp;
  final VoidCallback onVerify;
  final VoidCallback onCancel;

  const _EmailVerificationField({
    required this.emailCtrl,
    required this.otpCtrl,
    required this.emailVerified,
    required this.otpSent,
    required this.loading,
    required this.onSendOtp,
    required this.onVerify,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Field(
            label: 'EMAIL',
            ctrl:  emailCtrl,
            hint:  'you@example.com',
            icon:  Icons.mail_outline,
            keyboardType: TextInputType.emailAddress,
            enabled: !otpSent,
            suffix: emailVerified
                ? const Icon(Icons.check_circle_outline, color: AppColors.success, size: 18)
                : null,
          ),
          if (emailVerified) ...[
            const Padding(
              padding: EdgeInsets.only(top: 4, bottom: 12),
              child: Text('Verified', style: TextStyle(color: AppColors.success, fontSize: 12)),
            ),
          ],

          if (!otpSent)
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: loading ? null : onSendOtp,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: loading ? AppColors.border : AppColors.white, width: 1.5),
                  ),
                  child: Center(
                    child: loading
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: AppColors.grey, strokeWidth: 2))
                        : const Text('Send Verification OTP',
                            style: TextStyle(color: AppColors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            )
          else ...[
            const SizedBox(height: 4),
            _Field(label: 'VERIFICATION CODE', ctrl: otpCtrl, hint: '6-digit OTP', icon: Icons.lock_outline,
                keyboardType: TextInputType.number, maxLength: 6),
            Row(
              children: [
                Expanded(child: _SaveButton(label: 'Verify & Update', onTap: onVerify, isSaving: loading)),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: loading ? null : onCancel,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Text('Cancel', style: TextStyle(color: AppColors.grey, fontSize: 14)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text('OTP sent to ${emailCtrl.text}',
                  style: const TextStyle(color: AppColors.greyDark, fontSize: 11)),
            ),
          ],

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _MediaThumb extends StatelessWidget {
  final Widget child;
  final bool isVideo;
  final bool isNew;
  final VoidCallback onRemove;
  final VoidCallback? onView;

  const _MediaThumb({
    required this.child,
    required this.onRemove,
    this.isVideo = false,
    this.isNew   = false,
    this.onView,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80, height: 80,
      margin: const EdgeInsets.only(right: 8),
      child: Stack(
        children: [
          GestureDetector(
            onTap: onView,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 80, height: 80,
                color: AppColors.surface2,
                child: child,
              ),
            ),
          ),
          if (isVideo)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.play_circle_fill_rounded, color: AppColors.white, size: 28),
              ),
            ),
          if (isNew)
            Positioned(
              top: 4, left: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.info.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('NEW', style: TextStyle(color: AppColors.white, fontSize: 8, fontWeight: FontWeight.w700)),
              ),
            ),
          Positioned(
            top: 4, right: 4,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                width: 20, height: 20,
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.85),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close_rounded, color: AppColors.white, size: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── KYC / Documents Tab ────────────────────────────────────────────────────

class _KycTab extends ConsumerStatefulWidget {
  final Map<String, dynamic> data;
  const _KycTab({required this.data});

  @override
  ConsumerState<_KycTab> createState() => _KycTabState();
}

class _KycTabState extends ConsumerState<_KycTab> {
  final _aadhaarNumber = TextEditingController();
  final _panNumber     = TextEditingController();
  final _gstNumber     = TextEditingController();

  Uint8List? _aadhaarFrontBytes;
  Uint8List? _aadhaarBackBytes;
  Uint8List? _panDocBytes;
  Uint8List? _gstDocBytes;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    if (widget.data.isNotEmpty) _populate();
  }

  @override
  void didUpdateWidget(_KycTab old) {
    super.didUpdateWidget(old);
    if (!_initialized && widget.data.isNotEmpty) _populate();
  }

  void _populate() {
    _initialized = true;
    _gstNumber.text = widget.data['gstNumber'] as String? ?? '';

    // The backend never returns the raw Aadhaar/PAN number — only a masked
    // last-4 form. Once a section is locked for review there's no editable
    // value to restore, so show the masked number instead of a blank field.
    final status = widget.data['status'] as String?;
    final locked = status == 'PENDING' || status == 'APPROVED';
    if (locked) {
      final aadhaarLast4 = widget.data['aadhaarLast4'] as String?;
      final panLast4     = widget.data['panLast4']     as String?;
      if (aadhaarLast4 != null) _aadhaarNumber.text = '•••• •••• ${_KycStatusBanner._last4(aadhaarLast4)}';
      if (panLast4 != null)     _panNumber.text     = '•••••${_KycStatusBanner._last4(panLast4)}';
    }
  }

  @override
  void dispose() {
    _aadhaarNumber.dispose();
    _panNumber.dispose();
    _gstNumber.dispose();
    super.dispose();
  }

  Future<void> _pickDoc(void Function(Uint8List bytes) onPicked) async {
    HapticUtils.light();
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
      withData: true,
    );
    final bytes = result?.files.single.bytes;
    if (bytes != null) setState(() => onPicked(bytes));
  }

  Future<void> _saveAadhaar() async {
    if (_aadhaarNumber.text.trim().length != 12) {
      AppToast.show(context, message: 'Enter a valid 12-digit Aadhaar number', type: ToastType.error);
      return;
    }
    if (_aadhaarFrontBytes == null || _aadhaarBackBytes == null) {
      AppToast.show(context, message: 'Upload both sides of your Aadhaar card', type: ToastType.error);
      return;
    }
    HapticUtils.medium();
    final ok = await ref.read(settingsPod.notifier).submitAadhaarDocuments(
      aadhaarNumber: _aadhaarNumber.text.trim(),
      frontBytes:    _aadhaarFrontBytes!,
      backBytes:     _aadhaarBackBytes!,
    );
    if (ok && mounted) {
      setState(() { _aadhaarFrontBytes = null; _aadhaarBackBytes = null; });
    }
  }

  Future<void> _savePan() async {
    if (_panNumber.text.trim().length != 10) {
      AppToast.show(context, message: 'Enter a valid 10-character PAN number', type: ToastType.error);
      return;
    }
    if (_panDocBytes == null) {
      AppToast.show(context, message: 'Upload your PAN card document', type: ToastType.error);
      return;
    }
    HapticUtils.medium();
    final ok = await ref.read(settingsPod.notifier).submitPanDocument(
      panNumber: _panNumber.text.trim().toUpperCase(),
      docBytes:  _panDocBytes!,
    );
    if (ok && mounted) setState(() => _panDocBytes = null);
  }

  Future<void> _saveGst() async {
    if (_gstNumber.text.trim().length != 15) {
      AppToast.show(context, message: 'Enter a valid 15-character GSTIN', type: ToastType.error);
      return;
    }
    if (_gstDocBytes == null) {
      AppToast.show(context, message: 'Upload your GST document', type: ToastType.error);
      return;
    }
    HapticUtils.medium();
    final ok = await ref.read(settingsPod.notifier).submitGstDocument(
      gstNumber: _gstNumber.text.trim().toUpperCase(),
      docBytes:  _gstDocBytes!,
    );
    if (ok && mounted) setState(() => _gstDocBytes = null);
  }

  @override
  Widget build(BuildContext context) {
    final savingSection = ref.watch(settingsPod).savingSection;
    final status = widget.data['status'] as String?;
    // Aadhaar/PAN lock once the pair is complete and queued for review;
    // GST stays editable (it's optional and doesn't gate review) until approved.
    final mandatoryLocked = status == 'PENDING' || status == 'APPROVED';
    final gstLocked        = status == 'APPROVED';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _KycStatusBanner(
          status: status,
          rejectionReason: widget.data['rejectionReason'] as String?,
          aadhaarLast4: widget.data['aadhaarLast4'] as String?,
          panLast4: widget.data['panLast4'] as String?,
        ),
        const SizedBox(height: 20),

        const Text('AADHAAR CARD',
            style: TextStyle(color: AppColors.grey, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.4)),
        const SizedBox(height: 4),
        const Text('Mandatory — required for shop verification',
            style: TextStyle(color: AppColors.greyDark, fontSize: 11)),
        const SizedBox(height: 12),
        _Field(
          label: 'AADHAAR NUMBER', ctrl: _aadhaarNumber, hint: '12-digit number',
          icon: Icons.badge_outlined, keyboardType: TextInputType.number,
          maxLength: 12, enabled: !mandatoryLocked,
        ),
        Row(
          children: [
            Expanded(
              child: _DocUploadBox(
                label: 'Front side',
                bytes: _aadhaarFrontBytes,
                existingUrl: widget.data['aadhaarFrontUrl'] as String?,
                enabled: !mandatoryLocked,
                onTap: () => _pickDoc((b) => _aadhaarFrontBytes = b),
                onRemove: () => setState(() => _aadhaarFrontBytes = null),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _DocUploadBox(
                label: 'Back side',
                bytes: _aadhaarBackBytes,
                existingUrl: widget.data['aadhaarBackUrl'] as String?,
                enabled: !mandatoryLocked,
                onTap: () => _pickDoc((b) => _aadhaarBackBytes = b),
                onRemove: () => setState(() => _aadhaarBackBytes = null),
              ),
            ),
          ],
        ),
        if (!mandatoryLocked) ...[
          const SizedBox(height: 8),
          _SaveButton(
            label: 'Save Aadhaar Details',
            onTap: _saveAadhaar,
            isSaving: savingSection == 'kyc-aadhaar',
          ),
        ],

        const SizedBox(height: 24),
        const Text('PAN CARD',
            style: TextStyle(color: AppColors.grey, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.4)),
        const SizedBox(height: 4),
        const Text('Mandatory — required for shop verification',
            style: TextStyle(color: AppColors.greyDark, fontSize: 11)),
        const SizedBox(height: 12),
        _Field(
          label: 'PAN NUMBER', ctrl: _panNumber, hint: 'ABCDE1234F',
          icon: Icons.credit_card_outlined, maxLength: 10, enabled: !mandatoryLocked,
        ),
        _DocUploadBox(
          label: 'PAN document',
          bytes: _panDocBytes,
          existingUrl: widget.data['panDocumentUrl'] as String?,
          enabled: !mandatoryLocked,
          onTap: () => _pickDoc((b) => _panDocBytes = b),
          onRemove: () => setState(() => _panDocBytes = null),
        ),
        if (!mandatoryLocked) ...[
          const SizedBox(height: 8),
          _SaveButton(
            label: 'Save PAN Details',
            onTap: _savePan,
            isSaving: savingSection == 'kyc-pan',
          ),
        ],

        const SizedBox(height: 24),
        const Text('GST DETAILS',
            style: TextStyle(color: AppColors.grey, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.4)),
        const SizedBox(height: 4),
        const Text('Optional — add this any time', style: TextStyle(color: AppColors.greyDark, fontSize: 11)),
        const SizedBox(height: 12),
        _Field(
          label: 'GST NUMBER', ctrl: _gstNumber, hint: '15-character GSTIN',
          icon: Icons.receipt_long_outlined, maxLength: 15, enabled: !gstLocked,
        ),
        _DocUploadBox(
          label: 'GST document',
          bytes: _gstDocBytes,
          existingUrl: widget.data['gstDocumentUrl'] as String?,
          enabled: !gstLocked,
          onTap: () => _pickDoc((b) => _gstDocBytes = b),
          onRemove: () => setState(() => _gstDocBytes = null),
        ),
        if (!gstLocked) ...[
          const SizedBox(height: 8),
          _SaveButton(
            label: 'Save GST Details',
            onTap: _saveGst,
            isSaving: savingSection == 'kyc-gst',
          ),
        ],
      ],
    );
  }
}

class _KycStatusBanner extends StatelessWidget {
  final String? status;
  final String? rejectionReason;
  final String? aadhaarLast4;
  final String? panLast4;

  const _KycStatusBanner({
    required this.status,
    required this.rejectionReason,
    required this.aadhaarLast4,
    required this.panLast4,
  });

  // Backend sends a fully masked string (e.g. "********9876") — strip the
  // stars so only the actual last 4 characters are shown here.
  static String _last4(String masked) => masked.replaceAll('*', '');

  @override
  Widget build(BuildContext context) {
    late final Color color;
    late final IconData icon;
    late final String title;
    late final String subtitle;

    switch (status) {
      case 'PENDING':
        color = AppColors.warning;
        icon = Icons.hourglass_top_rounded;
        title = 'Under review';
        subtitle = 'Our team is verifying your documents. This usually takes 1-2 business days.';
        break;
      case 'APPROVED':
        color = AppColors.success;
        icon = Icons.verified_rounded;
        title = 'Verified';
        subtitle = 'Your documents are approved and your shop is authorized.';
        break;
      case 'REJECTED':
        color = AppColors.error;
        icon = Icons.error_outline_rounded;
        title = 'Rejected — please resubmit';
        subtitle = rejectionReason?.isNotEmpty == true
            ? rejectionReason!
            : 'Your submission was rejected. Please check your details and resubmit.';
        break;
      case 'IN_PROGRESS':
        color = AppColors.info;
        icon = Icons.pending_actions_rounded;
        title = 'In progress';
        subtitle = 'Add your remaining mandatory document(s) to submit for review.';
        break;
      default:
        color = AppColors.info;
        icon = Icons.info_outline_rounded;
        title = 'Verification required';
        subtitle = 'Add your Aadhaar and PAN — one at a time — to get your shop verified. GST is optional.';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(subtitle, style: const TextStyle(color: AppColors.grey, fontSize: 12)),
                if (status != null && (aadhaarLast4 != null || panLast4 != null)) ...[
                  const SizedBox(height: 6),
                  Text(
                    [
                      if (aadhaarLast4 != null) 'Aadhaar ••${_last4(aadhaarLast4!)}',
                      if (panLast4 != null) 'PAN ••${_last4(panLast4!)}',
                    ].join('  ·  '),
                    style: const TextStyle(color: AppColors.greyDark, fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DocUploadBox extends StatelessWidget {
  final String label;
  final Uint8List? bytes;
  final String? existingUrl;
  final bool enabled;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _DocUploadBox({
    required this.label,
    required this.bytes,
    required this.existingUrl,
    required this.enabled,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final hasNew      = bytes != null;
    final hasExisting = !hasNew && (existingUrl?.isNotEmpty ?? false);

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.grey, fontSize: 11, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: enabled ? onTap : null,
            child: Container(
              width: double.infinity,
              height: 90,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: hasNew || hasExisting
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: hasNew
                              ? Image.memory(bytes!, fit: BoxFit.cover)
                              : CachedNetworkImage(
                                  imageUrl: existingUrl!, fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => const Icon(Icons.description_outlined, color: AppColors.grey),
                                ),
                        ),
                        if (hasNew)
                          Positioned(
                            top: 4, left: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.info.withOpacity(0.85),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text('NEW', style: TextStyle(color: AppColors.white, fontSize: 8, fontWeight: FontWeight.w700)),
                            ),
                          ),
                        if (enabled && hasNew)
                          Positioned(
                            top: 4, right: 4,
                            child: GestureDetector(
                              onTap: onRemove,
                              child: Container(
                                width: 20, height: 20,
                                decoration: BoxDecoration(color: AppColors.error.withOpacity(0.85), shape: BoxShape.circle),
                                child: const Icon(Icons.close_rounded, color: AppColors.white, size: 12),
                              ),
                            ),
                          ),
                      ],
                    )
                  : Center(
                      child: Icon(
                        enabled ? Icons.add_photo_alternate_outlined : Icons.lock_outline_rounded,
                        color: AppColors.greyDark, size: 24,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Business Tab ─────────────────────────────────────────────────────────────

const _kBusinessTypes = [
  ('Sole Proprietorship', Icons.person_rounded),
  ('Partnership',         Icons.people_rounded),
  ('Private Limited',     Icons.business_rounded),
  ('LLP',                 Icons.account_balance_rounded),
  ('One Person Company',  Icons.person_pin_rounded),
];

final _superCategoriesPod = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final res  = await ApiClient.instance.client.get(
    ApiEndpoints.levelZeroCategories,
    queryParameters: {'level': 'SUPER_CATEGORY'},
  );
  final body = res.data as Map<String, dynamic>;
  final list = body['data'] as List? ?? [];
  return list.map((e) => e as Map<String, dynamic>).toList();
});

class _BusinessTab extends ConsumerStatefulWidget {
  final Map<String, dynamic> data;
  const _BusinessTab({required this.data});
  @override
  ConsumerState<_BusinessTab> createState() => _BusinessTabState();
}

class _BusinessTabState extends ConsumerState<_BusinessTab> {
  final _gst = TextEditingController();

  String _bizType    = '';
  String _categoryId = '';
  bool   _initialized = false;

  @override
  void initState() {
    super.initState();
    if (widget.data.isNotEmpty) _populate();
  }

  @override
  void didUpdateWidget(_BusinessTab old) {
    super.didUpdateWidget(old);
    if (!_initialized && widget.data.isNotEmpty) _populate();
  }

  void _populate() {
    _initialized = true;
    _bizType     = widget.data['businessType']      as String? ?? '';
    _categoryId  = widget.data['businessCategory']  as String? ?? '';
    _gst.text = widget.data['gstNumber'] as String? ?? '';
  }

  @override
  void dispose() {
    _gst.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final saved = widget.data;
    final noChange =
        _bizType         == (saved['businessType']     as String? ?? '') &&
        _gst.text.trim() == (saved['gstNumber']        as String? ?? '') &&
        _categoryId      == (saved['businessCategory'] as String? ?? '');

    if (noChange) {
      AppToast.show(context, message: 'Nothing to update', type: ToastType.info);
      return;
    }

    HapticUtils.medium();
    await ref.read(settingsPod.notifier).updateBusiness(
      businessName:      '',
      businessType:      _bizType,
      gstNumber:         _gst.text.trim(),
      businessCategory:  _categoryId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final saving     = ref.watch(settingsPod).savingSection == 'business';
    final categories = ref.watch(_superCategoriesPod);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        // ── Business Type ──────────────────────────────────────────────────
        const Text('BUSINESS TYPE',
            style: TextStyle(color: AppColors.grey, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _kBusinessTypes.map((t) {
            final selected = _bizType == t.$1;
            return GestureDetector(
              onTap: () { HapticUtils.light(); setState(() => _bizType = t.$1); },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? AppColors.white : AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected ? AppColors.white : AppColors.border,
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(t.$2,
                        size: 15,
                        color: selected ? AppColors.bg : AppColors.grey),
                    const SizedBox(width: 6),
                    Text(t.$1,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                          color: selected ? AppColors.bg : AppColors.grey,
                        )),
                  ],
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 24),

        // ── GST ───────────────────────────────────────────────────────────
        _Field(label: 'GST NUMBER', ctrl: _gst, hint: 'Optional', icon: Icons.receipt_long_outlined),

        // ── Business Category ──────────────────────────────────────────────
        const Text('BUSINESS CATEGORY',
            style: TextStyle(color: AppColors.grey, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
        const SizedBox(height: 10),

        categories.when(
          loading: () => SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 5,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, __) => const AppShimmer(child: ShimmerBox(width: 90, height: 38)),
            ),
          ),
          error: (_, __) => Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.07),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.error.withOpacity(0.25)),
            ),
            child: const Row(
              children: [
                Icon(Icons.error_outline_rounded, color: AppColors.error, size: 16),
                SizedBox(width: 8),
                Text('Failed to load categories', style: TextStyle(color: AppColors.error, fontSize: 12)),
              ],
            ),
          ),
          data: (cats) => Wrap(
            spacing: 8,
            runSpacing: 8,
            children: cats.map((cat) {
              final id       = cat['id']   as String? ?? '';
              final name     = cat['name'] as String? ?? '';
              final selected = _categoryId == id;
              return GestureDetector(
                onTap: () { HapticUtils.light(); setState(() => _categoryId = id); },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.white : AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected ? AppColors.white : AppColors.border,
                      width: selected ? 1.5 : 1,
                    ),
                  ),
                  child: Text(
                    name,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? AppColors.bg : AppColors.grey,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 24),
        _SaveButton(label: 'Save Business Details', onTap: _save, isSaving: saving),
      ].animate(interval: 40.ms).fadeIn().slideY(begin: 0.05, end: 0),
    );
  }
}

// ─── Bank Tab ─────────────────────────────────────────────────────────────────

class _BankTab extends ConsumerStatefulWidget {
  final Map<String, dynamic> data;
  const _BankTab({required this.data});
  @override
  ConsumerState<_BankTab> createState() => _BankTabState();
}

class _BankTabState extends ConsumerState<_BankTab> {
  final _holder   = TextEditingController();
  final _account  = TextEditingController();
  final _ifsc     = TextEditingController();
  final _bankName = TextEditingController();
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    if (widget.data.isNotEmpty) _populate();
  }

  @override
  void didUpdateWidget(_BankTab old) {
    super.didUpdateWidget(old);
    if (!_initialized && widget.data.isNotEmpty) _populate();
  }

  void _populate() {
    _initialized   = true;
    _holder.text   = widget.data['accountHolderName'] as String? ?? '';
    _ifsc.text     = widget.data['ifscCode']          as String? ?? '';
    _bankName.text = widget.data['bankName']          as String? ?? '';
    // Don't pre-fill account number for security
  }

  @override
  void dispose() {
    _holder.dispose(); _account.dispose();
    _ifsc.dispose();   _bankName.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    HapticUtils.medium();
    await ref.read(settingsPod.notifier).updateBank(
      accountHolderName: _holder.text.trim(),
      accountNumber:     _account.text.trim(),
      ifscCode:          _ifsc.text.trim().toUpperCase(),
      bankName:          _bankName.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final saving        = ref.watch(settingsPod).savingSection == 'bank';
    final verified       = widget.data['verified'] as bool? ?? false;
    final maskedOnFile   = widget.data['accountNumber'] as String?;
    final hasExisting    = maskedOnFile != null && maskedOnFile.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasExisting)
          _BankStatusBanner(verified: verified)
        else
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.warning.withOpacity(0.3)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Bank details are encrypted and require verification before payouts start.',
                    style: TextStyle(color: AppColors.warning, fontSize: 12, height: 1.5),
                  ),
                ),
              ],
            ),
          ),

        _Field(label: 'ACCOUNT HOLDER NAME', ctrl: _holder,   hint: 'As on bank records',        icon: Icons.person_outline),

        const Text('ACCOUNT NUMBER',
            style: TextStyle(color: AppColors.grey, fontSize: 11, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        if (hasExisting) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.lock_outline_rounded, color: AppColors.grey, size: 16),
                const SizedBox(width: 10),
                Text(maskedOnFile, style: const TextStyle(color: AppColors.white, fontSize: 15, letterSpacing: 1)),
                const Spacer(),
                const Text('on file', style: TextStyle(color: AppColors.greyDark, fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(height: 6),
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              'To change it, enter a new account number below.',
              style: TextStyle(color: AppColors.greyDark, fontSize: 11),
            ),
          ),
        ],
        _Field(ctrl: _account, hint: hasExisting ? 'Enter a new account number' : 'Enter account number',
            label: hasExisting ? 'NEW ACCOUNT NUMBER' : 'ACCOUNT NUMBER', icon: Icons.tag_outlined,
            keyboardType: TextInputType.number),

        _Field(label: 'IFSC CODE',           ctrl: _ifsc,     hint: 'e.g. SBIN0001234',          icon: Icons.code_rounded),
        _Field(label: 'BANK NAME',           ctrl: _bankName, hint: 'e.g. State Bank of India',  icon: Icons.account_balance_outlined),
        const SizedBox(height: 8),
        _SaveButton(label: 'Update Bank Details', onTap: _save, isSaving: saving),
      ].animate(interval: 40.ms).fadeIn().slideY(begin: 0.05, end: 0),
    );
  }
}

class _BankStatusBanner extends StatelessWidget {
  final bool verified;
  const _BankStatusBanner({required this.verified});

  @override
  Widget build(BuildContext context) {
    final color = verified ? AppColors.success : AppColors.warning;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(verified ? Icons.verified_rounded : Icons.hourglass_top_rounded, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(verified ? 'Verified' : 'Verification pending',
                    style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(
                  verified
                      ? 'Payouts will go to this account.'
                      : 'Our team is verifying this account. Changing details restarts verification and may delay payouts by 2–3 business days.',
                  style: const TextStyle(color: AppColors.grey, fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Notifications Tab ────────────────────────────────────────────────────────

class _NotificationsTab extends ConsumerStatefulWidget {
  final Map<String, dynamic> data;
  const _NotificationsTab({required this.data});
  @override
  ConsumerState<_NotificationsTab> createState() => _NotificationsTabState();
}

class _NotificationsTabState extends ConsumerState<_NotificationsTab> {
  late Map<String, bool> _prefs;

  static const _rows = [
    {'key': 'order',    'title': 'Order Notifications',  'desc': 'New orders and order updates'},
    {'key': 'payment',  'title': 'Payment Alerts',       'desc': 'Payouts and settlements'},
    {'key': 'stock',    'title': 'Low Stock Alerts',     'desc': 'When inventory runs low'},
    {'key': 'promo',    'title': 'Promotional Updates',  'desc': 'Tips, offers, and insights'},
    {'key': 'security', 'title': 'Security Alerts',      'desc': 'Login attempts and changes'},
  ];

  static const _channels = ['Email', 'Push', 'Sms'];

  @override
  void initState() {
    super.initState();
    _prefs = {};
    for (final row in _rows) {
      for (final ch in _channels) {
        final key = '${row['key']}$ch';
        _prefs[key] = widget.data[key] as bool? ?? false;
      }
    }
  }

  Future<void> _save() async {
    final noChange = _prefs.entries.every(
      (e) => (widget.data[e.key] as bool? ?? false) == e.value,
    );
    if (noChange) {
      AppToast.show(context, message: 'Nothing to update', type: ToastType.info);
      return;
    }
    HapticUtils.medium();
    await ref.read(settingsPod.notifier).updateNotifications(
      Map<String, dynamic>.from(_prefs),
    );
  }

  @override
  Widget build(BuildContext context) {
    final saving = ref.watch(settingsPod).savingSection == 'notifications';
    return Column(
      children: [
        ..._rows.map((row) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(row['title']!, style: const TextStyle(color: AppColors.white, fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(row['desc']!, style: const TextStyle(color: AppColors.grey, fontSize: 12)),
              const SizedBox(height: 12),
              Row(
                children: _channels.map((ch) {
                  final key = '${row['key']}$ch';
                  return Expanded(
                    child: GestureDetector(
                      onTap: () { HapticUtils.light(); setState(() => _prefs[key] = !(_prefs[key] ?? false)); },
                      child: Row(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 18, height: 18,
                            decoration: BoxDecoration(
                              color: (_prefs[key] ?? false) ? AppColors.white : AppColors.surface2,
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(color: (_prefs[key] ?? false) ? AppColors.white : AppColors.border),
                            ),
                            child: (_prefs[key] ?? false)
                                ? const Icon(Icons.check_rounded, color: AppColors.bg, size: 12)
                                : null,
                          ),
                          const SizedBox(width: 6),
                          Text(ch, style: const TextStyle(color: AppColors.grey, fontSize: 12)),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        )),
        const SizedBox(height: 8),
        _SaveButton(label: 'Save Preferences', onTap: _save, isSaving: saving),
      ].animate(interval: 40.ms).fadeIn(),
    );
  }
}

// ─── Shared Widgets ───────────────────────────────────────────────────────────

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final String hint;
  final IconData icon;
  final TextInputType keyboardType;
  final bool enabled;
  final Widget? suffix;
  final int? maxLength;
  const _Field({
    required this.label,
    required this.ctrl,
    required this.hint,
    this.icon         = Icons.edit_outlined,
    this.keyboardType = TextInputType.text,
    this.enabled      = true,
    this.suffix,
    this.maxLength,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.grey, fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.4)),
          const SizedBox(height: 8),
          TextField(
            controller:   ctrl,
            keyboardType: keyboardType,
            enabled:      enabled,
            maxLength:    maxLength,
            style: const TextStyle(color: AppColors.white, fontSize: 15),
            cursorColor: AppColors.white,
            decoration: InputDecoration(
              hintText:          hint,
              hintStyle:         const TextStyle(color: AppColors.greyDark, fontSize: 15),
              prefixIcon:        Icon(icon, color: AppColors.grey, size: 18),
              suffixIcon:        suffix,
              filled:            true,
              fillColor:         AppColors.surface,
              counterText:       maxLength != null ? '' : null,
              contentPadding:    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border:            OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
              enabledBorder:     OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
              disabledBorder:    OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
              focusedBorder:     OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.white, width: 1.5)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isSaving;

  const _SaveButton({required this.label, required this.onTap, required this.isSaving});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isSaving ? null : onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSaving ? AppColors.surface2 : AppColors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: isSaving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: AppColors.grey, strokeWidth: 2))
              : Text(label, style: const TextStyle(color: AppColors.bg, fontSize: 14, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }
}

