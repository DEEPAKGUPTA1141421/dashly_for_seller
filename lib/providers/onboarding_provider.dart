import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../core/errors/app_exception.dart';
import '../utils/storage_service.dart';

class OnboardingState {
  final bool isLoading;
  final bool isLoadingSettings;
  final String? error;
  final int currentStep;
  final bool isComplete;
  final Map<String, dynamic> formData;
  final String? profileImagePath;
  final List<String> mediaFilePaths;

  const OnboardingState({
    this.isLoading        = false,
    this.isLoadingSettings = true,
    this.error,
    this.currentStep      = 0,
    this.isComplete       = false,
    this.formData         = const {},
    this.profileImagePath,
    this.mediaFilePaths   = const [],
  });

  OnboardingState copyWith({
    bool? isLoading,
    bool? isLoadingSettings,
    String? error,
    int? currentStep,
    bool? isComplete,
    Map<String, dynamic>? formData,
    String? profileImagePath,
    bool clearProfileImage = false,
    List<String>? mediaFilePaths,
  }) {
    return OnboardingState(
      isLoading:         isLoading         ?? this.isLoading,
      isLoadingSettings: isLoadingSettings ?? this.isLoadingSettings,
      error:             error,
      currentStep:       currentStep       ?? this.currentStep,
      isComplete:        isComplete        ?? this.isComplete,
      profileImagePath:  clearProfileImage ? null : (profileImagePath ?? this.profileImagePath),
      mediaFilePaths:    mediaFilePaths    ?? this.mediaFilePaths,
      formData: formData != null
          ? {...this.formData, ...formData}
          : this.formData,
    );
  }
}

class OnboardingNotifier extends StateNotifier<OnboardingState> {
  OnboardingNotifier() : super(const OnboardingState());

  Dio get _client => ApiClient.instance.client;

  void updateFormData(Map<String, dynamic> data) =>
      state = state.copyWith(formData: data);

  void setProfileImage(String? path) =>
      state = path == null
          ? state.copyWith(clearProfileImage: true)
          : state.copyWith(profileImagePath: path);

  void addMediaFile(String path) =>
      state = state.copyWith(mediaFilePaths: [...state.mediaFilePaths, path]);

  void removeMediaFile(int index) {
    final updated = [...state.mediaFilePaths]..removeAt(index);
    state = state.copyWith(mediaFilePaths: updated);
  }

  void nextStep() {
    if (state.currentStep < 5) {
      state = state.copyWith(currentStep: state.currentStep + 1);
    }
  }

  void prevStep() {
    if (state.currentStep > 0) {
      state = state.copyWith(currentStep: state.currentStep - 1);
    }
  }

  // PUT /api/v1/seller/settings/personal  (multipart/form-data)
  Future<bool> submitBasicInfo(Map<String, dynamic> data) async {
    state = state.copyWith(isLoading: true, error: null, formData: data);
    try {
      final formMap = <String, dynamic>{
        'fullName': data['name']?.toString() ?? '',
        if ((data['email']       as String?)?.isNotEmpty == true) 'email':       data['email'],
        if ((data['phone']       as String?)?.isNotEmpty == true) 'phone':       data['phone'],
        if ((data['displayName'] as String?)?.isNotEmpty == true) 'displayName': data['displayName'],
      };

      if (state.profileImagePath != null) {
        formMap['profileImage'] = await MultipartFile.fromFile(
          state.profileImagePath!,
          filename: 'profile.jpg',
        );
      }

      if (state.mediaFilePaths.isNotEmpty) {
        formMap['mediaFiles'] = await Future.wait(
          state.mediaFilePaths.map((p) => MultipartFile.fromFile(p)),
        );
      }

      final res  = await _client.put(ApiEndpoints.settingsPersonal, data: FormData.fromMap(formMap));
      final body = res.data as Map<String, dynamic>;
      if (body['success'] == true) {
        state = state.copyWith(isLoading: false, currentStep: 1);
        return true;
      }
      state = state.copyWith(isLoading: false, error: body['message']);
      return false;
    } on DioException catch (e) {
      state = state.copyWith(isLoading: false, error: AppException.fromDioError(e).message);
      return false;
    }
  }

