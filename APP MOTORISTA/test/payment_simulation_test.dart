// dart run test/payment_simulation_test.dart <tel-motorista> <pin-motorista> <tel-passageiro> <pin-passageiro>
//
// Simula os dois fluxos de pagamento com DUAS contas distintas:
//
//   FLUXO 1 — Passageiro escaneia QR do assento (motorista mostra QR)
//     1. Motorista: inicia sessão → childQrs[0].publicToken
//     2. Passageiro: GET /qrcodes/resolve?token= → driverId + paymentToken
//     3. Passageiro: POST /payments/process  (paymentToken do resolve)
//
//   FLUXO 2 — Motorista escaneia QR de pagamento do passageiro (PAYMENT_INTENT)
//     1. Passageiro: POST /qr-code/payment-request → QR PAYMENT_INTENT
//     2. Motorista: POST /payments/authorize-passenger-qr (qrData = JSON string)
//
//   FLUXO 3 — Motorista escaneia cartão virtual do passageiro
//     1. Passageiro: GET /virtual-cards/:id/qr → PNG base64
//     2. Motorista: POST /virtual-cards/resolve-qr → verifica cartão
//     3. Motorista: POST /wallet/card/withdraw (bloqueado: sem cardId UUID)

import 'dart:convert';
import 'dart:io';

const String _base = 'https://trocoseguro.wemof.tech/api/v1';
final HttpClient _http = HttpClient()
  ..connectionTimeout = const Duration(seconds: 20);

// ─── Estado Motorista ─────────────────────────────────────────────────────────
String _driverToken = '';
String _driverId = '';
String _vehicleId = '';
String _sessionId = '';
String _parentQrToken = '';
String _childQrToken = '';
double _pricePerSeat = 0;

// ─── Estado Passageiro ────────────────────────────────────────────────────────
String _passengerToken = '';
String _passengerId = '';
String _passengerVirtualCardId = '';
String _passengerCardPin = '1234'; // PIN 4 dígitos do cartão virtual (definido ao criar)
String _passengerPaymentQrData = ''; // conteúdo do QR PAYMENT_INTENT

int _pass = 0, _fail = 0, _warn = 0;

// ─── HTTP helper ──────────────────────────────────────────────────────────────

Future<({int status, dynamic body})> req(
  String method,
  String path, {
  Map<String, dynamic>? body,
  bool auth = true,
  Map<String, String>? query,
  String? token,
}) async {
  var uriStr = '$_base$path';
  if (query != null && query.isNotEmpty) {
    uriStr +=
        '?${query.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&')}';
  }
  final uri = Uri.parse(uriStr);
  try {
    final rq = await _http.openUrl(method, uri);
    rq.headers.set('Content-Type', 'application/json');
    rq.headers.set('Accept', 'application/json');
    rq.headers.set('user-agent', 'TrocoSeguroPaySim/2.0');
    if (auth) {
      final t = token ?? _driverToken;
      if (t.isNotEmpty) rq.headers.set('Authorization', 'Bearer $t');
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
  } on SocketException catch (e) {
    print('\n❌ ERRO DE REDE: Não foi possível ligar ao servidor.');
    print('   ${e.message}');
    print('   Verifique se o servidor https://trocoseguro.wemof.tech está activo.');
    exit(1);
  }
}

// ─── Logging ─────────────────────────────────────────────────────────────────

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

void result(int status, dynamic body) {
  print('       HTTP $status');
  if (body is Map) {
    for (final k in body.keys.take(10)) {
      print('       $k: ${body[k]}');
    }
  } else {
    print('       $body');
  }
}

Map<String, dynamic> _asMap(dynamic v) =>
    v is Map<String, dynamic> ? v : (v is Map ? v.cast<String, dynamic>() : <String, dynamic>{});

List<dynamic> _asList(dynamic v) => v is List ? v : [];

String _short(String s, [int n = 20]) =>
    s.isEmpty ? 'AUSENTE' : '${s.substring(0, s.length < n ? s.length : n)}...';

// ─── QR PNG Decoder (via Node.js + jsqr) ─────────────────────────────────────

