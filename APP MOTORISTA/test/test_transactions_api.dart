import 'package:troco_seguro_motorista/services/api_service.dart';

void main() async {
  print('🧪 Testando API de Transações...\n');

  final api = ApiService();

  // 1. Carregar tokens
  print('1️⃣ Carregando tokens...');
  await api.loadTokens();
  print('✅ Tokens carregados\n');

  // 2. Testar getEarnings
  print('2️⃣ Testando getEarnings()...');
  final earningsResult = await api.getEarnings();
  print('   Success: ${earningsResult.isSuccess}');
  if (earningsResult.data != null) {
    print('   Today: ${earningsResult.data!.todayAmount} Kz');
    print('   Trips: ${earningsResult.data!.todayTrips}');
  } else {
    print('   Error: ${earningsResult.error}');
  }
  print('');

  // 3. Testar getTransactionHistory
  print('3️⃣ Testando getTransactionHistory()...');
  final transResult = await api.getTransactionHistory(limit: 10);
  print('   Success: ${transResult.isSuccess}');
  if (transResult.data != null) {
    print('   Total: ${transResult.data!.length} transações');
    for (int i = 0; i < transResult.data!.length && i < 3; i++) {
      final tx = transResult.data![i];
      print('   [$i] ${tx.type}: ${tx.amount} (${tx.date})');
    }
  } else {
    print('   Error: ${transResult.error}');
  }
  print('');

  print('✅ Teste concluído!');
}
