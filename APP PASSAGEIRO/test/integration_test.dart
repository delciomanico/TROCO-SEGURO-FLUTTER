// dart run test/integration_test.dart <telefone> <pin>
//
// Testa todos os endpoints do APP PASSAGEIRO contra a API de produção.
// Verifica status HTTP + shape das respostas (campos esperados pelo app).
//
// Exemplo:
//   dart run test/integration_test.dart +244933000000 123456

import 'dart:convert';
import 'dart:io';

const String _base = 'https://trocoseguro.wemof.tech/api/v1';

final HttpClient _http = HttpClient()
  ..connectionTimeout = const Duration(seconds: 15);

// Estado global
String _token = '';
String _userId = '';
String _cardId = '';
String _card2Id = '';
String _tripId = '';
String _notifId = '';
String _complaintId = '';
String _testPin = '';  // PIN da conta, definido no main()

int _pass = 0, _fail = 0, _warn = 0;
final List<String> _shapeErrors = [];

// ─── HTTP helper ──────────────────────────────────────────────────────────────

Future<({int status, dynamic body})> req(
  String method,
  String path, {
  Map<String, dynamic>? body,
  bool auth = true,
  Map<String, String>? query,
}) async {
  var uriStr = '$_base$path';
  if (query != null && query.isNotEmpty) {
    uriStr += '?' + query.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
  }
  final uri = Uri.parse(uriStr);
  final rq = await _http.openUrl(method, uri);
  rq.headers.set('Content-Type', 'application/json');
  rq.headers.set('Accept', 'application/json');
  rq.headers.set('user-agent', 'TrocoSeguroPassageiroTest/1.0');
  if (auth && _token.isNotEmpty) rq.headers.set('Authorization', 'Bearer $_token');
  if (body != null) rq.write(jsonEncode(body));
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

// ─── Logging ──────────────────────────────────────────────────────────────────

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
void section(String title) =>
    print('\n── $title ─────────────────────────────────────');

// ─── Shape validation ─────────────────────────────────────────────────────────

void shape(String endpoint, dynamic data, List<String> fields) {
  if (data is! Map) {
    _shapeErrors.add('$endpoint: não é Map (${data.runtimeType})');
    return;
  }
  final missing = fields.where((f) => !data.containsKey(f)).toList();
  if (missing.isNotEmpty) {
    _shapeErrors.add('$endpoint: campos em falta: $missing');
    print('  ⚠️   Shape: $endpoint — em falta: $missing');
    print('       Chaves recebidas: ${(data as Map).keys.toList()}');
  }
}

void shapeItem(String ep, dynamic item, List<String> fields) {
  if (item is! Map) { _shapeErrors.add('$ep item: não é Map'); return; }
  final missing = fields.where((f) => !item.containsKey(f)).toList();
  if (missing.isNotEmpty) {
    _shapeErrors.add('$ep item: em falta: $missing');
    print('  ⚠️   Shape item: $ep — em falta: $missing');
  }
}

Map<String, dynamic> _asMap(dynamic v) =>
    v is Map<String, dynamic> ? v : (v is Map ? v.cast<String, dynamic>() : <String, dynamic>{});

List<dynamic> _asList(dynamic v) => v is List ? v : [];

// ─── TESTES ──────────────────────────────────────────────────────────────────

Future<void> testAuth(String phone, String pin) async {
  section('1. AUTENTICAÇÃO');

  // Login
  {
    final r = await req('POST', '/auth/login',
        body: {'phoneNumber': phone, 'password': pin}, auth: false);
    if (r.status == 200 || r.status == 201) {
      ok('POST /auth/login (${r.status})');
      final b = _asMap(r.body);
      // Token pode estar em raiz ou em data{}
      _token = b['accessToken']?.toString() ??
          _asMap(b['data'])['accessToken']?.toString() ?? '';
      final user = _asMap(b['user'] ?? _asMap(b['data'])['user'] ?? b['data'] ?? {});
      _userId = user['id']?.toString() ?? '';
      final role = user['role']?.toString().toUpperCase() ?? '';
      info('userId=$_userId  role=$role');
      shape('/auth/login', b, ['accessToken']);
      shape('/auth/login user', user, ['id', 'role']);
      if (_token.isEmpty) {
        fail('  └─ accessToken não encontrado', b.keys.toList());
        exit(1);
      }
      if (role.isNotEmpty && role != 'PASSENGER') {
        warn('Role=$role — esperado PASSENGER para este app');
      }
    } else {
      fail('POST /auth/login', 'status=${r.status}  body=${r.body}');
      exit(1);
    }
  }

  // GET /users/me
  {
    final r = await req('GET', '/users/me');
    if (r.status == 200) {
      ok('GET /users/me');
      final b = _asMap(r.body);
      final data = b.containsKey('data') ? _asMap(b['data']) : b;
      if (_userId.isEmpty) _userId = data['id']?.toString() ?? '';
      shape('/users/me', data, ['id', 'fullName', 'role']);
      // Verificar wallet
      final wallet = _asMap(data['wallet']);
      if (wallet.isNotEmpty) {
        shape('/users/me wallet', wallet, ['balance']);
        info('balance=${wallet['balance']} ${wallet['currency'] ?? 'AOA'}');
      } else if (data['balance'] != null) {
        info('balance=${data['balance']} (campo directo)');
      }
    } else {
      fail('GET /users/me', r.body);
    }
  }

  // POST /auth/verify-pin
  {
    final r = await req('POST', '/auth/verify-pin', body: {'pin': pin});
    if (r.status == 200 || r.status == 400) {
      ok('POST /auth/verify-pin (${r.status})');
    } else {
      fail('POST /auth/verify-pin', r.body);
    }
  }

  // POST /auth/refresh
  {
    final r = await req('POST', '/auth/refresh',
        body: {'refreshToken': _token}, auth: false);
    if (r.status == 200 || r.status == 201) {
      ok('POST /auth/refresh');
      final b = _asMap(r.body);
      final data = b.containsKey('data') ? _asMap(b['data']) : b;
      shape('/auth/refresh', data, ['accessToken']);
      if (data['accessToken'] != null) _token = data['accessToken'].toString();
    } else if (r.status == 401 || r.status == 400) {
      warn('POST /auth/refresh (${r.status}) — refreshToken separado não disponível');
    } else {
      fail('POST /auth/refresh', r.body);
    }
  }
}

Future<void> testWallet() async {
  section('2. CARTEIRA');

  // GET /wallet/balance
  {
    final r = await req('GET', '/wallet/balance');
    if (r.status == 200) {
      ok('GET /wallet/balance');
      final b = _asMap(r.body);
      final data = b.containsKey('data') ? _asMap(b['data']) : b;
      final bal = data['balance'] ?? data['amount'] ?? data['available'];
      if (bal != null) {
        ok('  └─ balance=$bal AOA');
      } else {
        fail('  └─ campo balance ausente', 'Chaves: ${data.keys.toList()}');
      }
    } else {
      fail('GET /wallet/balance', r.body);
    }
  }

  // GET /wallet/transfer/verify/:phone — verificar destinatário
  {
    final r = await req('GET', '/wallet/transfer/verify/%2B244900000000');
    if (r.status == 200 || r.status == 404) {
      ok('GET /wallet/transfer/verify/:phone (${r.status})');
      if (r.status == 200) {
        final b = _asMap(r.body);
        final data = b.containsKey('data') ? _asMap(b['data']) : b;
        shapeItem('GET /wallet/transfer/verify', data, ['id', 'name']);
      }
    } else {
      fail('GET /wallet/transfer/verify/:phone', r.body);
    }
  }
}

Future<void> testVirtualCards() async {
  section('3. CARTÕES VIRTUAIS');

  // GET /virtual-cards
  {
    final r = await req('GET', '/virtual-cards');
    if (r.status == 200) {
      ok('GET /virtual-cards');
      final b = _asMap(r.body);
      final list = _asList(b['cards'] ?? b['data'] ?? (r.body is List ? r.body : []));
      info('${list.length} cartão(ões)');
      if (list.isNotEmpty) {
        final c = _asMap(list.first);
        shapeItem('GET /virtual-cards item', c, ['id', 'name', 'balance']);
        _cardId = c['id']?.toString() ?? '';
        if (list.length >= 2) _card2Id = _asMap(list[1])['id']?.toString() ?? '';
      }
    } else {
      fail('GET /virtual-cards', r.body);
    }
  }

  if (_cardId.isNotEmpty) {
    // GET /virtual-cards/:id
    {
      final r = await req('GET', '/virtual-cards/$_cardId');
      if (r.status == 200) {
        ok('GET /virtual-cards/:id');
        final b = _asMap(r.body);
        final data = b.containsKey('data') ? _asMap(b['data']) : b;
        shape('/virtual-cards/:id', data, ['id', 'name', 'balance']);
      } else {
        fail('GET /virtual-cards/:id', r.body);
      }
    }

    // GET /virtual-cards/:id/qr — QR server-side
    {
      final r = await req('GET', '/virtual-cards/$_cardId/qr');
      if (r.status == 200) {
        ok('GET /virtual-cards/:id/qr');
        final b = r.body;
        final hasContent = b is String && b.isNotEmpty ||
            (b is Map &&
                (b['qrCodeImage'] ?? b['qrData'] ?? b['qr'] ?? b['token']) != null);
        if (hasContent) {
          ok('  └─ QR image/token presente');
        } else {
          fail('  └─ QR vazio ou formato inesperado', b);
        }
      } else {
        fail('GET /virtual-cards/:id/qr', r.body);
      }
    }

    // POST /virtual-cards/:id/topup — valor mínimo para teste
    {
      final r = await req('POST', '/virtual-cards/$_cardId/topup', body: {'amount': 1});
      // 400 esperado se saldo insuficiente, 200 se OK
      if (r.status == 200 || r.status == 201 || r.status == 400) {
        ok('POST /virtual-cards/:id/topup (${r.status})');
      } else {
        fail('POST /virtual-cards/:id/topup', r.body);
      }
    }

    // PUT /virtual-cards/:id/status — congelar
    {
      final r = await req('PUT', '/virtual-cards/$_cardId/status',
          body: {'status': 'frozen'});
      if (r.status == 200) {
        ok('PUT /virtual-cards/:id/status {frozen}');
        // Descongelar imediatamente
        await req('PUT', '/virtual-cards/$_cardId/status', body: {'status': 'active'});
      } else {
        fail('PUT /virtual-cards/:id/status', r.body);
      }
    }

    // PUT /virtual-cards/:id/limit
    {
      final r = await req('PUT', '/virtual-cards/$_cardId/limit',
          body: {'dailyLimit': 5000});
      if (r.status == 200) {
        ok('PUT /virtual-cards/:id/limit');
      } else {
        fail('PUT /virtual-cards/:id/limit', r.body);
      }
    }
  } else {
    warn('Sem cartões — criando um de teste');

    // POST /virtual-cards — criar cartão de teste
    final r = await req('POST', '/virtual-cards', body: {
      'name': 'Cartao Teste API',
      'initialBalance': 100,
      'dailyLimit': 1000,
      'userPin': _testPin,   // PIN real da conta
      'cardPin': '1234',     // API exige ≤ 4 caracteres
    });
    if (r.status == 200 || r.status == 201) {
      ok('POST /virtual-cards (criar)');
      final b = _asMap(r.body);
      final data = b.containsKey('data') ? _asMap(b['data']) : b;
      _cardId = data['id']?.toString() ?? '';
      shapeItem('POST /virtual-cards', data, ['id', 'cardNumber']);
      info('cardNumber=${data['cardNumber']}  cvv=${data['cvv']}  expiry=${data['expiry']}');
    } else {
      fail('POST /virtual-cards', r.body);
    }
  }

  // POST /virtual-cards/resolve-qr — QR inválido → 400/422
  {
    final r = await req('POST', '/virtual-cards/resolve-qr', body: {'qrData': 'invalido'});
    if (r.status == 400 || r.status == 422 || r.status == 404) {
      ok('POST /virtual-cards/resolve-qr (${r.status} — rejeita QR inválido)');
    } else {
      fail('POST /virtual-cards/resolve-qr', r.body);
    }
  }

  // Transferência entre cartões — 400 esperado se PIN do cartão ≠ pin da conta
  if (_cardId.isNotEmpty && _card2Id.isNotEmpty) {
    final r = await req('POST', '/wallet/transfer', body: {
      'fromCardId': _cardId,
      'toCardId': _card2Id,
      'amount': 1,
      'pin': '000000',
    });
    if (r.status == 400 || r.status == 401 || r.status == 200) {
      ok('POST /wallet/transfer (${r.status})');
    } else {
      fail('POST /wallet/transfer', r.body);
    }
  }
}

Future<void> testQrAndPayments() async {
  section('4. QR E PAGAMENTOS');

  // GET /qrcodes/resolve?token=invalido — deve dar 404
  {
    final r = await req('GET', '/qrcodes/resolve',
        query: {'token': 'token-invalido-para-teste'});
    if (r.status == 404 || r.status == 400) {
      ok('GET /qrcodes/resolve?token= (${r.status} — rejeita token inválido)');
      // Verificar shape da resposta de erro
      final b = _asMap(r.body);
      info('Resposta de erro: ${b['message'] ?? b}');
    } else if (r.status == 200) {
      fail('GET /qrcodes/resolve aceitou token inválido', r.body);
    } else {
      fail('GET /qrcodes/resolve', r.body);
    }
  }

  // POST /payments/process — campos obrigatórios em falta → 400
  {
    final r = await req('POST', '/payments/process', body: {
      'driverId': 'id-invalido',
      'pin': '000000',
      'origin': 'Teste',
      'destination': 'Teste',
      'paymentToken': 'token-invalido',
    });
    if (r.status == 400 || r.status == 404 || r.status == 422) {
      ok('POST /payments/process (${r.status} — validação correcta)');
      // Verificar se o campo 'amount' é necessário (não está no schema ProcessPaymentDto)
      final b = _asMap(r.body);
      final msg = b['message']?.toString() ?? '';
      if (msg.toLowerCase().contains('amount')) {
        warn('  └─ API pede "amount" mas ProcessPaymentDto não o documenta — verificar');
      }
    } else if (r.status == 200) {
      warn('POST /payments/process aceitou dados completamente inválidos');
    } else {
      fail('POST /payments/process', r.body);
    }
  }

  // POST /payments/deposit/initiate — iniciar depósito
  {
    final r = await req('POST', '/payments/deposit/initiate', body: {'amount': 1000});
    if (r.status == 200 || r.status == 201) {
      ok('POST /payments/deposit/initiate');
      final b = _asMap(r.body);
      final data = b.containsKey('data') ? _asMap(b['data']) : b;
      info('Chaves de resposta: ${data.keys.toList()}');
    } else {
      fail('POST /payments/deposit/initiate', r.body);
    }
  }
}

Future<void> testTrips() async {
  section('5. VIAGENS');

  {
    final r = await req('GET', '/trips');
    if (r.status == 200) {
      ok('GET /trips');
      final b = _asMap(r.body);
      final list = _asList(b['trips'] ?? b['data'] ?? (r.body is List ? r.body : []));
      info('${list.length} viagem(ns)');
      if (list.isNotEmpty) {
        final t = _asMap(list.first);
        shapeItem('GET /trips item', t, ['id', 'amount', 'status']);
        _tripId = t['id']?.toString() ?? '';
      }
    } else {
      fail('GET /trips', r.body);
    }
  }

  if (_tripId.isNotEmpty) {
    final r = await req('GET', '/trips/$_tripId');
    if (r.status == 200) {
      ok('GET /trips/:id');
    } else {
      fail('GET /trips/:id', r.body);
    }
  }

  {
    final r = await req('GET', '/trips/stats');
    if (r.status == 200) {
      ok('GET /trips/stats');
      final b = _asMap(r.body);
      final data = b.containsKey('data') ? _asMap(b['data']) : b;
      shape('/trips/stats', data, ['totalTrips']);
    } else {
      fail('GET /trips/stats', r.body);
    }
  }
}

Future<void> testTransactions() async {
  section('6. TRANSAÇÕES');

  {
    final r = await req('GET', '/transactions/history');
    if (r.status == 200) {
      ok('GET /transactions/history');
      final b = _asMap(r.body);
      final list = _asList(
          b['transactions'] ?? b['history'] ?? b['data'] ?? (r.body is List ? r.body : []));
      info('${list.length} transação(ões)');
      if (list.isNotEmpty) {
        // API usa displayAmount/originalAmount (não 'amount')
        shapeItem('GET /transactions/history item', _asMap(list.first),
            ['id', 'displayAmount', 'status']);
      }
    } else {
      fail('GET /transactions/history', r.body);
    }
  }
}

Future<void> testNotifications() async {
  section('7. NOTIFICAÇÕES');

  {
    final r = await req('GET', '/notifications');
    if (r.status == 200) {
      ok('GET /notifications');
      final b = _asMap(r.body);
      final list = _asList(b['notifications'] ?? b['data'] ?? (r.body is List ? r.body : []));
      info('${list.length} notificação(ões)');
      if (list.isNotEmpty) {
        final n = _asMap(list.first);
        // API usa 'isRead' (não 'read') — model já lida com ambos
        shapeItem('GET /notifications item', n, ['id', 'title', 'isRead']);
        _notifId = n['id']?.toString() ?? '';
      }
    } else {
      fail('GET /notifications', r.body);
    }
  }

  if (_notifId.isNotEmpty) {
    final r = await req('PUT', '/notifications/$_notifId/read');
    if (r.status == 200 || r.status == 204) ok('PUT /notifications/:id/read');
    else fail('PUT /notifications/:id/read', r.body);
  }

  {
    final r = await req('PUT', '/notifications/read-all');
    if (r.status == 200 || r.status == 204) ok('PUT /notifications/read-all');
    else fail('PUT /notifications/read-all', r.body);
  }
}

Future<void> testSafety() async {
  section('8. SEGURANÇA');

  // GET /safety/emergency-contacts
  {
    final r = await req('GET', '/safety/emergency-contacts');
    if (r.status == 200) {
      ok('GET /safety/emergency-contacts');
      final b = _asMap(r.body);
      final list = _asList(b['contacts'] ?? b['data'] ?? (r.body is List ? r.body : []));
      info('${list.length} contacto(s)');
    } else {
      fail('GET /safety/emergency-contacts', r.body);
    }
  }

  // POST /safety/emergency-contacts + DELETE
  String testContactId = '';
  {
    final r = await req('POST', '/safety/emergency-contacts',
        body: {'name': 'Teste Passageiro', 'phoneNumber': '+244900000002'});
    if (r.status == 200 || r.status == 201) {
      ok('POST /safety/emergency-contacts');
      final b = _asMap(r.body);
      final data = _asMap(b['contact'] ?? b['emergencyContact'] ?? b['data'] ?? b);
      testContactId = data['id']?.toString() ?? '';
      shapeItem('POST /safety/emergency-contacts', data, ['id', 'name', 'phoneNumber']);
    } else {
      fail('POST /safety/emergency-contacts', r.body);
    }
  }
  if (testContactId.isNotEmpty) {
    final r = await req('DELETE', '/safety/emergency-contacts/$testContactId');
    if (r.status == 200 || r.status == 204) ok('DELETE /safety/emergency-contacts/:id');
    else warn('DELETE contacto (${r.status}) — limpar manualmente: $testContactId');
  }

  // POST /safety/panic
  {
    final r = await req('POST', '/safety/panic', body: {
      'latitude': -8.839988,
      'longitude': 13.289437,
    });
    if (r.status == 200 || r.status == 201 || r.status == 204) {
      ok('POST /safety/panic');
    } else {
      fail('POST /safety/panic', r.body);
    }
  }
}

Future<void> testRatings() async {
  section('9. AVALIAÇÕES');

  if (_userId.isEmpty) {
    warn('userId não disponível — saltado');
    return;
  }

  {
    final r = await req('GET', '/ratings/$_userId');
    if (r.status == 200) {
      ok('GET /ratings/:userId');
      final b = _asMap(r.body);
      final list = _asList(
          b['ratings'] ?? b['data'] ?? b['items'] ?? (r.body is List ? r.body : []));
      info('${list.length} avaliação(ões)');
    } else {
      fail('GET /ratings/:userId', r.body);
    }
  }
}

Future<void> testComplaints() async {
  section('10. RECLAMAÇÕES');

  // POST /complaints
  {
    final r = await req('POST', '/complaints', body: {
      'category': 'OTHER',
      'reasonCode': 'other',
      'description': 'Teste automatico de integracao - ignorar',
    });
    if (r.status == 200 || r.status == 201) {
      ok('POST /complaints (criar)');
      final b = _asMap(r.body);
      final data = _asMap(b['data'] ?? b);
      _complaintId = data['id']?.toString() ?? '';
    } else {
      fail('POST /complaints', r.body);
    }
  }

  // GET /complaints
  {
    final r = await req('GET', '/complaints');
    if (r.status == 200) {
      ok('GET /complaints (listar)');
      final b = _asMap(r.body);
      final list = _asList(b['data'] ?? (r.body is List ? r.body : []));
      info('${list.length} reclamação(ões)');
      if (list.isNotEmpty && _complaintId.isEmpty) {
        _complaintId = _asMap(list.first)['id']?.toString() ?? '';
      }
    } else {
      fail('GET /complaints', r.body);
    }
  }

  if (_complaintId.isNotEmpty) {
    final r = await req('GET', '/complaints/$_complaintId');
    if (r.status == 200) {
      ok('GET /complaints/:id');
    } else {
      fail('GET /complaints/:id', r.body);
    }
  }
}

Future<void> testAuthForgotPassword(String phone) async {
  section('11. RECUPERAÇÃO DE PASSWORD');

  {
    final r = await req('POST', '/auth/forgot-password',
        body: {'phoneNumber': phone}, auth: false);
    if (r.status == 200 || r.status == 201) {
      ok('POST /auth/forgot-password');
    } else if (r.status == 429) {
      warn('POST /auth/forgot-password → 429 (rate limit)');
    } else if (r.status == 404) {
      warn('POST /auth/forgot-password → 404');
    } else {
      fail('POST /auth/forgot-password', r.body);
    }
  }
}

Future<void> testUpdateProfile() async {
  section('12. ACTUALIZAR PERFIL');

  {
    // UpdateProfileDto aceita: fullName, birthDate
    final r = await req('PUT', '/users/me', body: {'fullName': 'Passageiro Teste'});
    if (r.status == 200) {
      ok('PUT /users/me');
      final b = _asMap(r.body);
      final data = b.containsKey('data') ? _asMap(b['data']) : b;
      shape('/users/me PUT response', data, ['id', 'fullName']);
    } else if (r.status == 422) {
      warn('PUT /users/me → 422 — campos podem ter mudado');
    } else {
      fail('PUT /users/me', r.body);
    }
  }

  // PUT /users/me/pin — muda para o mesmo PIN (confirma que endpoint existe e valida)
  {
    final r = await req('PUT', '/users/me/pin',
        body: {'currentPin': _testPin, 'newPin': _testPin});
    if (r.status == 200) {
      ok('PUT /users/me/pin (${r.status})');
    } else if (r.status == 400 || r.status == 401) {
      fail('PUT /users/me/pin (${r.status} — PIN correcto rejeitado)', r.body);
    } else {
      fail('PUT /users/me/pin', r.body);
    }
  }
}

Future<void> testLogout() async {
  section('13. LOGOUT');
  final r = await req('POST', '/auth/logout');
  if (r.status == 200 || r.status == 204) {
    ok('POST /auth/logout');
  } else {
    warn('POST /auth/logout (${r.status})');
  }
}

// ─── MAIN ────────────────────────────────────────────────────────────────────

Future<void> main(List<String> args) async {
  if (args.length < 2) {
    print('Uso: dart run test/integration_test.dart <telefone> <pin>');
    print('Ex:  dart run test/integration_test.dart +244933000000 123456');
    exit(1);
  }
  final phone = args[0];
  final pin = args[1];
  _testPin = pin;

  print('\n╔══════════════════════════════════════════════════╗');
  print('║  APP PASSAGEIRO — Integração API completa        ║');
  print('║  ${'$_base'.padRight(48)} ║');
  print('╚══════════════════════════════════════════════════╝');

  await testAuth(phone, pin);
  await testWallet();
  await testVirtualCards();
  await testQrAndPayments();
  await testTrips();
  await testTransactions();
  await testNotifications();
  await testSafety();
  await testRatings();
  await testComplaints();
  await testAuthForgotPassword(phone);
  await testUpdateProfile();
  await testLogout();

  // ── Shape errors ──────────────────────────────────────────────────────────
  if (_shapeErrors.isNotEmpty) {
    print('\n── Problemas de Shape (campos esperados pelo app ausentes na API) ──');
    for (final e in _shapeErrors) {
      print('  ⚠️   $e');
    }
  }

  // ── Resultado ─────────────────────────────────────────────────────────────
  final total = _pass + _fail;
  print('\n╔══════════════════════════════════════════════════╗');
  print('║  $_pass/$total passou  |  $_fail falharam  |  $_warn avisos'.padRight(51) + '║');
  if (_shapeErrors.isNotEmpty) {
    print('║  ${_shapeErrors.length} problema(s) de shape detectado(s)'.padRight(51) + '║');
  }
  print('╚══════════════════════════════════════════════════╝\n');

  exit(_fail > 0 ? 1 : 0);
}
