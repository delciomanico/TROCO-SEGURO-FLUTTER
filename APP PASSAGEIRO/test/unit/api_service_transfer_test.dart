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
    test('sends only receiverPhone when receiverId is not provided', () async {
      await api.transfer(amount: 500, receiverPhone: '+244900000011');

      final captured = verify(
        () => mockDio.post('transactions/transfer', data: captureAny(named: 'data')),
      ).captured.single as Map<String, dynamic>;

      expect(captured['amount'], 500);
      expect(captured['receiverPhone'], '+244900000011');
      expect(captured.containsKey('receiverId'), isFalse);
    });

    test('sends only receiverId when transferring directly to a driver', () async {
      await api.transfer(amount: 500, receiverId: 'driver-123');

      final captured = verify(
        () => mockDio.post('transactions/transfer', data: captureAny(named: 'data')),
      ).captured.single as Map<String, dynamic>;

      expect(captured['amount'], 500);
      expect(captured['receiverId'], 'driver-123');
      expect(captured.containsKey('receiverPhone'), isFalse);
    });

    test('includes description only when provided', () async {
      await api.transfer(amount: 500, receiverPhone: '+244900000011', description: 'Táxi');

      final captured = verify(
        () => mockDio.post('transactions/transfer', data: captureAny(named: 'data')),
      ).captured.single as Map<String, dynamic>;

      expect(captured['description'], 'Táxi');
    });

    test('asserts when neither receiverPhone nor receiverId is given', () {
      expect(
        () => api.transfer(amount: 500),
        throwsA(isA<AssertionError>()),
      );
    });

    test('parses the successful response into a TransactionResult', () async {
      final result = await api.transfer(amount: 500, receiverPhone: '+244900000011');

      expect(result.isSuccess, isTrue);
      expect(result.data?.transactionId, 'tx-1');
      expect(result.data?.newBalance, 900);
    });
  });
}
