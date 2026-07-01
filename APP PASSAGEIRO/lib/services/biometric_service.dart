import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

class BiometricService {
  static final BiometricService _instance = BiometricService._internal();
  factory BiometricService() => _instance;
  BiometricService._internal();

  final LocalAuthentication _auth = LocalAuthentication();

  Future<bool> isBiometricAvailable() async {
    try {
      return await _auth.isDeviceSupported();
    } catch (e) {
      return false;
    }
  }

  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } catch (e) {
      return [];
    }
  }

  Future<bool> authenticate({
    required String reason,
    bool useErrorDialogs = true,
    bool stickyAuth = false,
  }) async {
    try {
      final isSupported = await _auth.isDeviceSupported();
      if (!isSupported) return false;

      return await _auth.authenticate(
        localizedReason: reason,
        options: AuthenticationOptions(
          stickyAuth: stickyAuth,
          biometricOnly: false,
          useErrorDialogs: useErrorDialogs,
        ),
      );
    } catch (e) {
      debugPrint('❌ Biometric Auth Error: $e');
      return false;
    }
  }

  /// Authenticate with optional biometric step-up; if biometric fails or unavailable, returns false
  /// (caller should then prompt for PIN as fallback).
  Future<bool> authenticateWithFallback(String reason) async {
    if (await isBiometricAvailable()) {
      return authenticate(reason: reason);
    }
    return false;
  }
}