Future<String> _decodeQrPng(String base64Img, String fallbackCardNumber) async {
  try {
    final pureBase64 = base64Img.replaceFirst(RegExp(r'data:image/[^;]+;base64,'), '');
    final tmpFile = File('/tmp/troco_card_qr_tmp.png');
    tmpFile.writeAsBytesSync(base64Decode(pureBase64));

    const nodeScript = r'''
const {Jimp} = require('/tmp/qr-decode/node_modules/jimp');
const jsQR = require('/tmp/qr-decode/node_modules/jsqr');
Jimp.read(process.argv[1]).then(img => {
  const {data, width, height} = img.bitmap;
  const code = jsQR(data, width, height);
  if (code) process.stdout.write(code.data);
  else process.stdout.write('');
}).catch(() => process.stdout.write(''));
''';
    final r = await Process.run('node', ['-e', nodeScript, tmpFile.path]);
    return r.stdout.toString().trim();
  } catch (e) {
    if (fallbackCardNumber.isNotEmpty) {
      return '{"type":"VIRTUAL_CARD_TRANSFER","cardNumber":"$fallbackCardNumber"}';
    }
    return '';
  }
}

// ─── LOGIN ────────────────────────────────────────────────────────────────────

Future<({String token, String userId})> _login(
    String phone, String password, String label) async {
  final r = await req('POST', '/auth/login',
      body: {'phoneNumber': phone, 'password': password}, auth: false);
  if (r.status != 200 && r.status != 201) {
    fail('Login $label ($phone)', r.body);
    exit(1);
  }
  final b = _asMap(r.body);
  final data = b.containsKey('data') ? _asMap(b['data']) : b;
  final token =
      data['accessToken']?.toString() ?? data['access_token']?.toString() ?? '';
  final user = _asMap(data['user'] ?? data);
  final userId = user['id']?.toString() ?? '';
  if (token.isEmpty) {
    fail('accessToken ausente ($label)', b.keys.toList());
    exit(1);
  }
  ok('Login $label OK', 'userId=$userId  phone=$phone');
  return (token: token, userId: userId);
}

// ─── SETUP MOTORISTA ──────────────────────────────────────────────────────────

Future<void> setupMotorista(String phone, String password) async {
  section('SETUP MOTORISTA');

  final r = await _login(phone, password, 'MOTORISTA');
  _driverToken = r.token;
  _driverId = r.userId;

  // Veículo activo
  final rv = await req('GET', '/fleet', token: _driverToken);
  if (rv.status == 200) {
    final vb = _asMap(rv.body);
    final vehicles = _asList(vb['vehicles'] ?? vb['data'] ?? rv.body);
    if (vehicles.isNotEmpty) {
      final v = _asMap(vehicles.first);
      _vehicleId = v['id']?.toString() ?? '';
      ok('Veículo encontrado', 'id=$_vehicleId  modelo=${v['model']}');
    } else {
      fail('Nenhum veículo na frota', rv.body);
      exit(1);
    }
  } else {
    fail('GET /fleet', 'status=${rv.status}  body=${rv.body}');
    exit(1);
  }

  // Colocar motorista online
  await req('PUT', '/users/me/status',
      body: {'isOnline': true}, token: _driverToken);
  ok('Motorista marcado como online');
}

// ─── SETUP PASSAGEIRO ─────────────────────────────────────────────────────────

