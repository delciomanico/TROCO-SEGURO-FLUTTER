import 'package:dio/dio.dart';
import 'dart:convert';

void main() async {
  print('🔍 Inspecionando ESTRUTURA REAL de dados do backend\n');

  final dio = Dio(BaseOptions(
    baseUrl: 'https://troco-seguro.onrender.com/api/v1/',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  // Primeiro, fazer login com dados de teste
  print('1️⃣  Testando login...\n');

  try {
    final loginResponse = await dio.post('/auth/login', data: {
      'phoneNumber': '+244926283434', // Testar com número válido
      'password': '123456',
    }).timeout(const Duration(seconds: 10));

    print('✅ Login bem-sucedido!');
    print('Status: ${loginResponse.statusCode}\n');

    final accessToken = loginResponse.data['data']?['accessToken'] ??
        loginResponse.data['accessToken'] ??
        '';
    final refreshToken = loginResponse.data['data']?['refreshToken'] ??
        loginResponse.data['refreshToken'] ??
        '';

    print('📋 Login Response Structure:');
    print(jsonEncode(loginResponse.data));
    print('\n');

    if (accessToken.isNotEmpty) {
      dio.options.headers['Authorization'] = 'Bearer $accessToken';

      // Agora testar os endpoints com token válido
      print('2️⃣  Testando endpoints autenticados...\n');

      // GET /users/me
      try {
        final meResponse = await dio.get('/users/me').timeout(const Duration(seconds: 5));
        print('📋 GET /users/me Response:');
        print(jsonEncode(meResponse.data));
        print('\n');
      } catch (e) {
        print('❌ GET /users/me falhou: $e\n');
      }

      // GET /trips
      try {
        final tripsResponse = await dio.get('/trips?limit=5').timeout(const Duration(seconds: 5));
        print('📋 GET /trips Response:');
        print(jsonEncode(tripsResponse.data));
        print('\n');
      } catch (e) {
        print('❌ GET /trips falhou: $e\n');
      }

      // GET /trips/stats
      try {
        final statsResponse = await dio.get('/trips/stats').timeout(const Duration(seconds: 5));
        print('📋 GET /trips/stats Response:');
        print(jsonEncode(statsResponse.data));
        print('\n');
      } catch (e) {
        print('❌ GET /trips/stats falhou: $e\n');
      }

      // GET /transactions/history
      try {
        final txResponse =
            await dio.get('/transactions/history?limit=5').timeout(const Duration(seconds: 5));
        print('📋 GET /transactions/history Response:');
        print(jsonEncode(txResponse.data));
        print('\n');
      } catch (e) {
        print('❌ GET /transactions/history falhou: $e\n');
      }
    } else {
      print('❌ Não foi possível extrair o token de acesso\n');
      print('Estrutura da resposta: ${loginResponse.data}\n');
    }
  } on DioException catch (e) {
    print('❌ Erro ao fazer login:');
    print('Status: ${e.response?.statusCode}');
    print('Response: ${jsonEncode(e.response?.data)}\n');

    // Tentar com dados de teste diferentes
    print('Tentando com credenciais alternativas...\n');

    try {
      final altResponse = await dio.post('/auth/login', data: {
        'phoneNumber': '900123456', // Sem +244
        'password': 'Pass@1234',
      }).timeout(const Duration(seconds: 10));

      print('✅ Login alternativo bem-sucedido!');
      print(jsonEncode(altResponse.data));
    } catch (e2) {
      print('❌ Login alternativo também falhou: $e2');
    }
  }
}
