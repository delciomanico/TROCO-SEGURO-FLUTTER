# Correcções de Backend — Troco Seguro

Histórico de mudanças de contrato da API para a equipa mobile (APP MOTORISTA
e APP PASSAGEIRO).

**Actualizado em 2026-07-15 — todos os itens estão FEITOS e confirmados por
teste real de ponta a ponta**, incluindo os 5 itens desta ronda (tarifa +
cotação, valores como string decimal, detalhe por assento, `errorCode`,
limite de lugares) e os das rondas anteriores (PIN de cartão de 4 dígitos,
pagamento sem PIN por omissão, transferência directa por ID). O lado do app
já consome todas as mudanças — ver detalhe de cada item abaixo.

---

## 1. ✅ Tarifa da plataforma nas transacções + cotação prévia

**Confirmado ao vivo:** `transactions/transfer`, `transactions/withdraw`,
`wallet/transfer-to-user` e `payments/deposit/initiate` devolvem
`feeAmount`/`totalDebited`/`netAmount`. `GET transactions/quote?type=transfer
|deposit|withdrawal&amount=...` devolve `{type, amount, feePercent,
feeAmount, totalDebited, netReceived}` antes da confirmação.

**No app:** `ApiService.getTransactionQuote()` (ambos os apps) chama o
endpoint; `transfer_modal.dart` e `topup_modal.dart` (APP PASSAGEIRO) e
`withdrawal_modal.dart` (APP MOTORISTA, fluxo em dois passos "ver tarifa" →
"confirmar") mostram Valor/Tarifa/Total antes de confirmar.

---

## 2. ✅ Valores monetários como string decimal

**Confirmado ao vivo:** `balance`, `amount`, `feeAmount`, `totalDebited`,
`revenue`, `pricePerSeat`, etc. vêm como string decimal (`"4850.00"`) em
toda a API. Percentagens de taxa e contadores (`totalSeats`,
`totalPayments`) continuam número.

**No app:** corrigido um bug sistémico onde vários pontos usavam
`int.tryParse()` (falha silenciosamente com valores decimais, devolvendo 0)
em vez de `num.tryParse()`. Helpers `_toInt`/`_toIntOrNull` adicionados aos
`api_service.dart` de ambos os apps e aplicados a todos os campos
monetários; `VirtualCardResponse._parseInt` (APP PASSAGEIRO) tinha o mesmo
bug, corrigido.

---

## 3. ✅ Detalhe por assento (pago/disponível) na sessão activa

**Confirmado ao vivo** (pagamento real de um assento específico, REST e
SSE): `GET qrcodes/session/seats` e o SSE `seats-live` devolvem
`seats: [{label, paid}]`, mais `paidSeats`/`seatsPaidSum`.

**No app:** nenhuma mudança necessária — `SessionSeatsResult` já parseava
`seats` de forma defensiva e o painel "Lotação"
(`APP MOTORISTA/lib/screens/home_screen.dart`) já desenhava a grelha por
assento assim que o campo existisse; passou a aparecer automaticamente.

---

## 4. ✅ Código de erro estável (`errorCode`)

**Confirmado ao vivo:** erros de saldo insuficiente e PIN incorrecto
devolvem `errorCode` (`INSUFFICIENT_FUNDS`, `INVALID_PIN`). Lista completa
suportada pelo app: `INSUFFICIENT_FUNDS`, `INVALID_PIN`, `QR_EXPIRED`,
`DRIVER_OFFLINE`, `CARD_INACTIVE`, `SEAT_UNAVAILABLE`.

**No app:** `ApiResponse` (ambos os apps) ganhou um campo `errorCode`,
extraído pelo novo `_parseErrorCode()` nos endpoints de pagamento/
transferência (`transfer`, `transferToUser`, `processPayment`,
`resolveQrToken` no APP PASSAGEIRO; `authorizePassengerQr`,
`previewPassengerCard` no APP MOTORISTA). `PaymentErrorMessages.friendly()`
mapeia por `errorCode` exacto quando presente, com fallback para
correspondência por palavra-chave nos restantes erros.

---

## 5. ✅ Limite de lugares por veículo subido de 60 para 65

**Confirmado ao vivo:** `{"seats": 65}` aceite; `{"seats": 66}` rejeitado.

**No app:** nenhuma mudança — já usa o `childQrs` que a API devolve.

---

## Nota — Entrega de OTP por WhatsApp corrigida (só backend)

Confirmada pela equipa de backend; sem impacto no app.
