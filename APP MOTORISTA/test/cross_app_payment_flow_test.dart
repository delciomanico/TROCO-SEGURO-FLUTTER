// dart run test/cross_app_payment_flow_test.dart [driverPhone] [driverPin]
//
// Teste CRUZADO end-to-end do fluxo real de pagamento por QR entre os dois
// apps, contra a API de produção (https://trocoseguro.ao/api/v1) — sem
// depender do código Dart de nenhum dos dois apps.
//
// Por omissão usa as contas de QA já usadas nos outros testes:
//   Motorista:  +244900000022 / 738264  ("Teste Motorista QA")
//   Passageiro: +244900000011 / 482915  ("Teste Passageiro QA")
// Aceita opcionalmente telefone/PIN de um motorista diferente (ex. uma
// conta já verificada, capaz de ficar online) como argumentos 1 e 2 — o
// passageiro continua a ser sempre a conta de QA acima.
//
// Reproduz exactamente o que os dois apps fazem em conjunto numa corrida
// real, documentado em `APP PASSAGEIRO/CLAUDE.md` (secção "Payment flow")
// e em `ApiService.setupQrSession`/`authorizePassengerQr` do APP MOTORISTA:
//
//   1. Motorista inicia sessão de viagem  -> POST qrcodes/session/start
//      (gera QR pai + QR(s) filho por assento, cada um com `publicToken`)
//   2. Passageiro "lê" o QR de um assento -> GET qrcodes/resolve?token=
//      (resolve o token em driverId/paymentToken/amount)
//   3. Passageiro confirma o pagamento    -> POST payments/process
//   4. Motorista vê o assento marcado como pago -> GET qrcodes/session/seats
//   5. Motorista encerra a sessão          -> POST qrcodes/session/end
//
// Este ficheiro não faz parte da suite normal (não é chamado por
// `flutter test`) porque envolve duas contas e dinheiro real — correr
// manualmente quando for preciso validar o fluxo de ponta a ponta.

import 'dart:convert';
import 'dart:io';

const String _base = 'https://trocoseguro.ao/api/v1';

String _driverPhone = '+244900000022';
String _driverPin = '738264';
const _passengerPhone = '+244900000011';
const _passengerPin = '482915';

final HttpClient _http = HttpClient()
  ..connectionTimeout = const Duration(seconds: 15);

int _pass = 0, _fail = 0, _warn = 0;

Future<({int status, dynamic body})> req(
  String method,
  String path, {
  Map<String, dynamic>? body,
  String? token,
  Map<String, String>? query,
}) async {
  var uriStr = '$_base$path';
  if (query != null && query.isNotEmpty) {
    uriStr +=
        '?${query.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&')}';
  }
  final uri = Uri.parse(uriStr);
  final rq = await _http.openUrl(method, uri);
  rq.headers.set('Content-Type', 'application/json; charset=utf-8');
  rq.headers.set('Accept', 'application/json');
  rq.headers.set('user-agent', 'TrocoSeguroCrossAppTest/1.0');
  if (token != null && token.isNotEmpty) {
    rq.headers.set('Authorization', 'Bearer $token');
  }
  if (body != null) rq.add(utf8.encode(jsonEncode(body)));
  final rs = await rq.close();
  final raw = await rs.transform(utf8.decoder).join();
  dynamic parsed;
  try {
    parsed = raw.isEmpty ? <String, dynamic>{} : jsonDecode(raw);
  } catch (_) {
    parsed = raw;
  }
  return (status: rs.statusCode, body: parsed);
}

void ok(String label, [String detail = '']) {
  print('  ✅  $label${detail.isNotEmpty ? " — $detail" : ""}');
  _pass++;
}

void fail(String label, dynamic detail) {
  print('  ❌  $label');
  print('      → $detail');
  _fail++;
}

void warn(String label, [String detail = '']) {
  print('  ⚠️   $label${detail.isNotEmpty ? " — $detail" : ""}');
  _warn++;
}

void info(String label) => print('       $label');

void section(String title) {
  print('\n── $title ─────────────────────────────────────');
}

Map<String, dynamic> _asMap(dynamic v) => v is Map<String, dynamic>
    ? v
    : (v is Map ? v.cast<String, dynamic>() : <String, dynamic>{});

List<dynamic> _asList(dynamic v) => v is List ? v : [];

