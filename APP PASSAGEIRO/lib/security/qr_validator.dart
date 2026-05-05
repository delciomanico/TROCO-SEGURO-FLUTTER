import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Simple QR Validator for client-side validation of signed QR codes.
/// In production, pair with backend-issued JWS (JSON Web Signature) and public key distribution.
class QRValidator {
  /// Validates a QR code payload structure (amount, taxiId, timestamp, nonce).
  /// Returns null if valid; error message if invalid.
  static String? validateQRPayload(Map<String, dynamic> payload) {
    final requiredFields = ['amount', 'taxiId', 'timestamp', 'nonce'];
    for (final field in requiredFields) {
      if (!payload.containsKey(field)) {
        return 'QR inválido: falta campo $field';
      }
    }

    // Validate amount is positive
    if (payload['amount'] is! int || payload['amount'] <= 0) {
      return 'QR inválido: valor deve ser positivo';
    }

    // Validate timestamp is recent (within 2 minutes)
    final now = DateTime.now().millisecondsSinceEpoch;
    final qrTime = payload['timestamp'] is int ? payload['timestamp'] : 0;
    if ((now - qrTime).abs() > 120000) {
      // 2 minutes
      return 'QR expirado';
    }

    return null;
  }

  /// Simple hash-based verification: checks if payload hash matches signature.
  /// In production, use proper JWS (JSON Web Signature) with HMAC-SHA256 or RSA.
  static bool verifyQRSignature(
    Map<String, dynamic> payload,
    String signature,
    String sharedSecret,
  ) {
    try {
      final payloadJson = json.encode(payload);
      final hmac = Hmac(sha256, utf8.encode(sharedSecret));
      final digest = hmac.convert(utf8.encode(payloadJson));
      final expectedSig = digest.toString();
      return expectedSig == signature;
    } catch (e) {
      return false;
    }
  }

  /// Validate driver data from QR (basic sanity checks).
  static String? validateDriverData(Map<String, dynamic> driver) {
    if (driver['id']?.toString().isEmpty ?? true) {
      return 'Taxista inválido';
    }
    if (driver['plate']?.toString().isEmpty ?? true) {
      return 'Placa do veículo ausente';
    }
    return null;
  }

  /// Full QR validation pipeline: structure + freshness + driver data.
  static String? validateQR({
    required Map<String, dynamic> payload,
    Map<String, dynamic>? driver,
  }) {
    // Step 1: Structure validation
    final structError = validateQRPayload(payload);
    if (structError != null) return structError;

    // Step 2: Driver validation (if provided)
    if (driver != null) {
      final driverError = validateDriverData(driver);
      if (driverError != null) return driverError;
    }

    return null;
  }
}
