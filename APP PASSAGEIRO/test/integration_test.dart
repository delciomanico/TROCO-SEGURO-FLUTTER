// dart run test/integration_test.dart +244XXXXXXXXX PIN
// Testa todos os endpoints novos integrados no app passageiro.

import 'dart:convert';
import 'dart:io';

const String base = 'https://troco-seguro.onrender.com/api/v1';

final HttpClient _http = HttpClient()
  ..badCertificateCallback = (_, __, ___) => true;

String _accessToken = '';
String _userId = '';
String _cardId = '';
String _card2Id = '';

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
  if (auth && _accessToken.isNotEmpty) {
    req.headers.set('Authorization', 'Bearer $_accessToken');
  }
  if (body != null) req.write(jsonEncode(body));
  final res = await req.close();
  final raw = await res.transform(utf8.decoder).join();
  return {'status': res.statusCode, 'body': raw.isEmpty ? {} : jsonDecode(raw)};
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
    print('Ex:  dart run test/integration_test.dart +244926283434 123456');
    exit(1);
  }
  final phone = args[0];
  final pin = args[1];

  print('\n══════════════════════════════════════════════');
  print('  TROCO SEGURO — Testes de Integração API');
  print('══════════════════════════════════════════════\n');

  // ── 1. Login ──────────────────────────────────────
  print('── Autenticação ──');
  {
    final r = await _req('POST', '/auth/login',
        body: {'phoneNumber': phone, 'password': pin}, auth: false);
    final ok = r['status'] == 200 || r['status'] == 201;
    _log(ok, 'POST /auth/login', r['body']);
    if (ok) {
      final b = r['body'] as Map;
      _accessToken = b['accessToken'] ?? b['access_token'] ?? '';
      _userId = b['user']?['id'] ?? '';
      if (_accessToken.isEmpty) {
        print('❌  Token não encontrado no response. Abortando.');
        exit(1);
      }
    } else {
      print('❌  Login falhou. Verifique as credenciais.');
      exit(1);
    }
  }

  // ── 2. Perfil ─────────────────────────────────────
  print('\n── Perfil ──');
  {
    final r = await _req('GET', '/auth/profile');
    _log(r['status'] == 200, 'GET /auth/profile', r['body']);
  }

  // ── 3. Carteira — saldo dedicado ──────────────────
  print('\n── Carteira ──');
  {
    final r = await _req('GET', '/wallet/balance');
    final ok = r['status'] == 200;
    _log(ok, 'GET /wallet/balance', r['body']);
    if (!ok) print('   ⚠️  Endpoint de saldo dedicado não disponível — saldo vem do perfil');
  }

  // ── 4. Cartões Virtuais ───────────────────────────
  print('\n── Cartões Virtuais ──');
  {
    // Listar
    final r = await _req('GET', '/virtual-cards');
    final ok = r['status'] == 200;
    _log(ok, 'GET /virtual-cards (listar)', r['body']);
    if (ok) {
      final list = (r['body'] is List ? r['body'] : r['body']['data'] ?? []) as List;
      if (list.length >= 2) {
        _cardId = list[0]['id'];
        _card2Id = list[1]['id'];
      } else if (list.length == 1) {
        _cardId = list[0]['id'];
      }
    }
  }

  if (_cardId.isNotEmpty) {
    // Detalhe
    {
      final r = await _req('GET', '/virtual-cards/$_cardId');
      _log(r['status'] == 200, 'GET /virtual-cards/:id (detalhe)', r['body']);
    }

    // QR via API (endpoint novo — substituiu geração local)
    {
      final r = await _req('GET', '/virtual-cards/$_cardId/qr');
      final ok = r['status'] == 200;
      _log(ok, 'GET /virtual-cards/:id/qr (QR server-side)', r['body']);
      if (ok) {
        final body = r['body'];
        final hasToken = body is String && body.isNotEmpty ||
            (body is Map && (body['qrData'] ?? body['qr'] ?? body['token']) != null);
        _log(hasToken, '  └─ QR contém token válido', body);
      }
    }

    // Transferência entre cartões (só testa se há 2 cartões)
    if (_card2Id.isNotEmpty) {
      final r = await _req('POST', '/wallet/transfer', body: {
        'fromCardId': _cardId,
        'toCardId': _card2Id,
        'amount': 1,
        'pin': pin,
      });
      final ok = r['status'] == 200 || r['status'] == 201;
      _log(ok, 'POST /wallet/transfer (entre cartões)', r['body']);
    } else {
      print('⚠️   POST /wallet/transfer — apenas 1 cartão, transferência saltada');
    }
  } else {
    print('⚠️   Sem cartões virtuais — testes de cartão saltados');
  }

  // ── 5. Reclamações ────────────────────────────────
  print('\n── Reclamações ──');
  String complaintId = '';
  {
    // Criar
    final r = await _req('POST', '/complaints', body: {
      'category': 'OTHER',
      'reasonCode': 'other',
      'description': 'Teste de integracao automatico - pode ignorar',
    });
    final ok = r['status'] == 200 || r['status'] == 201;
    _log(ok, 'POST /complaints (criar)', r['body']);
    if (ok) {
      final b = r['body'];
      final bMap = b as Map? ?? {};
      complaintId = (bMap['id'] ?? (bMap['data'] as Map?)?['id'] ?? '').toString();
    }
  }
  {
    // Listar (endpoint novo)
    final r = await _req('GET', '/complaints');
    final ok = r['status'] == 200;
    _log(ok, 'GET /complaints (histórico)', r['body']);
    if (ok && complaintId.isEmpty) {
      final list = (r['body'] is List ? r['body'] : r['body']['data'] ?? []) as List;
      if (list.isNotEmpty) complaintId = list[0]['id']?.toString() ?? '';
    }
  }
  if (complaintId.isNotEmpty) {
    // Detalhe (endpoint novo)
    final r = await _req('GET', '/complaints/$complaintId');
    _log(r['status'] == 200, 'GET /complaints/:id (detalhe)', r['body']);
  }

  // ── 6. Avaliações ─────────────────────────────────
  print('\n── Avaliações ──');
  if (_userId.isNotEmpty) {
    final r = await _req('GET', '/ratings/$_userId');
    final ok = r['status'] == 200;
    _log(ok, 'GET /ratings/:userId (histórico)', r['body']);
    if (ok) {
      final list = (r['body'] is List ? r['body'] : r['body']['ratings'] ?? r['body']['data'] ?? []) as List;
      _log(true, '  └─ ${list.length} avaliação(ões) encontrada(s)', '');
    }
  } else {
    print('⚠️   userId não disponível — teste de avaliações saltado');
  }

  // ── 7. Notificações ───────────────────────────────
  print('\n── Notificações ──');
  {
    final r = await _req('GET', '/notifications');
    _log(r['status'] == 200, 'GET /notifications', r['body']);
  }

  // ── 8. Viagens ────────────────────────────────────
  print('\n── Viagens ──');
  {
    final r = await _req('GET', '/trips');
    _log(r['status'] == 200, 'GET /trips', r['body']);
  }

  // ── Resultado ─────────────────────────────────────
  print('\n══════════════════════════════════════════════');
  print('  Resultado: $_pass passou  |  $_fail falhou');
  print('══════════════════════════════════════════════\n');
  exit(_fail > 0 ? 1 : 0);
}
