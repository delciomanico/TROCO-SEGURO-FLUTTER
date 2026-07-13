import 'package:intl/intl.dart';

/// Ponto único para formatar valores monetários (Kz).
///
/// O backend só devolve valores inteiros hoje (ver BACKEND_PENDING_CHANGES.md,
/// item 4) — [showDecimals] fica `false` por omissão. Quando o backend
/// confirmar suporte a fracções de Kz, activar globalmente passa a ser uma
/// única mudança aqui, em vez de caçar cada `NumberFormat` espalhado pelo
/// código.
class AppFormatters {
  static const bool decimalsEnabled = false;

  static String currency(num amountInKz) {
    const pattern = decimalsEnabled ? '#,##0.00' : '#,##0';
    return NumberFormat(pattern, 'pt_AO').format(amountInKz);
  }
}
