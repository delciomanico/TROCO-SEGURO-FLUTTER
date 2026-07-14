@Timeout(Duration(seconds: 60))
library;

import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:troco_seguro_pro/services/api_service.dart';

/// Testes funcionais contra o ambiente de staging (trocoseguro.wemof.tech),
/// usando UMA CONTA DE TESTE DEDICADA — nunca uma conta de cliente real.
/// Confirmado com o dono do projecto que este ambiente é seguro para
/// operações reais. Ver BACKEND_PENDING_CHANGES.md para o contexto dos
/// campos ainda em falta no backend.
const _driverPhone = '+244900000022';
const _driverPin = '738264';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ApiService.login() persiste tokens via flutter_secure_storage — o canal
  // de plataforma não existe em `flutter_test`. Simula-o em memória para o
  // login real funcionar sem MissingPluginException, tal como num
  // dispositivo real.
  final fakeSecureStorage = <String, String>{};
  const secureStorageChannel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  late ApiService api;

  setUpAll(() async {
    HttpOverrides.global = null; // permitir rede real neste ficheiro (staging)
    await dotenv.load(fileName: '.env');
    api = ApiService();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, (call) async {
      final args = (call.arguments as Map?)?.cast<String, dynamic>() ?? {};
      switch (call.method) {
        case 'write':
          fakeSecureStorage[args['key'] as String] = args['value'] as String;
          return null;
        case 'read':
          return fakeSecureStorage[args['key'] as String];
        case 'readAll':
          return fakeSecureStorage;
        case 'delete':
          fakeSecureStorage.remove(args['key'] as String);
          return null;
        case 'deleteAll':
          fakeSecureStorage.clear();
          return null;
        case 'containsKey':
          return fakeSecureStorage.containsKey(args['key'] as String);
        default:
          return null;
      }
    });
  });

  String? driverId;

  test('1. login com a conta de teste devolve tokens válidos', () async {
    final result =
        await api.login(phoneNumber: _driverPhone, password: _driverPin);
    expect(result.isSuccess, isTrue, reason: result.error);
    expect(result.data?.accessToken, isNotNull);
    expect(api.isAuthenticated, isTrue);
  });

  test('2. getProfile devolve o motorista de teste autenticado', () async {
    final result = await api.getProfile();
    expect(result.isSuccess, isTrue, reason: result.error);
    expect(result.data?.fullName, 'Teste Motorista QA');
    driverId = result.data?.id;
  });

  test('3. getBalance responde com sucesso', () async {
    final result = await api.getBalance();
    expect(result.isSuccess, isTrue, reason: result.error);
    expect(result.data, isA<int>());
  });

  test('4. getMyRating responde sem erro para a conta de teste', () async {
    expect(driverId, isNotNull, reason: 'depende do teste 2 (getProfile)');
    final result = await api.getMyRating(driverId!);
    expect(result.isSuccess, isTrue, reason: result.error);
  });

  test(
      '5. uploadDocuments (carta de condução) — SKIP: requer um ficheiro de '
      'imagem válido; testar manualmente para não poluir a verificação de '
      'identidade da conta de teste com dados inválidos',
      () {},
      skip: 'Cobertura manual — ver BACKEND_PENDING_CHANGES.md');

  test(
      '6. requestWithdrawal — SKIP por omissão: cria um pedido real de saque '
      'no staging partilhado; correr manualmente só quando necessário',
      () async {
    final result = await api.requestWithdrawal(amount: 1000, iban: 'AO06 TESTE');
    expect(result.isSuccess, isTrue, reason: result.error);
  }, skip: 'Efeito colateral real no ambiente partilhado — correr manualmente');

  test(
      '7. initiateDeposit gera uma referência de pagamento pendente '
      '(payments/deposit/initiate, ver BACKEND_PENDING_CHANGES.md item 10)',
      () async {
    final result = await api.initiateDeposit(amount: 500);
    expect(result.isSuccess, isTrue, reason: result.error);
    expect(result.data?['reference'], isNotNull);
    expect(result.data?['status'], 'PENDING');
  });
}
