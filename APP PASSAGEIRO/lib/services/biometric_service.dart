import 'package:local_auth/local_auth.dart';

class BiometricService {
  static final BiometricService _instance = BiometricService._internal();
  factory BiometricService() => _instance;
  BiometricService._internal();

  final LocalAuthentication _auth = LocalAuthentication();

  Future<bool> isBiometricAvailable() async {
    try {
      return await _auth.canCheckBiometrics;
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
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      final hasBiometrics = (await _auth.getAvailableBiometrics()).isNotEmpty;

      print('🔍 Biometric Auth Check:');
      print('   - canCheckBiometrics: $canCheck');
      print('   - isDeviceSupported: $isSupported');
      print('   - hasBiometrics: $hasBiometrics');

      if (!isSupported) return false;

      return await _auth.authenticate(
        localizedReason: reason,
        options: AuthenticationOptions(
          stickyAuth: stickyAuth,
          biometricOnly:
              false, // Alterado para false para permitir face/fingerprint genérico e PIN do sistema se necessário
          useErrorDialogs: useErrorDialogs,
          sensitiveTransaction: true,
        ),
      );
    } catch (e) {
      print('❌ Biometric Auth Error: $e');
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