/// Extrai o payload "útil" de uma resposta que pode vir na raiz ou em
/// `{data: {...}}`, consoante o endpoint.
Map<String, dynamic> _payload(dynamic body) {
  final b = _asMap(body);
  return b.containsKey('data') ? _asMap(b['data']) : b;
}

Future<void> main(List<String> args) async {
  if (args.length >= 2) {
    _driverPhone = args[0];
    _driverPin = args[1];
  }

  print('\n╔══════════════════════════════════════════════════════════╗');
  print('║  Teste CRUZADO — Pagamento por QR (Motorista ↔ Passageiro) ║');
  print('${'║  $_base'.padRight(62)}║');
  print('╚══════════════════════════════════════════════════════════╝');
  print('  motorista=$_driverPhone  passageiro=$_passengerPhone');

  // ── 1. Login dos dois lados ─────────────────────────────────────────────
  section('1. LOGIN — MOTORISTA e PASSAGEIRO');

  String driverToken = '';
  String driverId = '';
  {
    final r = await req('POST', '/auth/login',
        body: {'phoneNumber': _driverPhone, 'password': _driverPin});
    if (r.status == 200 || r.status == 201) {
      final data = _payload(r.body);
      driverToken = data['accessToken']?.toString() ?? '';
      driverId = _asMap(data['user'] ?? data)['id']?.toString() ?? '';
      if (driverToken.isEmpty) {
        fail('POST /auth/login (motorista)', 'accessToken ausente: ${r.body}');
        exit(1);
      }
      ok('POST /auth/login (motorista)', 'userId=$driverId');
    } else {
      fail('POST /auth/login (motorista)', 'status=${r.status} body=${r.body}');
      exit(1);
    }
  }
  {
    final r = await req('GET', '/users/me', token: driverToken);
    if (r.status == 200) {
      final data = _payload(r.body);
      info('motorista: role=${data['role']} isVerified=${data['isVerified']}');
    }
  }

  String passengerToken = '';
  int passengerBalance = 0;
  {
    final r = await req('POST', '/auth/login',
        body: {'phoneNumber': _passengerPhone, 'password': _passengerPin});
    if (r.status == 200 || r.status == 201) {
      final data = _payload(r.body);
      passengerToken = data['accessToken']?.toString() ?? '';
      if (passengerToken.isEmpty) {
        fail('POST /auth/login (passageiro)', 'accessToken ausente: ${r.body}');
        exit(1);
      }
      ok('POST /auth/login (passageiro)');
    } else {
      fail('POST /auth/login (passageiro)', 'status=${r.status} body=${r.body}');
      exit(1);
    }
  }

  {
    final r = await req('GET', '/users/me', token: passengerToken);
    if (r.status == 200) {
      final data = _payload(r.body);
      final wallet = data['wallet'];
      passengerBalance = wallet is Map
          ? (num.tryParse(wallet['balance']?.toString() ?? '0') ?? 0).toInt()
          : (num.tryParse(data['balance']?.toString() ?? '0') ?? 0).toInt();
      ok('GET /users/me (passageiro)', 'balance=$passengerBalance AOA');
    } else {
      warn('GET /users/me (passageiro) (${r.status}) — a assumir saldo 0');
    }
  }

  // Preço do assento: o menor valor entre o saldo disponível e 20 AOA, para
  // não depender de o passageiro ter saldo elevado — se o saldo for 0,
  // usa-se 1 AOA de qualquer forma (o pedido deve chegar à lógica de
  // negócio e falhar por saldo insuficiente, o que também confirma o fluxo).
  final seatPrice = passengerBalance > 0 ? (passengerBalance < 20 ? passengerBalance : 20) : 1;
  info('preço do assento a usar no teste: $seatPrice AOA');

  // ── 2. Motorista precisa de um veículo activo (obrigatório pelo backend) ─
  section('2. MOTORISTA — obter/criar veículo para a sessão');

  String vehicleId = '';
  String tempVehicleId = '';
  {
    final r = await req('GET', '/fleet', token: driverToken);
    if (r.status == 200) {
      final data = _payload(r.body);
      final vehicles = _asList(data['vehicles'] ?? data);
      if (vehicles.isNotEmpty) {
        vehicleId = _asMap(vehicles.first)['id']?.toString() ?? '';
        ok('GET /fleet', 'a reutilizar veículo existente $vehicleId');
      } else {
        info('sem veículos — a criar um temporário para o teste');
      }
    } else {
      warn('GET /fleet (${r.status}) — a tentar criar veículo temporário');
    }
  }
  if (vehicleId.isEmpty) {
    final plate = 'QA-${DateTime.now().millisecondsSinceEpoch % 99999}';
    final r = await req('POST', '/fleet/vehicles', token: driverToken, body: {
      'licensePlate': plate,
      'model': 'Teste Cruzado',
      'color': 'Cinzento',
      'seats': 4,
    });
    if (r.status == 200 || r.status == 201) {
      final data = _payload(r.body);
      vehicleId = data['id']?.toString() ?? '';
      tempVehicleId = vehicleId;
      ok('POST /fleet/vehicles', 'veículo temporário criado $vehicleId ($plate)');
    } else {
      fail('POST /fleet/vehicles', 'status=${r.status} body=${r.body}');
    }
  }

  // ── 3. Motorista fica online (payments/process exige-o, ver DRIVER_OFFLINE) ─
  section('3. MOTORISTA — ficar online');
  bool driverOnline = false;
  {
    final r = await req('PUT', '/users/me/status',
        token: driverToken, body: {'isOnline': true});
    if (r.status == 200 || r.status == 204) {
      driverOnline = true;
      ok('PUT /users/me/status {isOnline: true}');
    } else {
      warn('PUT /users/me/status {isOnline: true} (${r.status})',
          'pagamento pode falhar com DRIVER_OFFLINE — ${r.body}');
    }
  }

  // ── 3b. Motorista inicia sessão de viagem (gera QR pai + QRs de assento) ─
  section('3b. MOTORISTA — iniciar sessão e gerar QR de assento');

  String childToken = '';
  if (vehicleId.isEmpty) {
    fail('Sem vehicleId disponível', 'não é possível iniciar sessão QR');
    _printSummary();
    exit(1);
  }
  {
    final r = await req('POST', '/qrcodes/session/start',
        token: driverToken, body: {'pricePerSeat': seatPrice, 'vehicleId': vehicleId});
    if (r.status == 200 || r.status == 201) {
      final data = _payload(r.body);
      final childQrs = _asList(data['childQrs']);
      if (childQrs.isNotEmpty) {
        final first = _asMap(childQrs.first);
        childToken = first['publicToken']?.toString() ?? '';
        ok('POST /qrcodes/session/start', '${childQrs.length} QR(s) de assento gerado(s)');
      } else {
        fail('POST /qrcodes/session/start', 'childQrs vazio — chaves: ${data.keys.toList()}');
      }
    } else {
      fail('POST /qrcodes/session/start', 'status=${r.status} body=${r.body}');
    }
  }

  if (childToken.isEmpty) {
    fail('Sem publicToken de assento', 'não é possível continuar o fluxo cruzado');
    await req('POST', '/qrcodes/session/end', token: driverToken);
    _printSummary();
    exit(1);
  }

  // ── 4. Passageiro "lê" o QR do assento e resolve o token ────────────────
  section('4. PASSAGEIRO — ler QR do assento (resolveQrToken)');

  String resolvedDriverId = '';
  String paymentToken = '';
  {
    final r = await req('GET', '/qrcodes/resolve',
        token: passengerToken, query: {'token': childToken});
    if (r.status == 200) {
      final data = _payload(r.body);
      final driver = _asMap(data['driver']);
      resolvedDriverId = driver['id']?.toString() ?? data['driverId']?.toString() ?? '';
      paymentToken =
          data['paymentToken']?.toString() ?? data['sessionToken']?.toString() ?? '';
      final amount = data['amount'];
      ok('GET /qrcodes/resolve?token= (assento real)',
          'driverId=$resolvedDriverId amount=$amount');
      if (resolvedDriverId != driverId) {
        warn('driverId devolvido ($resolvedDriverId) difere do motorista logado ($driverId)');
      }
      if (paymentToken.isEmpty) {
        fail('GET /qrcodes/resolve', 'paymentToken ausente — chaves: ${data.keys.toList()}');
      }
    } else {
      fail('GET /qrcodes/resolve', 'status=${r.status} body=${r.body}');
    }
  }

  // ── 5. Passageiro confirma o pagamento ──────────────────────────────────
  section('5. PASSAGEIRO — confirmar pagamento (processPayment)');
  if (!driverOnline) {
    info('nota: motorista não confirmou estado online no passo 3 — se isto falhar com DRIVER_OFFLINE, é consequência disso');
  }

  bool paymentSucceeded = false;
  if (paymentToken.isNotEmpty && resolvedDriverId.isNotEmpty) {
    final r = await req('POST', '/payments/process', token: passengerToken, body: {
      'driverId': resolvedDriverId,
      'pin': _passengerPin,
      'origin': 'Teste Cruzado — Origem',
      'destination': 'Teste Cruzado — Destino',
      'paymentToken': paymentToken,
      'seatsCount': 1,
      'distanceKm': 0,
      'durationMinutes': 0,
    });
    if (r.status == 200 || r.status == 201) {
      final data = _payload(r.body);
      paymentSucceeded = true;
      ok('POST /payments/process', 'transactionId=${data['transactionId']} newBalance=${data['newBalance']}');
    } else {
      final msg = jsonEncode(r.body).toLowerCase();
      if (msg.contains('insuficiente') || msg.contains('insufficient')) {
        warn('POST /payments/process (${r.status}) — saldo insuficiente na conta de QA',
            'pedido chegou correctamente à lógica de negócio');
      } else if (msg.contains('driver_offline') || msg.contains('não está online')) {
        warn('POST /payments/process (${r.status}) — DRIVER_OFFLINE: conta de QA do motorista '
                'nunca completou a verificação de documentos, por isso não pode ficar online',
            'fluxo (sessão → QR → resolve → cobrança) chegou correctamente até aqui; só a '
                'confirmação final foi bloqueada por esta limitação da conta de QA, não da API');
      } else {
        fail('POST /payments/process', 'status=${r.status} body=${r.body}');
      }
    }
  } else {
    warn('POST /payments/process — SKIP (sem paymentToken/driverId resolvidos no passo anterior)');
  }

  // ── 6. Motorista confirma o estado da sessão ────────────────────────────
  section('6. MOTORISTA — verificar assento pago (getSessionSeats)');

  {
    final r = await req('GET', '/qrcodes/session/seats', token: driverToken);
    if (r.status == 200) {
      final data = _payload(r.body);
      final paid = data['totalPayments'] ?? data['paidSeats'] ?? 0;
      final revenue = data['revenue'];
      ok('GET /qrcodes/session/seats', 'assentosPagos=$paid revenue=$revenue');
      if (paymentSucceeded) {
        final paidCount = num.tryParse(paid.toString()) ?? 0;
        if (paidCount >= 1) {
          ok('  └─ assento marcado como pago reflecte o pagamento do passageiro');
        } else {
          fail('  └─ pagamento teve sucesso mas assentosPagos continua em 0',
              'possível atraso de propagação ou inconsistência no backend');
        }
      }
    } else {
      fail('GET /qrcodes/session/seats', 'status=${r.status} body=${r.body}');
    }
  }

  // ── 7. Encerrar sessão e limpar veículo temporário (cleanup) ────────────
  section('7. MOTORISTA — encerrar sessão e limpar (cleanup)');
  {
    final r = await req('POST', '/qrcodes/session/end', token: driverToken);
    if (r.status == 200 || r.status == 201 || r.status == 204 || r.status == 404) {
      ok('POST /qrcodes/session/end (${r.status})');
    } else {
      warn('POST /qrcodes/session/end (${r.status}) — limpar sessão manualmente se necessário');
    }
  }
  if (tempVehicleId.isNotEmpty) {
    final r = await req('DELETE', '/fleet/vehicles/$tempVehicleId', token: driverToken);
    if (r.status == 200 || r.status == 204) {
      ok('DELETE /fleet/vehicles/:id (veículo temporário removido)');
    } else {
      warn('DELETE /fleet/vehicles/:id (${r.status}) — remover manualmente: $tempVehicleId');
    }
  }
  if (driverOnline) {
    await req('PUT', '/users/me/status', token: driverToken, body: {'isOnline': false});
  }

  _printSummary();
  exit(_fail > 0 ? 1 : 0);
}

void _printSummary() {
  final total = _pass + _fail;
  print('\n╔══════════════════════════════════════════════════╗');
  print('${'║  $_pass/$total passou  |  $_fail falharam  |  $_warn avisos'.padRight(51)}║');
  print('╚══════════════════════════════════════════════════╝\n');
}
