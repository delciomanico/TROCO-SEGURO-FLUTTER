import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:troco_seguro_pro/services/api_service.dart';

class MockDio extends Mock implements Dio {}

Response<dynamic> _fakeResponse(Map<String, dynamic> data) => Response(
      requestOptions: RequestOptions(path: ''),
      statusCode: 201,
      data: data,
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
  });

  group('ApiService.transfer', () {
    test('sends amount, receiverPhone and optional description', () async {
      when(() => mockDio.post(any(), data: any(named: 'data')))
          .thenAnswer((_) async => _fakeResponse({'transactionId': 'tx-1', 'newBalance': 900}));

      await api.transfer(amount: 500, receiverPhone: '+244900000022', description: 'Devolução');

      final captured = verify(
        () => mockDio.post('transactions/transfer', data: captureAny(named: 'data')),
      ).captured.single as Map<String, dynamic>;

      expect(captured['amount'], 500);
      expect(captured['receiverPhone'], '+244900000022');
      expect(captured['description'], 'Devolução');
    });

    test('parses the successful response into a TransactionResult', () async {
      when(() => mockDio.post(any(), data: any(named: 'data')))
          .thenAnswer((_) async => _fakeResponse({'transactionId': 'tx-2', 'newBalance': 700}));

      final result = await api.transfer(amount: 300, receiverPhone: '+244900000011');

      expect(result.isSuccess, isTrue);
      expect(result.data?.transactionId, 'tx-2');
      expect(result.data?.newBalance, 700);
    });
  });

  group('ApiService.requestWithdrawal (Banco vs MCX Express toggle is cosmetic)', () {
    test('sends the same request shape regardless of which method label the UI shows', () async {
      when(() => mockDio.post(any(), data: any(named: 'data')))
          .thenAnswer((_) async => _fakeResponse({}));

      await api.requestWithdrawal(amount: 5000, iban: 'AO06 0000 0000 0000 0000 0000 0');
      await api.requestWithdrawal(amount: 5000, iban: '923456789');

      final calls = verify(
        () => mockDio.post('transactions/withdraw', data: captureAny(named: 'data')),
      ).captured;

      expect(calls, hasLength(2));
      for (final call in calls) {
        final data = call as Map<String, dynamic>;
        expect(data.keys.toSet(), {'amount', 'iban'});
        expect(data['amount'], 5000);
      }
    });
  });
}
