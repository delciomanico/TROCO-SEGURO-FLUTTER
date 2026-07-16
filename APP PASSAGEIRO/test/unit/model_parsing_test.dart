import 'package:flutter_test/flutter_test.dart';
import 'package:troco_seguro/services/api_service.dart';

void main() {
  group('QrValidationResult.fromJson', () {
    test('parses driver identification fields', () {
      final result = QrValidationResult.fromJson({
        'valid': true,
        'driverId': 'drv-1',
        'driverName': 'Monarca',
        'amount': 2000,
        'paymentToken': 'tok-123',
      });

      expect(result.valid, isTrue);
      expect(result.driverId, 'drv-1');
      expect(result.driverName, 'Monarca');
      expect(result.amount, 2000);
      expect(result.paymentToken, 'tok-123');
    });

    test('prefers nested driver map fields when present', () {
      final result = QrValidationResult.fromJson({
        'valid': true,
        'driver': {'id': 'drv-2', 'name': 'Ana', 'licensePlate': 'LD-01-AA'},
      });

      expect(result.driverId, 'drv-2');
      expect(result.driverName, 'Ana');
      expect(result.licensePlate, 'LD-01-AA');
    });

    test('defaults valid to false when missing', () {
      final result = QrValidationResult.fromJson({});
      expect(result.valid, isFalse);
    });
  });

  group('TransactionResult.fromJson', () {
    test('feeAmount stays null when backend does not send it (current reality)', () {
      final result = TransactionResult.fromJson({
        'transactionId': 'tx-1',
        'amount': 1000,
        'newBalance': 5000,
      });

      expect(result.transactionId, 'tx-1');
      expect(result.amount, 1000);
      expect(result.newBalance, 5000);
      expect(result.feeAmount, isNull);
    });

    test('feeAmount picks up any of the plausible field names', () {
      expect(TransactionResult.fromJson({'feeAmount': 50}).feeAmount, 50);
      expect(TransactionResult.fromJson({'fee': 30}).feeAmount, 30);
      expect(TransactionResult.fromJson({'tax': 20}).feeAmount, 20);
      expect(TransactionResult.fromJson({'platformFeeApplied': 10}).feeAmount, 10);
    });
  });

  group('PaymentResult.fromJson', () {
    test('parses required fields with defaults and nullable feeAmount', () {
      final result = PaymentResult.fromJson({});
      expect(result.transactionId, '');
      expect(result.amount, 0);
      expect(result.newBalance, 0);
      expect(result.status, 'completed');
      expect(result.feeAmount, isNull);
    });

    test('feeAmount reflects backend value when present', () {
      final result = PaymentResult.fromJson({'feeAmount': 75});
      expect(result.feeAmount, 75);
    });
  });

  group('RecipientInfo.fromJson', () {
    test('parses id/name/phone with fallback keys', () {
      final result = RecipientInfo.fromJson({
        'userId': 'u-1',
        'fullName': 'João',
        'phoneNumber': '+244900000011',
      });
      expect(result.id, 'u-1');
      expect(result.name, 'João');
      expect(result.phone, '+244900000011');
    });

    test('defaults to empty strings when fields are missing', () {
      final result = RecipientInfo.fromJson({});
      expect(result.id, '');
      expect(result.name, '');
      expect(result.phone, '');
    });
  });
}
