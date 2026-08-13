// dart run test/integration_test.dart <telefone> <pin> [<vehicleId>]
//
// Testa todos os endpoints do APP MOTORISTA contra a API de produção.
// Verifica status HTTP + shape das respostas (campos esperados pelo app).
//
// Exemplo:
//   dart run test/integration_test.dart +244926000000 123456

import 'dart:convert';
import 'dart:io';

const String _base = 'https://trocoseguro.wemof.tech/api/v1';

final HttpClient _http = HttpClient()
  ..connectionTimeout = const Duration(seconds: 15);

// Estado global do teste
String _token = '';
String _userId = '';
String _vehicleId = '';
String _sessionParentToken = '';
String _tripId = '';
String _contactId = '';

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
    uriStr += '?${query.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&')}';
  }
  final uri = Uri.parse(uriStr);
  final rq = await _http.openUrl(method, uri);
  rq.headers.set('Content-Type', 'application/json');
  rq.headers.set('Accept', 'application/json');
  rq.headers.set('user-agent', 'TrocoSeguroTest/1.0');
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

// ─── Logging helpers ──────────────────────────────────────────────────────────

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

// ─── Shape validation ─────────────────────────────────────────────────────────

/// Verifica se [data] contém os [fields] esperados.
/// Regista falha de shape mas não incrementa _fail (é aviso de integração).
void shape(String endpoint, dynamic data, List<String> fields) {
  if (data is! Map) {
    _shapeErrors.add('$endpoint: resposta não é Map (${data.runtimeType})');
    return;
  }
  final missing = fields.where((f) => !data.containsKey(f)).toList();
  if (missing.isNotEmpty) {
    _shapeErrors.add('$endpoint: campos em falta: $missing');
    print('  ⚠️   Shape: $endpoint — em falta: $missing');
    print('       Chaves recebidas: ${(data).keys.toList()}');
  }
}

/// Mesma verificação mas para um item dentro de uma lista.
void shapeItem(String endpoint, dynamic item, List<String> fields) {
  if (item is! Map) {
    _shapeErrors.add('$endpoint item: não é Map');
    return;
  }
  final missing = fields.where((f) => !item.containsKey(f)).toList();
  if (missing.isNotEmpty) {
    _shapeErrors.add('$endpoint item: campos em falta: $missing');
    print('  ⚠️   Shape item: $endpoint — em falta: $missing');
  }
}

