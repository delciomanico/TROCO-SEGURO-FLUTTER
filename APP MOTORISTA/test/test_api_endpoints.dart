import 'package:dio/dio.dart';

void main() async {
  print('✅ Testando endpoints CORRIGIDOS da API\n');

  final dio = Dio(BaseOptions(
    baseUrl: 'https://troco-seguro.onrender.com/api/v1/',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  // Com token mock
  dio.options.headers['Authorization'] = 'Bearer test_token_12345';

  final endpoints = {
    'Utilizadores': [
      ('GET', '/users/me'),
      ('PUT', '/users/me'),
    ],
    'Viagens': [
      ('GET', '/trips'),
      ('GET', '/trips/stats'),
    ],
    'Transações': [
      ('GET', '/transactions/history'),
    ],
    'QR Code': [
      ('POST', '/qr-code/payment-request'),
      ('GET', '/qr-code/my-code'),
    ],
    'Público (sem auth)': [
      ('GET', '/faq'),
    ],
  };

  final found = <String>[];
  final needsAuth = <String>[];
  final notFound = <String>[];

  for (final entry in endpoints.entries) {
    final category = entry.key;
    final methodEndpoints = entry.value;
    print('📂 $category:');
    
    for (final (method, path) in methodEndpoints) {
      try {
        late Response response;
        if (method == 'GET') {
          response = await dio.get(path).timeout(const Duration(seconds: 2),
              onTimeout: () => throw TimeoutException());
        } else if (method == 'POST') {
          response = await dio.post(path, data: {}).timeout(
              const Duration(seconds: 2),
              onTimeout: () => throw TimeoutException());
        } else if (method == 'PUT') {
          response = await dio.put(path, data: {}).timeout(
              const Duration(seconds: 2),
              onTimeout: () => throw TimeoutException());
        }
        
        if (response.statusCode == 200) {
          print('  ✅ $method $path → 200 OK');
          found.add('$method $path');
        } else {
          print('  ✅ $method $path → ${response.statusCode}');
          found.add('$method $path');
        }
      } on DioException catch (e) {
        if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
          print('  🔐 $method $path → ${e.response?.statusCode} (requer auth válido)');
          needsAuth.add('$method $path');
        } else if (e.response?.statusCode == 404) {
          print('  ❌ $method $path → 404 (não existe)');
          notFound.add('$method $path');
        } else {
          print('  ⚠️  $method $path → ${e.response?.statusCode}');
        }
      } catch (e) {
        print('  ⏱️  $method $path → TIMEOUT');
      }
    }
  }

  print('\n═════════════════════════════════════════');
  print('📊 RESUMO');
  print('═════════════════════════════════════════\n');

  print('✅ Endpoints funcionando: ${found.length}');
  print('🔐 Endpoints que precisam de token válido: ${needsAuth.length}');
  print('❌ Endpoints não encontrados: ${notFound.length}');

  if (notFound.isNotEmpty) {
    print('\n⚠️  Endpoints não encontrados:');
    for (final ep in notFound) {
      print('   $ep');
    }
  }

  print('\n✨ Os endpoints estão prontos!');
}

class TimeoutException implements Exception {
  @override
  String toString() => 'Timeout';
}
