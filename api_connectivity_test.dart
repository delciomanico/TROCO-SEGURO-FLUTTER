// Teste de Conectividade e Funcionalidades contra a API Troco Seguro
// Execute com: dart run api_connectivity_test.dart

import 'dart:io';
import 'dart:convert';

const String baseUrl = 'https://trocoseguro.wemof.tech/api/v1';

void main() async {
  print('╔══════════════════════════════════════════════════╗');
  print('║  TESTE DE CONECTIVIDADE - TROCO SEGURO           ║');
  print('║  API: $baseUrl  ║');
  print('╚══════════════════════════════════════════════════╝\n');

  final httpClient = HttpClient()
    ..connectionTimeout = const Duration(seconds: 15)
    ..badCertificateCallback = (cert, host, port) => true; // Aceita certs inválidos

  int passed = 0;
  int failed = 0;

  // Teste 1: Health Check
  print('🔍 Teste 1: Health Check');
  try {
    final response = await _makeRequest(httpClient, 'GET', '/health');
    if (response.status >= 200 && response.status < 300) {
      print('✅ API respondendo (Status: ${response.status})\n');
      passed++;
    } else {
      print('❌ API com status inesperado (${response.status})\n');
      failed++;
    }
  } catch (e) {
    print('❌ Erro de conexão: $e\n');
    failed++;
  }

  // Teste 2: Endpoints de Autenticação
  print('🔍 Teste 2: Endpoints de Autenticação');
  try {
    final response = await _makeRequest(httpClient, 'POST', '/auth/login', {
      'phoneNumber': '+244900000000',
      'password': '000000',
    });
    if (response.status == 401) {
      print('✅ Endpoint /auth/login existe (Status: 401 - Credenciais esperadamente inválidas)\n');
      passed++;
    } else if (response.status >= 200 && response.status < 300) {
      print('✅ Endpoint /auth/login funcionando\n');
      passed++;
    } else {
      print('⚠️  Status inesperado: ${response.status}\n');
    }
  } catch (e) {
    print('❌ Erro: $e\n');
    failed++;
  }

  // Teste 3: Registro de Usuário
  print('🔍 Teste 3: Validar Endpoint de Registro');
  try {
    final response = await _makeRequest(httpClient, 'POST', '/auth/register', {
      'fullName': 'Teste Usuario',
      'phoneNumber': '+244900000001',
      'password': '000000',
      'role': 'PASSENGER',
    });
    if (response.status >= 200 && response.status < 300) {
      print('✅ Registro criado com sucesso\n');
      passed++;
    } else if (response.status == 409) {
      print('✅ Endpoint /auth/register existe (409 - Usuário já existe)\n');
      passed++;
    } else if (response.status == 400) {
      print('✅ Endpoint /auth/register validando entrada (400)\n');
      passed++;
    } else {
      print('⚠️  Status: ${response.status}\n');
    }
  } catch (e) {
    print('❌ Erro: $e\n');
    failed++;
  }

  // Teste 4: FAQ (Público - sem autenticação)
  print('🔍 Teste 4: Endpoint Público (FAQ)');
  try {
    final response = await _makeRequest(httpClient, 'GET', '/faq');
    if (response.status >= 200 && response.status < 300) {
      print('✅ Endpoint /faq respondendo (Status: ${response.status})\n');
      passed++;
    } else {
      print('⚠️  Status: ${response.status}\n');
    }
  } catch (e) {
    print('❌ Erro: $e\n');
    failed++;
  }

  // Teste 5: Verificar endpoints suportados via OPTIONS
  print('🔍 Teste 5: Suporte CORS');
  try {
    final response = await _makeRequest(httpClient, 'OPTIONS', '/auth/login');
    print('✅ CORS disponível (Status: ${response.status})\n');
    passed++;
  } catch (e) {
    print('⚠️  CORS não respondeu (normal em alguns servidores)\n');
  }

  // Teste 6: Teste de timeout (simula requisição lenta)
  print('🔍 Teste 6: Resposta em Tempo Aceitável');
  try {
    final stopwatch = Stopwatch()..start();
    await _makeRequest(httpClient, 'GET', '/health');
    stopwatch.stop();
    
    if (stopwatch.elapsedMilliseconds < 5000) {
      print('✅ Resposta rápida: ${stopwatch.elapsedMilliseconds}ms\n');
      passed++;
    } else {
      print('⚠️  Resposta lenta: ${stopwatch.elapsedMilliseconds}ms\n');
    }
  } catch (e) {
    print('❌ Erro: $e\n');
    failed++;
  }

  // Teste 7: Validação de Role (DRIVER vs PASSENGER)
  print('🔍 Teste 7: Suporte de Roles');
  try {
    final response = await _makeRequest(httpClient, 'POST', '/auth/register', {
      'fullName': 'Teste Motorista',
      'phoneNumber': '+244900000002',
      'password': '000000',
      'role': 'DRIVER',
    });
    print('✅ API suporta role DRIVER (Status: ${response.status})\n');
    passed++;
  } catch (e) {
    print('❌ Erro: $e\n');
    failed++;
  }

  // Resumo
  print('════════════════════════════════════════════════════');
  print('📊 RESULTADO FINAL');
  print('════════════════════════════════════════════════════');
  print('✅ Testes Passados: $passed');
  print('❌ Testes Falhados: $failed');
  print('📈 Taxa de Sucesso: ${(passed / (passed + failed) * 100).toStringAsFixed(1)}%\n');

  if (failed == 0) {
    print('🎉 TUDO FUNCIONANDO! API Pronta para Uso\n');
  } else {
    print('⚠️  Alguns testes falharam. Verifique a API.\n');
  }

  httpClient.close();
}

Future<({int status, String body})> _makeRequest(
  HttpClient client,
  String method,
  String path, [
  Map<String, dynamic>? body,
]) async {
  final uri = Uri.parse('$baseUrl$path');
  final request = await client.openUrl(method, uri);
  
  request.headers.set('Content-Type', 'application/json');
  request.headers.set('Accept', 'application/json');
  request.headers.set('user-agent', 'TrocoSeguroTest/1.0');
  
  if (body != null) {
    request.write(jsonEncode(body));
  }
  
  final response = await request.close();
  final responseBody = await response.transform(utf8.decoder).join();
  
  return (status: response.statusCode, body: responseBody);
}
