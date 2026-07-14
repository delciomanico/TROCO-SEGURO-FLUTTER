import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:troco_seguro/services/api_service.dart';

class MockDio extends Mock implements Dio {}

Response<dynamic> _fakeInitiateResponse() => Response(
      requestOptions: RequestOptions(path: 'payments/deposit/initiate'),
      statusCode: 201,
      data: {
        'message': 'Pedido de carregamento iniciado.',
        'transactionId': 'tx-dep-1',
        'reference': 'MCX-1784049688328',
        'status': 'PENDING',
      },
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
        .thenAnswer((_) async => _fakeInitiateResponse());
  });

  group('ApiService.initiateDeposit', () {
    test('sends amount in the request body', () async {
      await api.initiateDeposit(amount: 500);

      final captured = verify(
        () => mockDio.post('payments/deposit/initiate', data: captureAny(named: 'data')),
      ).captured.single as Map<String, dynamic>;

      expect(captured['amount'], 500);
    });

    test('parses the successful response into a DepositInitiateResult', () async {
      final result = await api.initiateDeposit(amount: 500);

      expect(result.isSuccess, isTrue);
      expect(result.data?.transactionId, 'tx-dep-1');
      expect(result.data?.reference, 'MCX-1784049688328');
      expect(result.data?.status, 'PENDING');
    });
  });
}