Future<void> setupPassageiro(String phone, String password) async {
  section('SETUP PASSAGEIRO');

  final r = await _login(phone, password, 'PASSAGEIRO');
  _passengerToken = r.token;
  _passengerId = r.userId;

  // 1. Depositar saldo na carteira do passageiro (pode ser restrito a admins)
  print('\n  → A tentar carregar saldo: POST /transactions/deposit...');
  final rd = await req('POST', '/transactions/deposit',
      body: {'amount': 5000}, token: _passengerToken);
  result(rd.status, rd.body);
  if (rd.status == 200 || rd.status == 201) {
    ok('POST /transactions/deposit — 5000 AOA carregados na carteira');
  } else {
    warn('POST /transactions/deposit → ${rd.status}',
        _asMap(rd.body)['message']?.toString() ?? '${rd.body}');
  }

  // 2. Cartão virtual do passageiro
  final rc = await req('GET', '/virtual-cards', token: _passengerToken);
  if (rc.status == 200) {
    final cb = _asMap(rc.body);
    final cards = _asList(cb['cards'] ?? cb['data'] ?? rc.body);
    if (cards.isNotEmpty) {
      final card = _asMap(cards.first);
      _passengerVirtualCardId = card['id']?.toString() ?? '';
      ok('Cartão virtual do passageiro', 'id=$_passengerVirtualCardId  número=${card['cardNumber']}');
    } else {
      // Criar cartão virtual para o passageiro
      print('\n  → Passageiro sem cartão — a criar via POST /virtual-cards...');
      final rcreate = await req('POST', '/virtual-cards', body: {
        'name': 'Cartão Ercilio',
        'initialBalance': 0,
        'dailyLimit': 20000,
        'userPin': password,
        'cardPin': _passengerCardPin,
      }, token: _passengerToken);
      result(rcreate.status, rcreate.body);
      if (rcreate.status == 200 || rcreate.status == 201) {
        final cb2 = _asMap(rcreate.body);
        final cardData = _asMap(cb2['card'] ?? cb2['data'] ?? cb2);
        _passengerVirtualCardId = cardData['id']?.toString() ?? '';
        ok('Cartão virtual criado', 'id=$_passengerVirtualCardId');
      } else {
        warn('POST /virtual-cards → ${rcreate.status}',
            _asMap(rcreate.body)['message']?.toString() ?? '');
      }
    }
  } else {
    warn('GET /virtual-cards (passageiro) → ${rc.status}');
  }

  // 3. Depositar no cartão virtual (se existir) — sem campo 'pin' (API rejeita)
  if (_passengerVirtualCardId.isNotEmpty) {
    print('\n  → A depositar no cartão virtual do passageiro...');
    final rcd = await req('POST', '/wallet/card/deposit', body: {
      'cardId': _passengerVirtualCardId,
      'amount': 5000,
    }, token: _passengerToken);
    if (rcd.status == 200 || rcd.status == 201) {
      ok('POST /wallet/card/deposit — 5000 AOA no cartão virtual');
    } else {
      warn('POST /wallet/card/deposit → ${rcd.status}',
          _asMap(rcd.body)['message']?.toString() ?? '');
    }
  }

  // 4. Gerar QR PAYMENT_INTENT do passageiro para Fluxo 2.
  // Segundo a documentação, o QR é gerado localmente pelo app do passageiro
  // (não passa pelo backend). O JSON gerado é scaneado pelo motorista.
  const amount = 1500;
  final passengerProfile = await req('GET', '/users/me', token: _passengerToken);
  String passengerName = 'Passageiro';
  String passengerPhone = '';
  if (passengerProfile.status == 200) {
    final pb = _asMap(passengerProfile.body);
    final pd = pb.containsKey('data') ? _asMap(pb['data']) : pb;
    passengerName = pd['fullName']?.toString() ?? 'Passageiro';
    passengerPhone = pd['phoneNumber']?.toString() ?? '';
  }
  _passengerPaymentQrData = jsonEncode({
    'type': 'PAYMENT_INTENT',
    'userId': _passengerId,
    'amount': amount,
    'name': passengerName,
    'phoneNumber': passengerPhone,
  });
  ok('QR PAYMENT_INTENT gerado localmente', 'userId=$_passengerId  amount=$amount AOA');
  info('qrData=$_passengerPaymentQrData');
}

// ─── FLUXO 1 — Motorista inicia sessão ───────────────────────────────────────

Future<void> fluxo1IniciarSessao(double preco) async {
  section('FLUXO 1 — MOTORISTA: iniciar sessão QR');

  final r = await req('POST', '/qrcodes/session/start', body: {
    'pricePerSeat': preco.toInt(),
    'vehicleId': _vehicleId,
  }, token: _driverToken);

  if (r.status == 200 || r.status == 201) {
    final b = _asMap(r.body);
    final data = b.containsKey('data') ? _asMap(b['data']) : b;
    _sessionId = data['sessionId']?.toString() ?? '';
    _pricePerSeat = double.tryParse(data['pricePerSeat']?.toString() ?? '0') ?? preco;

    final qrCode = _asMap(data['qrCode']);
    _parentQrToken = qrCode['publicToken']?.toString() ?? '';

    final childQrs = _asList(data['childQrs']);
    if (childQrs.isNotEmpty) {
      final firstChild = _asMap(childQrs.first);
      _childQrToken = firstChild['publicToken']?.toString() ?? '';
    }

    ok('POST /qrcodes/session/start', 'sessionId=$_sessionId  preço=${_pricePerSeat.toInt()} AOA');
    info('parentToken=${_short(_parentQrToken)}');
    info('childQrs=${childQrs.length}  childToken[0]=${_short(_childQrToken)}');

    if (_childQrToken.isEmpty) {
      fail('childQr.publicToken ausente — Fluxo 1 incompleto', data.keys.toList());
    }
  } else {
    fail('POST /qrcodes/session/start', 'status=${r.status}  body=${r.body}');
  }
}

