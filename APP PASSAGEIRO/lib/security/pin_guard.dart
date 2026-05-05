import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

class PinGuard {
  // Simple attempt limiter with exponential-ish lockouts per scope.
  // For production, consider server-side enforcement too.
  static const _attemptsKeyPrefix = 'ts_pin_attempts_';
  static const _lockUntilKeyPrefix = 'ts_pin_lock_until_';
  static const int maxAttempts = 5;

  static Duration lockDurationForFailures(int failures) {
    if (failures < maxAttempts) return Duration.zero;
    // On or above threshold: 1, 2, 4, 8, 15 minutes caps
    final steps = [1, 2, 4, 8, 15];
    final idx = (failures - maxAttempts).clamp(0, steps.length - 1);
    return Duration(minutes: steps[idx]);
  }

  static Future<bool> isLocked(String scope) async {
    final prefs = await SharedPreferences.getInstance();
    final until = prefs.getInt('$_lockUntilKeyPrefix$scope') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    return now < until;
  }

  static Future<String?> lockRemainingMessage(String scope) async {
    final prefs = await SharedPreferences.getInstance();
    final until = prefs.getInt('$_lockUntilKeyPrefix$scope') ?? 0;
    if (until == 0) return null;
    final remaining = until - DateTime.now().millisecondsSinceEpoch;
    if (remaining <= 0) return null;
    final secs = (remaining / 1000).ceil();
    final mins = (secs / 60).floor();
    final remSecs = secs % 60;
    return mins > 0
        ? 'Tente novamente em ${mins}m ${remSecs}s'
        : 'Tente novamente em ${remSecs}s';
  }

  static Future<void> _recordFailure(String scope) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_attemptsKeyPrefix$scope';
    final failures = (prefs.getInt(key) ?? 0) + 1;
    await prefs.setInt(key, failures);
    final lock = lockDurationForFailures(failures);
    if (lock > Duration.zero) {
      final until = DateTime.now().add(lock).millisecondsSinceEpoch;
      await prefs.setInt('$_lockUntilKeyPrefix$scope', until);
    }
  }

  static Future<void> resetFailures(String scope) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_attemptsKeyPrefix$scope');
    await prefs.remove('$_lockUntilKeyPrefix$scope');
  }

  static Future<bool> validatePin({
    required String scope,
    required String enteredPin,
    required Future<String?> Function() readExpectedPin,
  }) async {
    if (await isLocked(scope)) {
      return false;
    }
    final expected = await readExpectedPin();
    final ok = expected != null && enteredPin == expected;
    if (ok) {
      await resetFailures(scope);
      return true;
    }
    await _recordFailure(scope);
    return false;
  }
}
