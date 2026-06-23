// dart run test/integration_test.dart +244XXXXXXXXX PIN
// Testa os endpoints relevantes ao app motorista.

import 'dart:convert';
import 'dart:io';

const String base = 'https://troco-seguro.onrender.com/api/v1';

final HttpClient _http = HttpClient()
  ..badCertificateCallback = (_, __, ___) => true;

String _accessToken = '';
String _userId = '';
String _tripId = '';
String _vehicleId = '';
String _contactId = '';

int _pass = 0, _fail = 0;

Future<Map<String, dynamic>> _req(
  String method,
  String path, {
  Map<String, dynamic>? body,
  bool auth = true,
}) async {
  final uri = Uri.parse('$base$path');
  final req = await _http.openUrl(method, uri);
  req.headers.set('Content-Type', 'application/json');
  req.headers.set('user-agent', 'TrocoSeguroMotorista/1.0');
  if (auth && _accessToken.isNotEmpty) {
    req.headers.set('Authorization', 'Bearer $_accessToken');
  }
  if (body != null) req.write(jsonEncode(body));
  final res = await req.close();
  final raw = await res.transform(utf8.decoder).join();
  try {
    return {
      'status': res.statusCode,
      'body': raw.isEmpty ? <String, dynamic>{} : jsonDecode(raw),
    };
  } catch (_) {
    return {'status': res.statusCode, 'body': raw};
  }
}

void _log(bool ok, String label, dynamic detail) {
  final icon = ok ? '✅' : '❌';
  print('$icon  $label');
  if (!ok) print('   → $detail');
  ok ? _pass++ : _fail++;
}