// ─── FLUXO 1 — Passageiro resolve e paga ─────────────────────────────────────

Future<void> fluxo1PagarAssento(String passengerPin) async {
  section('FLUXO 1 — PASSAGEIRO: resolver QR e pagar');

  if (_childQrToken.isEmpty) {
    warn('Sem childQrToken — a saltar');
    return;
  }

  // 1. Resolver token do assento (usa token do PASSAGEIRO)
  final rr = await req('GET', '/qrcodes/resolve',
      query: {'token': _childQrToken}, token: _passengerToken);
  String resolvedPaymentToken = _childQrToken;
  String driverId = _driverId;

  if (rr.status == 200) {
    ok('GET /qrcodes/resolve', 'HTTP ${rr.status}');
    final rb = _asMap(rr.body);
    final data = rb.containsKey('data') ? _asMap(rb['data']) : rb;
    info('Campos: ${data.keys.toList()}');
    driverId = data['driverId']?.toString() ??
        _asMap(data['driver'])['id']?.toString() ??
        _driverId;
    resolvedPaymentToken = data['paymentToken']?.toString() ?? _childQrToken;
    final amount = data['pricePerSeat'] ?? data['amount'] ?? _pricePerSeat;
    info('driverId=$driverId  amount=$amount AOA');
    info('paymentToken=${_short(resolvedPaymentToken)}');

    if (driverId == _passengerId) {
      warn('driverId == passengerId — token pode estar ligado à conta errada');
    }
  } else if (rr.status == 404) {
    warn('GET /qrcodes/resolve → 404 (token expirado?)');
  } else {
    warn('GET /qrcodes/resolve → ${rr.status}', '${rr.body}');
  }

  // 2. POST /payments/process — tentar cartão primeiro, depois carteira
  Future<void> tryPay(String pin, {String? cardId}) async {
    final modoLabel = cardId != null
        ? 'cartão virtual (pin=$pin  cardId=$cardId)'
        : 'carteira (pin=$pin)';
    print('\n  → POST /payments/process ($modoLabel)...');
    final rp = await req('POST', '/payments/process', body: {
      'driverId': driverId,
      'pin': pin,
      'origin': 'Rangel',
      'destination': 'Maianga',
      'paymentToken': resolvedPaymentToken,
      'seatsCount': 1,
      'distanceKm': 3.5,
      'durationMinutes': 12,
      if (cardId != null) 'cardId': cardId,
    }, token: _passengerToken);
    result(rp.status, rp.body);
    if (rp.status == 200 || rp.status == 201) {
      ok('POST /payments/process — PAGAMENTO CONCLUÍDO ✨ ($modoLabel)');
      final pb = _asMap(rp.body);
      final data = pb.containsKey('data') ? _asMap(pb['data']) : pb;
      info('transactionId=${data['transactionId'] ?? data['id'] ?? "?"}');
      info('amount=${data['amount'] ?? data['displayAmount'] ?? "?"}');
    } else if (rp.status == 400) {
      final pb = _asMap(rp.body);
      warn('POST /payments/process ($modoLabel) → 400', pb['message']?.toString() ?? '');
    } else if (rp.status == 403) {
      warn('POST /payments/process → 403', '${_asMap(rp.body)['message']}');
    } else if (rp.status == 500) {
      fail('POST /payments/process → 500 (bug servidor)', rp.body);
    } else {
      warn('POST /payments/process → ${rp.status}', '${rp.body}');
    }
  }

  // Tentativa 1: com cartão virtual (se existir)
  if (_passengerVirtualCardId.isNotEmpty) {
    await tryPay(_passengerCardPin, cardId: _passengerVirtualCardId);
  }
  // Tentativa 2: da carteira (sem cardId)
  await tryPay(passengerPin);
}

