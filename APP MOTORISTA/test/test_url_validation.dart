import 'package:dio/dio.dart';

/// 🔍 TESTE DE VALIDAÇÃO DE URLs
/// Valida que as URLs estão sendo montadas corretamente após a correção

void main() async {
  print('═══════════════════════════════════════════════════════');
  print('🔍 TESTE DE VALIDAÇÃO DE URLs - PÓS CORREÇÃO');
  print('═══════════════════════════════════════════════════════\n');
  
  // Configuração igual ao ApiService
  const baseUrl = 'https://troco-seguro.onrender.com/api/v1/';
  
  final dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: Duration(seconds: 30),
    receiveTimeout: Duration(seconds: 30),
    validateStatus: (status) => true,
  ));
  
  print('📋 CONFIGURAÇÃO');
  print('   Base URL: $baseUrl');
  print('   Ambiente: Development\n');
  
  // Adicionar interceptor para capturar URLs
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) {
      print('🔗 ${options.method} ${options.uri}');
      return handler.next(options);
    },
  ));
  
  print('═══════════════════════════════════════════════════════');
  print('TESTANDO ENDPOINTS');
  print('═══════════════════════════════════════════════════════\n');
  
  final endpoints = [
    {'method': 'POST', 'path': 'auth/register', 'expected': 'https://troco-seguro.onrender.com/api/v1/auth/register'},
    {'method': 'POST', 'path': 'auth/login', 'expected': 'https://troco-seguro.onrender.com/api/v1/auth/login'},
    {'method': 'POST', 'path': 'auth/verify-otp', 'expected': 'https://troco-seguro.onrender.com/api/v1/auth/verify-otp'},
    {'method': 'GET', 'path': 'users/profile', 'expected': 'https://troco-seguro.onrender.com/api/v1/users/profile'},
  ];
  
  int passed = 0;
  int failed = 0;
  
  for (final endpoint in endpoints) {
    final method = endpoint['method'] as String;
    final path = endpoint['path'] as String;
    final expected = endpoint['expected'] as String;
    
    try {
      // Interceptar a request para pegar a URL final
      dio.interceptors.clear();
      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          // Não enviar a request, apenas capturar
          handler.reject(DioException(
            requestOptions: options,
            type: DioExceptionType.cancel,
            message: 'Cancelled for testing',
          ));
        },
      ));
      
      // Tentar fazer a requisição (será cancelada)
      if (method == 'POST') {
        await dio.post(path, data: {'test': 'test'});
      } else {
        await dio.get(path);
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        final actualUrl = e.requestOptions.uri.toString();
        
        if (actualUrl == expected) {
          print('✅ $method $path');
          print('   URL: $actualUrl\n');
          passed++;
        } else {
          print('❌ $method $path');
          print('   Esperada: $expected');
          print('   Obtida:   $actualUrl\n');
          failed++;
        }
      }
    }
  }
  
  // Teste real com a API
  print('\n═══════════════════════════════════════════════════════');
  print('TESTE REAL: Login Endpoint');
  print('═══════════════════════════════════════════════════════\n');
  
  final realDio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: Duration(seconds: 30),
    receiveTimeout: Duration(seconds: 30),
    validateStatus: (status) => true,
  ));
  
  try {
    final response = await realDio.post('auth/login', data: {
      'phoneNumber': '923456789',
      'password': '123456',
    });
    
    print('🔗 URL Final: ${realDio.options.baseUrl}auth/login');
    print('📊 Status: ${response.statusCode}');
    
    if (response.statusCode == 404) {
      print('❌ AINDA RETORNA 404');
      print('   Verifique se a API está correta\n');
    } else if (response.statusCode == 400 || response.statusCode == 401) {
      print('✅ ENDPOINT ENCONTRADO!');
      print('   (Erro de validação/autenticação é esperado)');
      print('   Mensagem: ${response.data}\n');
    } else {
      print('✅ Status: ${response.statusCode}');
      print('   Resposta: ${response.data}\n');
    }
  } on DioException catch (e) {
    if (e.response != null) {
      print('📊 Status: ${e.response!.statusCode}');
      
      if (e.response!.statusCode == 404) {
        print('❌ ERRO 404 PERSISTE');
        print('   URL tentada: ${e.requestOptions.uri}');
        print('   A API pode não estar correta ou o endpoint não existe\n');
      } else {
        print('✅ ENDPOINT EXISTE!');
        print('   Mensagem: ${e.response!.data}\n');
      }
    }
  }
  
  // Relatório final
  print('═══════════════════════════════════════════════════════');
  print('📊 RELATÓRIO FINAL');
  print('═══════════════════════════════════════════════════════\n');
  
  print('✅ Testes passaram: $passed/${endpoints.length}');
  print('❌ Testes falharam: $failed/${endpoints.length}\n');
  
  if (failed == 0) {
    print('🎉 TODAS AS URLs ESTÃO CORRETAS!\n');
    print('📱 Agora você pode testar no app com:');
    print('   flutter run\n');
  } else {
    print('⚠️ Algumas URLs ainda estão incorretas.\n');
  }
}
