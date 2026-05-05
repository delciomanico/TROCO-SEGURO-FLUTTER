import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';
import 'package:troco_seguro_motorista/services/secure_storage_service.dart';

/// Gerador de QR Codes seguros para pagamentos
class QrGenerator {
  static const String _version = '1.0';
  static const String _appId = 'troco_seguro_driver';

  /// Gera dados para QR Code de pagamento
  static Future<QrPaymentData> generatePaymentQr({
    required String driverId,
    required String driverName,
    int? amount,
    String? tripId,
    Map<String, dynamic>? metadata,
  }) async {
    final storage = SecureStorageService();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final nonce = const Uuid().v4().substring(0, 8);

    // Criar payload
    final payload = {
      'v': _version,
      'app': _appId,
      'type': 'payment_request',
      'driver_id': driverId,
      'driver_name': driverName,
      'ts': timestamp,
      'nonce': nonce,
      if (amount != null) 'amount': amount,
      if (tripId != null) 'trip_id': tripId,
      if (metadata != null) 'meta': metadata,
    };

    // Gerar assinatura
    final signature = _generateSignature(payload);
    payload['sig'] = signature;

    // Converter para JSON
    final jsonData = json.encode(payload);

    // Base64 encode para QR
    final base64Data = base64Encode(utf8.encode(jsonData));

    // Salvar token localmente para validação futura
    await storage.saveQRToken(signature);

    return QrPaymentData(
      rawData: base64Data,
      signature: signature,
      expiresAt: DateTime.now().add(const Duration(minutes: 10)),
      amount: amount,
      tripId: tripId,
    );
  }

  /// Valida um QR Code escaneado (para receber pagamentos)
  static QrValidationResult validateQrData(String qrData) {
    try {
      // Decodificar base64
      final jsonString = utf8.decode(base64Decode(qrData));
      final payload = json.decode(jsonString) as Map<String, dynamic>;

      // Verificar versão
      if (payload['v'] != _version) {
        return QrValidationResult(
          isValid: false,
          error: 'Versão do QR Code incompatível',
        );
      }

      // Verificar app
      final appId = payload['app'] as String?;
      if (appId != 'troco_seguro' && appId != 'troco_seguro_driver') {
        return QrValidationResult(
          isValid: false,
          error: 'QR Code inválido para este app',
        );
      }

      // Verificar timestamp (não mais que 10 minutos)
      final timestamp = payload['ts'] as int?;
      if (timestamp == null) {
        return QrValidationResult(
          isValid: false,
          error: 'QR Code sem timestamp',
        );
      }

      final qrTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final now = DateTime.now();
      if (now.difference(qrTime).inMinutes > 10) {
        return QrValidationResult(
          isValid: false,
          error: 'QR Code expirado',
        );
      }

      // Verificar assinatura
      final providedSig = payload['sig'] as String?;
      if (providedSig == null) {
        return QrValidationResult(
          isValid: false,
          error: 'QR Code sem assinatura',
        );
      }

      final payloadWithoutSig = Map<String, dynamic>.from(payload)
        ..remove('sig');
      final expectedSig = _generateSignature(payloadWithoutSig);

      if (providedSig != expectedSig) {
        return QrValidationResult(
          isValid: false,
          error: 'Assinatura inválida',
        );
      }

      // Extrair dados
      return QrValidationResult(
        isValid: true,
        type: payload['type'] as String?,
        passengerId: payload['user_id'] as String?,
        passengerName: payload['user_name'] as String?,
        driverId: payload['driver_id'] as String?,
        driverName: payload['driver_name'] as String?,
        amount: payload['amount'] as int?,
        tripId: payload['trip_id'] as String?,
        timestamp: qrTime,
        metadata: payload['meta'] as Map<String, dynamic>?,
      );
    } catch (e) {
      return QrValidationResult(
        isValid: false,
        error: 'Erro ao processar QR Code: $e',
      );
    }
  }

  /// Gera assinatura HMAC-SHA256 do payload
  static String _generateSignature(Map<String, dynamic> payload) {
    // Ordenar chaves para consistência
    final sortedKeys = payload.keys.toList()..sort();
    final sortedPayload = {for (var k in sortedKeys) k: payload[k]};
    final message = json.encode(sortedPayload);

    // Usar uma chave secreta (em produção, viria do servidor)
    const secret = 'troco_seguro_secret_key_2024';
    final key = utf8.encode(secret);
    final bytes = utf8.encode(message);

    final hmac = Hmac(sha256, key);
    final digest = hmac.convert(bytes);

    return digest.toString().substring(0, 16);
  }
}

/// Dados do QR Code de pagamento gerado
class QrPaymentData {
  final String rawData;
  final String signature;
  final DateTime expiresAt;
  final int? amount;
  final String? tripId;

  QrPaymentData({
    required this.rawData,
    required this.signature,
    required this.expiresAt,
    this.amount,
    this.tripId,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Duration get remainingTime => expiresAt.difference(DateTime.now());
}

/// Resultado da validação de QR Code
class QrValidationResult {
  final bool isValid;
  final String? error;
  final String? type;
  final String? passengerId;
  final String? passengerName;
  final String? driverId;
  final String? driverName;
  final int? amount;
  final String? tripId;
  final DateTime? timestamp;
  final Map<String, dynamic>? metadata;

  QrValidationResult({
    required this.isValid,
    this.error,
    this.type,
    this.passengerId,
    this.passengerName,
    this.driverId,
    this.driverName,
    this.amount,
    this.tripId,
    this.timestamp,
    this.metadata,
  });

  bool get isPaymentRequest => type == 'payment' || type == 'payment_request';
}