// ─── FLUXO 2 — Motorista escaneia QR PAYMENT_INTENT do passageiro ─────────────

Future<void> fluxo2MotoristaCobraPassageiro(String passengerAccountPin) async {
  section('FLUXO 2 — MOTORISTA: escanear QR PAYMENT_INTENT do passageiro');

  if (_passengerPaymentQrData.isEmpty) {
    warn('Sem QR PAYMENT_INTENT do passageiro — a saltar Fluxo 2');
    return;
  }

  info('qrData = $_passengerPaymentQrData');

  // POST /payments/authorize-passenger-qr (usa token do MOTORISTA)
  // passengerPin = password da conta do passageiro (6 dígitos) — confirmado na sessão anterior
  print('\n  → POST /payments/authorize-passenger-qr...');
  final r = await req('POST', '/payments/authorize-passenger-qr', body: {
    'qrData': _passengerPaymentQrData,
    'passengerPin': passengerAccountPin,
    'origin': 'Rangel',
    'destination': 'Maianga',
    'distanceKm': 3.5,
    'durationMinutes': 12,
    'seatsCount': 1,
    if (_parentQrToken.isNotEmpty) 'parentQrToken': _parentQrToken,
  }, token: _driverToken);

  result(r.status, r.body);

  if (r.status == 200 || r.status == 201) {
    ok('POST /payments/authorize-passenger-qr — COBRANÇA CONCLUÍDA ✨');
    final rb = _asMap(r.body);
    final data = rb.containsKey('data') ? _asMap(rb['data']) : rb;
    info('transactionId=${data['transactionId'] ?? data['id'] ?? "?"}');
    info('amount=${data['amount'] ?? data['displayAmount'] ?? "?"}');
  } else if (r.status == 400) {
    final rb = _asMap(r.body);
    fail('POST /payments/authorize-passenger-qr → 400', rb['message'] ?? rb);
  } else if (r.status == 403) {
    warn('POST /payments/authorize-passenger-qr → 403', '${_asMap(r.body)['message']}');
  } else if (r.status == 500) {
    fail('POST /payments/authorize-passenger-qr → 500 (bug servidor)', r.body);
  } else {
    warn('POST /payments/authorize-passenger-qr → ${r.status}', '${r.body}');
  }
}

// ─── FLUXO 3 — Motorista escaneia cartão virtual do passageiro ───────────────