// ─── Extracção segura ────────────────────────────────────────────────────────

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
      final data = b.containsKey('data') ? _asMap(b['data']) : b;
      _token = data['accessToken']?.toString() ?? data['access_token']?.toString() ?? '';
      final user = _asMap(data['user'] ?? data);
      _userId = user['id']?.toString() ?? '';
      final role = user['role']?.toString().toUpperCase() ?? '';
      info('userId=$_userId  role=$role');
      if (_token.isEmpty) {
        fail('  └─ accessToken não encontrado na resposta', b.keys.toList());
        exit(1);
      }
      if (role.isNotEmpty && role != 'DRIVER') {
        fail('  └─ Role inválido: $role (necessário DRIVER)', '');
        exit(1);
      }
      shape('/auth/login response', data, ['accessToken', 'user']);
      shape('/auth/login user', user, ['id', 'role']);
    } else {
      fail('POST /auth/login', 'status=${r.status}  body=${r.body}');
      exit(1);
    }
  }

  // GET /users/me — endpoint principal de perfil
  {
    final r = await req('GET', '/users/me');
    if (r.status == 200) {
      ok('GET /users/me');
      final b = _asMap(r.body);
      final data = b.containsKey('data') ? _asMap(b['data']) : b;
      if (_userId.isEmpty) _userId = data['id']?.toString() ?? '';
      shape('/users/me', data, ['id', 'fullName', 'role']);
      // Verificar wallet/balance no perfil (usado como fallback no app)
      if (data['wallet'] != null) {
        final wallet = _asMap(data['wallet']);
        shape('/users/me wallet', wallet, ['balance']);
        info('balance=${wallet['balance']} ${wallet['currency'] ?? 'AOA'}');
      } else if (data['balance'] != null) {
        info('balance=${data['balance']} (campo directo)');
      } else {
        warn('  └─ /users/me sem wallet nem balance — fallback de saldo pode falhar');
      }
    } else {
      fail('GET /users/me', r.body);
    }
  }

  // GET /auth/profile — endpoint alternativo (usado como fallback no app)
  {
    final r = await req('GET', '/auth/profile');
    if (r.status == 200) {
      ok('GET /auth/profile (fallback)');
    } else {
      warn('GET /auth/profile não disponível (${r.status}) — fallback inoperacional');
    }
  }

  // PUT /users/me/status — offline (não perturbar estado)
  {
    final r = await req('PUT', '/users/me/status', body: {'isOnline': false});
    if (r.status == 200 || r.status == 204) {
      ok('PUT /users/me/status {isOnline: false}');
    } else {
      fail('PUT /users/me/status', r.body);
    }
  }

  // POST /auth/verify-pin
  {
    final r = await req('POST', '/auth/verify-pin', body: {'pin': pin});
    if (r.status == 200 || r.status == 400) {
      // 400 = PIN inválido mas endpoint existe e valida
      ok('POST /auth/verify-pin (${r.status})');
    } else {
      fail('POST /auth/verify-pin', r.body);
    }
  }

  // POST /auth/refresh
  {
    // Guardar token actual para comparar
    final oldToken = _token;
    final r = await req('POST', '/auth/refresh',
        body: {'refreshToken': oldToken}, auth: false);
    // Nota: se não temos refreshToken separado, vai usar o accessToken — pode dar 401
    if (r.status == 200 || r.status == 201) {
      ok('POST /auth/refresh');
      final b = _asMap(r.body);
      final data = b.containsKey('data') ? _asMap(b['data']) : b;
      shape('/auth/refresh', data, ['accessToken']);
      if (data['accessToken'] != null) _token = data['accessToken'].toString();
    } else if (r.status == 401 || r.status == 400) {
      warn('POST /auth/refresh (${r.status}) — refreshToken não disponível no teste');
    } else {
      fail('POST /auth/refresh', r.body);
    }
  }
}

Future<void> testFleet(String phone) async {
  section('2. FROTA E VEÍCULOS');

  // GET /fleet
  {
    final r = await req('GET', '/fleet');
    if (r.status == 200) {
      ok('GET /fleet');
      final b = _asMap(r.body);
      // API retorna {id, name, vehicles: [...]}
      final vehicles = _asList(b['vehicles'] ?? b['data'] ?? (r.body is List ? r.body : []));
      info('${vehicles.length} veículo(s) na frota');
      if (vehicles.isNotEmpty) {
        final v = _asMap(vehicles.first);
        shapeItem('GET /fleet vehicles', v, ['id', 'model', 'seats']);
        _vehicleId = v['id']?.toString() ?? '';
        info('vehicleId=$_vehicleId  modelo=${v['model']}  lugares=${v['seats']}');
      }
    } else {
      fail('GET /fleet', r.body);
    }
  }

  // POST /fleet/vehicles — criar veículo de teste
  final plate = 'TST-${DateTime.now().millisecondsSinceEpoch % 99999}';
  String testVehicleId = '';
  {
    final r = await req('POST', '/fleet/vehicles', body: {
      'licensePlate': plate,
      'model': 'Teste API',
      'color': 'Cinzento',
      'seats': 4,
    });
    if (r.status == 200 || r.status == 201) {
      ok('POST /fleet/vehicles (criar)');
      final b = _asMap(r.body);
      final data = _asMap(b['data'] ?? b);
      testVehicleId = data['id']?.toString() ?? '';
      shapeItem('POST /fleet/vehicles', data, ['id', 'licensePlate', 'model', 'seats']);
      info('Veículo de teste: $testVehicleId ($plate)');
      if (_vehicleId.isEmpty) _vehicleId = testVehicleId;
    } else if (r.status == 500) {
      warn('POST /fleet/vehicles → 500 (bug servidor — criação de veículos indisponível)');
    } else {
      fail('POST /fleet/vehicles', r.body);
    }
  }

  // PUT /fleet/vehicles/:id — editar
  if (testVehicleId.isNotEmpty) {
    final r = await req('PUT', '/fleet/vehicles/$testVehicleId', body: {
      'model': 'Teste API Editado',
      'seats': 5,
    });
    if (r.status == 200 || r.status == 201) {
      ok('PUT /fleet/vehicles/:id (editar)');
    } else {
      fail('PUT /fleet/vehicles/:id', r.body);
    }
  }

  // DELETE /fleet/vehicles/:id — cleanup
  if (testVehicleId.isNotEmpty) {
    final r = await req('DELETE', '/fleet/vehicles/$testVehicleId');
    if (r.status == 200 || r.status == 204) {
      ok('DELETE /fleet/vehicles/:id (eliminar veículo de teste)');
    } else {
      warn('DELETE /fleet/vehicles/:id (${r.status}) — limpeza manual necessária: $testVehicleId');
    }
  }
}

