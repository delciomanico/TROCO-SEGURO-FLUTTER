/// Mapeamento de mensagens de erro de pagamento para texto mais amigável.
///
/// O backend ainda não devolve um código de erro estável (ver
/// BACKEND_PENDING_CHANGES.md, item 8) — só uma mensagem em texto livre, por
/// vezes técnica. Este mapa cobre palavras-chave plausíveis encontradas em
/// mensagens reais da API; qualquer mensagem que não corresponda a nenhuma
/// entrada é devolvida tal como veio (comportamento actual, inalterado).
class PaymentErrorMessages {
  static const Map<String, String> _byKeyword = {
    'insufficient': 'Saldo insuficiente para este pagamento.',
    'saldo insuficiente': 'Saldo insuficiente para este pagamento.',
    'invalid pin': 'PIN incorrecto. Confirme o PIN e tente novamente.',
    'pin incorreto': 'PIN incorrecto. Confirme o PIN e tente novamente.',
    'pin inválido': 'PIN incorrecto. Confirme o PIN e tente novamente.',
    'expired': 'O código QR expirou. Peça ao motorista para gerar um novo.',
    'expirou': 'O código QR expirou. Peça ao motorista para gerar um novo.',
  };

  static String friendly(String? rawMessage, {required String fallback}) {
    if (rawMessage == null || rawMessage.isEmpty) return fallback;
    final lower = rawMessage.toLowerCase();
    for (final entry in _byKeyword.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }
    return rawMessage;
  }
}
