import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:troco_seguro/services/api_service.dart';

class MockDio extends Mock implements Dio {}

Response<dynamic> _fakeTransferResponse() => Response(
      requestOptions: RequestOptions(path: 'transactions/transfer'),
      statusCode: 201,
      data: {'transactionId': 'tx-1', 'newBalance': 900},
    );

void main() {
  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  late MockDio mockDio;
  late ApiService api;

  setUp(() {
    mockDio = MockDio();
    api = ApiService.test(mockDio);
    when(() => mockDio.post(any(), data: any(named: 'data')))
        .thenAnswer((_) async => _fakeTransferResponse());
  });

  group('ApiService.transfer', () {
    test('sends receiverPhone to transactions/transfer', () async {
      await api.transfer(amount: 500, receiverPhone: '+244900000011');

      final captured = verify(
        () => mockDio.post('transactions/transfer', data: captureAny(named: 'data')),
      ).captured.single as Map<String, dynamic>;

      expect(captured['amount'], 500);
      expect(captured['receiverPhone'], '+244900000011');
    });

    test('includes description only when provided', () async {
      await api.transfer(amount: 500, receiverPhone: '+244900000011', description: 'Táxi');

      final captured = verify(
        () => mockDio.post('transactions/transfer', data: captureAny(named: 'data')),
      ).captured.single as Map<String, dynamic>;

      expect(captured['description'], 'Táxi');
    });

    test('parses the successful response into a TransactionResult', () async {
      final result = await api.transfer(amount: 500, receiverPhone: '+244900000011');

      expect(result.isSuccess, isTrue);
      expect(result.data?.transactionId, 'tx-1');
      expect(result.data?.newBalance, 900);
    });
  });

  group('ApiService.transferToUser', () {
    test('sends targetUserId and pin to wallet/transfer-to-user', () async {
      await api.transferToUser(amount: 500, targetUserId: 'driver-123', pin: '482915');

      final captured = verify(
        () => mockDio.post('wallet/transfer-to-user', data: captureAny(named: 'data')),
      ).captured.single as Map<String, dynamic>;

      expect(captured['amount'], 500);
      expect(captured['targetUserId'], 'driver-123');
      expect(captured['pin'], '482915');
      expect(captured.containsKey('phoneNumber'), isFalse);
    });

    test('asserts when neither targetUserId nor phoneNumber is given', () {
      expect(
        () => api.transferToUser(amount: 500, pin: '482915'),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
