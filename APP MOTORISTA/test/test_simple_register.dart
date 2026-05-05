import 'package:dio/dio.dart';
import 'dart:math';

void main() async {
  print('🧪 TESTE DE REGISTRO SIMPLIFICADO\n');
  
  final dio = Dio(BaseOptions(
    baseUrl: 'https://troco-seguro.onrender.com',
    connectTimeout: Duration(seconds: 30),
    receiveTimeout: Duration(seconds: 30),
    validateStatus: (status) => true,
  ));
  
  final random = Random();
  final randomPhone = '9${20000000 + random.nextInt(79999999)}';
  final fullPhone = '+244$randomPhone';
  const pin = '123456';
  
  print('📱 Telefone: $fullPhone');
  print('🔑 PIN: $pin\n');
  
  // Teste 1: Registro apenas com campos obrigatórios
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('TESTE 1: Registro Simplificado');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
  
  try {
    final response = await dio.post('/api/v1/auth/register', data: {
      'fullName': 'Motorista Teste',
      'phoneNumber': fullPhone,
      'password': pin,
    });
    
    print('✅ Status: ${response.statusCode}');
    print('📄 Resposta: ${response.data}\n');
    
    if (response.statusCode == 201 || response.statusCode == 200) {
      print('🎉 REGISTRO BEM-SUCEDIDO!');
      print('📧 Verifique o SMS em $fullPhone\n');
      
      // Marcar que precisa verificar OTP
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('PRÓXIMOS PASSOS:');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('1. Verificar código SMS no telefone');
      print('2. Chamar /api/v1/auth/verify-otp com:');
      print('   {');
      print('     "phoneNumber": "$fullPhone",');
      print('     "otpCode": "CÓDIGO_DO_SMS"');
      print('   }');
      print('3. Após verificar, fazer login com:');
      print('   {');
      print('     "phoneNumber": "$fullPhone",');
      print('     "password": "$pin"');
      print('   }\n');
    }
  } on DioException catch (e) {
    if (e.response != null) {
      print('❌ Status: ${e.response!.statusCode}');
      final data = e.response!.data;
      print('📄 Erro: $data\n');
      
      if (e.response!.statusCode == 400) {
        print('⚠️ Erro de validação. Campos aceitos pela API:');
        if (data['message'] is List) {
          for (final msg in data['message']) {
            print('   - $msg');
          }
        }
      } else if (e.response!.statusCode == 409) {
        print('⚠️ Usuário já existe. Testando login...\n');
        await testLogin(dio, fullPhone, pin);
      }
    } else {
      print('❌ Erro: ${e.message}\n');
    }
  }
}

Future<void> testLogin(Dio dio, String phone, String pin) async {
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('TESTE: Login com conta existente');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
  
  try {
    final response = await dio.post('/api/v1/auth/login', data: {
      'phoneNumber': phone,
      'password': pin,
    });
    
    print('✅ Status: ${response.statusCode}');
    print('📄 Resposta: ${response.data}');
    print('\n🎉 LOGIN BEM-SUCEDIDO!\n');
  } on DioException catch (e) {
    if (e.response != null) {
      print('❌ Status: ${e.response!.statusCode}');
      final data = e.response!.data;
      print('📄 Mensagem: ${data['message']}\n');
      
      if (data['message'].toString().contains('não verificada')) {
        print('⚠️ Conta não verificada. Você precisa:');
        print('   1. Verificar o código SMS recebido');
        print('   2. Chamar /api/v1/auth/verify-otp\n');
      }
    }
  }
}
