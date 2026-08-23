import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../core/errors/app_exception.dart';

// ─── State ────────────────────────────────────────────────────────────────────

class SettingsState {
  final bool isLoading;
  final String? savingSection; // 'personal' | 'business' | 'bank' | 'notifications'
  final String? error;
  final String? successMessage;

  // Fetched from /api/v1/seller/settings/all
  final Map<String, dynamic> personal;
  final Map<String, dynamic> business;
  final Map<String, dynamic> bank;
  final Map<String, dynamic> notifications;
  final Map<String, dynamic> preferences;
  final bool onboardingComplete;
  final String? onboardingStage;

  const SettingsState({
    this.isLoading         = false,
    this.savingSection,
    this.error,
    this.successMessage,
    this.personal          = const {},
    this.business          = const {},
    this.bank              = const {},
    this.notifications     = const {},
    this.preferences       = const {},
    this.onboardingComplete = true, // default true to avoid flashing banner before load
    this.onboardingStage,
  });

  SettingsState copyWith({
    bool? isLoading,
    String? savingSection,
    bool clearSaving = false,
    String? error,
    bool clearError = false,
    String? successMessage,
    bool clearSuccess = false,
    Map<String, dynamic>? personal,
    Map<String, dynamic>? business,
    Map<String, dynamic>? bank,
    Map<String, dynamic>? notifications,
    Map<String, dynamic>? preferences,
    bool? onboardingComplete,
    String? onboardingStage,
  }) {
    return SettingsState(
      isLoading:          isLoading          ?? this.isLoading,
      savingSection:      clearSaving        ? null : (savingSection ?? this.savingSection),
      error:              clearError         ? null : (error         ?? this.error),
      successMessage:     clearSuccess       ? null : (successMessage ?? this.successMessage),
      personal:           personal           ?? this.personal,
      business:           business           ?? this.business,
      bank:               bank               ?? this.bank,
      notifications:      notifications      ?? this.notifications,
      preferences:        preferences        ?? this.preferences,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      onboardingStage:    onboardingStage    ?? this.onboardingStage,
    );
  }
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier() : super(const SettingsState());

  Dio get _client => ApiClient.instance.client;

