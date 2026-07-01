import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static const _pinKey = 'ts_driver_secure_pin';
  static const _deviceIdKey = 'ts_driver_device_id';
  static const _qrTokenKey = 'ts_driver_qr_token';
  static const _accessTokenKey = 'ts_driver_access_token';
  static const _refreshTokenKey = 'ts_driver_refresh_token';

  static final SecureStorageService _instance =
      SecureStorageService._internal();
  factory SecureStorageService() => _instance;
  SecureStorageService._internal();

  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
        accessibility: KeychainAccessibility.first_unlock_this_device),
  );

  // PIN
  Future<void> savePin(String pin) async {
    await _storage.write(key: _pinKey, value: pin);
  }

  Future<String?> readPin() async {
    return _storage.read(key: _pinKey);
  }

  Future<void> deletePin() async {
    await _storage.delete(key: _pinKey);
  }

  // Device ID
  Future<void> saveDeviceId(String deviceId) async {
    await _storage.write(key: _deviceIdKey, value: deviceId);
  }

  Future<String?> readDeviceId() async {
    return _storage.read(key: _deviceIdKey);
  }

  // QR Token
  Future<void> saveQRToken(String token) async {
    await _storage.write(key: _qrTokenKey, value: token);
  }

  Future<String?> readQRToken() async {
    return _storage.read(key: _qrTokenKey);
  }

  Future<void> deleteQRToken() async {
    await _storage.delete(key: _qrTokenKey);
  }

  // Access Token
  Future<void> saveAccessToken(String token) async {
    await _storage.write(key: _accessTokenKey, value: token);
  }

  Future<String?> readAccessToken() async {
    return _storage.read(key: _accessTokenKey);
  }

  Future<void> deleteAccessToken() async {
    await _storage.delete(key: _accessTokenKey);
  }

  // Refresh Token
  Future<void> saveRefreshToken(String token) async {
    await _storage.write(key: _refreshTokenKey, value: token);
  }

  Future<String?> readRefreshToken() async {
    return _storage.read(key: _refreshTokenKey);
  }

  Future<void> deleteRefreshToken() async {
    await _storage.delete(key: _refreshTokenKey);
  }

  // Clear all
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
