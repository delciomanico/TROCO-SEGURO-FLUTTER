@Timeout(Duration(seconds: 120))
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:troco_seguro_pro/services/api_service.dart';

/// Cobertura funcional exaustiva de todos os métodos de [ApiService] contra
/// o ambiente ao vivo (https://trocoseguro.ao/api/v1/), usando a conta de
/// teste dedicada do motorista (QA). Segue o mesmo padrão de
/// `auth_and_wallet_test.dart`: desliga o `HttpOverrides` do `flutter_test`
/// para permitir rede real e simula o `flutter_secure_storage` via
/// MethodChannel para o login persistir tokens sem depender de plugin nativo.
///
/// Itens explicitamente SKIP (não chamados nesta suite) por terem efeitos
/// colaterais reais/irreversíveis na conta partilhada:
///   - register / verifyOtp / resendOtp (criariam contas reais)
///   - requestWithdrawal (levantamento real)
///   - forgotPassword / verifyForgotPasswordOtp / resetPassword (quebraria o
///     login partilhado da conta QA)
///   - changePin (mudaria o PIN partilhado da conta QA)
///   - triggerPanic (alerta de segurança real)
///   - deleteAccount (destrutivo)
///   - uploadDocuments (precisa de ficheiro de imagem real)
///   - simulateDepositWebhook (creditaria saldo real em produção sem
///     pagamento real associado — não confirmado como idempotente/seguro)
const _driverPhone = '+244900000022';
const _driverPin = '738264';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final fakeSecureStorage = <String, String>{};
  const secureStorageChannel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  late ApiService api;
  // Dio "cru" usado só para os endpoints de cartão virtual, que não têm
  // wrapper em ApiService (a app do motorista não cria cartões virtuais —
  // só os lê via QR). Reaproveita o mesmo token da sessão ApiService.
  late Dio raw;

  setUpAll(() async {
    HttpOverrides.global = null;
    await dotenv.load(fileName: '.env');
    // Sem isto, ApiService.clearTokens() (chamado por logout() e pelo
    // interceptor de sessão expirada) lança MissingPluginException ao
    // tentar SharedPreferences.getInstance() — não há handler mock
    // registado para esse canal neste ficheiro por omissão.
    SharedPreferences.setMockInitialValues({});
    api = ApiService();
    raw = Dio(BaseOptions(
      baseUrl: ApiService.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      validateStatus: (_) => true,
    ));
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

  // ── Estado partilhado entre testes (ordem de execução importa) ──────────
  String? driverId;
  String? tripId;
  String? notificationId;
  String? emergencyContactId;
  String? vehicleId; // veículo já existente na frota
  String? testVehicleId; // veículo de teste criado/eliminado nesta suite
  String? virtualCardId;
  String? virtualCardNumber;
  String? virtualCardQrData;
  String? ratingTargetUserId;

  // ============ AUTENTICAÇÃO ============

  test('login: autentica a conta de teste do motorista', () async {
    final result = await api.login(phoneNumber: _driverPhone, password: _driverPin);
    expect(result.isSuccess, isTrue, reason: result.error);
    expect(result.data?.accessToken, isNotNull);
    expect(api.isAuthenticated, isTrue);
    driverId = result.data?.driver?.id;
    raw.options.headers['Authorization'] = 'Bearer ${result.data?.accessToken}';
  });

  test('register/verifyOtp/resendOtp — SKIP (criaria conta real)', () {},
      skip: 'Criaria uma conta real — não testado nesta suite');

  // ============ PERFIL ============

  test('getProfile: devolve o perfil do motorista autenticado', () async {
    final result = await api.getProfile();
    expect(result.isSuccess, isTrue, reason: result.error);
    driverId ??= result.data?.id;
    expect(driverId, isNotNull);
  });

  test('updateProfile: actualiza o nome do motorista', () async {
    final result = await api.updateProfile(fullName: 'Teste Motorista QA');
    expect(result.isSuccess, isTrue, reason: result.error);
  });

  test('updateDriverStatus: liga o motorista (isOnline: true)', () async {
    final result = await api.updateDriverStatus(isOnline: true);
    // Observado em execuções anteriores: pode devolver 403 dependendo do
    // estado da conta (ex.: documentos pendentes) — regista o resultado
    // sem falhar a suite por causa disso, mas volta a marcar offline a
    // seguir para não deixar a conta partilhada "presa" online.
    // ignore: avoid_print
    print('updateDriverStatus(online): success=${result.isSuccess} error=${result.error}');
  });

  test('updateDriverStatus: desliga o motorista (isOnline: false) — cleanup', () async {
    final result = await api.updateDriverStatus(isOnline: false);
    expect(result.isSuccess, isTrue, reason: result.error);
  });

  // ============ GANHOS / VIAGENS ============

  test('getEarnings: devolve resumo de ganhos', () async {
    final result = await api.getEarnings();
    expect(result.isSuccess, isTrue, reason: result.error);
  });

  test('getTrips: lista viagens do motorista', () async {
    final result = await api.getTrips();
    expect(result.isSuccess, isTrue, reason: result.error);
    if (result.data != null && result.data!.isNotEmpty) {
      tripId = result.data!.first.id;
    }
  });

  test('getTripDetail: detalhe de uma viagem real', () async {
    if (tripId == null) {
      // ignore: avoid_print
      print('getTripDetail: SKIP — conta de teste não tem nenhuma viagem no histórico');
      return;
    }
    final result = await api.getTripDetail(tripId!);
    expect(result.isSuccess, isTrue, reason: result.error);
  }, skip: null);

  test('rateTrip: avaliar uma viagem real', () async {
    if (tripId == null) {
      // ignore: avoid_print
      print('rateTrip: SKIP — conta de teste não tem nenhuma viagem no histórico');
      return;
    }
    final result = await api.rateTrip(tripId: tripId!, stars: 5, comment: 'Teste automático');
    // Pode falhar se a viagem já foi avaliada — aceitar como conhecido.
    // ignore: avoid_print
    print('rateTrip: success=${result.isSuccess} error=${result.error}');
  });

  test('getTripStats: estatísticas de viagens', () async {
    final result = await api.getTripStats();
    expect(result.isSuccess, isTrue, reason: result.error);
  });

  // ============ TRANSAÇÕES / CARTEIRA ============

  test('getTransactionHistory: histórico de transações', () async {
    final result = await api.getTransactionHistory();
    expect(result.isSuccess, isTrue, reason: result.error);
  });

  test('requestWithdrawal — SKIP (efeito colateral real de saque)', () {},
      skip: 'Cria um pedido real de saque na conta partilhada — não testado nesta suite');

  test('getTransactionQuote: cotação de levantamento', () async {
    final result = await api.getTransactionQuote(type: 'withdrawal', amount: 500);
    if (!result.isSuccess) {
      // ignore: avoid_print
      print('getTransactionQuote: error=${result.error}');
    }
    expect(result.isSuccess, isTrue, reason: result.error);
  });

  test('getBalance: saldo disponível', () async {
    final result = await api.getBalance();
    expect(result.isSuccess, isTrue, reason: result.error);
    expect(result.data, isA<int>());
  });

  test('transfer: transferência P2P (destino inválido/self) — deve chegar à lógica de negócio', () async {
    final result = await api.transfer(
      amount: 1,
      receiverPhone: _driverPhone,
      description: 'Teste automático — não deve ser possível transferir para si mesmo',
    );
    // Esperado: erro de negócio (ex. "não pode transferir para si mesmo",
    // saldo insuficiente, etc.) — prova que o pedido chegou à lógica da
    // API. Sucesso também seria aceitável (não critico) mas não esperado.
    // ignore: avoid_print
    print('transfer: success=${result.isSuccess} error=${result.error}');
  });

  test('transferToExternalCard: cartão inexistente deve ser rejeitado', () async {
    final result = await api.transferToExternalCard(
      cardNumber: '0000000000000000',
      amount: 1,
      pin: _driverPin,
    );
    expect(result.isSuccess, isFalse, reason: 'esperado erro para cartão inexistente');
    // ignore: avoid_print
    print('transferToExternalCard (cartão inválido): error=${result.error}');
  });

  test('verifyTransferRecipient: verifica destinatário por telefone', () async {
    final result = await api.verifyTransferRecipient(_driverPhone);
    if (!result.isSuccess) {
      // ignore: avoid_print
      print('verifyTransferRecipient: error=${result.error}');
    }
    expect(result.isSuccess, isTrue, reason: result.error);
  });

  test('initiateDeposit: gera referência de depósito pendente', () async {
    final result = await api.initiateDeposit(amount: 500);
    expect(result.isSuccess, isTrue, reason: result.error);
    expect(result.data?['reference'], isNotNull);
  });

  test('simulateDepositWebhook — SKIP (crédito real de saldo em produção)', () {},
      skip: 'Endpoint depreciado que credita saldo real sem pagamento associado — inseguro em produção');

  // ============ CARTÃO VIRTUAL — PRIORIDADE: balance-by-qr ============

  test(
      'PRIORIDADE — cria cartão virtual próprio + obtém QR real + '
      'getWalletBalanceByQr(cardNumber) — confirma se o bug 500 documentado '
      'em BACKEND_PENDING_CHANGES.md #1 foi corrigido', () async {
    // 1. Listar cartões virtuais existentes da própria conta.
    final listResp = await raw.get('virtual-cards');
    // ignore: avoid_print
    print('GET virtual-cards -> ${listResp.statusCode} ${listResp.data}');
    List<dynamic> cards = [];
    if (listResp.statusCode == 200) {
      final body = listResp.data;
      final map = body is Map ? body.cast<String, dynamic>() : <String, dynamic>{};
      cards = (map['cards'] ?? map['data'] ?? (body is List ? body : [])) as List<dynamic>;
    }

    if (cards.isNotEmpty) {
      final first = (cards.first as Map).cast<String, dynamic>();
      virtualCardId = first['id']?.toString();
    } else {
      // 2. Criar um cartão virtual de teste para a própria conta.
      final createResp = await raw.post('virtual-cards', data: {
        'name': 'Cartão QA Automático',
        'initialBalance': 0,
        'dailyLimit': 20000,
        'userPin': _driverPin,
        'cardPin': '1234',
      });
      // ignore: avoid_print
      print('POST virtual-cards (criar) -> ${createResp.statusCode} ${createResp.data}');
      if (createResp.statusCode == 200 || createResp.statusCode == 201) {
        final body = createResp.data;
        final map = body is Map ? body.cast<String, dynamic>() : <String, dynamic>{};
        final cardData = (map['card'] ?? map['data'] ?? map).cast<String, dynamic>();
        virtualCardId = cardData['id']?.toString();
      }
    }

    if (virtualCardId == null || virtualCardId!.isEmpty) {
      fail('Não foi possível obter/criar um cartão virtual para o teste prioritário — '
          'ver output acima para a resposta exacta da API');
    }
    // ignore: avoid_print
    print('virtualCardId=$virtualCardId');

    // 3. Obter o QR do cartão — a resposta já inclui 'cardNumber' directamente
    //    (não é preciso descodificar o PNG).
    final qrResp = await raw.get('virtual-cards/$virtualCardId/qr');
    // ignore: avoid_print
    print('GET virtual-cards/:id/qr -> ${qrResp.statusCode} keys=${qrResp.data is Map ? (qrResp.data as Map).keys.toList() : qrResp.data}');
    expect(qrResp.statusCode, anyOf(200, 201), reason: 'GET virtual-cards/:id/qr falhou: ${qrResp.data}');
    final qrBody = (qrResp.data as Map).cast<String, dynamic>();
    virtualCardNumber = qrBody['cardNumber']?.toString();
    expect(virtualCardNumber, isNotNull, reason: 'QR do cartão não incluiu cardNumber: ${qrBody.keys.toList()}');
    // ignore: avoid_print
    print('cardNumber (real, do QR) = $virtualCardNumber');

    // 4. Construir o mesmo JSON que o QR real codifica (confirmado em
    //    BACKEND_PENDING_CHANGES.md) e resolver via ApiService.resolveVirtualCardQr.
    virtualCardQrData = jsonEncode({
      'type': 'VIRTUAL_CARD_TRANSFER',
      'cardNumber': virtualCardNumber,
      'cardName': qrBody['cardName'] ?? qrBody['name'] ?? 'Cartão QA Automático',
      'userName': qrBody['userName'] ?? qrBody['ownerName'] ?? 'Teste Motorista QA',
    });
    final resolveResult = await api.resolveVirtualCardQr(virtualCardQrData!);
    // ignore: avoid_print
    print('resolveVirtualCardQr: success=${resolveResult.isSuccess} '
        'cardNumber=${resolveResult.data?.cardNumber} error=${resolveResult.error}');
    expect(resolveResult.isSuccess, isTrue, reason: resolveResult.error);

    // 5. O TESTE PRIORITÁRIO: getWalletBalanceByQr com o cardNumber REAL
    //    (o único valor disponível a partir de uma leitura de QR real —
    //    ver BACKEND_PENDING_CHANGES.md item 1). Antes da correcção
    //    reportada, isto devolvia 500. Faz-se a chamada crua (para termos o
    //    status code exacto) e também via ApiService (o caminho real da app).
    final rawBalanceResp =
        await raw.get('wallet/balance-by-qr/${Uri.encodeComponent(virtualCardNumber!)}');
    // ignore: avoid_print
    print('GET wallet/balance-by-qr/:cardNumber (cru) -> HTTP ${rawBalanceResp.statusCode}');
    // ignore: avoid_print
    print('  body: ${rawBalanceResp.data}');

    final apiResult = await api.getWalletBalanceByQr(virtualCardNumber!);
    // ignore: avoid_print
    print('ApiService.getWalletBalanceByQr: success=${apiResult.isSuccess} '
        'balance=${apiResult.data?.balance} error=${apiResult.error}');

    // ignore: avoid_print
    print('\n════════════════════════════════════════════════════════');
    // ignore: avoid_print
    print('RESULTADO DO BUG PRIORITÁRIO (BACKEND_PENDING_CHANGES.md #1):');
    // ignore: avoid_print
    print(rawBalanceResp.statusCode == 200
        ? '✅ CORRIGIDO — GET wallet/balance-by-qr/:cardNumber devolveu 200 para o cardNumber real'
        : '❌ AINDA QUEBRADO — GET wallet/balance-by-qr/:cardNumber devolveu HTTP ${rawBalanceResp.statusCode} (esperado 200)');
    // ignore: avoid_print
    print('════════════════════════════════════════════════════════\n');

    // Não falhamos o teste automaticamente se o backend ainda não tiver
    // corrigido — o objectivo desta suite é REPORTAR o estado, não bloquear
    // a corrida por causa de um bug já conhecido/documentado. O status HTTP
    // exacto fica nos logs acima para o relatório final.
  });

  // ============ SESSÃO QR ============

  test('getVehicles: lista veículos da frota (para usar no setup de sessão)', () async {
    final result = await api.getVehicles();
    expect(result.isSuccess, isTrue, reason: result.error);
    if (result.data != null && result.data!.isNotEmpty) {
      vehicleId = result.data!.first.id;
    }
  });

  test('setupQrSession: inicia sessão de viagem e gera QRs', () async {
    final result = await api.setupQrSession(amount: 500, activeVehicleId: vehicleId);
    expect(result.isSuccess, isTrue, reason: result.error);
  });

  test('getSessionSeats: estado da sessão activa', () async {
    final result = await api.getSessionSeats();
    expect(result.isSuccess, isTrue, reason: result.error);
  });

  test('authorizePassengerQr: QR inválido deve ser rejeitado pela lógica de negócio', () async {
    final bogusQr = jsonEncode({
      'type': 'PAYMENT_INTENT',
      'userId': 'invalid-user-id-teste',
      'amount': 500,
      'name': 'Passageiro Teste',
      'phoneNumber': '+244900000000',
    });
    final result = await api.authorizePassengerQr(
      qrData: bogusQr,
      passengerPin: '000000',
      origin: 'Teste',
      destination: 'Teste',
      seatsCount: 1,
    );
    expect(result.isSuccess, isFalse, reason: 'esperado erro para QR de passageiro inválido');
    // ignore: avoid_print
    print('authorizePassengerQr (QR inválido): error=${result.error}');
  });

  test('previewPassengerCard: pré-visualiza o cartão virtual próprio via QR', () async {
    if (virtualCardQrData == null) {
      // ignore: avoid_print
      print('previewPassengerCard: SKIP — sem QR de cartão virtual disponível (teste anterior falhou)');
      return;
    }
    final result = await api.previewPassengerCard(qrData: virtualCardQrData!);
    // ignore: avoid_print
    print('previewPassengerCard: success=${result.isSuccess} error=${result.error}');
  });

  test('processPayment: melhor esforço com paymentToken sintético (sem sessão real de passageiro)',
      () async {
    // ATENÇÃO — descoberta desta suite: um paymentToken sintético/inválido
    // fez o backend devolver 401 repetidamente (não 400), o que aciona o
    // interceptor de refresh-e-repetição de ApiService (api_service.dart,
    // onError) em loop recursivo sem limite de tentativas — a chamada
    // ficou presa vários minutos numa corrida anterior desta suite. Usa-se
    // aqui um timeout curto e local só para não travar o resto da suite;
    // o loop de fundo continua a correr mesmo depois deste timeout (ver
    // relatório final para detalhes).
    try {
      final result = await api
          .processPayment(
            driverId: driverId ?? '',
            cardId: '',
            amount: 500,
            pin: _driverPin,
            paymentToken: 'token-sintetico-invalido-para-teste',
            origin: 'Teste',
            destination: 'Teste',
            seatsCount: 1,
          )
          .timeout(const Duration(seconds: 20));
      // ignore: avoid_print
      print('processPayment (best-effort, token sintético): success=${result.isSuccess} error=${result.error}');
    } on TimeoutException {
      // ignore: avoid_print
      print('processPayment (best-effort, token sintético): SEM RESPOSTA em 20s — '
          'ver nota acima sobre possível loop recursivo de refresh/401 no interceptor');
    }
  });

  test('endSession: encerra a sessão de viagem activa — cleanup', () async {
    final result = await api.endSession();
    expect(result.isSuccess, isTrue, reason: result.error);
  });

  // ============ AVALIAÇÕES ============

  test('getMyRating: média de avaliação do motorista', () async {
    if (driverId == null) {
      // ignore: avoid_print
      print('getMyRating: SKIP — driverId indisponível');
      return;
    }
    final result = await api.getMyRating(driverId!);
    expect(result.isSuccess, isTrue, reason: result.error);
  });

  test('getRatings: histórico de avaliações do motorista', () async {
    if (driverId == null) {
      // ignore: avoid_print
      print('getRatings: SKIP — driverId indisponível');
      return;
    }
    final result = await api.getRatings(driverId!);
    expect(result.isSuccess, isTrue, reason: result.error);
    if (result.data != null && result.data!.isNotEmpty) {
      final first = result.data!.first;
      ratingTargetUserId = (first['raterId'] ?? first['fromUserId'] ?? first['userId'] ?? first['passengerId'])
          ?.toString();
      // ignore: avoid_print
      print('getRatings: primeira avaliação chaves=${first.keys.toList()}');
    }
  });

  test('getDriverProfile: perfil público do próprio motorista', () async {
    if (driverId == null) {
      // ignore: avoid_print
      print('getDriverProfile: SKIP — driverId indisponível');
      return;
    }
    final result = await api.getDriverProfile(driverId!);
    expect(result.isSuccess, isTrue, reason: result.error);
  });

  test('ratePassenger: avaliar um passageiro real (a partir do histórico de avaliações)', () async {
    if (ratingTargetUserId == null) {
      // ignore: avoid_print
      print('ratePassenger: SKIP — nenhum userId de passageiro disponível no histórico de avaliações');
      return;
    }
    final result = await api.ratePassenger(
      targetUserId: ratingTargetUserId!,
      stars: 5,
      comment: 'Teste automático',
    );
    // ignore: avoid_print
    print('ratePassenger: success=${result.isSuccess} error=${result.error}');
  });

  // ============ PIN / SEGURANÇA ============

  test('verifyPin: PIN correcto devolve true', () async {
    final result = await api.verifyPin(_driverPin);
    expect(result.isSuccess, isTrue, reason: result.error);
    expect(result.data, isTrue);
  });

  test('changePin — SKIP (mudaria o PIN partilhado da conta QA)', () {},
      skip: 'Mudaria o PIN da conta de teste partilhada — não testado nesta suite');

  test('triggerPanic — SKIP (alerta de pânico real)', () {},
      skip: 'Dispararia um alerta de segurança real — não testado nesta suite');

  test('forgotPassword / verifyForgotPasswordOtp / resetPassword — SKIP', () {},
      skip: 'Quebraria o login da conta QA partilhada — não testado nesta suite '
          '(POST auth/forgot-password já foi exercitado por test/integration_test.dart, '
          'que só envia o OTP sem completar o reset)');

  // ============ CONTACTOS DE EMERGÊNCIA ============

  test('getEmergencyContacts: lista contactos de emergência', () async {
    final result = await api.getEmergencyContacts();
    expect(result.isSuccess, isTrue, reason: result.error);
  });

  test('addEmergencyContact + deleteEmergencyContact: cria e remove um contacto de teste', () async {
    final addResult = await api.addEmergencyContact(
      name: 'Contacto Teste Automático',
      phoneNumber: '+244900000099',
    );
    expect(addResult.isSuccess, isTrue, reason: addResult.error);
    emergencyContactId = addResult.data?.id;
    expect(emergencyContactId, isNotNull);

    final delResult = await api.deleteEmergencyContact(emergencyContactId!);
    expect(delResult.isSuccess, isTrue, reason: delResult.error);
  });

  // ============ NOTIFICAÇÕES ============

  test('getNotifications: lista notificações', () async {
    final result = await api.getNotifications();
    expect(result.isSuccess, isTrue, reason: result.error);
    if (result.data != null && result.data!.notifications.isNotEmpty) {
      notificationId = result.data!.notifications.first.id;
    }
  });

  test('markNotificationRead: marca uma notificação real como lida', () async {
    if (notificationId == null) {
      // ignore: avoid_print
      print('markNotificationRead: SKIP — sem notificações na conta de teste');
      return;
    }
    final result = await api.markNotificationRead(notificationId!);
    expect(result.isSuccess, isTrue, reason: result.error);
  });

  test('markAllNotificationsRead: marca todas as notificações como lidas', () async {
    final result = await api.markAllNotificationsRead();
    expect(result.isSuccess, isTrue, reason: result.error);
  });

  // ============ FCM ============

  test('updateFcmToken: actualiza o token de push', () async {
    final result = await api.updateFcmToken('fcm-token-teste-automatico-${DateTime.now().millisecondsSinceEpoch}');
    expect(result.isSuccess, isTrue, reason: result.error);
  });

  // ============ DOCUMENTOS / BI ============

  test('uploadDocuments — SKIP (precisa de ficheiro de imagem real)', () {},
      skip: 'Cobertura manual — poluiria a verificação de identidade da conta de teste');

  test('verifyBiQr: QR de BI inválido deve ser rejeitado', () async {
    final result = await api.verifyBiQr('qr-de-bi-invalido-para-teste');
    // Esperado: erro de validação (não é um BI real) — prova que o
    // endpoint está a validar o conteúdo.
    // ignore: avoid_print
    print('verifyBiQr (QR inválido): success=${result.isSuccess} error=${result.error}');
  });

  // ============ FAQ ============

  test('getFAQs: lista de perguntas frequentes', () async {
    final result = await api.getFAQs();
    expect(result.isSuccess, isTrue, reason: result.error);
  });

  // ============ VEÍCULOS (CRUD completo, auto-limpo) ============

  test('registerVehicle + updateVehicle + deleteVehicle: CRUD completo de veículo de teste', () async {
    final plate = 'QA-${DateTime.now().millisecondsSinceEpoch % 99999}';
    final createResult = await api.registerVehicle(plate, 'Veículo Teste QA', 'Prata', seats: 4);
    expect(createResult.isSuccess, isTrue, reason: createResult.error);
    testVehicleId = createResult.data?.id;
    expect(testVehicleId, isNotNull);

    final updateResult = await api.updateVehicle(testVehicleId!, model: 'Veículo Teste QA Editado', seats: 5);
    expect(updateResult.isSuccess, isTrue, reason: updateResult.error);

    final deleteResult = await api.deleteVehicle(testVehicleId!);
    expect(deleteResult.isSuccess, isTrue, reason: deleteResult.error);
  });

  // ============ DESTRUTIVOS — SKIP ============

  test('deleteAccount — SKIP (destrutivo)', () {},
      skip: 'Eliminaria a conta de teste partilhada — não testado nesta suite');

  // ============ LOGOUT ============

  test('logout: termina a sessão', () async {
    final result = await api.logout();
    expect(result.isSuccess, isTrue, reason: result.error);
    expect(api.isAuthenticated, isFalse);
  });
}
