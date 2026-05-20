import 'dart:io';
import 'package:troco_seguro_motorista/services/api_service.dart';

void main() async {
  print('🧪 Testando API de Saldo...\n');

  final api = ApiService();

  // 1. Carregar tokens
  print('1️⃣ Carregando tokens...');
  await api.loadTokens();
  print('✅ Tokens carregados\n');

  // 2. Testar getBalance
  print('2️⃣ Testando getBalance()...');
  final balanceResult = await api.getBalance();
  print('   Success: ${balanceResult.isSuccess}');
  print('   Data: ${balanceResult.data}');
  print('   Error: ${balanceResult.error}');
  print('');

  // 3. Testar getProfile
  print('3️⃣ Testando getProfile()...');
  final profileResult = await api.getProfile();
  print('   Success: ${profileResult.isSuccess}');
  if (profileResult.data != null) {
    print('   Name: ${profileResult.data!.fullName}');
    print('   Balance: ${profileResult.data!.balance}');
    print('   Wallet: ${profileResult.data!.wallet}');
  }
  print('   Error: ${profileResult.error}');
  print('');

  print('✅ Teste concluído!');
  exit(0);
}