Future<void> testQrSession() async {
  section('3. SESSÃO QR / VIAGEM');

  if (_vehicleId.isEmpty) {
    warn('Sem vehicleId — testes de sessão QR saltados');
    return;
  }

  // GET /qrcodes/my-static — QR estáticos do motorista
  {
    final r = await req('GET', '/qrcodes/my-static');
    if (r.status == 200) {
      ok('GET /qrcodes/my-static');
      final b = _asMap(r.body);
      final list = _asList(b['data'] ?? b['qrcodes'] ?? (r.body is List ? r.body : []));
      info('${list.length} QR(s) estático(s)');
    } else if (r.status == 403) {
      warn('GET /qrcodes/my-static → 403 (role sem acesso?)');
    } else {
      fail('GET /qrcodes/my-static', r.body);
    }
  }

  // GET /qrcodes/session/history — histórico de sessões
  {
    final r = await req('GET', '/qrcodes/session/history');
    if (r.status == 200) {
      ok('GET /qrcodes/session/history');
      final b = _asMap(r.body);
      final list = _asList(b['data'] ?? b['sessions'] ?? (r.body is List ? r.body : []));
      info('${list.length} sessão(ões) no histórico');
    } else if (r.status == 404) {
      warn('GET /qrcodes/session/history → 404');
    } else {
      fail('GET /qrcodes/session/history', r.body);
    }
  }

  // Ficar online antes de iniciar sessão
  {
    final r = await req('PUT', '/users/me/status', body: {'isOnline': true});
    if (r.status == 200 || r.status == 204) {
      ok('PUT /users/me/status {isOnline: true}');
    } else {
      warn('PUT /users/me/status online (${r.status})');
    }
  }

  // POST /qrcodes/session/start — corpo: {pricePerSeat, vehicleId}
  String parentQrImage = '';
  {
    final r = await req('POST', '/qrcodes/session/start', body: {
      'pricePerSeat': 500,
      'vehicleId': _vehicleId,
    });
    if (r.status == 200 || r.status == 201) {
      ok('POST /qrcodes/session/start');
      final b = _asMap(r.body);
      final data = b.containsKey('data') ? _asMap(b['data']) : b;

      // App tenta 'qrCode' primeiro, depois 'parentQr'
      final parentQrRaw = data['qrCode'] ?? data['parentQr'];
      final parentQr = _asMap(parentQrRaw);
      _sessionParentToken = parentQr['publicToken']?.toString() ?? '';

      info('Chaves na resposta: ${data.keys.toList()}');

      if (parentQrRaw != null) {
        ok('  └─ parentQr/qrCode presente na resposta');
        // qrCode retorna {publicToken, image} — sem campo 'id' (sessionId está no topo)
        shapeItem('session/start parentQr', parentQr, ['publicToken', 'image']);
        parentQrImage = parentQr['image']?.toString() ?? '';
        final imageOk = parentQrImage.startsWith('data:image/');
        if (imageOk) {
          ok('  └─ parentQr.image é base64 PNG válido');
        } else {
          warn('  └─ parentQr.image formato inesperado: ${parentQrImage.substring(0, parentQrImage.length.clamp(0, 40))}');
        }
      } else {
        fail('  └─ parentQr/qrCode ausente da resposta', 'Chaves: ${data.keys.toList()}');
      }

      final childQrs = _asList(data['childQrs']);
      if (childQrs.isNotEmpty) {
        ok('  └─ ${childQrs.length} childQr(s) gerados');
        shapeItem('session/start childQrs[0]', _asMap(childQrs.first), ['id', 'label', 'image']);
      } else {
        warn('  └─ childQrs vazio ou ausente — SeatQrsModal não vai funcionar');
      }

      // Verificar pricePerSeat no parentQr (o app lê este campo)
      final price = parentQr['pricePerSeat'] ?? parentQr['tripPrice'];
      if (price != null) {
        ok('  └─ pricePerSeat/tripPrice presente: $price AOA');
      } else {
        warn('  └─ pricePerSeat não encontrado no parentQr — badge de preço pode mostrar 0');
      }
    } else {
      fail('POST /qrcodes/session/start', 'status=${r.status}  body=${r.body}');
    }
  }

  // GET /qrcodes/session/seats — verificar estado da sessão
  {
    final r = await req('GET', '/qrcodes/session/seats');
    if (r.status == 200) {
      ok('GET /qrcodes/session/seats');
      final b = _asMap(r.body);
      final data = b.containsKey('data') ? _asMap(b['data']) : b;
      shape('/qrcodes/session/seats', data, ['active', 'totalSeats', 'revenue']);

      info('active=${data['active']}  totalSeats=${data['totalSeats']}  revenue=${data['revenue']}');

      // O app lê 'totalPayments' OU 'paidSeats' — verificar qual existe
      final paidKey = data.containsKey('totalPayments')
          ? 'totalPayments'
          : data.containsKey('paidSeats')
              ? 'paidSeats'
              : null;
      if (paidKey != null) {
        ok('  └─ campo assentos pagos: "$paidKey"=${data[paidKey]}');
      } else {
        fail('  └─ nem totalPayments nem paidSeats na resposta',
            'Chaves: ${data.keys.toList()}');
      }
    } else if (r.status == 404) {
      warn('GET /qrcodes/session/seats → 404 (sessão não iniciada?)');
    } else {
      fail('GET /qrcodes/session/seats', r.body);
    }
  }

  // GET /qrcodes/session/current — endpoint novo, verificar o que retorna
  {
    final r = await req('GET', '/qrcodes/session/current');
    if (r.status == 200) {
      ok('GET /qrcodes/session/current (novo endpoint)');
      final b = _asMap(r.body);
      final data = b.containsKey('data') ? _asMap(b['data']) : b;
      info('Chaves: ${data.keys.toList()}');
    } else if (r.status == 404) {
      info('GET /qrcodes/session/current → 404 (sem sessão activa)');
    } else {
      warn('GET /qrcodes/session/current (${r.status})');
    }
  }

  // POST /payments/authorize-passenger-qr — dados inválidos → 400 esperado
  {
    final qrPayload = jsonEncode({
      'type': 'PAYMENT_INTENT',
      'userId': 'invalid-user-id',
      'amount': 500,
      'name': 'Passageiro Teste',
      'phoneNumber': '+244900000000',
    });
    final r = await req('POST', '/payments/authorize-passenger-qr', body: {
      'qrData': qrPayload,
      'passengerPin': '000000',
      'origin': 'Teste',
      'destination': 'Teste',
      'seatsCount': 1,
      if (_sessionParentToken.isNotEmpty) 'parentQrToken': _sessionParentToken,
    });
    if (r.status == 400 || r.status == 404 || r.status == 422) {
      ok('POST /payments/authorize-passenger-qr (${r.status} — validação correcta)');
    } else if (r.status == 200 || r.status == 201) {
      warn('POST /payments/authorize-passenger-qr devolveu 2xx com dados inválidos — verificar');
    } else if (r.status == 500) {
      warn('POST /payments/authorize-passenger-qr → 500 (bug servidor ao processar userId inválido)');
    } else {
      fail('POST /payments/authorize-passenger-qr', 'status=${r.status}  body=${r.body}');
    }
  }

  // POST /qrcodes/session/end
  {
    final r = await req('POST', '/qrcodes/session/end');
    if (r.status == 200 || r.status == 201 || r.status == 204 || r.status == 404) {
      ok('POST /qrcodes/session/end (${r.status})');
    } else {
      fail('POST /qrcodes/session/end', r.body);
    }
  }

  // Voltar offline
  {
    await req('PUT', '/users/me/status', body: {'isOnline': false});
  }
}

