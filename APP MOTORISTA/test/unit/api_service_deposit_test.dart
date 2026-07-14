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

  group('ApiService.initiateDeposit', () {
    test('sends amount in the request body', () async {
      when(() => mockDio.post(any(), data: any(named: 'data'))).thenAnswer(
        (_) async => _fakeResponse({
          'message': 'Pedido de carregamento iniciado.',
          'transactionId': 'tx-dep-1',
          'reference': 'MCX-1784049688328',
          'status': 'PENDING',
        }),
      );

      await api.initiateDeposit(amount: 500);

      final captured = verify(
        () => mockDio.post('payments/deposit/initiate', data: captureAny(named: 'data')),
      ).captured.single as Map<String, dynamic>;

      expect(captured['amount'], 500);
    });

    test('parses the successful response, including the payment reference', () async {
      when(() => mockDio.post(any(), data: any(named: 'data'))).thenAnswer(
        (_) async => _fakeResponse({
          'transactionId': 'tx-dep-2',
          'reference': 'MCX-999',
          'status': 'PENDING',
        }),
      );

      final result = await api.initiateDeposit(amount: 1000);

      expect(result.isSuccess, isTrue);
      expect(result.data?['transactionId'], 'tx-dep-2');
      expect(result.data?['reference'], 'MCX-999');
      expect(result.data?['status'], 'PENDING');
    });
  });
}