  // PUT /api/v1/seller/settings/business
  Future<bool> submitBusiness(Map<String, dynamic> data) async {
    state = state.copyWith(isLoading: true, error: null, formData: data);
    try {
      final res  = await _client.put(
        ApiEndpoints.settingsBusiness,
        data: {
          'businessName': data['businessName'],
          'shopType':     data['businessType'],
          'gstNumber':    data['gst'] ?? '',
          'panNumber':    data['pan'],
        },
      );
      final body = res.data as Map<String, dynamic>;
      if (body['success'] == true) {
        state = state.copyWith(isLoading: false, currentStep: 2);
        return true;
      }
      state = state.copyWith(isLoading: false, error: body['message']);
      return false;
    } on DioException catch (e) {
      state = state.copyWith(isLoading: false, error: AppException.fromDioError(e).message);
      return false;
    }
  }

  // POST /api/v1/seller/product/update-address
  Future<bool> submitLocation(Map<String, dynamic> data) async {
    state = state.copyWith(isLoading: true, error: null, formData: data);
    try {
      final res  = await _client.post(
        '/api/v1/seller/product/update-address',
        data: {
          'address':   data['address'],
          'city':      data['city'],
          'state':     data['state'],
          'pincode':   data['pincode'],
          'latitude':  (data['latitude']  as double?) ?? 0.0,
          'longitude': (data['longitude'] as double?) ?? 0.0,
        },
      );
      final body = res.data as Map<String, dynamic>;
      if (body['success'] == true) {
        state = state.copyWith(isLoading: false, currentStep: 3);
        return true;
      }
      state = state.copyWith(isLoading: false, error: body['message']);
      return false;
    } on DioException catch (e) {
      state = state.copyWith(isLoading: false, error: AppException.fromDioError(e).message);
      return false;
    }
  }

  // PUT /api/v1/seller/settings/bank
  Future<bool> submitBank(Map<String, dynamic> data) async {
    state = state.copyWith(isLoading: true, error: null, formData: data);
    try {
      final res  = await _client.put(
        ApiEndpoints.settingsBank,
        data: {
          'accountNumber':   data['accountNumber'],
          'ifscCode':        data['ifsc'],
          'accountHolderName': data['accountHolder'],
          'bankName':        data['bankName'],
        },
      );
      final body = res.data as Map<String, dynamic>;
      if (body['success'] == true) {
        state = state.copyWith(isLoading: false, currentStep: 4);
        return true;
      }
      state = state.copyWith(isLoading: false, error: body['message']);
      return false;
    } on DioException catch (e) {
      state = state.copyWith(isLoading: false, error: AppException.fromDioError(e).message);
      return false;
    }
  }

  // POST /api/v1/seller/product/kyc/aadhar/send-otp
  Future<bool> submitAadhar(Map<String, dynamic> data) async {
    state = state.copyWith(isLoading: true, error: null, formData: data);
    try {
      final sendRes  = await _client.post(ApiEndpoints.aadharSendOtp, data: {'aadharNumber': data['aadharNumber']});
      final sendBody = sendRes.data as Map<String, dynamic>;
      if (sendBody['success'] != true) {
        state = state.copyWith(isLoading: false, error: sendBody['message']);
        return false;
      }
      await StorageService.saveOnboardingComplete(true);
      state = state.copyWith(isLoading: false, currentStep: 5, isComplete: true);
      return true;
    } on DioException catch (e) {
      state = state.copyWith(isLoading: false, error: AppException.fromDioError(e).message);
      return false;
    }
  }

