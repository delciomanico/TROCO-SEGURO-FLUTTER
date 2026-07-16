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
    'INSUFFICIENT_FUNDS': 'Saldo insuficiente do passageiro para este pagamento.',
    'INVALID_PIN': 'PIN incorrecto. Peça ao passageiro para confirmar o PIN.',
    'QR_EXPIRED': 'O QR do passageiro expirou. Peça para gerar um novo.',
    'DRIVER_OFFLINE': 'Precisa de estar online para cobrar.',
    'CARD_INACTIVE': 'Este cartão está inactivo ou bloqueado.',
    'SEAT_UNAVAILABLE': 'Este assento já foi pago ou não está disponível.',
  };

  static const Map<String, String> _byKeyword = {
    'insufficient': 'Saldo insuficiente do passageiro para este pagamento.',
    'saldo insuficiente': 'Saldo insuficiente do passageiro para este pagamento.',
    'invalid pin': 'PIN incorrecto. Peça ao passageiro para confirmar o PIN.',
    'pin incorreto': 'PIN incorrecto. Peça ao passageiro para confirmar o PIN.',
    'pin inválido': 'PIN incorrecto. Peça ao passageiro para confirmar o PIN.',
    'expired': 'O QR do passageiro expirou. Peça para gerar um novo.',
    'expirou': 'O QR do passageiro expirou. Peça para gerar um novo.',
    'seat': 'Este assento já foi pago ou não está disponível.',
    'assento': 'Este assento já foi pago ou não está disponível.',
  };

  static String friendly(String? rawMessage, {String? errorCode}) {
    if (errorCode != null && _byCode.containsKey(errorCode)) {
      return _byCode[errorCode]!;
    }
    if (rawMessage == null || rawMessage.isEmpty) {
      return 'Pagamento recusado pela API.';
    }
    final lower = rawMessage.toLowerCase();
    for (final entry in _byKeyword.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }
    return rawMessage;
  }
}
