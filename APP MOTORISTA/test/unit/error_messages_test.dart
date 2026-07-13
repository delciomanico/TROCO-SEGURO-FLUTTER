import 'package:flutter_test/flutter_test.dart';
import 'package:troco_seguro_pro/utils/error_messages.dart';

void main() {
  group('PaymentErrorMessages.friendly', () {
    test('passes through unknown messages unchanged (current backend behavior)', () {
      const raw = 'Some unmapped backend message';
      expect(PaymentErrorMessages.friendly(raw), raw);
    });

    test('falls back to a generic message when null or empty', () {
      expect(PaymentErrorMessages.friendly(null), 'Pagamento recusado pela API.');
      expect(PaymentErrorMessages.friendly(''), 'Pagamento recusado pela API.');
    });

    test('maps known keywords case-insensitively', () {
      expect(
        PaymentErrorMessages.friendly('INSUFFICIENT funds'),
        'Saldo insuficiente do passageiro para este pagamento.',
      );
      expect(
        PaymentErrorMessages.friendly('Seat already paid'),
        'Este assento já foi pago ou não está disponível.',
      );
    });
  });
}
