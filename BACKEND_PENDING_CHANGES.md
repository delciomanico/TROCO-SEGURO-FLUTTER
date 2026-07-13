# Pendências de Backend — Troco Seguro

Este documento lista as alterações de backend necessárias para desbloquear
pedidos do cliente que o Flutter (APP MOTORISTA e APP PASSAGEIRO) já não
consegue resolver sozinho. Cada secção indica o comportamento actual, a
mudança pedida e o que o cliente já está pronto para consumir assim que o
campo existir — para a maioria dos itens não é preciso nenhuma mudança
adicional no app depois da API expor o dado.

Formato inspirado nos `API_ENDPOINTS.md` já existentes em cada app.

---

## 1. PIN de 6 para 4 dígitos (pagamento por cartão do passageiro)

**Endpoint:** `POST payments/authorize-passenger-qr`

**Actual:** o campo `passengerPin` exige 6 dígitos numéricos (contrato
documentado em `APP PASSAGEIRO/CLAUDE.md` e reforçado por
`APP MOTORISTA/lib/screens/home_screen.dart` — `_pinLength`).

**Pedido:** o cliente pediu 4 dígitos. Antes de mudar isto no app,
precisamos de confirmação do backend sobre:
- Se o comprimento do PIN pode ser reduzido para 4 dígitos sem
  comprometer a segurança do fluxo (o PIN aqui identifica o *passageiro*,
  não o motorista, e é digitado no aparelho do motorista).
- Se a mudança seria uma migração (PINs já existentes de 6 dígitos
  continuam válidos) ou uma alteração de contrato pura.

**Estado no app:** nenhuma mudança feita — mudar só o comprimento no
Flutter faria todos os pedidos falharem contra o contrato actual de 6
dígitos.

---

## 2. Opção de remover o PIN do cartão virtual

**Endpoints:** `POST virtual-cards`, `PUT virtual-cards/{id}/status`,
`PUT virtual-cards/{id}/limit`

**Actual:** `CreateCardPayload` exige sempre `cardPin` (4 dígitos); não
existe nenhum campo para desactivar a exigência de PIN num pagamento com
esse cartão.

**Pedido:** um campo novo, ex. `pinRequired: boolean` (default `true`) em
`CreateCardPayload`, e o correspondente suporte em
`updateCardStatus`/`updateCardLimit` (ou um novo endpoint dedicado) para
alternar isto depois de criado o cartão. O fluxo de pagamento com cartão
(`payments/authorize-passenger-qr` ou equivalente) precisa de saltar a
validação de PIN quando `pinRequired == false`.

**Estado no app:** nenhuma mudança feita — foi avaliado e descartado
propositadamente um contorno client-side (cache do PIN no dispositivo)
por ser inseguro.

---

## 3. Tarifa da plataforma no lado do passageiro

**Endpoints:** `POST transactions/transfer`, `POST payments/process`,
`POST transactions/deposit`

**Actual:** nenhuma destas respostas devolve o valor da taxa cobrada.
Comparar com `POST payments/authorize-passenger-qr` (usado pelo
motorista), que **já devolve** `platformFeeApplied` (valor em Kz) — o app
do motorista já mostra isto ao passageiro/motorista no ecrã de sucesso
pós-pagamento.

**Pedido:** paridade — devolver `feeAmount` (ou `fee`/`tax`, o cliente
aceita qualquer um destes nomes) nas respostas dos 3 endpoints acima, com
o mesmo significado de `platformFeeApplied` (valor em Kz já cobrado).

**Pedido adicional (opcional, mais valioso):** um endpoint de "cotação"
que devolva a taxa **antes** de confirmar a operação (ex.
`GET transactions/quote?amount=...&type=transfer`), para se poder mostrar
"Valor / Tarifa / Total" antes do utilizador confirmar — hoje isso só é
possível depois de a operação já ter sido executada, porque a taxa só
existe na resposta final.

**Estado no app:** `TransactionResult`/`PaymentResult`
(`APP PASSAGEIRO/lib/services/api_service.dart`) já têm um campo nullable
`feeAmount`, parseado defensivamente de `feeAmount`/`fee`/`tax`/
`platformFeeApplied` — fica `null` (sem mudança visível) até o backend
começar a enviá-lo. Assim que existir, a UI mostra automaticamente
"Tarifa aplicada: X Kz" na confirmação da transferência.

---

## 4. Cêntimos/decimais no saldo

**Actual:** valores monetários são inteiros em Kwanzas (Kz), documentado
em `APP PASSAGEIRO/CLAUDE.md`.

