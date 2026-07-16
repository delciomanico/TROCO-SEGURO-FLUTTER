import 'package:intl/intl.dart';

/// Ponto único para formatar valores monetários (Kz).
///
/// O backend devolve valores monetários como string decimal (ex.
/// "500.00") desde 2026-07-15, mas os valores em si continuam sempre
/// inteiros — o parsing para string acontece na camada de modelos/
/// `ApiService` (que já converte para `int`/`num` antes de chegar aqui).
/// `decimalsEnabled` fica `false` por omissão porque não há fracções de Kz
/// em uso; se o backend começar a devolver cêntimos reais, activar
/// globalmente passa a ser uma única mudança aqui.
class AppFormatters {
  static const bool decimalsEnabled = false;

  static String currency(num amountInKz) {
    const pattern = decimalsEnabled ? '#,##0.00' : '#,##0';
    return NumberFormat(pattern, 'pt_AO').format(amountInKz);
  }
}
