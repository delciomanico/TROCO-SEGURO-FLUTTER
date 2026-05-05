import 'package:dio/dio.dart';

void main() async {
  print('🧪 TESTE DE LOGIN COM DADOS CORRETOS\n');
  
  final dio = Dio(BaseOptions(
    baseUrl: 'https://troco-seguro.onrender.com',
    connectTimeout: Duration(seconds: 30),
    receiveTimeout: Duration(seconds: 30),
    validateStatus: (status) => true,
  ));
  
  // Lista de formatos de telefone para testar
  final phoneFormats = [
    '+244923456789',   // Com +244
    '244923456789',    // Sem +
    '923456789',       // Apenas o número
    '+244 923 456 789', // Com espaços
  ];
  
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('🔐 TESTANDO FORMATOS DE TELEFONE');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
  
  for (final phone in phoneFormats) {
    print('📱 Telefone: "$phone"');
    
    try {
      final response = await dio.post('/api/v1/auth/login', data: {
        'phoneNumber': phone,
        'password': '123456', // PIN válido (6 dígitos)
      });
      
      print('   ✅ Status: ${response.statusCode}');
      print('   📄 Resposta: ${response.data}\n');
    } on DioException catch (e) {
      if (e.response != null) {
        final status = e.response!.statusCode;
        print('   ℹ️ Status: $status');
        
        if (status == 400) {
          print('   ⚠️ Validação: ${e.response!.data}');
        } else if (status == 401) {
          print('   ✅ Formato aceito! (Credenciais inválidas - esperado)');
          print('   📄 Mensagem: ${e.response!.data}');
        } else if (status == 404) {
          print('   ❌ Usuário não encontrado');
        } else {
          print('   📄 Resposta: ${e.response!.data}');
        }
        print('');
      } else {
        print('   ❌ Erro: ${e.message}\n');
      }
    }
  }
  
  print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('🔐 TESTANDO FORMATOS DE SENHA');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
  
  final passwords = [
    '123456',       // 6 dígitos ✅
    '12345',        // 5 dígitos ❌
    '1234567',      // 7 dígitos ❌
    'Abc123',       // Com letras ❌
  ];
  
  for (final pwd in passwords) {
    print('🔑 Senha: "$pwd"');
    
    try {
      final response = await dio.post('/api/v1/auth/login', data: {
        'phoneNumber': '923456789',
        'password': pwd,
      });
      
      print('   ✅ Status: ${response.statusCode}');
      print('   📄 Resposta: ${response.data}\n');
    } on DioException catch (e) {
      if (e.response != null) {
        final status = e.response!.statusCode;
        print('   ℹ️ Status: $status');
        
        if (status == 400) {
          final data = e.response!.data;
          if (data['message'] is List) {
            print('   ⚠️ Validações:');
            for (final msg in data['message']) {
              print('      - $msg');
            }
          } else {
            print('   ⚠️ ${data['message']}');
          }
        } else if (status == 401 || status == 404) {
          print('   ✅ Formato aceito! (Erro esperado: credenciais inválidas)');
        }
        print('');
      }
    }
  }
  
  print('\n💡 RESULTADO:');
  print('   • Use exatamente 6 dígitos numéricos como senha');
  print('   • Formato do telefone: testar qual formato a API aceita');
  print('   • Se todos retornam 400, verificar mensagem de validação específica');
}
