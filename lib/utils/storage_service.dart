import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageService {
  static const _storage = FlutterSecureStorage();

  static const _accessTokenKey        = 'seller_access_token';
  static const _refreshTokenKey       = 'seller_refresh_token';
  static const _sellerIdKey           = 'seller_id';
  static const _displayNameKey        = 'seller_display_name';
  static const _deviceIdKey           = 'seller_push_device_id';

  // In-memory cache — populated on saveTokens so interceptor never reads null
  // from an uninitialized FlutterSecureStorage instance on Android.
  static String? _cachedAccessToken;
  static String? _cachedRefreshToken;

  static Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    _cachedAccessToken  = accessToken;
    _cachedRefreshToken = refreshToken;
    await _storage.write(key: _accessTokenKey,  value: accessToken);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
  }

  static Future<String?> getAccessToken() async {
    if (_cachedAccessToken != null && _cachedAccessToken!.isNotEmpty) {
      return _cachedAccessToken;
    }
    final value = await _storage.read(key: _accessTokenKey);
    _cachedAccessToken = value;
    return value;
  }

  static Future<String?> getRefreshToken() async {
    if (_cachedRefreshToken != null && _cachedRefreshToken!.isNotEmpty) {
      return _cachedRefreshToken;
    }
    final value = await _storage.read(key: _refreshTokenKey);
    _cachedRefreshToken = value;
    return value;
  }

  static Future<void> saveSellerId(String id) async =>
      _storage.write(key: _sellerIdKey, value: id);

  static Future<String?> getSellerId() async => _storage.read(key: _sellerIdKey);

  static Future<void> saveDisplayName(String name) async =>
      _storage.write(key: _displayNameKey, value: name);

  static Future<String?> getDisplayName() async => _storage.read(key: _displayNameKey);

  static Future<void> saveDeviceId(String id) async =>
      _storage.write(key: _deviceIdKey, value: id);

  static Future<String?> getDeviceId() async => _storage.read(key: _deviceIdKey);

  static Future<void> clearDeviceId() async => _storage.delete(key: _deviceIdKey);

  static Future<void> clearAll() async {
    _cachedAccessToken  = null;
    _cachedRefreshToken = null;
    await _storage.deleteAll();
  }

  static Future<bool> isLoggedIn() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

}