  // ── Fetch all settings at once ────────────────────────────────────────────
  // GET /api/v1/seller/settings/all
  // Response: { success, data: { personal, business, bank, notifications, preferences } }
  Future<void> fetchAll() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final res  = await _client.get(ApiEndpoints.settingsAll);
      final body = res.data as Map<String, dynamic>;
      final data = body['data'] as Map<String, dynamic>? ?? {};
      state = state.copyWith(
        isLoading:          false,
        personal:           _asMap(data['personal']),
        business:           _asMap(data['business']),
        bank:               _asMap(data['bank']),
        notifications:      _asMap(data['notifications']),
        preferences:        _asMap(data['preferences']),
        onboardingComplete: (data['onboardingComplete'] as bool?) ?? false,
        onboardingStage:    data['onboardingStage'] as String?,
      );
    } on DioException catch (e) {
      state = state.copyWith(isLoading: false, error: AppException.fromDioError(e).message);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  // ── Personal Info ─────────────────────────────────────────────────────────
  // PUT /api/v1/seller/settings/personal  (multipart/form-data)
  // Fields: fullName, displayName, email, phone, profileImage (file), mediaFiles (files)
  Future<bool> updatePersonalInfo({
    required String fullName,
    required String displayName,
    required String email,
    required String phone,
    Uint8List? profilePhotoBytes,
    String profilePhotoName = 'profile.jpg',
    List<MapEntry<String, Uint8List>> mediaFiles = const [],
  }) async {
    state = state.copyWith(savingSection: 'personal', clearError: true, clearSuccess: true);
    try {
      final stored  = state.personal;
      final formMap = <String, dynamic>{};

      // Only include fields that actually changed
      if (fullName    != (stored['fullName']    as String? ?? '')) formMap['fullName']    = fullName;
      if (displayName != (stored['displayName'] as String? ?? '')) formMap['displayName'] = displayName;
      if (email       != (stored['email']       as String? ?? '')) formMap['email']       = email;
      if (phone       != (stored['phone']       as String? ?? '')) formMap['phone']       = phone;

      if (profilePhotoBytes != null) {
        formMap['profileImage'] = MultipartFile.fromBytes(
          profilePhotoBytes,
          filename: profilePhotoName,
        );
      }

      // Nothing changed — skip the API call entirely
      if (formMap.isEmpty && mediaFiles.isEmpty) {
        state = state.copyWith(clearSaving: true, successMessage: 'Nothing to update');
        return true;
      }

      final formData = FormData.fromMap(formMap);
      for (final entry in mediaFiles) {
        formData.files.add(MapEntry(
          'mediaFiles',
          MultipartFile.fromBytes(entry.value, filename: entry.key),
        ));
      }
      final res  = await _client.put(
        ApiEndpoints.settingsPersonal,
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );
      final body = res.data as Map<String, dynamic>;
      if (body['success'] == true) {
        final updated = _asMap(body['data']);
        state = state.copyWith(
          clearSaving:    true,
          personal:       updated.isNotEmpty ? updated : state.personal,
          successMessage: 'Personal info saved',
        );
        return true;
      }
      state = state.copyWith(clearSaving: true, error: body['message'] ?? 'Failed to save');
      return false;
    } on DioException catch (e) {
      state = state.copyWith(clearSaving: true, error: AppException.fromDioError(e).message);
      return false;
    }
  }

  // ── Business Details ──────────────────────────────────────────────────────
  // PUT /api/v1/seller/settings/business  (JSON)
  // Fields: businessName, businessType, gstNumber, registeredAddress, businessCategory
  Future<bool> updateBusiness({
    required String businessName,
    required String businessType,
    String? gstNumber,
    String? registeredAddress,
    String? businessCategory,
  }) async {
    state = state.copyWith(savingSection: 'business', clearError: true, clearSuccess: true);
    try {
      final res  = await _client.put(ApiEndpoints.settingsBusiness, data: {
        'businessName':      businessName,
        'businessType':      businessType,
        if (gstNumber?.isNotEmpty == true)          'gstNumber':         gstNumber,
        if (registeredAddress?.isNotEmpty == true)  'registeredAddress': registeredAddress,
        if (businessCategory?.isNotEmpty == true)   'businessCategory':  businessCategory,
      });
      final body = res.data as Map<String, dynamic>;
      if (body['success'] == true) {
        final updated = _asMap(body['data']);
        state = state.copyWith(
          clearSaving:    true,
          business:       updated.isNotEmpty ? updated : state.business,
          successMessage: 'Business details saved',
        );
        return true;
      }
      state = state.copyWith(clearSaving: true, error: body['message'] ?? 'Failed to save');
      return false;
    } on DioException catch (e) {
      state = state.copyWith(clearSaving: true, error: AppException.fromDioError(e).message);
      return false;
    }
  }

  // ── Bank Details ──────────────────────────────────────────────────────────
  // PUT /api/v1/seller/settings/bank  (JSON)
  // Fields: accountHolderName, accountNumber, ifscCode, bankName
  Future<bool> updateBank({
    required String accountHolderName,
    required String accountNumber,
    required String ifscCode,
    required String bankName,
  }) async {
    state = state.copyWith(savingSection: 'bank', clearError: true, clearSuccess: true);
    try {
      final res  = await _client.put(ApiEndpoints.settingsBank, data: {
        'accountHolderName': accountHolderName,
        'accountNumber':     accountNumber,
        'ifscCode':          ifscCode,
        'bankName':          bankName,
      });
      final body = res.data as Map<String, dynamic>;
      if (body['success'] == true) {
        final updated = _asMap(body['data']);
        state = state.copyWith(
          clearSaving:    true,
          bank:           updated.isNotEmpty ? updated : state.bank,
          successMessage: 'Bank details updated',
        );
        return true;
      }
      state = state.copyWith(clearSaving: true, error: body['message'] ?? 'Failed to save');
      return false;
    } on DioException catch (e) {
      state = state.copyWith(clearSaving: true, error: AppException.fromDioError(e).message);
      return false;
    }
  }

  // ── Notification Preferences ──────────────────────────────────────────────
  // PUT /api/v1/seller/settings/notifications  (JSON)
  Future<bool> updateNotifications(Map<String, dynamic> prefs) async {
    state = state.copyWith(savingSection: 'notifications', clearError: true, clearSuccess: true);
    try {
      final res  = await _client.put(ApiEndpoints.settingsNotifications, data: prefs);
      final body = res.data as Map<String, dynamic>;
      if (body['success'] == true) {
        state = state.copyWith(
          clearSaving:    true,
          notifications:  prefs,
          successMessage: 'Notifications saved',
        );
        return true;
      }
      state = state.copyWith(clearSaving: true, error: body['message'] ?? 'Failed to save');
      return false;
    } on DioException catch (e) {
      state = state.copyWith(clearSaving: true, error: AppException.fromDioError(e).message);
      return false;
    }
  }

  // ── Change Password ───────────────────────────────────────────────────────
  // PUT /api/v1/seller/settings/security/password  (JSON)
  // Fields: currentPassword, newPassword
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    state = state.copyWith(savingSection: 'security', clearError: true, clearSuccess: true);
    try {
      final res  = await _client.put(ApiEndpoints.settingsPassword, data: {
        'currentPassword': currentPassword,
        'newPassword':     newPassword,
      });
      final body = res.data as Map<String, dynamic>;
      if (body['success'] == true) {
        state = state.copyWith(clearSaving: true, successMessage: 'Password updated successfully');
        return true;
      }
      state = state.copyWith(clearSaving: true, error: body['message'] ?? 'Failed to update password');
      return false;
    } on DioException catch (e) {
      state = state.copyWith(clearSaving: true, error: AppException.fromDioError(e).message);
      return false;
    }
  }

  void clearMessages() =>
      state = state.copyWith(clearError: true, clearSuccess: true);

  Map<String, dynamic> _asMap(dynamic v) =>
      v is Map<String, dynamic> ? v : const {};
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final settingsPod = StateNotifierProvider<SettingsNotifier, SettingsState>(
  (ref) => SettingsNotifier(),
);
