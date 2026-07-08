// Teste de integração: confirma que quando o access token E o refresh token
// estão inválidos/expirados, o interceptor da API limpa a sessão e dispara
// `sessionExpiredListenable` (o que o AppController usa para fazer logout
// automático e voltar ao ecrã de login).
//
// Usa o backend real (trocoseguro.wemof.tech) com tokens inventados para
// simular de forma realista um 401 + falha de refresh, sem mocks de rede.
//
// Execute com: flutter test test/session_expiry_test.dart

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:troco_seguro_pro/services/api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    // TestWidgetsFlutterBinding instala um HttpOverrides fake que responde
    // sempre 400 sem tocar na rede. Removê-lo permite este teste de
    // integração fazer pedidos reais ao backend.
    HttpOverrides.global = null;

    dotenv.loadFromString(
        envString: 'BASE_URL=https://trocoseguro.wemof.tech/api/v1/');
    SharedPreferences.setMockInitialValues({});

    const secureStorageChannel =
        MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, (call) async {
      switch (call.method) {
        case 'read':
          return null;
        case 'readAll':
          return <String, String>{};
        case 'write':
        case 'delete':
        case 'deleteAll':
          return null;
        case 'containsKey':
          return false;
        default:
          return null;
      }
    });
  });

  test(
      'token e refresh token inválidos -> sessão termina automaticamente (401 real do backend)',
      () async {
    final api = ApiService();
    await api.loadTokens();

    api.setTokens(
      'bogus-access-token-simulating-expired',
      'bogus-refresh-token-simulating-expired',
    );
    expect(api.isAuthenticated, isTrue,
        reason: 'deveria estar autenticado antes do 401');

    var sessionExpiredCount = 0;
    void listener() => sessionExpiredCount++;
    api.sessionExpiredListenable.addListener(listener);
    addTearDown(() => api.sessionExpiredListenable.removeListener(listener));

    final result = await api.getProfile();

    expect(result.isSuccess, isFalse,
        reason: 'pedido com token inválido deve falhar');
    expect(sessionExpiredCount, 1,
        reason:
            'sessionExpiredListenable deve disparar exactamente uma vez após 401 + refresh falhado');
    expect(api.isAuthenticated, isFalse,
        reason: 'tokens devem ser limpos localmente após a sessão expirar');
  });
}
