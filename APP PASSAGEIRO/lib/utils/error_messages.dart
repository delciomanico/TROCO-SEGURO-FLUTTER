/// Mapeamento de mensagens de erro de pagamento para texto mais amigável.
///
/// Desde 2026-07-15 o backend devolve um campo `errorCode` estável nas
/// respostas de erro de pagamento/transferência/cartão/sessão (ver
/// `ApiResponse.errorCode`); `_byCode` cobre esses valores exactos e tem
/// prioridade sobre `_byKeyword`. Erros sem `errorCode` (outros endpoints
/// ou validações genéricas) continuam a usar a correspondência por
/// palavra-chave como aproximação.
class PaymentErrorMessages {
  static const Map<String, String> _byCode = {
    'INSUFFICIENT_FUNDS': 'Saldo insuficiente para este pagamento.',
    'INVALID_PIN': 'PIN incorrecto. Confirme o PIN e tente novamente.',
    'QR_EXPIRED': 'O código QR expirou. Peça ao motorista para gerar um novo.',
    'DRIVER_OFFLINE': 'O motorista não está online.',
    'CARD_INACTIVE': 'Este cartão está inactivo ou bloqueado.',
    'SEAT_UNAVAILABLE': 'Este assento já foi pago ou não está disponível.',
  };

  static const Map<String, String> _byKeyword = {
    'insufficient': 'Saldo insuficiente para este pagamento.',
    'saldo insuficiente': 'Saldo insuficiente para este pagamento.',
    'invalid pin': 'PIN incorrecto. Confirme o PIN e tente novamente.',
    'pin incorreto': 'PIN incorrecto. Confirme o PIN e tente novamente.',
    'pin inválido': 'PIN incorrecto. Confirme o PIN e tente novamente.',
    'expired': 'O código QR expirou. Peça ao motorista para gerar um novo.',
    'expirou': 'O código QR expirou. Peça ao motorista para gerar um novo.',
  };

  static String friendly(String? rawMessage,
      {required String fallback, String? errorCode}) {
    if (errorCode != null && _byCode.containsKey(errorCode)) {
      return _byCode[errorCode]!;
    }
    if (rawMessage == null || rawMessage.isEmpty) return fallback;
    final lower = rawMessage.toLowerCase();
    for (final entry in _byKeyword.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }
    return rawMessage;
  }
}
