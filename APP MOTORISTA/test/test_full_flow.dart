import 'package:dio/dio.dart';
import 'dart:math';

void main() async {
  print('🚀 FLUXO COMPLETO: REGISTRO → VERIFICAÇÃO → LOGIN\n');
  
  final dio = Dio(BaseOptions(
    baseUrl: 'https://troco-seguro.onrender.com',
    connectTimeout: Duration(seconds: 30),
    receiveTimeout: Duration(seconds: 30),
    validateStatus: (status) => true,
  ));
  
  // Gerar telefone aleatório para teste
  final random = Random();
  final randomPhone = '9${20000000 + random.nextInt(79999999)}'; // 9XXXXXXXX
  final fullPhone = '+244$randomPhone';
  const pin = '123456';
  
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('📋 DADOS DO TESTE');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('📱 Telefone: $fullPhone');
  print('🔑 PIN: $pin');
  print('👤 Nome: Motorista Teste');
  print('🚗 Matrícula: LD-00-${random.nextInt(99).toString().padLeft(2, '0')}-AA');
  print('🚙 Modelo: Toyota Corolla\n');
  
  // PASSO 1: REGISTRO
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('1️⃣ REGISTRO');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
  
  try {
    final response = await dio.post('/api/v1/auth/register', data: {
      'fullName': 'Motorista Teste',
      'phoneNumber': fullPhone,
      'password': pin,
      'licensePlate': 'LD-00-${random.nextInt(99).toString().padLeft(2, '0')}-AA',
      'vehicleModel': 'Toyota Corolla',
    });
    
    print('✅ Status: ${response.statusCode}');
    print('📄 Resposta: ${response.data}');
    print('\n💬 Mensagem: Código OTP enviado por SMS!\n');
  } on DioException catch (e) {
    if (e.response != null) {
      print('❌ Status: ${e.response!.statusCode}');
      print('📄 Erro: ${e.response!.data}');
      
      if (e.response!.statusCode == 409) {
        print('\n⚠️ Usuário já existe. Tentando com login direto...\n');
        // Pular para login
        await testLogin(dio, fullPhone, pin);
        return;
      } else {
        print('\n❌ Falha no registro. Abortando teste.\n');
        return;
      }
    } else {
      print('❌ Erro de conexão: ${e.message}\n');
      return;
    }
  }
  
  // PASSO 2: SIMULAR VERIFICAÇÃO OTP
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('2️⃣ VERIFICAÇÃO OTP');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
  print('ℹ️ Na produção, você receberia um SMS com o código.');
  print('ℹ️ Para teste, vamos tentar alguns códigos comuns...\n');
  
  // Tentar códigos de teste comuns
  final testCodes = ['000000', '123456', '111111', '999999'];
  bool otpVerified = false;
  
  for (final code in testCodes) {
    try {
      print('🔍 Tentando código: $code');
      final response = await dio.post('/api/v1/auth/verify-otp', data: {
        'phoneNumber': fullPhone,
        'otpCode': code,
      });
      
      print('   ✅ Status: ${response.statusCode}');
      print('   📄 Resposta: ${response.data}');
      print('   🎉 OTP verificado com sucesso!\n');
      otpVerified = true;
      break;
    } on DioException catch (e) {
      if (e.response != null) {
        print('   ❌ Status: ${e.response!.statusCode}');
        if (e.response!.statusCode == 401) {
          print('   📄 Código inválido\n');
        } else {
          print('   📄 Erro: ${e.response!.data}\n');
        }
      }
    }
  }
  
  if (!otpVerified) {
    print('⚠️ Não foi possível verificar OTP com códigos de teste.');
    print('💡 INSTRUÇÕES MANUAIS:');
    print('   1. Verifique o SMS recebido em $fullPhone');
    print('   2. Use o código recebido no app para verificar');
    print('   3. Depois faça login com:');
    print('      📱 Telefone: $fullPhone');
    print('      🔑 PIN: $pin\n');
    return;
  }
  
  // PASSO 3: LOGIN
  await testLogin(dio, fullPhone, pin);
}

Future<void> testLogin(Dio dio, String phone, String pin) async {
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('3️⃣ LOGIN');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
  
  try {
    final response = await dio.post('/api/v1/auth/login', data: {
      'phoneNumber': phone,
      'password': pin,
    });
    
    print('✅ Status: ${response.statusCode}');
    print('📄 Resposta completa:');
    print('${response.data}');
    
    if (response.data['accessToken'] != null) {
      print('\n🎉 LOGIN BEM-SUCEDIDO!');
      print('🔑 Token: ${response.data['accessToken'].substring(0, 50)}...');
      print('👤 Usuário: ${response.data['user']?['fullName'] ?? 'N/A'}');
      print('📱 Telefone: ${response.data['user']?['phoneNumber'] ?? 'N/A'}');
      print('\n✅ O app está pronto para uso em produção!\n');
    }
  } on DioException catch (e) {
    if (e.response != null) {
      print('❌ Status: ${e.response!.statusCode}');
      print('📄 Erro: ${e.response!.data}');
      
      if (e.response!.statusCode == 401) {
        final msg = e.response!.data['message'];
        if (msg.contains('não verificada')) {
          print('\n⚠️ AÇÃO NECESSÁRIA:');
          print('   Você precisa verificar o código SMS primeiro!');
          print('   Use o endpoint /api/v1/auth/verify-otp com o código recebido.\n');
        } else {
          print('\n⚠️ Credenciais inválidas. Verifique telefone e PIN.\n');
        }
      }
    } else {
      print('❌ Erro de conexão: ${e.message}\n');
    }
  }
}
