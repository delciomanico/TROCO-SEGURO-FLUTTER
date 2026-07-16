import 'package:flutter_test/flutter_test.dart';
import 'package:troco_seguro/utils/error_messages.dart';

void main() {
  group('PaymentErrorMessages.friendly', () {
    test('passes through unknown messages unchanged (current backend behavior)', () {
      const raw = 'Some unmapped backend message';
      expect(
        PaymentErrorMessages.friendly(raw, fallback: 'fallback'),
        raw,
      );
    });

    test('uses fallback when the message is null or empty', () {
      expect(PaymentErrorMessages.friendly(null, fallback: 'fallback'), 'fallback');
      expect(PaymentErrorMessages.friendly('', fallback: 'fallback'), 'fallback');
    });

    test('maps known keywords case-insensitively', () {
      expect(
        PaymentErrorMessages.friendly('Insufficient balance', fallback: 'x'),
        'Saldo insuficiente para este pagamento.',
      );
      expect(
        PaymentErrorMessages.friendly('QR code has EXPIRED', fallback: 'x'),
        'O código QR expirou. Peça ao motorista para gerar um novo.',
      );
    });
  });
}
