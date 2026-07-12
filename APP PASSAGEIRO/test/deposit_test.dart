// dart run test/deposit_test.dart <telefone> <pin> [valor]
//
// Testa o fluxo de depósito (carregar carteira) do APP PASSAGEIRO contra a
// API real de produção.
//
// IMPORTANTE: ApiService.deposit() (POST /transactions/deposit) está
// obsoleto — o backend actual devolve 404 nesse endpoint. Este script usa o
// fluxo real: POST /payments/deposit/initiate (gera referência Multicaixa,
// status PENDING) seguido de POST /payments/webhook/simulate para confirmar
// o pagamento — este último está restrito a administradores, pelo que numa
// conta normal o teste espera 403 e valida que o saldo permanece inalterado.
//
// Passos:
//   1. Login (POST /auth/login) — telefone com prefixo internacional (+244…)
//   2. Saldo antes do depósito (GET /wallet/balance)
//   3. Iniciar depósito (POST /payments/deposit/initiate)
//   4. Tentar confirmar via webhook (POST /payments/webhook/simulate)
//   5. Saldo depois — só deve mudar se a confirmação foi bem sucedida
//   6. Verifica histórico de transações (GET /transactions/history)
//
// Exemplo:
//   dart run test/deposit_test.dart +244954542042 135791 5000

import 'dart:convert';
import 'dart:io';

const String _base = 'https://trocoseguro.wemof.tech/api/v1';

final HttpClient _http = HttpClient()
  ..connectionTimeout = const Duration(seconds: 15);

String _token = '';

int _pass = 0, _fail = 0, _warn = 0;

// ─── HTTP helper ────────────────────────────────────────────────────────────

