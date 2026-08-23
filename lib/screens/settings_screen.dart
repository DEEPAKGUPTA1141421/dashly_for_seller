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
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/app_colors.dart';
import '../utils/haptic_utils.dart';

// ─── Tabs ─────────────────────────────────────────────────────────────────────

enum _Tab { personal, business, bank, notifications }

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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                children: [
                  const Text(
                    'Settings',
                    style: TextStyle(
                      color: AppColors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
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
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.error.withOpacity(0.3)),
                      ),
                      child: const Icon(Icons.logout_rounded, color: AppColors.error, size: 20),
                    ),
                  ),
                ],
              ).animate().fadeIn(),
            ),
            const SizedBox(height: 16),

            // Tab bar
            SizedBox(
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
            ).animate().fadeIn(delay: 80.ms),

            const SizedBox(height: 4),

            // Content
            Expanded(
              child: state.isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.white))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: _buildTab(state),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(SettingsState state) {
    switch (_tab) {
      case _Tab.personal:      return _PersonalTab(data: state.personal);
      case _Tab.business:      return _BusinessTab(data: state.business);
      case _Tab.bank:          return _BankTab(data: state.bank);
      case _Tab.notifications: return _NotificationsTab(data: state.notifications);
    }
  }

  String _tabLabel(_Tab t) {
    switch (t) {
      case _Tab.personal:      return 'Personal';
      case _Tab.business:      return 'Business';
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

  Uint8List? _profilePhotoBytes;
  String     _profilePhotoName  = 'profile.jpg';
  List<String>      _existingMediaUrls = [];
  List<_LocalMedia> _newMediaItems     = [];
  bool _initialized = false;

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
      email:             _email.text.trim(),
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
            GestureDetector(
              onTap: _pickProfilePhoto,
              child: Stack(
                children: [
                  Container(
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
                  Positioned(
                    right: 0, bottom: 0,
                    child: Container(
                      width: 24, height: 24,
                      decoration: const BoxDecoration(color: AppColors.white, shape: BoxShape.circle),
                      child: const Icon(Icons.camera_alt_rounded, color: AppColors.bg, size: 14),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Profile Photo', style: TextStyle(color: AppColors.white, fontSize: 14, fontWeight: FontWeight.w600)),
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

        _Field(label: 'FULL NAME',    ctrl: _fullName,    hint: 'Enter full name'),
        _Field(label: 'DISPLAY NAME', ctrl: _displayName, hint: 'Store / display name'),
        _Field(label: 'EMAIL',        ctrl: _email,       hint: 'you@example.com',   keyboardType: TextInputType.emailAddress),
        _Field(label: 'PHONE',        ctrl: _phone,       hint: '10-digit number',   keyboardType: TextInputType.phone),

        const SizedBox(height: 8),

        _SaveButton(label: 'Save Personal Info', onTap: _save, isSaving: saving),
      ],
    );
  }
}

class _MediaThumb extends StatelessWidget {
  final Widget child;
  final bool isVideo;
  final bool isNew;
  final VoidCallback onRemove;

  const _MediaThumb({
    required this.child,
    required this.onRemove,
    this.isVideo = false,
    this.isNew   = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80, height: 80,
      margin: const EdgeInsets.only(right: 8),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 80, height: 80,
              color: AppColors.surface2,
              child: child,
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
        _Field(label: 'GST NUMBER', ctrl: _gst, hint: 'Optional'),

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
    final saving   = ref.watch(settingsPod).savingSection == 'bank';
    final verified = widget.data['verified'] as bool? ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (verified)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.success.withOpacity(0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.verified_rounded, color: AppColors.success, size: 18),
                SizedBox(width: 10),
                Text('Bank account verified — payouts will go to this account',
                    style: TextStyle(color: AppColors.success, fontSize: 13)),
              ],
            ),
          ),

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
                  'Changing bank details will require re-verification and may delay payouts by 2–3 business days.',
                  style: TextStyle(color: AppColors.warning, fontSize: 12, height: 1.5),
                ),
              ),
            ],
          ),
        ),

        _Field(label: 'ACCOUNT HOLDER NAME', ctrl: _holder,   hint: 'As on bank records'),
        _Field(label: 'ACCOUNT NUMBER',      ctrl: _account,  hint: 'Enter account number',  obscure: true),
        _Field(label: 'IFSC CODE',           ctrl: _ifsc,     hint: 'e.g. SBIN0001234'),
        _Field(label: 'BANK NAME',           ctrl: _bankName, hint: 'e.g. State Bank of India'),
        const SizedBox(height: 8),
        _SaveButton(label: 'Update Bank Details', onTap: _save, isSaving: saving),
      ].animate(interval: 40.ms).fadeIn().slideY(begin: 0.05, end: 0),
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
  final TextInputType keyboardType;
  final bool obscure;
  const _Field({
    required this.label,
    required this.ctrl,
    required this.hint,
    this.keyboardType = TextInputType.text,
    this.obscure      = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.grey, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
          const SizedBox(height: 6),
          TextField(
            controller:   ctrl,
            keyboardType: keyboardType,
            obscureText:  obscure,
            maxLines:     obscure ? 1 : 1,
            style: const TextStyle(color: AppColors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText:          hint,
              hintStyle:         const TextStyle(color: AppColors.greyDark, fontSize: 14),
              filled:            true,
              fillColor:         AppColors.surface,
              contentPadding:    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border:            OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
              enabledBorder:     OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
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
    return SizedBox(
      width: double.infinity,
      child: GestureDetector(
        onTap: isSaving ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSaving ? AppColors.surface2 : AppColors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: isSaving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: AppColors.grey, strokeWidth: 2))
                : Text(label, style: const TextStyle(color: AppColors.bg, fontSize: 14, fontWeight: FontWeight.w700)),
          ),
        ),
      ),
    );
  }
}

