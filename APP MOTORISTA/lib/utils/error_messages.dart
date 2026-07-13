/// Mapeamento de mensagens de erro de pagamento para texto mais amigável.
///
/// O backend ainda não devolve um código de erro estável (ver
/// BACKEND_PENDING_CHANGES.md, item 8) — só uma mensagem em texto livre, por
/// vezes técnica. Este mapa cobre palavras-chave plausíveis encontradas em
/// mensagens reais da API; qualquer mensagem que não corresponda a nenhuma
/// entrada é devolvida tal como veio (comportamento actual, inalterado).
class PaymentErrorMessages {
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

  static String friendly(String? rawMessage) {
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