  // POST /api/v1/seller/product/aadhaar/verify-otp?otp=XXXXXX
  Future<bool> verifyAadharOtp(String otp) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res  = await _client.post(ApiEndpoints.aadharVerifyOtp, queryParameters: {'otp': otp});
      final body = res.data as Map<String, dynamic>;
      if (body['success'] == true) {
        state = state.copyWith(isLoading: false, isComplete: true);
        return true;
      }
      state = state.copyWith(isLoading: false, error: body['message']);
      return false;
    } on DioException catch (e) {
      state = state.copyWith(isLoading: false, error: AppException.fromDioError(e).message);
      return false;
    }
  }

  // GET /api/v1/seller/settings/all — parses existing data and pre-populates formData.
  Future<bool> checkOnboardingStatus() async {
    state = state.copyWith(isLoadingSettings: true);
    try {
      final res  = await _client.get(ApiEndpoints.settingsAll);
      final body = res.data as Map<String, dynamic>;
      final data = body['data'] as Map<String, dynamic>? ?? {};

      final personal = data['personal'] as Map<String, dynamic>? ?? {};
      final business = data['business'] as Map<String, dynamic>? ?? {};
      final bank     = data['bank']     as Map<String, dynamic>?;
      final done     = (data['onboardingComplete'] as bool?) ?? false;

      final prefill = <String, dynamic>{
        if ((personal['fullName']      as String?)?.isNotEmpty == true) 'name':            personal['fullName'],
        if ((personal['email']         as String?)?.isNotEmpty == true) 'email':           personal['email'],
        if ((personal['phone']         as String?)?.isNotEmpty == true) 'phone':           personal['phone'],
        if ((personal['displayName']   as String?)?.isNotEmpty == true) 'displayName':     personal['displayName'],
        if ((personal['profile_image'] as String?)?.isNotEmpty == true) 'profileImageUrl': personal['profile_image'],
        if ((personal['address']       as String?)?.isNotEmpty == true) 'address':         personal['address'],
        if ((personal['city']          as String?)?.isNotEmpty == true) 'city':            personal['city'],
        if ((personal['state']         as String?)?.isNotEmpty == true) 'state':           personal['state'],
        if ((personal['pinCode']       as String?)?.isNotEmpty == true) 'pincode':         personal['pinCode'],
        if ((business['businessName']  as String?)?.isNotEmpty == true) 'businessName':    business['businessName'],
        if ((business['shopCategory']  as String?)?.isNotEmpty == true) 'businessType':    business['shopCategory'],
        if (bank != null) ...{
          if (bank['accountHolderName'] != null) 'accountHolder': bank['accountHolderName'].toString(),
          if (bank['accountNumber']     != null) 'accountNumber': bank['accountNumber'].toString(),
          if (bank['bankName']          != null) 'bankName':      bank['bankName'].toString(),
          if (bank['ifscCode']          != null) 'ifsc':          bank['ifscCode'].toString(),
        },
      };

      // Determine which step to resume from based on data completeness
      int resumeStep = 0;
      if (done) {
        resumeStep = 5;
      } else if (bank != null) {
        resumeStep = 4; // bank saved → resume at Aadhaar
      } else if ((personal['address'] as String?)?.isNotEmpty == true ||
                 (personal['city']    as String?)?.isNotEmpty == true) {
        resumeStep = 3; // location saved → resume at Bank
      } else if ((business['businessName'] as String?)?.isNotEmpty == true) {
        resumeStep = 2; // business saved → resume at Location
      } else if ((personal['fullName'] as String?)?.isNotEmpty == true) {
        resumeStep = 1; // name saved → resume at Business
      }

      if (done) await StorageService.saveOnboardingComplete(true);
      state = state.copyWith(
        isComplete:        done,
        isLoadingSettings: false,
        formData:          prefill,
        currentStep:       resumeStep,
      );
      return done;
    } catch (_) {
      state = state.copyWith(isLoadingSettings: false);
      return false;
    }
  }
}

final onboardingPod = StateNotifierProvider<OnboardingNotifier, OnboardingState>(
  (ref) => OnboardingNotifier(),
);