Future<({int status, dynamic body})> req(
  String method,
  String path, {
  Map<String, dynamic>? body,
  bool auth = true,
}) async {
  final uri = Uri.parse('$_base$path');
  final rq = await _http.openUrl(method, uri);
  rq.headers.set('Content-Type', 'application/json');
  rq.headers.set('Accept', 'application/json');
  rq.headers.set('user-agent', 'TrocoSeguroPassageiroDepositTest/1.0');
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

// ─── Logging ────────────────────────────────────────────────────────────────

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

Map<String, dynamic> _asMap(dynamic v) =>
    v is Map<String, dynamic> ? v : (v is Map ? v.cast<String, dynamic>() : <String, dynamic>{});

List<dynamic> _asList(dynamic v) => v is List ? v : [];

num? _readBalance(Map<String, dynamic> data) {
  final wallet = _asMap(data['wallet']);
  if (wallet.isNotEmpty && wallet['balance'] != null) {
    return num.tryParse(wallet['balance'].toString());
  }
  if (data['balance'] != null) return num.tryParse(data['balance'].toString());
  if (data['amount'] != null) return num.tryParse(data['amount'].toString());
  if (data['available'] != null) return num.tryParse(data['available'].toString());
  return null;
}

// ─── Passos do teste ────────────────────────────────────────────────────────

Future<void> testLogin(String phone, String pin) async {
  section('1. LOGIN');
  final r = await req('POST', '/auth/login',
      body: {'phoneNumber': phone, 'password': pin}, auth: false);
  if (r.status != 200 && r.status != 201) {
    fail('POST /auth/login', 'status=${r.status}  body=${r.body}');
    exit(1);
  }
  final b = _asMap(r.body);
  _token = b['accessToken']?.toString() ??
      _asMap(b['data'])['accessToken']?.toString() ?? '';
  if (_token.isEmpty) {
    fail('accessToken ausente na resposta de login', b.keys.toList());
    exit(1);
  }
  ok('POST /auth/login', 'token obtido');
}

Future<num> _getBalance(String label) async {
  final r = await req('GET', '/wallet/balance');
  if (r.status != 200) {
    fail('GET /wallet/balance ($label)', 'status=${r.status}  body=${r.body}');
    exit(1);
  }
  final b = _asMap(r.body);
  final data = b.containsKey('data') ? _asMap(b['data']) : b;
  final bal = _readBalance(data);
  if (bal == null) {
    fail('GET /wallet/balance ($label) — campo balance ausente', 'Chaves: ${data.keys.toList()}');
    exit(1);
  }
  ok('GET /wallet/balance ($label)', 'balance=$bal AOA');
  return bal;
}

Future<void> testDeposit(int amount) async {
  section('2. SALDO ANTES DO DEPÓSITO');
  final before = await _getBalance('antes');

  // NOTA: /transactions/deposit (usado por ApiService.deposit()) devolve 404 —
  // endpoint removido do backend. O fluxo actual de depósito é iniciar uma
  // referência Multicaixa via /payments/deposit/initiate; o crédito só é
  // aplicado quando o gateway de pagamento real confirma via webhook
  // (endpoint /payments/webhook/simulate é restrito a administradores).
  section('3. DEPÓSITO — POST /payments/deposit/initiate');
  final r = await req('POST', '/payments/deposit/initiate', body: {'amount': amount});
  if (r.status != 200 && r.status != 201) {
    fail('POST /payments/deposit/initiate', 'status=${r.status}  body=${r.body}');
    exit(1);
  }
  final b = _asMap(r.body);
  final data = b.containsKey('data') ? _asMap(b['data']) : b;
  final reference = data['reference']?.toString() ?? '';
  final txId = data['transactionId']?.toString() ?? data['id']?.toString() ?? '';
  final status = data['status']?.toString() ?? '';
  ok('POST /payments/deposit/initiate', 'id=$txId  reference=$reference  status=$status  amount=$amount AOA');
  if (reference.isEmpty) {
    warn('Resposta sem "reference"', 'Chaves recebidas: ${data.keys.toList()}');
  }
  if (status.toUpperCase() != 'PENDING') {
    warn('Status inesperado (esperava PENDING)', 'status=$status');
  }

  section('4. CONFIRMAÇÃO DO PAGAMENTO — POST /payments/webhook/simulate');
  final rw = await req('POST', '/payments/webhook/simulate', body: {'reference': reference});
  bool confirmed = false;
  if (rw.status == 200 || rw.status == 201) {
    confirmed = true;
    ok('POST /payments/webhook/simulate', 'depósito confirmado (conta tem privilégio de admin)');
  } else if (rw.status == 403) {
    warn('POST /payments/webhook/simulate → 403',
        'esperado — conta normal não pode simular o webhook; em produção só o gateway Multicaixa confirma');
  } else {
    fail('POST /payments/webhook/simulate', 'status=${rw.status}  body=${rw.body}');
  }

  section('5. SALDO DEPOIS DO DEPÓSITO');
  final after = await _getBalance('depois');

  if (confirmed) {
    final expected = before + amount;
    if (after == expected) {
      ok('Saldo actualizado correctamente', '$before + $amount = $after AOA');
    } else if (after > before) {
      warn('Saldo aumentou mas não corresponde exactamente ao esperado',
          'esperado=$expected  obtido=$after (pode haver arredondamento/taxas)');
    } else {
      fail('Saldo NÃO aumentou após confirmação do depósito', 'antes=$before  depois=$after');
    }
  } else {
    if (after == before) {
      ok('Saldo mantém-se (esperado enquanto PENDING)', '$after AOA');
    } else {
      warn('Saldo mudou apesar de o depósito não ter sido confirmado', 'antes=$before  depois=$after');
    }
  }

  section('6. HISTÓRICO DE TRANSAÇÕES');
  final rh = await req('GET', '/transactions/history');
  if (rh.status == 200) {
    final hb = _asMap(rh.body);
    final list = _asList(
        hb['transactions'] ?? hb['history'] ?? hb['data'] ?? (rh.body is List ? rh.body : []));
    final found = list.any((t) {
      final m = _asMap(t);
      return m['id']?.toString() == txId ||
          m['type']?.toString().toUpperCase() == 'DEPOSIT';
    });
    if (found) {
      ok('GET /transactions/history', 'depósito encontrado no histórico (${list.length} transações)');
    } else {
      warn('GET /transactions/history', 'depósito não encontrado explicitamente entre ${list.length} transações (pode não aparecer enquanto PENDING)');
    }
  } else {
    fail('GET /transactions/history', 'status=${rh.status}  body=${rh.body}');
  }
}

// ─── MAIN ───────────────────────────────────────────────────────────────────

Future<void> main(List<String> args) async {
  if (args.length < 2) {
    print('Uso: dart run test/deposit_test.dart <telefone> <pin> [valor]');
    print('Ex:  dart run test/deposit_test.dart 954542042 Senha135791 5000');
    exit(1);
  }
  final phone = args[0];
  final pin = args[1];
  final amount = args.length >= 3 ? int.tryParse(args[2]) ?? 5000 : 5000;

  print('\n╔══════════════════════════════════════════════════╗');
  print('║  APP PASSAGEIRO — Teste de Depósito               ║');
  print('║  ${_base.padRight(48)} ║');
  print('╚══════════════════════════════════════════════════╝');

  await testLogin(phone, pin);
  await testDeposit(amount);

  final total = _pass + _fail;
  print('\n╔══════════════════════════════════════════════════╗');
  print(('║  $_pass/$total passou  |  $_fail falharam  |  $_warn avisos').padRight(53) + '║');
  print('╚══════════════════════════════════════════════════╝\n');

  _http.close();
  exit(_fail > 0 ? 1 : 0);
}
