import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Gerenciador de segurança de PIN com proteção contra brute force
class PinGuard {
  static const int maxAttempts = 5;
  static const int lockoutMinutes = 15;
  static const String _attemptsKey = 'pin_attempts';
  static const String _lockoutKey = 'pin_lockout_until';

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  /// Valida um PIN com proteção contra brute force
  static Future<bool> validatePin({
    required String scope,
    required String enteredPin,
    required Future<String?> Function() readExpectedPin,
  }) async {
    // Verificar se está bloqueado
    if (await isLocked(scope)) {
      return false;
    }

    // Ler PIN esperado
    final expectedPin = await readExpectedPin();
    if (expectedPin == null) {
      return false;
    }

    // Comparar hashes
    final enteredHash = _hashPin(enteredPin);
    final expectedHash = _hashPin(expectedPin);

    if (enteredHash == expectedHash) {
      // Sucesso - resetar tentativas
      await _resetAttempts(scope);
      return true;
    } else {
      // Falha - incrementar tentativas
      await _incrementAttempts(scope);
      return false;
    }
  }

  /// Verifica se está bloqueado por tentativas excessivas
  static Future<bool> isLocked(String scope) async {
    final lockoutUntil = await _getLockoutUntil(scope);
    if (lockoutUntil == null) return false;
    return DateTime.now().isBefore(lockoutUntil);
  }

  /// Retorna quanto tempo falta para desbloquear (em segundos)
  static Future<int> getRemainingLockoutSeconds(String scope) async {
    final lockoutUntil = await _getLockoutUntil(scope);
    if (lockoutUntil == null) return 0;
    final remaining = lockoutUntil.difference(DateTime.now()).inSeconds;
    return remaining > 0 ? remaining : 0;
  }

  /// Retorna o número de tentativas restantes
  static Future<int> getRemainingAttempts(String scope) async {
    final attempts = await _getAttempts(scope);
    final remaining = maxAttempts - attempts;
    return remaining > 0 ? remaining : 0;
  }

  /// Hash do PIN para comparação segura
  static String _hashPin(String pin) {
    final bytes = utf8.encode(pin);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Obtém o número de tentativas falhadas
  static Future<int> _getAttempts(String scope) async {
    final key = '${_attemptsKey}_$scope';
    final value = await _storage.read(key: key);
    return value != null ? int.tryParse(value) ?? 0 : 0;
  }

  /// Incrementa o contador de tentativas falhadas
  static Future<void> _incrementAttempts(String scope) async {
    final attempts = await _getAttempts(scope) + 1;
    final key = '${_attemptsKey}_$scope';
    await _storage.write(key: key, value: attempts.toString());

    // Se atingiu o limite, bloqueia
    if (attempts >= maxAttempts) {
      final lockoutUntil = DateTime.now().add(Duration(minutes: lockoutMinutes));
      final lockKey = '${_lockoutKey}_$scope';
      await _storage.write(key: lockKey, value: lockoutUntil.toIso8601String());
    }
  }

  /// Reseta o contador de tentativas
  static Future<void> _resetAttempts(String scope) async {
    final key = '${_attemptsKey}_$scope';
    final lockKey = '${_lockoutKey}_$scope';
    await _storage.delete(key: key);
    await _storage.delete(key: lockKey);
  }

  /// Obtém a data/hora de desbloqueio
  static Future<DateTime?> _getLockoutUntil(String scope) async {
    final lockKey = '${_lockoutKey}_$scope';
    final value = await _storage.read(key: lockKey);
    if (value == null) return null;
    return DateTime.tryParse(value);
  }

  /// Limpa todos os dados de segurança (para logout)
  static Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}

/// Widget para tela de bloqueio com countdown
class LockoutInfo {
  final bool isLocked;
  final int remainingSeconds;
  final int remainingAttempts;

  LockoutInfo({
    required this.isLocked,
    required this.remainingSeconds,
    required this.remainingAttempts,
  });

  String get formattedRemainingTime {
    final minutes = remainingSeconds ~/ 60;
    final seconds = remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

/// Extension para obter info de lockout
extension PinGuardInfo on PinGuard {
  static Future<LockoutInfo> getInfo(String scope) async {
    final isLocked = await PinGuard.isLocked(scope);
    final remainingSeconds = await PinGuard.getRemainingLockoutSeconds(scope);
    final remainingAttempts = await PinGuard.getRemainingAttempts(scope);

    return LockoutInfo(
      isLocked: isLocked,
      remainingSeconds: remainingSeconds,
      remainingAttempts: remainingAttempts,
    );
  }
}
