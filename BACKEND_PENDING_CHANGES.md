# Correcções de Backend — Troco Seguro

Histórico de mudanças de contrato da API para a equipa mobile (APP MOTORISTA
e APP PASSAGEIRO).

**Actualizado em 2026-07-18.** Item 0 (bug do `POST fleet/vehicles`) está
**confirmado corrigido ao vivo** — depois de duas rondas anteriores em que
o backend indicou "corrigido" e o teste ao vivo mostrava o contrário, desta
vez a correcção foi verificada a funcionar de ponta a ponta (ver detalhe
abaixo). Itens 1 a 5 (2026-07-15) permanecem FEITOS, sem regressão.

---

## 0. ✅ Frota: múltiplos veículos e múltiplas frotas por motorista

**Confirmado ao vivo** contra `trocoseguro.wemof.tech`, com o motorista de
teste (`+244900000022`), depois de duas rondas anteriores em que o mesmo
bug fora reportado como corrigido pelo backend mas continuava a falhar:

- `POST fleet/vehicles` — criado um 2º e um 3º veículo para o mesmo
  motorista (que já tinha um): `201` em ambos, sem 500. Antes falhava
  sempre no 2º veículo.
- `DELETE fleet/vehicles/:id` — motorista removeu um veículo próprio:
  `200 {"message":"Veículo removido com sucesso."}`. Antes ficava sem
  saída (a API exigia desvincular primeiro, rota só para gestor).
- `POST qrcodes/session/start` — iniciada sessão com o veículo A (15
  lugares), depois com o veículo B (4 lugares) sem terminar a sessão A
  manualmente: a API fechou a sessão A automaticamente e abriu uma nova
  (`sessionId` diferente) já com o nome, preço e nº de assentos do veículo
  B (`childQrs` com 4 QRs, não 15) — troca de viatura entre sessões
  confirmada a funcionar correctamente.
- `POST qrcodes/session/start` com um `vehicleId` inexistente devolveu
  exactamente o erro novo documentado: `404 {"message":"Veículo não
  encontrado ou não está atribuído a si."}`.
- Itens 4-6 do documento da equipa de backend (`assign-driver`,
  `unassign-driver`, `admin/fleet/:id/stats`, `fleet/trips`) não têm
  qualquer chamada no APP MOTORISTA (confirmado por grep) — são
  exclusivos do portal do gestor de frota, não aplicável a este app.

**No app:** nenhuma mudança de código necessária.
`vehicles_screen.dart` já renderiza uma lista de veículos sem limite
artificial de quantidade; `_showVehicleSelectionModal()`
(`APP MOTORISTA/lib/main.dart`) já deixa o motorista escolher entre vários
veículos ao ficar online; e o fluxo de início de sessão
(`_showQRConfig` em `home_screen.dart`) já trata qualquer erro de
`setupQrSession` (incluindo o novo 404) mostrando a mensagem da API em vez
de rebentar — se o `vehicleId` em cache ficar desactualizado (veículo
removido/reatribuído entre sessões da app), o motorista só precisa de
ficar offline e voltar a ficar online para escolher de novo.

Dados de teste (3 veículos, 2 sessões) limpos após o teste; motorista
devolvido ao estado original (1 veículo, offline).

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
