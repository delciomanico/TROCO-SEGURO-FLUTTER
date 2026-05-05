// Teste simples da API
// Execute com: dart run test/api_test.dart

import 'dart:convert';
import 'package:http/http.dart' as http;

const baseUrl = 'https://troco-seguro.onrender.com';

Future<void> main() async {
  print('🧪 Testando API Troco Seguro...\n');

  // Teste 1: FAQ (público)
  print('1️⃣ Testando GET /faq...');
  try {
    final faqResponse = await http.get(Uri.parse('$baseUrl/faq'));
    if (faqResponse.statusCode == 200) {
      final data = json.decode(faqResponse.body);
      print('   ✅ FAQ carregado: ${(data['items'] as List).length} itens');
    } else {
      print('   ❌ Erro: ${faqResponse.statusCode}');
    }
  } catch (e) {
    print('   ❌ Erro de conexão: $e');
  }

  // Teste 2: Login (inválido - só para testar resposta)
  print('\n2️⃣ Testando POST /auth/login...');
  try {
    final loginResponse = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {
        'Content-Type': 'application/json',
        'user-agent': 'TrocoSeguroApp/1.0',
      },
      body: json.encode({
        'phoneNumber': '+244900000000',
        'password': '123456',
      }),
    );

    if (loginResponse.statusCode == 200) {
      print('   ✅ Login bem sucedido!');
    } else if (loginResponse.statusCode == 401) {
      print('   ⚠️ Credenciais inválidas (esperado para teste)');
    } else {
      print('   ❌ Erro: ${loginResponse.statusCode}');
      print('   ${loginResponse.body}');
    }
  } catch (e) {
    print('   ❌ Erro de conexão: $e');
  }

  // Teste 3: Endpoints protegidos
  print('\n3️⃣ Testando GET /notifications (sem token)...');
  try {
    final notifResponse = await http.get(Uri.parse('$baseUrl/notifications'));
    if (notifResponse.statusCode == 401) {
      print('   ✅ Retornou 401 (correto - requer autenticação)');
    } else {
      print('   ⚠️ Resposta inesperada: ${notifResponse.statusCode}');
    }
  } catch (e) {
    print('   ❌ Erro de conexão: $e');
  }

  // Teste 4: Registro
  print('\n4️⃣ Testando POST /auth/register...');
  try {
    final registerResponse = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'fullName': 'Teste Automatico',
        'phoneNumber':
            '+244900${DateTime.now().millisecondsSinceEpoch % 1000000}',
        'password': '123456',
      }),
    );

    if (registerResponse.statusCode == 201) {
      print('   ✅ Registro criado! Verifique SMS para OTP.');
    } else if (registerResponse.statusCode == 409) {
      print('   ⚠️ Número já existe (esperado)');
    } else {
      print('   ❌ Erro: ${registerResponse.statusCode}');
      print('   ${registerResponse.body}');
    }
  } catch (e) {
    print('   ❌ Erro de conexão: $e');
  }

  print('\n✨ Testes concluídos!');
}
