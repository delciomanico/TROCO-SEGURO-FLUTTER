@Timeout(Duration(seconds: 120))
library;

import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:troco_seguro/services/api_service.dart';
import 'package:troco_seguro/models/virtual_card.dart';

/// Cobertura funcional alargada contra o ambiente real (trocoseguro.ao),
/// usando a MESMA conta de teste dedicada do ficheiro
/// `auth_and_wallet_test.dart` — ver esse ficheiro para o contexto de
/// segurança (conta QA aprovada pelo dono do projecto para operações
/// reais).
///
/// Este ficheiro cobre TODOS os métodos públicos de `ApiService` ainda não
/// exercitados por `auth_and_wallet_test.dart`, EXCEPTO os explicitamente
/// destrutivos ou que teriam efeitos colaterais reais partilhados:
///   - register/verifyOtp/resendOtp — criaria conta real
///   - deleteAccount — apagaria a conta QA partilhada
///   - changePassword/changePin — mudaria o PIN partilhado
///   - forgotPassword/verifyForgotPasswordOtp/resetPassword — quebraria o
///     login da conta QA para outros testes
///   - triggerPanic — dispararia um alerta de segurança real
///   - requestWithdrawal — efeito real de levantamento por IBAN
///
/// `processPayment`/`resolveQrToken` com um QR de pagamento real não são
/// testáveis a partir desta app isoladamente — precisam de um QR gerado
/// pelo APP MOTORISTA (ver notas nos testes 15/16).
const _passengerPhone = '+244900000011';
const _passengerPin = '482915';
const _driverPhone = '+244900000022';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final fakeSecureStorage = <String, String>{};
  const secureStorageChannel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  late ApiService api;

  setUpAll(() async {
    HttpOverrides.global = null;
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

  /// Alguns pedidos falham legitimamente por falta de saldo/recurso — isto
  /// prova que o pedido chegou bem formado à lógica de negócio, que é o que
  /// estamos a validar aqui (não a disponibilidade de saldo da conta QA).
  void expectSuccessOrAcceptableBusinessError(
    ApiResponse result,
    String label, {
    List<String> acceptableSubstrings = const ['nsuficiente', 'insufficient'],
  }) {
    print('[$label] isSuccess=${result.isSuccess} '
        'error=${result.error} errorCode=${result.errorCode}');
    if (!result.isSuccess) {
      final lower = (result.error ?? '').toLowerCase();
      final acceptable =
          acceptableSubstrings.any((s) => lower.contains(s.toLowerCase()));
      expect(acceptable, isTrue,
          reason:
              '[$label] Esperada apenas falha de negócio conhecida; erro real: ${result.error}');
    }
  }

  String? driverId;
  String? testCardId;
  String? testCardNumber;
  String? secondCardId;
  String? complaintId;
  String? emergencyContactId;
  String? tripId;
  String? notificationId;

  test('1. login com a conta de teste devolve tokens válidos', () async {
    final result =
        await api.login(phoneNumber: _passengerPhone, password: _passengerPin);
    expect(result.isSuccess, isTrue, reason: result.error);
    expect(api.isAuthenticated, isTrue);
  });

  test('2. getProfile — estado actual da conta QA', () async {
    final result = await api.getProfile();
    expect(result.isSuccess, isTrue, reason: result.error);
    print('[getProfile] fullName=${result.data?.fullName} '
        'balance=${result.data?.balance} id=${result.data?.id}');
  });

  test(
      '3. updateProfile — repõe fullName="Teste Passageiro QA" '
      '(um run anterior de integration_test.dart deixou-o como '
      '"Passageiro Teste")', () async {
    final result = await api.updateProfile(fullName: 'Teste Passageiro QA');
    expect(result.isSuccess, isTrue, reason: result.error);
    expect(result.data?.fullName, 'Teste Passageiro QA');
  });

  test('4. verifyPin com o PIN correcto', () async {
    final result = await api.verifyPin(_passengerPin);
    expect(result.isSuccess, isTrue, reason: result.error);
    print('[verifyPin] valid=${result.data}');
  });

  test('5. verifyTransferRecipient obtém o id do motorista QA', () async {
    final result = await api.verifyTransferRecipient(_driverPhone);
    expect(result.isSuccess, isTrue, reason: result.error);
    driverId = result.data?.id;
    expect(driverId, isNotEmpty);
  });

  test('6. getTransactionQuote (type=transfer) devolve tarifa estimada',
      () async {
    final result = await api.getTransactionQuote(type: 'transfer', amount: 100);
    expect(result.isSuccess, isTrue, reason: result.error);
    print('[getTransactionQuote] fee=${result.data?.feeAmount} '
        'total=${result.data?.totalDebited}');
  });

  test('7. getMyQrCode devolve o QR de identidade do utilizador', () async {
    final result = await api.getMyQrCode();
    expect(result.isSuccess, isTrue, reason: result.error);
    expect(result.data, isNotNull);
  });

  // ============ CARTÕES VIRTUAIS ============

  test('8. getVirtualCards lista os cartões existentes', () async {
    final result = await api.getVirtualCards();
    expect(result.isSuccess, isTrue, reason: result.error);
    print('[getVirtualCards] count=${result.data?.length}');
  });

  test('9. createVirtualCard cria um cartão de teste (saldo inicial 0)',
      () async {
    final result = await api.createVirtualCard(CreateCardPayload(
      name: 'Cartao Teste Cobertura',
      initialBalance: 0,
      dailyLimit: 5000,
      userPin: _passengerPin,
      cardPin: '1234',
    ));
    expect(result.isSuccess, isTrue, reason: result.error);
    testCardId = result.data?.id;
    testCardNumber = result.data?.cardNumber;
    expect(testCardId, isNotEmpty);
    expect(testCardNumber, isNotEmpty);
    print('[createVirtualCard] id=$testCardId cardNumber=$testCardNumber');
  });

  test('9b. createVirtualCard cria um segundo cartão para transferBetweenCards',
      () async {
    final result = await api.createVirtualCard(CreateCardPayload(
      name: 'Cartao Teste Cobertura 2',
      initialBalance: 0,
      dailyLimit: 5000,
      userPin: _passengerPin,
      cardPin: '1234',
    ));
    expect(result.isSuccess, isTrue, reason: result.error);
    secondCardId = result.data?.id;
    expect(secondCardId, isNotEmpty);
  });

  test('10. getVirtualCard devolve os detalhes do cartão criado', () async {
    expect(testCardId, isNotNull, reason: 'depende do teste 9');
    final result = await api.getVirtualCard(testCardId!);
    expect(result.isSuccess, isTrue, reason: result.error);
    expect(result.data?.id, testCardId);
  });

  test('11. getVirtualCardQr devolve o payload de QR oficial do servidor',
      () async {
    expect(testCardId, isNotNull, reason: 'depende do teste 9');
    final result = await api.getVirtualCardQr(testCardId!);
    expect(result.isSuccess, isTrue, reason: result.error);
    expect(result.data, isNotEmpty);
    print('[getVirtualCardQr] qrData=${result.data}');
  });

  test(
      '12. resolveVirtualCardQr resolve o payload JSON de um QR de cartão '
      '(formato documentado em BACKEND_PENDING_CHANGES.md item 1 — '
      'NOTA: getVirtualCardQr() devolve a IMAGEM PNG renderizada do QR '
      '(data:image/png;base64,...), não o texto JSON codificado nela; o '
      'texto só está disponível ao ESCANEAR o QR com a câmara, por isso '
      'construímos aqui o mesmo JSON que um scan real produziria)',
      () async {
    expect(testCardNumber, isNotNull, reason: 'depende do teste 9');
    final qrData = '{"type":"VIRTUAL_CARD_TRANSFER",'
        '"cardNumber":"$testCardNumber",'
        '"cardName":"Cartao Teste Cobertura",'
        '"userName":"Teste Passageiro QA"}';
    final result = await api.resolveVirtualCardQr(qrData);
    expect(result.isSuccess, isTrue, reason: result.error);
    expect(result.data?.cardNumber, isNotNull);
    // Confirma que o cardNumber resolvido é o mesmo devolvido na criação —
    // é este valor (nunca o id/UUID interno) que uma leitura real de QR
    // disponibiliza (ver BACKEND_PENDING_CHANGES.md item 1).
    expect(result.data?.cardNumber, testCardNumber);
    print('[resolveVirtualCardQr] cardNumber=${result.data?.cardNumber} '
        'ownerName=${result.data?.ownerName}');
  });

  test(
      '13. [PRIORITÁRIO] getWalletBalanceByQr com o cardNumber REAL (não o '
      'UUID interno) — ver BACKEND_PENDING_CHANGES.md item 1: '
      'anteriormente devolvia 500, devia devolver 200/saldo', () async {
    expect(testCardNumber, isNotNull, reason: 'depende do teste 9');
    final result = await api.getWalletBalanceByQr(testCardNumber!);
    print('[getWalletBalanceByQr cardNumber=$testCardNumber] '
        'isSuccess=${result.isSuccess} error=${result.error}');
    if (result.isSuccess) {
      print('  -> RESOLVIDO: balance=${result.data?.balance} '
          'ownerName=${result.data?.ownerName}');
    } else {
      print('  -> AINDA FALHA com cardNumber real: ${result.error}');
    }
    // Não fazemos expect(isSuccess) aqui de propósito — o objectivo deste
    // teste é REPORTAR se o bug documentado já foi corrigido no backend
    // actualizado, não fazer a suite falhar se ainda não foi.
  });

  test(
      '13b. getWalletBalanceByQr com o id interno (UUID) do cartão — '
      'já funcionava antes da actualização, deve continuar a funcionar',
      () async {
    expect(testCardId, isNotNull, reason: 'depende do teste 9');
    final result = await api.getWalletBalanceByQr(testCardId!);
    print('[getWalletBalanceByQr id=$testCardId] '
        'isSuccess=${result.isSuccess} error=${result.error}');
    expect(result.isSuccess, isTrue, reason: result.error);
  });

  test('14. updateCardStatus congela e reactiva o cartão de teste', () async {
    expect(testCardId, isNotNull, reason: 'depende do teste 9');
    final frozen = await api.updateCardStatus(cardId: testCardId!, status: 'frozen');
    expect(frozen.isSuccess, isTrue, reason: frozen.error);
    final active = await api.updateCardStatus(cardId: testCardId!, status: 'active');
    expect(active.isSuccess, isTrue, reason: active.error);
  });

  test('15. updateCardLimit altera o limite diário', () async {
    expect(testCardId, isNotNull, reason: 'depende do teste 9');
    final result = await api.updateCardLimit(cardId: testCardId!, dailyLimit: 8000);
    expect(result.isSuccess, isTrue, reason: result.error);
  });

  test('16. updateCardPinRequired liga e desliga a exigência do PIN do cartão',
      () async {
    expect(testCardId, isNotNull, reason: 'depende do teste 9');
    final on = await api.updateCardPinRequired(cardId: testCardId!, pinRequired: true);
    expect(on.isSuccess, isTrue, reason: on.error);
    final off = await api.updateCardPinRequired(cardId: testCardId!, pinRequired: false);
    expect(off.isSuccess, isTrue, reason: off.error);
  });

  test(
      '17. topupVirtualCard carrega o cartão a partir da carteira principal '
      '(sucesso ou saldo insuficiente na carteira)', () async {
    expect(testCardId, isNotNull, reason: 'depende do teste 9');
    final result = await api.topupVirtualCard(cardId: testCardId!, amount: 50);
    expectSuccessOrAcceptableBusinessError(result, 'topupVirtualCard');
  });

  test(
      '18. depositToVirtualCard (wallet/card/deposit) — mesma operação por '
      'outro endpoint (sucesso ou saldo insuficiente)', () async {
    expect(testCardId, isNotNull, reason: 'depende do teste 9');
    final result =
        await api.depositToVirtualCard(cardId: testCardId!, amount: 50);
    expectSuccessOrAcceptableBusinessError(result, 'depositToVirtualCard');
  });

  test(
      '19. transferBetweenCards entre os dois cartões de teste (sucesso ou '
      'saldo insuficiente — usa o PIN de 4 dígitos do CARTÃO, não o PIN da '
      'conta: um 1º run confirmou empiricamente que "pin" aqui é o cardPin '
      'definido em createVirtualCard — devolvia "PIN do cartão incorreto" '
      'ao usar o PIN de 6 dígitos da conta)', () async {
    expect(testCardId, isNotNull, reason: 'depende do teste 9');
    expect(secondCardId, isNotNull, reason: 'depende do teste 9b');
    final result = await api.transferBetweenCards(
      fromCardId: testCardId!,
      toCardId: secondCardId!,
      amount: 10,
      pin: '1234', // cardPin definido na criação dos cartões (teste 9/9b)
    );
    expectSuccessOrAcceptableBusinessError(result, 'transferBetweenCards');
  });

  test(
      '20. transferToExternalCard para o cardNumber do próprio cartão de '
      'teste — o backend bloqueia correctamente auto-transferência com uma '
      'mensagem dedicada ("use Deposit"), o que já confirma que o pedido '
      'chega à lógica de negócio', () async {
    expect(testCardNumber, isNotNull, reason: 'depende do teste 9');
    final result = await api.transferToExternalCard(
      cardNumber: testCardNumber!,
      amount: 10,
      pin: _passengerPin,
    );
    expectSuccessOrAcceptableBusinessError(result, 'transferToExternalCard',
        acceptableSubstrings: const [
          'nsuficiente',
          'insufficient',
          'próprios cartões',
          'carregamento',
        ]);
  });

  test(
      '21. withdrawFromVirtualCard levanta do cartão de teste para a '
      'carteira (sucesso ou saldo insuficiente) — também usa o cardPin, '
      'não o PIN da conta (ver nota no teste 19)', () async {
    expect(testCardId, isNotNull, reason: 'depende do teste 9');
    final result = await api.withdrawFromVirtualCard(
      cardId: testCardId!,
      amount: 5,
      pin: '1234', // cardPin definido na criação do cartão (teste 9)
    );
    expectSuccessOrAcceptableBusinessError(result, 'withdrawFromVirtualCard');
  });

  test('22. deleteVirtualCard remove ambos os cartões de teste (limpeza)',
      () async {
    if (testCardId != null) {
      final r1 = await api.deleteVirtualCard(testCardId!);
      expect(r1.isSuccess, isTrue, reason: r1.error);
      print('[deleteVirtualCard $testCardId] refunded=${r1.data?.refundedAmount}');
    }
    if (secondCardId != null) {
      final r2 = await api.deleteVirtualCard(secondCardId!);
      expect(r2.isSuccess, isTrue, reason: r2.error);
    }
  });

  // ============ QR DE PAGAMENTO (consulta de pagamento por QR) ============

  test(
      '23. [PRIORITÁRIO] resolveQrToken com token inválido/malformado — '
      'confirma falha limpa (400/404), NUNCA 500', () async {
    final result = await api.resolveQrToken('token-invalido-teste-cobertura');
    print('[resolveQrToken invalid] isSuccess=${result.isSuccess} '
        'error=${result.error} errorCode=${result.errorCode}');
    expect(result.isSuccess, isFalse,
        reason: 'token claramente inválido não devia ser aceite');
    // O erro genérico de "Erro no servidor (500)" viria de _parseError()
    // quando o corpo de erro não tem 'message'/'error' — verificamos que
    // NÃO é esse o caso.
    expect(result.error, isNot(matches(RegExp(r'\(500\)'))),
        reason: 'resolveQrToken NÃO deve devolver 500 para um token inválido');
  });

  test(
      '24. processPayment com paymentToken/driverId inválidos — confirma '
      'falha limpa (não testável ponta-a-ponta sem um QR de pagamento real '
      'gerado pelo APP MOTORISTA — ver nota no relatório)', () async {
    final result = await api.processPayment(
      driverId: 'driver-id-invalido-teste',
      amount: 100,
      pin: _passengerPin,
      origin: 'Teste',
      destination: 'Teste',
      paymentToken: 'payment-token-invalido-teste',
    );
    print('[processPayment invalid] isSuccess=${result.isSuccess} '
        'error=${result.error} errorCode=${result.errorCode}');
    expect(result.isSuccess, isFalse,
        reason: 'dados claramente inválidos não deviam ser aceites');
    expect(result.error, isNot(matches(RegExp(r'\(500\)'))),
        reason: 'processPayment NÃO deve devolver 500 para dados inválidos');
  });

  // ============ VIAGENS ============

  test('25. getTrips lista as viagens da conta QA', () async {
    final result = await api.getTrips();
    expect(result.isSuccess, isTrue, reason: result.error);
    print('[getTrips] count=${result.data?.length}');
    if (result.data != null && result.data!.isNotEmpty) {
      tripId = result.data!.first.id;
    }
  });

  test('26. getTrip devolve os detalhes de uma viagem real (se existir)',
      () async {
    if (tripId == null || tripId!.isEmpty) {
      print('[getTrip] SALTADO — conta QA sem viagens registadas');
      return;
    }
    final result = await api.getTrip(tripId!);
    expect(result.isSuccess, isTrue, reason: result.error);
  });

  test('27. getTripStats devolve estatísticas agregadas', () async {
    final result = await api.getTripStats();
    expect(result.isSuccess, isTrue, reason: result.error);
    print('[getTripStats] totalTrips=${result.data?.totalTrips} '
        'monthSpent=${result.data?.totalSpentMonth}');
  });

  test(
      '28. rateTrip avalia a primeira viagem existente (se existir e ainda '
      'não avaliada)', () async {
    if (tripId == null || tripId!.isEmpty) {
      print('[rateTrip] SALTADO — conta QA sem viagens registadas');
      return;
    }
    final result = await api.rateTrip(tripId: tripId!, stars: 5, comment: 'Teste automatizado');
    expectSuccessOrAcceptableBusinessError(result, 'rateTrip',
        acceptableSubstrings: const [
          'nsuficiente',
          'insufficient',
          'already',
          'já',
          'duplicat',
        ]);
  });

  // ============ AVALIAÇÕES ============

  test('29. getRatings devolve o histórico de avaliações do motorista QA',
      () async {
    expect(driverId, isNotNull, reason: 'depende do teste 5');
    final result = await api.getRatings(driverId!);
    expect(result.isSuccess, isTrue, reason: result.error);
    print('[getRatings] count=${result.data?.length}');
  });

  test('30. createRating cria uma avaliação para o motorista QA', () async {
    expect(driverId, isNotNull, reason: 'depende do teste 5');
    final result = await api.createRating(
      targetUserId: driverId!,
      stars: 5,
      comment: 'Teste automatizado de cobertura',
    );
    expectSuccessOrAcceptableBusinessError(result, 'createRating',
        acceptableSubstrings: const [
          'nsuficiente',
          'insufficient',
          'already',
          'já',
          'duplicat',
          'not found',
          'não encontrad',
        ]);
  });

  // ============ NOTIFICAÇÕES ============

  test('31. getNotifications lista as notificações da conta QA', () async {
    final result = await api.getNotifications();
    expect(result.isSuccess, isTrue, reason: result.error);
    print('[getNotifications] count=${result.data?.notifications.length} '
        'unread=${result.data?.unreadCount}');
    if (result.data != null && result.data!.notifications.isNotEmpty) {
      notificationId = result.data!.notifications.first.id;
    }
  });

  test('32. markNotificationRead marca uma notificação real como lida',
      () async {
    if (notificationId == null || notificationId!.isEmpty) {
      print('[markNotificationRead] SALTADO — sem notificações na conta QA');
      return;
    }
    final result = await api.markNotificationRead(notificationId!);
    expect(result.isSuccess, isTrue, reason: result.error);
  });

  test('33. markAllNotificationsRead marca todas como lidas', () async {
    final result = await api.markAllNotificationsRead();
    expect(result.isSuccess, isTrue, reason: result.error);
  });

  // ============ CONTACTOS DE EMERGÊNCIA (auto-limpeza) ============

  test('34. getEmergencyContacts lista os contactos actuais', () async {
    final result = await api.getEmergencyContacts();
    expect(result.isSuccess, isTrue, reason: result.error);
    print('[getEmergencyContacts] count=${result.data?.length}');
  });

  test('35. addEmergencyContact cria um contacto de teste', () async {
    final result = await api.addEmergencyContact(
      name: 'Contacto Teste Cobertura',
      phoneNumber: '+244900000033',
    );
    expect(result.isSuccess, isTrue, reason: result.error);
    emergencyContactId = result.data?.id;
    expect(emergencyContactId, isNotEmpty);
  });

  test('36. deleteEmergencyContact remove o contacto de teste (limpeza)',
      () async {
    expect(emergencyContactId, isNotNull, reason: 'depende do teste 35');
    final result = await api.deleteEmergencyContact(emergencyContactId!);
    expect(result.isSuccess, isTrue, reason: result.error);
  });

  // ============ FAQ / FCM ============

  test('37. getFaq devolve a lista de perguntas frequentes', () async {
    final result = await api.getFaq();
    expect(result.isSuccess, isTrue, reason: result.error);
    print('[getFaq] count=${result.data?.length}');
  });

  test('38. updateFcmToken actualiza o token de push da conta QA', () async {
    final result =
        await api.updateFcmToken('fcm-token-teste-cobertura-automatizada');
    expect(result.isSuccess, isTrue, reason: result.error);
  });

  // ============ RECLAMAÇÕES (sem endpoint de delete — não limpa) ============

  test('39. createComplaint cria uma reclamação de teste', () async {
    final result = await api.createComplaint(
      category: 'OTHER',
      reasonCode: 'other',
      description: 'Teste automatizado de cobertura — ignorar',
    );
    expect(result.isSuccess, isTrue, reason: result.error);
  });

  test('40. getComplaints lista as reclamações da conta QA', () async {
    final result = await api.getComplaints();
    expect(result.isSuccess, isTrue, reason: result.error);
    print('[getComplaints] count=${result.data?.length}');
    if (result.data != null && result.data!.isNotEmpty) {
      complaintId = result.data!.first.id;
    }
  });

  test('41. getComplaint devolve os detalhes da reclamação criada', () async {
    if (complaintId == null || complaintId!.isEmpty) {
      print('[getComplaint] SALTADO — nenhuma reclamação disponível');
      return;
    }
    print('[getComplaint] id=$complaintId');
    final result = await api.getComplaint(complaintId!);
    expect(result.isSuccess, isTrue, reason: result.error);
  });
}