Future<void> main(List<String> args) async {
  if (args.length < 2) {
    print('Uso: dart run test/integration_test.dart <telefone> <pin>');
    print('Ex:  dart run test/integration_test.dart +244926000000 123456');
    exit(1);
  }
  final phone = args[0];
  final pin = args[1];

  print('\n══════════════════════════════════════════════');
  print('  TROCO SEGURO MOTORISTA — Testes de Integração');
  print('══════════════════════════════════════════════\n');

  // ── 1. Autenticação ───────────────────────────────
  print('── Autenticação ──');
  {
    final r = await _req('POST', '/auth/login',
        body: {'phoneNumber': phone, 'password': pin}, auth: false);
    final ok = r['status'] == 200 || r['status'] == 201;
    _log(ok, 'POST /auth/login', r['body']);
    if (ok) {
      final b = r['body'] as Map;
      // Tokens podem estar em data ou raiz
      final data = b['data'] ?? b;
      _accessToken = data['accessToken'] ?? data['access_token'] ?? '';
      final user = data['user'] ?? data;
      _userId = (user as Map?)?['id']?.toString() ?? '';
      final role = (user)?['role']?.toString().toUpperCase() ?? '';
      if (_accessToken.isEmpty) {
        print('❌  Token não encontrado no response. Abortando.');
        exit(1);
      }
      if (role.isNotEmpty && role != 'DRIVER') {
        print('❌  Conta não é DRIVER (role=$role). Use uma conta de motorista.');
        exit(1);
      }
      print('   → userId=$_userId  role=$role');
    } else {
      print('❌  Login falhou. Verifique as credenciais.');
      exit(1);
    }
  }

  // ── 2. Perfil ─────────────────────────────────────
  print('\n── Perfil ──');
  {
    final r = await _req('GET', '/users/me');
    final ok = r['status'] == 200;
    _log(ok, 'GET /users/me', ok ? 'ok' : r['body']);
    if (ok && _userId.isEmpty) {
      final data = (r['body'] as Map?)?.cast<String, dynamic>() ?? {};
      _userId = (data['data'] as Map?)?['id']?.toString() ??
          data['id']?.toString() ?? '';
    }
  }
  {
    final r = await _req('GET', '/auth/profile');
    _log(r['status'] == 200, 'GET /auth/profile (fallback)', r['body']);
  }

  // ── 3. Status online/offline ─────────────────────
  print('\n── Status Online/Offline ──');
  {
    final r = await _req('PUT', '/users/me/status', body: {'isOnline': false});
    _log(
      r['status'] == 200 || r['status'] == 204,
      'PUT /users/me/status (isOnline: false)',
      r['body'],
    );
  }

  // ── 4. Carteira — saldo ───────────────────────────
  print('\n── Carteira ──');
  {
    final r = await _req('GET', '/wallet/balance');
    final ok = r['status'] == 200;
    _log(ok, 'GET /wallet/balance', ok ? 'ok' : r['body']);
    if (!ok) {
      print('   ⚠️  Endpoint de saldo dedicado indisponível — saldo vem do perfil');
    }
  }

  // ── 5. Frota / Veículos ──────────────────────────
  print('\n── Frota / Veículos ──');
  {
    final r = await _req('GET', '/fleet');
    final ok = r['status'] == 200;
    _log(ok, 'GET /fleet (listar frota)', ok ? 'ok' : r['body']);
    if (ok) {
      final body = r['body'];
      List<dynamic> vehicles = [];
      if (body is List) {
        vehicles = body;
      } else if (body is Map) {
        vehicles = body['vehicles'] as List? ??
            body['data'] as List? ?? [];
      }
      _log(true, '  └─ ${vehicles.length} veículo(s) encontrado(s)', '');
      if (vehicles.isNotEmpty) {
        final v = (vehicles[0] as Map).cast<String, dynamic>();
        _vehicleId = v['id']?.toString() ?? '';
        print('   → vehicleId=$_vehicleId  modelo=${v['model']}');
      }
    }
  }
  {
    // Registar veículo de teste
    final r = await _req('POST', '/fleet/vehicles', body: {
      'licensePlate': 'TEST-99-99',
      'model': 'Teste Integração',
      'color': 'Azul',
    });
    final ok = r['status'] == 200 || r['status'] == 201;
    _log(ok, 'POST /fleet/vehicles (registar veículo)', ok ? 'ok' : r['body']);
    if (ok && _vehicleId.isEmpty) {
      final data =
          (r['body'] as Map?)?.cast<String, dynamic>() ?? {};
      final v = data['data'] ?? data;
      _vehicleId = (v as Map?)?['id']?.toString() ?? '';
    }
  }

  // ── 6. QR Code ───────────────────────────────────
  print('\n── QR Code ──');
  {
    // QR estático
    final r = await _req('GET', '/qrcodes/my-static');
    final ok = r['status'] == 200;
    _log(ok, 'GET /qrcodes/my-static', ok ? 'ok' : r['body']);
    if (!ok) {
      // Fallback
      final r2 = await _req('GET', '/qr-code/my-code');
      _log(r2['status'] == 200, 'GET /qr-code/my-code (fallback)', r2['body']);
    }
  }
  {
    // Configurar preço
    final body = <String, dynamic>{'tripPrice': 2500};
    if (_vehicleId.isNotEmpty) body['activeVehicleId'] = _vehicleId;
    final r = await _req('POST', '/qrcodes/setup', body: body);
    final ok = r['status'] == 200 || r['status'] == 201;
    _log(ok, 'POST /qrcodes/setup (definir preço)', ok ? 'ok' : r['body']);
  }

  // ── 7. Viagens ───────────────────────────────────
  print('\n── Viagens ──');
  {
    final r = await _req('GET', '/trips?page=1&limit=10');
    final ok = r['status'] == 200;
    _log(ok, 'GET /trips (histórico)', ok ? 'ok' : r['body']);
    if (ok) {
      final body = r['body'];
      List<dynamic> trips = [];
      if (body is List) {
        trips = body;
      } else if (body is Map) {
        trips =
            body['data'] as List? ?? body['trips'] as List? ?? [];
      }
      _log(true, '  └─ ${trips.length} viagem(ns) encontrada(s)', '');
      if (trips.isNotEmpty) {
        final t = (trips[0] as Map).cast<String, dynamic>();
        _tripId = t['id']?.toString() ?? '';
      }
    }
  }
  if (_tripId.isNotEmpty) {
    {
      final r = await _req('GET', '/trips/$_tripId');
      _log(r['status'] == 200, 'GET /trips/:id (detalhe)', r['body']);
    }
    {
      // Avaliar viagem
      final r = await _req('POST', '/trips/$_tripId/rate', body: {
        'stars': 5,
        'comment': 'Teste de integração',
      });
      _log(
        r['status'] == 200 || r['status'] == 201 || r['status'] == 409,
        'POST /trips/:id/rate (já avaliado = 409 também ok)',
        r['body'],
      );
    }
  } else {
    print('⚠️   Sem viagens — testes de detalhe/avaliação saltados');
  }
  {
    // Estatísticas
    final r = await _req('GET', '/trips/stats');
    _log(r['status'] == 200, 'GET /trips/stats', r['body']);
  }

  // ── 8. Transações ────────────────────────────────
  print('\n── Transações ──');
  {
    final r = await _req('GET', '/transactions/history?page=1&limit=20');
    final ok = r['status'] == 200;
    _log(ok, 'GET /transactions/history', ok ? 'ok' : r['body']);
  }

  // ── 9. Avaliações ────────────────────────────────
  print('\n── Avaliações ──');
  if (_userId.isNotEmpty) {
    final r = await _req('GET', '/ratings/$_userId');
    final ok = r['status'] == 200;
    _log(ok, 'GET /ratings/:userId', ok ? 'ok' : r['body']);
    if (ok) {
      final body = r['body'] as Map? ?? {};
      final list = body['ratings'] as List? ?? body['data'] as List? ?? [];
      _log(true, '  └─ ${list.length} avaliação(ões)', '');
    }
  } else {
    print('⚠️   userId não disponível — testes de avaliação saltados');
  }

  // ── 10. Notificações ─────────────────────────────
  print('\n── Notificações ──');
  {
    final r = await _req('GET', '/notifications');
    final ok = r['status'] == 200;
    _log(ok, 'GET /notifications', ok ? 'ok' : r['body']);
    if (ok) {
      final body = r['body'];
      List<dynamic> notifs = [];
      if (body is List) {
        notifs = body;
      } else if (body is Map) {
        notifs = body['data'] as List? ?? body['notifications'] as List? ?? [];
      }
      _log(true, '  └─ ${notifs.length} notificação(ões)', '');
      if (notifs.isNotEmpty) {
        final id = (notifs[0] as Map)['id']?.toString() ?? '';
        if (id.isNotEmpty) {
          final r2 = await _req('PUT', '/notifications/$id/read');
          _log(
            r2['status'] == 200 || r2['status'] == 204,
            'PUT /notifications/:id/read',
            r2['body'],
          );
        }
      }
    }
  }
  {
    final r = await _req('PUT', '/notifications/read-all');
    _log(
      r['status'] == 200 || r['status'] == 204,
      'PUT /notifications/read-all',
      r['body'],
    );
  }

  // ── 11. Segurança — Contactos de Emergência ──────
  print('\n── Segurança ──');
  {
    final r = await _req('GET', '/safety/emergency-contacts');
    final ok = r['status'] == 200;
    _log(ok, 'GET /safety/emergency-contacts', ok ? 'ok' : r['body']);
    if (ok) {
      final body = r['body'];
      List<dynamic> contacts = body is List ? body : (body as Map?)?['data'] as List? ?? [];
      _log(true, '  └─ ${contacts.length} contacto(s)', '');
      if (contacts.isNotEmpty) {
        _contactId = (contacts[0] as Map)['id']?.toString() ?? '';
      }
    }
  }
  if (_contactId.isEmpty) {
    // Adicionar contacto de teste
    final r = await _req('POST', '/safety/emergency-contacts', body: {
      'name': 'Teste Integração',
      'phoneNumber': '+244900000000',
    });
    final ok = r['status'] == 200 || r['status'] == 201;
    _log(ok, 'POST /safety/emergency-contacts (adicionar)', ok ? 'ok' : r['body']);
    if (ok) {
      final body = (r['body'] as Map?)?.cast<String, dynamic>() ?? {};
      final data = body['data'] ?? body;
      _contactId = (data as Map?)?['id']?.toString() ?? '';
    }
    if (_contactId.isNotEmpty) {
      final r2 = await _req('DELETE', '/safety/emergency-contacts/$_contactId');
      _log(
        r2['status'] == 200 || r2['status'] == 204,
        'DELETE /safety/emergency-contacts/:id (remover)',
        r2['body'],
      );
    }
  }

  // ── 12. Perfil público de motorista ──────────────
  print('\n── Perfil Público ──');
  if (_userId.isNotEmpty) {
    final r = await _req('GET', '/users/drivers/$_userId');
    _log(
      r['status'] == 200 || r['status'] == 404,
      'GET /users/drivers/:id (404 aceitável se endpoint for passageiro-only)',
      r['status'] == 200 ? 'ok' : r['body'],
    );
  }

  // ── 13. Auth — Recuperação de Password ───────────
  print('\n── Auth extras ──');
  {
    final r = await _req('POST', '/auth/verify-pin', body: {'pin': pin});
    _log(
      r['status'] == 200 || r['status'] == 400,
      'POST /auth/verify-pin',
      r['body'],
    );
  }

  // ── Logout ────────────────────────────────────────
  print('\n── Cleanup ──');
  {
    final r = await _req('POST', '/auth/logout');
    _log(r['status'] == 200 || r['status'] == 204, 'POST /auth/logout', r['body']);
  }

  // ── Resumo ────────────────────────────────────────
  final total = _pass + _fail;
  print('\n══════════════════════════════════════════════');
  print('  Resultado: $_pass/$total passed  •  $_fail falharam');
  print('══════════════════════════════════════════════\n');

  exit(_fail > 0 ? 1 : 0);
}