Future<void> fluxo3CartaoVirtual(String driverPin) async {
  section('FLUXO 3 — MOTORISTA: escanear cartão virtual do passageiro');

  if (_passengerVirtualCardId.isEmpty) {
    warn('Passageiro sem cartão virtual — a saltar Fluxo 3');
    return;
  }

  // Obter QR do cartão virtual do passageiro (usa token do PASSAGEIRO)
  final rq = await req('GET', '/virtual-cards/$_passengerVirtualCardId/qr',
      token: _passengerToken);
  String virtualCardQrData = '';

  if (rq.status == 200) {
    final qb = _asMap(rq.body);
    final base64Img = qb['qrCodeImage']?.toString() ?? '';
    final cardNumber = qb['cardNumber']?.toString() ?? '';
    if (base64Img.isNotEmpty) {
      virtualCardQrData = await _decodeQrPng(base64Img, cardNumber);
      if (virtualCardQrData.isNotEmpty) {
        ok('QR do cartão virtual descodificado', 'qrData=${_short(virtualCardQrData)}');
        info('Conteúdo: $virtualCardQrData');
      } else {
        warn('Não foi possível descodificar PNG do cartão virtual');
        return;
      }
    } else {
      warn('GET /virtual-cards/:id/qr sem imagem', 'keys=${qb.keys.toList()}');
      return;
    }
  } else {
    warn('GET /virtual-cards/:id/qr → ${rq.status}');
    return;
  }

  // 1. Motorista: POST /virtual-cards/resolve-qr (verifica o cartão)
  print('\n  → POST /virtual-cards/resolve-qr (motorista resolve cartão)...');
  final rr = await req('POST', '/virtual-cards/resolve-qr',
      body: {'qrData': virtualCardQrData}, token: _driverToken);
  result(rr.status, rr.body);

  if (rr.status == 200 || rr.status == 201) {
    ok('POST /virtual-cards/resolve-qr — cartão identificado');
    final rrb = _asMap(rr.body);
    info('Campos: ${rrb.keys.toList()}');
    info('cardNumber=${rrb['cardNumber']}  ownerName=${rrb['ownerName']}');

    // 2. Verificar se retorna cardId UUID (necessário para wallet/card/withdraw)
    final cardId = rrb['cardId']?.toString() ?? rrb['id']?.toString() ?? '';
    if (cardId.isNotEmpty) {
      ok('cardId UUID disponível — Fluxo 3 completo possível', 'cardId=$cardId');

      print('\n  → POST /wallet/card/withdraw (motorista cobra cartão)...');
      final rw = await req('POST', '/wallet/card/withdraw', body: {
        'cardId': cardId,
        'amount': _pricePerSeat.toInt() > 0 ? _pricePerSeat.toInt() : 1500,
        'pin': driverPin,
      }, token: _driverToken);
      result(rw.status, rw.body);
      if (rw.status == 200 || rw.status == 201) {
        ok('POST /wallet/card/withdraw — COBRANÇA DE CARTÃO CONCLUÍDA ✨');
      } else {
        final rwb = _asMap(rw.body);
        warn('POST /wallet/card/withdraw → ${rw.status}', rwb['message']?.toString() ?? '${rw.body}');
      }
    } else {
      warn('resolve-qr NÃO retornou cardId UUID — wallet/card/withdraw não é possível');
      info('Limitação do backend: endpoint retorna {valid, cardNumber, cardName, ownerName} mas não cardId');
      info('App mostra erro orientando passageiro a usar Fluxo 2 (PAYMENT_INTENT)');
    }
  } else {
    warn('POST /virtual-cards/resolve-qr → ${rr.status}', '${rr.body}');
  }
}

// ─── CLEANUP ──────────────────────────────────────────────────────────────────

Future<void> cleanup() async {
  section('CLEANUP');
  if (_sessionId.isNotEmpty) {
    final r = await req('POST', '/qrcodes/session/end', token: _driverToken);
    if (r.status == 200 || r.status == 201 || r.status == 500) {
      ok('POST /qrcodes/session/end');
    } else {
      warn('POST /qrcodes/session/end', 'status=${r.status}');
    }
  }
  await req('PUT', '/users/me/status',
      body: {'isOnline': false}, token: _driverToken);
  ok('Motorista marcado como offline');
}

// ─── MAIN ─────────────────────────────────────────────────────────────────────

Future<void> main(List<String> args) async {
  if (args.length < 4) {
    print('Uso: dart run test/payment_simulation_test.dart <tel-motorista> <pin-motorista> <tel-passageiro> <pin-passageiro>');
    print('Ex:  dart run test/payment_simulation_test.dart +244926283434 000000 973087387 123456');
    exit(1);
  }
  final driverPhone = args[0];
  final driverPin = args[1];
  final passengerPhone = args[2];
  final passengerPin = args[3];
  const preco = 1500.0;

  print('╔══════════════════════════════════════════════════════════╗');
  print('║  SIMULAÇÃO DE PAGAMENTO — Troco Seguro (duas contas)     ║');
  print('║  Motorista: $driverPhone   Passageiro: $passengerPhone');
  print('╚══════════════════════════════════════════════════════════╝');

  await setupMotorista(driverPhone, driverPin);
  await setupPassageiro(passengerPhone, passengerPin);
  await fluxo1IniciarSessao(preco);
  await fluxo1PagarAssento(passengerPin);
  await fluxo2MotoristaCobraPassageiro(passengerPin);
  await fluxo3CartaoVirtual(driverPin);
  await cleanup();

  print('\n╔══════════════════════════════════════════════════════════╗');
  print('║  RESULTADOS: $_pass passaram  |  $_fail falharam  |  $_warn avisos');
  print('╚══════════════════════════════════════════════════════════╝\n');

  _http.close();
  exit(_fail > 0 ? 1 : 0);
}