**Pedido:** o cliente pediu para o saldo mostrar cêntimos. Precisamos de
confirmação se/quando o backend passará a guardar e devolver valores
fraccionários.

**Estado no app:** criado `AppFormatters.currency()` em ambos os apps
(`lib/utils/formatters.dart`) como ponto único de formatação do saldo —
hoje usa `#,##0` (inteiro); assim que o backend confirmar suporte a
fracções, activar `decimalsEnabled = true` nesse ficheiro é a única
mudança necessária no Flutter.

---

## 5. Segunda viatura devolve erro 500

**Endpoint:** `POST fleet/vehicles`

**Actual:** ao tentar registar uma segunda viatura para o mesmo
motorista, a API devolve 500. Confirmado que **não há nenhuma restrição
do lado do app** — o ecrã `vehicles_screen.dart` sempre permitiu
adicionar múltiplas viaturas.

**Pedido:** isto é um **bug report**, não um pedido de funcionalidade —
por favor investigar por que `POST fleet/vehicles` falha para um
motorista que já tem uma viatura activa.

**Estado no app:** nada a mudar; assim que o backend corrigir, a
funcionalidade já funciona sem qualquer alteração no Flutter.

---

## 6. Capacidade de assentos por sessão (`childQrs`)

**Endpoint:** `POST qrcodes/session/start`

**Actual:** o número de QRs filho (`childQrs`) devolvido depende do
backend/perfil do veículo, não do app.

**Pedido:** confirmar se a capacidade máxima por sessão pode chegar a 65
assentos (o cliente pediu para o limite de cobrança por scan subir de 10
para 65 — já feito no app — mas se a *sessão inteira* estiver limitada a
menos de 65 QRs no backend, o pedido do cliente não fica plenamente
satisfeito).

**Estado no app:** o limite de UI conhecido (quantos assentos cobrar de
uma vez ao escanear o cartão do passageiro) já subiu de 10 para 65.

---

## 7. Detalhe por assento (pago/disponível) na sessão activa

**Endpoints:** `GET qrcodes/session/seats` (REST, hoje devolve 500) e
`qrcodes/session/seats-live` (stream SSE, só envia agregados:
`totalSeats`/`paidSeats`/`availableSeats`/`revenue`).

**Pedido:** ou corrigir o endpoint REST, ou (preferível, evita polling)
incluir no payload do SSE um array por assento, ex.:
```json
{
  "totalSeats": 10,
  "paidSeats": 3,
  "seats": [
    { "label": "Assento 1", "paid": true },
    { "label": "Assento 2", "paid": false }
  ]
}
```

**Estado no app:** `SessionSeatsResult` (`APP MOTORISTA/lib/services/api_service.dart`)
já parseia um campo opcional `seats`/`seatList` (aceita `label`/`seatLabel`/
`seatNumber` e `paid`/`isPaid`) — hoje fica `null` (o painel "Lotação"
mostra só os agregados, como antes). Assim que o backend enviar este
array, o painel desenha automaticamente uma grelha real por assento.

---

## 8. Códigos de erro estáveis nas respostas de pagamento/transferência

**Actual:** erros vêm só como texto livre em `message`/`error` (via
`_parseError` em ambos os `api_service.dart`), por vezes técnico ou
genérico ("Pagamento recusado pela API.").

**Pedido:** um campo `errorCode` estável (ex. `INSUFFICIENT_FUNDS`,
`INVALID_PIN`, `SEAT_UNAVAILABLE`, `QR_EXPIRED`) nas respostas de erro dos
endpoints de pagamento/transferência, além da mensagem em texto livre
(que pode continuar a existir para debug).

**Estado no app:** criado `PaymentErrorMessages` (ambos os apps,
`lib/utils/error_messages.dart`) — hoje faz correspondência por
palavra-chave no texto da mensagem (ex. "insufficient", "expired") como
aproximação temporária. Assim que existir `errorCode`, o mapeamento pode
passar a ser por código exacto (mais fiável que procurar palavras no
texto).

---

## 9. Nota (não bloqueante) — `receiverId` vs `receiverPhone` em transferências

`API_ENDPOINTS.md` documenta `POST transactions/transfer` com
`receiverId` no corpo do pedido; a implementação actual do app usa
maioritariamente `receiverPhone` (fluxo de transferência por número de
telefone) e, mais recentemente, também `receiverId` (nova funcionalidade
"Transferir para este motorista", que usa o `driverId` já devolvido pela
resolução do QR, sem precisar de telefone). Pedimos confirmação de que o
backend aceita ambos os campos de forma estável e continuada, para não
haver divergência futura entre a documentação e o comportamento real.
