import 'package:flutter_test/flutter_test.dart';
import 'package:troco_seguro_pro/services/api_service.dart';

void main() {
  group('PassengerQrPaymentResult.fromJson', () {
    test('parses the real platformFeeApplied amount already returned by the backend', () {
      final result = PassengerQrPaymentResult.fromJson({
        'success': true,
        'transactionId': 'tx-1',
        'platformFeeApplied': 50,
        'newBalance': 1950,
      });

      expect(result.success, isTrue);
      expect(result.transactionId, 'tx-1');
      expect(result.platformFeeApplied, 50);
      expect(result.newBalance, 1950);
    });

    test('defaults platformFeeApplied to 0 when absent', () {
      final result = PassengerQrPaymentResult.fromJson({'success': true});
      expect(result.platformFeeApplied, 0);
    });
  });

  group('SessionSeatsResult.fromJson', () {
    test('parses aggregate fields (current backend reality)', () {
      final result = SessionSeatsResult.fromJson({
        'active': true,
        'totalSeats': 10,
        'totalPayments': 3,
        'availableSeats': 7,
        'revenue': 6000,
      });

      expect(result.active, isTrue);
      expect(result.totalSeats, 10);
      expect(result.paidSeats, 3);
      expect(result.availableSeats, 7);
      expect(result.revenue, 6000);
      expect(result.seats, isNull);
    });

    test('parses per-seat detail when the backend eventually sends it', () {
      final result = SessionSeatsResult.fromJson({
        'active': true,
        'seats': [
          {'label': 'Assento 1', 'paid': true},
          {'seatLabel': 'Assento 2', 'isPaid': false},
        ],
      });

      expect(result.seats, isNotNull);
      expect(result.seats!.length, 2);
      expect(result.seats![0].label, 'Assento 1');
      expect(result.seats![0].paid, isTrue);
      expect(result.seats![1].label, 'Assento 2');
      expect(result.seats![1].paid, isFalse);
    });
  });

  group('VirtualCardQrResult.fromJson', () {
    test('reads nested card map when present', () {
      final result = VirtualCardQrResult.fromJson({
        'card': {'cardNumber': '1234', 'ownerName': 'Ana', 'id': 'card-1'},
      });
      expect(result.cardNumber, '1234');
      expect(result.ownerName, 'Ana');
      expect(result.cardId, 'card-1');
    });

    test('falls back to top-level fields when no card map exists', () {
      final result = VirtualCardQrResult.fromJson({
        'number': '5678',
        'name': 'João',
        'cardId': 'card-2',
      });
      expect(result.cardNumber, '5678');
      expect(result.ownerName, 'João');
      expect(result.cardId, 'card-2');
    });
  });

  group('CardBalanceResult.fromJson', () {
    test('parses balance with fallback key', () {
      expect(CardBalanceResult.fromJson({'balance': 3000}).balance, 3000);
      expect(CardBalanceResult.fromJson({'saldo': 1500}).balance, 1500);
      expect(CardBalanceResult.fromJson({}).balance, 0);
    });
  });
}
