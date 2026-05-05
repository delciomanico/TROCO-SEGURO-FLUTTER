import 'package:dio/dio.dart';

void main() async {
  print('🔍 TESTE COM URL CORRETA\n');
  
  final dio = Dio(BaseOptions(
    connectTimeout: Duration(seconds: 30),
    receiveTimeout: Duration(seconds: 30),
    validateStatus: (status) => true,
  ));
  
  // URLs para testar
  final tests = [
    {
      'desc': '❌ URL INCORRETA (com /api/v1/ no final)',
      'base': 'https://troco-seguro.onrender.com/api/v1/',
      'endpoint': 'auth/login',
    },
    {
      'desc': '✅ URL CORRETA (sem barra final)',
      'base': 'https://troco-seguro.onrender.com',
      'endpoint': '/api/v1/auth/login',
    },
  ];
  
  for (final test in tests) {
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print(test['desc']);
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    
    final fullUrl = '${test['base']}${test['endpoint']}';
    print('🔗 URL completa: $fullUrl');
    
    try {
      final response = await dio.post(fullUrl, data: {
        'phoneNumber': '923456789',
        'password': 'Test123!',
      });
      
      print('✅ Status: ${response.statusCode}');
      print('📄 Resposta: ${response.data}\n');
    } on DioException catch (e) {
      if (e.response != null) {
        final status = e.response!.statusCode;
        print('ℹ️ Status: $status');
        
        if (status == 404) {
          print('❌ ENDPOINT NÃO ENCONTRADO (404)\n');
        } else if (status == 400 || status == 401 || status == 422) {
          print('✅ ENDPOINT EXISTE! (Erro esperado de validação)');
          print('📄 Mensagem: ${e.response!.data}\n');
        } else {
          print('📄 Resposta: ${e.response!.data}\n');
        }
      } else {
        print('❌ Erro: ${e.message}\n');
      }
    }
  }
  
  print('\n💡 CONCLUSÃO:');
  print('   Se a URL correta funcionar, precisamos ajustar environment_config.dart');
}
