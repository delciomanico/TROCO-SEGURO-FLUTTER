@Timeout(Duration(seconds: 60))
library;

import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:troco_seguro/services/api_service.dart';

/// Testes funcionais contra o ambiente de staging (trocoseguro.wemof.tech),
/// usando UMA CONTA DE TESTE DEDICADA — nunca uma conta de cliente real.
/// Confirmado com o dono do projecto que este ambiente é seguro para
/// operações reais (login, transferências) desde que limitadas a esta
/// conta. Ver BACKEND_PENDING_CHANGES.md para o contexto dos campos ainda
/// em falta no backend.
const _passengerPhone = '+244900000011';
const _passengerPin = '482915';
const _driverPhone = '+244900000022';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ApiService.login() persiste tokens via flutter_secure_storage — o canal
  // de plataforma não existe em `flutter_test`. Simula-o em memória para o
  // login real (e o resto do fluxo de autenticação) funcionar sem
  // MissingPluginException, tal como aconteceria num dispositivo real.
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
        await api.login(phoneNumber: _passengerPhone, password: _passengerPin);
    expect(result.isSuccess, isTrue, reason: result.error);
    expect(result.data?.accessToken, isNotNull);
    expect(api.isAuthenticated, isTrue);
  });

  test('2. getProfile devolve o utilizador de teste autenticado', () async {
    final result = await api.getProfile();
    expect(result.isSuccess, isTrue, reason: result.error);
    expect(result.data?.fullName, 'Teste Passageiro QA');
  });

  test('3. getTransactionHistory responde com sucesso', () async {
    final result = await api.getTransactionHistory();
    expect(result.isSuccess, isTrue, reason: result.error);
  });

  // Nota: `POST transactions/deposit` devolve 404 neste ambiente (staging
  // trocoseguro.wemof.tech) — só existia no backend antigo documentado em
  // API_ENDPOINTS.md (troco-seguro.onrender.com). A conta de teste não tem
  // forma de ser carregada a partir do app; os testes de transferência
  // abaixo por isso toleram tanto sucesso como "Saldo insuficiente" como
  // resultado válido — ambos confirmam que o pedido chegou bem formado à
  // lógica de negócio (o que estamos a validar), só o resultado depende de
  // haver saldo ou não na conta de teste.

  test('4. verifyTransferRecipient encontra a conta de teste do motorista', () async {
    final result = await api.verifyTransferRecipient(_driverPhone);
    expect(result.isSuccess, isTrue, reason: result.error);
    driverId = result.data?.id;
    expect(driverId, isNotEmpty);
  });

  test(
      '5. transferência por receiverPhone (fluxo existente) chega à lógica '
      'de negócio (sucesso ou "saldo insuficiente", nunca erro de validação)',
      () async {
    final result = await api.transfer(
      amount: 100,
      receiverPhone: _driverPhone,
      description: 'Teste automatizado — receiverPhone',
    );
    if (!result.isSuccess) {
      expect(result.error, contains('nsuficiente'),
          reason: 'Esperado apenas falha de saldo; qualquer outro erro indica '
              'um problema real no pedido: ${result.error}');
    }
  });

  test(
      '6. [canário] transferência por receiverId ainda é rejeitada pelo backend real — '
      'reactivar o botão "Transferir para este motorista" (removido do UI) só depois '
      'deste teste passar a ter sucesso', () async {
    expect(driverId, isNotNull,
        reason: 'depende do teste 4 (verifyTransferRecipient) ter corrido antes');
    final result = await api.transfer(
      amount: 100,
      receiverId: driverId!,
      description: 'Teste automatizado — receiverId',
    );
    // Confirmado em 2026-07-13 contra trocoseguro.wemof.tech: o backend
    // rejeita receiverId ("property receiverId should not exist"). Ver
    // BACKEND_PENDING_CHANGES.md, item 9. Este teste falhar (i.e. passar a
    // ter sucesso) é o sinal de que já é seguro reactivar a funcionalidade
    // no APP PASSAGEIRO/lib/screens/home_screen.dart (_handleIdentifyQr).
    expect(result.isSuccess, isFalse,
        reason: 'O backend passou a aceitar receiverId — reactivar a UI removida.');
    expect(result.error, contains('receiverId'));
  });
}