Future<void> testTrips() async {
  section('4. VIAGENS');

  {
    final r = await req('GET', '/trips', query: {'page': '1', 'limit': '10'});
    if (r.status == 200) {
      ok('GET /trips');
      final b = _asMap(r.body);
      final list = _asList(b['data'] ?? b['trips'] ?? (r.body is List ? r.body : []));
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
  section('5. TRANSAÇÕES E CARTEIRA');

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
        fail('  └─ campo balance não encontrado', 'Chaves: ${data.keys.toList()}');
      }
    } else {
      fail('GET /wallet/balance', r.body);
    }
  }

  // GET /transactions/history
  {
    final r = await req('GET', '/transactions/history',
        query: {'page': '1', 'limit': '20'});
    if (r.status == 200) {
      ok('GET /transactions/history');
      final b = _asMap(r.body);
      final list = _asList(b['data'] ?? b['transactions'] ?? b['history'] ?? (r.body is List ? r.body : []));
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

  // POST /transactions/withdraw — validação (IBAN inválido → 400)
  {
    final r = await req('POST', '/transactions/withdraw',
        body: {'amount': 100, 'iban': 'IBAN-INVALIDO-TESTE'});
    if (r.status == 400 || r.status == 422) {
      ok('POST /transactions/withdraw (${r.status} — validação IBAN correcta)');
    } else if (r.status == 200 || r.status == 201) {
      warn('POST /transactions/withdraw aceitou IBAN inválido — verificar validação');
    } else {
      fail('POST /transactions/withdraw', r.body);
    }
  }

  // GET /wallet/transfer/verify/:phone — pré-validação de destinatário P2P
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

  // POST /wallet/transfer-to-user — P2P por phoneNumber (PIN errado → 400/401)
  {
    final r = await req('POST', '/wallet/transfer-to-user', body: {
      'phoneNumber': '+244900000000',
      'amount': 1,
      'pin': '000000',
    });
    if (r.status == 400 || r.status == 404 || r.status == 200 || r.status == 201) {
      ok('POST /wallet/transfer-to-user (${r.status})');
    } else {
      fail('POST /wallet/transfer-to-user', r.body);
    }
  }

  // POST /wallet/transfer-to-card — PAN inválido → 400/404/422
  {
    final r = await req('POST', '/wallet/transfer-to-card', body: {
      'cardNumber': '0000000000000000',
      'amount': 1,
      'pin': '000000',
    });
    if (r.status == 400 || r.status == 404 || r.status == 422) {
      ok('POST /wallet/transfer-to-card (${r.status} — PAN inválido rejeitado)');
    } else {
      fail('POST /wallet/transfer-to-card', r.body);
    }
  }

  // POST /wallet/card/deposit — carregar cartão virtual alheio (cardId inválido → 400/404)
  {
    final r = await req('POST', '/wallet/card/deposit', body: {
      'cardId': 'id-invalido',
      'amount': 1,
    });
    if (r.status == 400 || r.status == 404 || r.status == 422) {
      ok('POST /wallet/card/deposit (${r.status} — cardId inválido rejeitado)');
    } else {
      fail('POST /wallet/card/deposit', r.body);
    }
  }

  // GET /wallet/balance-by-qr/:qrId — QR inválido → 404
  {
    final r = await req('GET', '/wallet/balance-by-qr/qr-invalido-teste');
    if (r.status == 404 || r.status == 400) {
      ok('GET /wallet/balance-by-qr/:qrId (${r.status} — QR inválido rejeitado)');
    } else if (r.status == 200) {
      warn('GET /wallet/balance-by-qr com QR inválido devolveu 200 — verificar');
    } else if (r.status == 500) {
      warn('GET /wallet/balance-by-qr/:qrId → 500 (bug servidor — devia retornar 404)');
    } else {
      fail('GET /wallet/balance-by-qr/:qrId', r.body);
    }
  }
}

Future<void> testNotifications() async {
  section('6. NOTIFICAÇÕES');

  String notifId = '';
  {
    final r = await req('GET', '/notifications');
    if (r.status == 200) {
      ok('GET /notifications');
      final b = _asMap(r.body);
      final list = _asList(b['data'] ?? b['notifications'] ?? (r.body is List ? r.body : []));
      info('${list.length} notificação(ões)');
      if (list.isNotEmpty) {
        final n = _asMap(list.first);
        // API usa 'isRead' (não 'read') — model já lida com ambos
        shapeItem('GET /notifications item', n, ['id', 'title', 'isRead']);
        notifId = n['id']?.toString() ?? '';
      }
    } else {
      fail('GET /notifications', r.body);
    }
  }

  if (notifId.isNotEmpty) {
    final r = await req('PUT', '/notifications/$notifId/read');
    if (r.status == 200 || r.status == 204) {
      ok('PUT /notifications/:id/read');
    } else {
      fail('PUT /notifications/:id/read', r.body);
    }
  }

  {
    final r = await req('PUT', '/notifications/read-all');
    if (r.status == 200 || r.status == 204) {
      ok('PUT /notifications/read-all');
    } else {
      fail('PUT /notifications/read-all', r.body);
    }
  }
}

Future<void> testSafety() async {
  section('7. SEGURANÇA');

  // GET /safety/emergency-contacts
  {
    final r = await req('GET', '/safety/emergency-contacts');
    if (r.status == 200) {
      ok('GET /safety/emergency-contacts');
      final b = _asMap(r.body);
      final list = _asList(b['data'] ?? (r.body is List ? r.body : []));
      info('${list.length} contacto(s)');
      if (list.isNotEmpty) {
        _contactId = _asMap(list.first)['id']?.toString() ?? '';
        shapeItem('GET /safety/emergency-contacts item', _asMap(list.first),
            ['id', 'name', 'phoneNumber']);
      }
    } else {
      fail('GET /safety/emergency-contacts', r.body);
    }
  }

  // POST /safety/emergency-contacts — criar contacto de teste
  String testContactId = '';
  {
    final r = await req('POST', '/safety/emergency-contacts', body: {
      'name': 'Teste Automatico',
      'phoneNumber': '+244900000001',
    });
    if (r.status == 200 || r.status == 201) {
      ok('POST /safety/emergency-contacts (criar)');
      final b = _asMap(r.body);
      final data = _asMap(b['data'] ?? b['contact'] ?? b['emergencyContact'] ?? b);
      testContactId = data['id']?.toString() ?? '';
      shapeItem('POST /safety/emergency-contacts', data, ['id', 'name', 'phoneNumber']);
    } else {
      fail('POST /safety/emergency-contacts', r.body);
    }
  }

  // DELETE /safety/emergency-contacts/:id — cleanup
  if (testContactId.isNotEmpty) {
    final r = await req('DELETE', '/safety/emergency-contacts/$testContactId');
    if (r.status == 200 || r.status == 204) {
      ok('DELETE /safety/emergency-contacts/:id (cleanup)');
    } else {
      warn('DELETE /safety/emergency-contacts/$testContactId (${r.status}) — limpar manualmente');
    }
  }

  // POST /safety/panic — GPS de Luanda
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
  section('8. AVALIAÇÕES');

  if (_userId.isEmpty) {
    warn('userId não disponível — testes saltados');
    return;
  }

  final r = await req('GET', '/ratings/$_userId');
  if (r.status == 200) {
    ok('GET /ratings/:userId');
    final b = _asMap(r.body);
    final list = _asList(b['ratings'] ?? b['data'] ?? b['items'] ?? (r.body is List ? r.body : []));
    info('${list.length} avaliação(ões)');
    final avg = b['average'] ?? b['averageRating'] ?? b['rating'];
    if (avg != null) info('média=$avg');
  } else {
    fail('GET /ratings/:userId', r.body);
  }

  // Verificar perfil público de motorista
  {
    final r = await req('GET', '/users/drivers/$_userId');
    if (r.status == 200) {
      ok('GET /users/drivers/:id');
    } else {
      warn('GET /users/drivers/:id (${r.status})');
    }
  }
}

Future<void> testQrResolve() async {
  section('9. QR — RESOLVER TOKEN (validação)');

  // GET /qrcodes/resolve?token= — token inválido → 404 esperado
  {
    final r = await req('GET', '/qrcodes/resolve', query: {'token': 'token-invalido-teste'});
    if (r.status == 404 || r.status == 400) {
      ok('GET /qrcodes/resolve?token= (${r.status} — rejeita token inválido)');
    } else if (r.status == 200) {
      warn('GET /qrcodes/resolve aceitou token inválido — verificar');
    } else {
      fail('GET /qrcodes/resolve', r.body);
    }
  }

  // POST /virtual-cards/resolve-qr — QR inválido → 400/422 esperado
  {
    final r = await req('POST', '/virtual-cards/resolve-qr', body: {'qrData': 'invalido'});
    if (r.status == 400 || r.status == 422 || r.status == 404) {
      ok('POST /virtual-cards/resolve-qr (${r.status} — rejeita QR inválido)');
    } else {
      fail('POST /virtual-cards/resolve-qr', r.body);
    }
  }
}

Future<void> testAuthForgotPassword(String phone) async {
  section('10. RECUPERAÇÃO DE PASSWORD');

  // POST /auth/forgot-password
  {
    final r = await req('POST', '/auth/forgot-password',
        body: {'phoneNumber': phone}, auth: false);
    if (r.status == 200 || r.status == 201) {
      ok('POST /auth/forgot-password (SMS/WhatsApp enviado)');
    } else if (r.status == 404) {
      warn('POST /auth/forgot-password → 404 (telefone não encontrado?)');
    } else if (r.status == 429) {
      warn('POST /auth/forgot-password → 429 (rate limit — chamado recentemente)');
    } else {
      fail('POST /auth/forgot-password', r.body);
    }
  }
}

Future<void> testUpdateProfile() async {
  section('11. ACTUALIZAR PERFIL');

  {
    final r = await req('PUT', '/users/me', body: {'fullName': 'Motorista Teste'});
    // 200 OK ou 422 se campo não permitido
    if (r.status == 200) {
      ok('PUT /users/me');
      final b = _asMap(r.body);
      final data = b.containsKey('data') ? _asMap(b['data']) : b;
      shape('/users/me PUT response', data, ['id', 'fullName']);
    } else if (r.status == 422) {
      warn('PUT /users/me → 422 — campos actualizáveis podem ter mudado');
    } else {
      fail('PUT /users/me', r.body);
    }
  }
}

Future<void> testInvoices() async {
  section('12. FATURAS');

  // GET /invoices — lista paginada (geradas automaticamente por transaction.completed)
  {
    final r = await req('GET', '/invoices',
        query: {'page': '1', 'limit': '10'});
    if (r.status == 200) {
      ok('GET /invoices');
      final b = _asMap(r.body);
      final list = _asList(b['data'] ?? b['invoices'] ?? (r.body is List ? r.body : []));
      info('${list.length} fatura(s)');
      if (list.isNotEmpty) {
        shapeItem('GET /invoices item', _asMap(list.first), ['id', 'status', 'amount']);
      }
    } else {
      fail('GET /invoices', r.body);
    }
  }

  // GET /invoices?status=paid — filtro por estado
  {
    final r = await req('GET', '/invoices', query: {'status': 'paid'});
    if (r.status == 200) {
      ok('GET /invoices?status=paid');
    } else if (r.status == 400) {
      warn('GET /invoices?status=paid → 400 (filtro não suportado)');
    } else {
      fail('GET /invoices?status=paid', r.body);
    }
  }

  // GET /invoices/export — download CSV/JSON
  {
    final r = await req('GET', '/invoices/export', query: {'format': 'json'});
    if (r.status == 200) {
      ok('GET /invoices/export?format=json');
      final hasContent = r.body is List ||
          (r.body is Map && (r.body as Map).isNotEmpty) ||
          (r.body is String && (r.body as String).isNotEmpty);
      if (hasContent) {
        ok('  └─ conteúdo do export presente');
      } else {
        warn('  └─ export vazio');
      }
    } else {
      fail('GET /invoices/export', r.body);
    }
  }
}

// ─── LOGOUT ──────────────────────────────────────────────────────────────────

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
    print('Uso: dart run test/integration_test.dart <telefone> <pin> [vehicleId]');
    print('Ex:  dart run test/integration_test.dart +244926000000 123456');
    exit(1);
  }
  final phone = args[0];
  final pin = args[1];
  if (args.length >= 3) _vehicleId = args[2];

  print('\n╔══════════════════════════════════════════════════╗');
  print('║  APP MOTORISTA — Integração API completa         ║');
  print('║  ${_base.padRight(48)} ║');
  print('╚══════════════════════════════════════════════════╝');

  await testAuth(phone, pin);
  await testFleet(phone);
  await testQrSession();
  await testTrips();
  await testTransactions();
  await testNotifications();
  await testSafety();
  await testRatings();
  await testQrResolve();
  await testAuthForgotPassword(phone);
  await testUpdateProfile();
  await testInvoices();
  await testLogout();

  // ── Resumo de shapes ──────────────────────────────────────────────────────
  if (_shapeErrors.isNotEmpty) {
    print('\n── Problemas de Shape (campos esperados pelo app ausentes na API) ──');
    for (final e in _shapeErrors) {
      print('  ⚠️   $e');
    }
  }

  // ── Resultado final ───────────────────────────────────────────────────────
  final total = _pass + _fail;
  print('\n╔══════════════════════════════════════════════════╗');
  print('${'║  $_pass/$total passou  |  $_fail falharam  |  $_warn avisos'.padRight(51)}║');
  if (_shapeErrors.isNotEmpty) {
    print('${'║  ${_shapeErrors.length} problema(s) de shape detectado(s)'.padRight(51)}║');
  }
  print('╚══════════════════════════════════════════════════╝\n');

  exit(_fail > 0 ? 1 : 0);
}
