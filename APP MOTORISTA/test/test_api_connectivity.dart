import 'package:dio/dio.dart';

void main() async {
  print('🔍 TESTE DE CONECTIVIDADE API - Troco Seguro Motorista\n');
  
  // Lista de URLs para testar
  final urls = [
    'https://troco-seguro-dev.onrender.com',
    'https://troco-seguro-staging.onrender.com',
    'https://troco-seguro.onrender.com',
  ];
  
  final dio = Dio(BaseOptions(
    connectTimeout: Duration(seconds: 30),
    receiveTimeout: Duration(seconds: 30),
    validateStatus: (status) => true, // Aceitar qualquer status para diagnóstico
  ));
  
  for (final baseUrl in urls) {
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('📡 Testando: $baseUrl');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    
    // Teste 1: Raiz da API
    await testEndpoint(dio, '$baseUrl/api/v1', 'Raiz API (/api/v1)');
    
    // Teste 2: Health check
    await testEndpoint(dio, '$baseUrl/api/v1/health', 'Health Check');
    
    // Teste 3: Status
    await testEndpoint(dio, '$baseUrl/api/v1/status', 'Status');
    
    // Teste 4: Endpoint de auth
    await testEndpoint(dio, '$baseUrl/api/v1/auth', 'Auth Base');
    
    // Teste 5: Login endpoint (GET para ver se existe)
    await testEndpoint(dio, '$baseUrl/api/v1/auth/login', 'Login Endpoint (GET)');
    
    // Teste 6: Tentar POST no login com dados vazios
    await testLoginPost(dio, '$baseUrl/api/v1/auth/login');
    
    print('\n');
  }
  
  print('✅ Diagnóstico completo!\n');
  print('💡 PRÓXIMOS PASSOS:');
  print('   1. Verifique qual URL respondeu corretamente');
  print('   2. Confirme se o endpoint /auth/login existe');
  print('   3. Verifique se a API está pública ou requer VPN');
  print('   4. Confirme se há autenticação prévia necessária');
}

Future<void> testEndpoint(Dio dio, String url, String description) async {
  try {
    print('🔗 $description');
    print('   URL: $url');
    
    final response = await dio.get(url);
    
    print('   ✅ Status: ${response.statusCode}');
    print('   📦 Headers: ${response.headers.map.keys.join(', ')}');
    
    if (response.data != null) {
      final dataStr = response.data.toString();
      if (dataStr.length > 200) {
        print('   📄 Resposta: ${dataStr.substring(0, 200)}...');
      } else {
        print('   📄 Resposta: $dataStr');
      }
    }
  } on DioException catch (e) {
    if (e.response != null) {
      print('   ❌ Status: ${e.response!.statusCode}');
      print('   📄 Erro: ${e.response!.data}');
    } else {
      print('   ❌ Erro de conexão: ${e.message}');
      print('   🔍 Tipo: ${e.type}');
    }
  } catch (e) {
    print('   ❌ Erro inesperado: $e');
  }
  print('');
}

Future<void> testLoginPost(Dio dio, String url) async {
  try {
    print('🔗 Login Endpoint (POST com dados vazios)');
    print('   URL: $url');
    
    final response = await dio.post(url, data: {
      'phoneNumber': '',
      'password': '',
    });
    
    print('   ✅ Status: ${response.statusCode}');
    print('   📄 Resposta: ${response.data}');
  } on DioException catch (e) {
    if (e.response != null) {
      print('   ℹ️ Status: ${e.response!.statusCode}');
      
      if (e.response!.statusCode == 404) {
        print('   ⚠️ ENDPOINT NÃO EXISTE (404)');
        print('   💡 Possíveis causas:');
        print('      - Caminho incorreto da API');
        print('      - Versão da API diferente');
        print('      - Backend não deployado');
      } else if (e.response!.statusCode == 400 || e.response!.statusCode == 422) {
        print('   ✅ ENDPOINT EXISTE! (Erro de validação esperado)');
        print('   📄 Mensagem: ${e.response!.data}');
      } else {
        print('   📄 Resposta: ${e.response!.data}');
      }
    } else {
      print('   ❌ Erro de conexão: ${e.message}');
    }
  }
  print('');
}
