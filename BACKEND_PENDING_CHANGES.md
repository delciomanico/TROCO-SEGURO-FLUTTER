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

**`POST payments/process` — JÁ RESOLVIDO, confirmado 2026-07-14**: ao
testar um pagamento real de assento de ponta a ponta (passageiro paga,
ver item 11), a resposta já inclui a taxa:
`{"success":true,"transactionId":"...","tripId":"...",
"platformFeeApplied":5,"platformFeePercentage":5,"newBalance":4900}`.
A taxa é descontada do lado do **motorista** (recebeu 95 de um pagamento
de 100), não do passageiro (pagou os 100 completos) — útil para a UI não
mostrar "tarifa" como um custo extra ao passageiro neste fluxo, só
informativamente. Como `PaymentResult.fromJson` já tinha
`platformFeeApplied` como uma das chaves aceites (ver "Estado no app"
abaixo), **não foi preciso nenhuma mudança no Flutter** — a UI já mostra
a tarifa automaticamente neste ecrã.

**`POST transactions/transfer` e `POST transactions/deposit` — ainda por
resolver.** Nenhuma destas respostas devolve o valor da taxa cobrada.
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

## 5. ~~Segunda viatura devolve erro 500~~ — CORRIGIDO (confirmado 2026-07-14)

**Endpoint:** `POST fleet/vehicles`

**Estado anterior:** ao tentar registar uma segunda viatura para o mesmo
motorista, a API devolvia 500.

**Confirmado corrigido em 2026-07-14**: testado directamente contra
`trocoseguro.wemof.tech` com a conta de teste do motorista (que já tinha
uma viatura) — `POST fleet/vehicles` com uma segunda viatura devolveu
`201` com o registo criado normalmente. Nenhuma mudança necessária no
app (nunca teve restrição própria).

---

## 6. ~~Capacidade de assentos por sessão (`childQrs`)~~ — RESPONDIDO (confirmado 2026-07-14)

**Endpoint:** `POST qrcodes/session/start` / `PUT fleet/vehicles/{id}`

**Confirmado directamente contra a API** com a conta de teste do
motorista: o número de `childQrs` devolvido por `qrcodes/session/start`
é **exactamente igual** ao campo `seats` do veículo activo (testado com
um veículo de 4 lugares → 4 `childQrs`, cada um com o seu `label`/
`publicToken`). E `PUT fleet/vehicles/{id}` tem uma validação rígida:
`{"seats": 65}` devolve `400` com `"seats must not be greater than 60"`;
`{"seats": 60}` é aceite. **Ou seja, a capacidade máxima real de uma
sessão é 60 assentos, não 65** — não há nenhum limite adicional a
"confirmar", a resposta é definitiva: o tecto é o próprio campo `seats`
do veículo, capado a 60 no backend.

Isto é **diferente** do outro limite de 65 já implementado no app — o
"limite de cobrança por scan" (`_seatsCount` em
`APP MOTORISTA/lib/screens/home_screen.dart`, usado no modal de cobrança
por cartão do passageiro, `payments/authorize-passenger-qr`) é um
multiplicador manual independente do número de lugares do veículo, sem
validação de tecto no backend — esse continua correctamente em 65 e não
precisa de mudança.

**Estado no app:** nenhuma mudança necessária — o app já usa o `childQrs`
que a API devolve, sem impor um limite próprio. Se o cliente quiser
mesmo sessões de 65 lugares, o pedido passa a ser ao backend para subir o
tecto de validação de `seats` em `fleet/vehicles` de 60 para 65 (não é
uma limitação do Flutter).

---

## 7. Detalhe por assento (pago/disponível) na sessão activa

**Endpoints:** `GET qrcodes/session/seats` (REST — **500 corrigido em
2026-07-14**, confirmado a devolver 200 directamente contra a API) e
`qrcodes/session/seats-live` (stream SSE, ainda só envia agregados:
`totalSeats`/`paidSeats`/`availableSeats`/`revenue`).

**Parcialmente resolvido**: o bug do 500 no endpoint REST já não
acontece — testado em 2026-07-14 com a conta de teste do motorista
(sem sessão activa), devolveu `200` com
`{"active":false,"totalPayments":0,"totalSeats":0,"revenue":0}`.

**Confirmado definitivamente em 2026-07-14, com um pagamento real de
ponta a ponta**: creditámos saldo à conta de teste do passageiro (depósito
aprovado manualmente pelo admin, ver item 10), verificámos a conta do
motorista (precisou de ser marcada como verificada no admin para poder
ficar online — ver item 11), iniciámos uma sessão real, e o passageiro
pagou um lugar com sucesso (`payments/process` → `success: true`,
`newBalance: 4900`). Mesmo **depois** desse pagamento confirmado,
`GET qrcodes/session/seats` continuou só agregada:
`{"active":true,"sessionId":"...","totalPayments":1,"totalSeats":1,
"revenue":100}` — sem nenhum array `seats`. Isto fecha definitivamente a
questão: não é falta de sessão activa nem de pagamentos — o backend
simplesmente não expõe detalhe por assento em nenhum cenário testado.

**Pedido (ainda válido se a resposta continuar só agregada com sessão
activa):** incluir no payload (REST ou SSE) um array por assento, ex.:
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

**Re-verificado em 2026-07-14**: provocámos vários erros reais de propósito
(saldo insuficiente numa transferência, payload inválido num pagamento por
QR) para inspeccionar a resposta completa — em todos os casos o formato é
o mesmo (`{"statusCode":400,"message":"Saldo insuficiente.","error":"Bad
Request"}` ou `message` como array de strings de validação), sem nenhum
campo de código estável escondido. Confirma que não há nada a extrair do
lado do cliente — o pedido ao backend continua válido tal como descrito.

**Estado no app:** criado `PaymentErrorMessages` (ambos os apps,
`lib/utils/error_messages.dart`) — hoje faz correspondência por
palavra-chave no texto da mensagem (ex. "insufficient", "expired") como
aproximação temporária. Assim que existir `errorCode`, o mapeamento pode
passar a ser por código exacto (mais fiável que procurar palavras no
texto).

---

## 9. `POST transactions/transfer` rejeita `receiverId` (confirmado — bloqueia a funcionalidade "Transferir para este motorista")

**Endpoint:** `POST transactions/transfer`

**Confirmado em 2026-07-13** contra o staging real
(`trocoseguro.wemof.tech`), com um teste funcional autenticado
(`APP PASSAGEIRO/test/functional/auth_and_wallet_test.dart`, teste 6): o
backend devolve 400 com a mensagem `"property receiverId should not
exist. receiverPhone should not be empty. receiverPhone must be a
string"` quando o pedido inclui `receiverId` — ou seja, **só aceita
`receiverPhone`**, ao contrário do que `API_ENDPOINTS.md` documenta
(nota: esse ficheiro parece descrever um backend antigo, em
`troco-seguro.onrender.com`, não o ambiente actual).

Confirmámos também que `GET users/drivers/{id}` (a única forma que o app
tem de obter mais dados sobre um motorista a partir do seu `driverId`)
**não devolve o número de telefone** — só `id`, `fullName`, `isVerified`,
`createdAt`, `totalTrips`, `rating`. Ou seja, não há hoje nenhuma forma
de o passageiro transferir directamente para um motorista identificado
por QR sem pedir o número de telefone por outro meio.

**Pedido:** ou (a) `POST transactions/transfer` passar a aceitar
`receiverId` como alternativa a `receiverPhone`, ou (b)
`GET users/drivers/{id}` passar a incluir o número de telefone (se a
política de privacidade permitir).

**Re-testado em 2026-07-14** (pedido explícito para confirmar depois de
outras correcções do backend) — **ainda não resolvido**: mesmo pedido
directo à API devolveu exactamente a mesma mensagem de erro
(`"property receiverId should not exist..."`). Itens 5 e 7 (segunda
viatura, `GET qrcodes/session/seats`) já foram corrigidos nesta mesma
ronda — este continua pendente.

**Estado no app:** a funcionalidade "Transferir para este motorista" foi
**removida do ecrã de identificação por QR**
(`APP PASSAGEIRO/lib/screens/home_screen.dart`, `_handleIdentifyQr`) para
não deixar um botão que falha sempre que tocado — mostra agora uma
mensagem a explicar que depende desta actualização. `ApiService.transfer`/
`AppProvider.transfer` mantêm o parâmetro `receiverId` (testado
unitariamente, sem custo) pronto a ligar de volta à UI assim que este
item for resolvido. Há um teste funcional "canário"
(`auth_and_wallet_test.dart`, teste 6) que falha propositadamente hoje e
passará a ter sucesso no dia em que o backend aceitar `receiverId` — é o
sinal para reactivar a UI.

---

## 10. ~~`POST transactions/deposit` devolve 404~~ — RESOLVIDO com endpoint vivo alternativo (2026-07-14)

`POST transactions/deposit` continua a devolver 404 em
`trocoseguro.wemof.tech` (só existe documentado para o backend antigo,
`troco-seguro.onrender.com`, que aliás está agora completamente
inacessível — confirmámos via `curl` que nem responde ao handshake TLS
após 90s, ao contrário deste host que responde em <1s). **Mas** confirmámos
que o backend actual já expõe um par de endpoints vivo e funcional que
resolve a mesma necessidade (carregar saldo com referência):

- `POST payments/deposit/initiate` `{ "amount": 500 }` → `201`
  `{ "message": "Pedido de carregamento iniciado.", "transactionId": "...",
  "reference": "MCX-1784049688328", "status": "PENDING" }`. Testado com
  as duas contas de teste (passageiro e motorista) — ambas conseguem
  iniciar um pedido. A transação aparece de imediato em
  `GET transactions/history` com `status: "PENDING"`.
- `POST payments/webhook/simulate` `{ "reference": "..." }` — confirma o
  pagamento e credita o saldo. **Importante**: está protegido a
  administradores (`403 Forbidden` — "Acesso restrito a administradores"
  para contas `PASSENGER`/`DRIVER`). Ou seja, hoje só um admin consegue
  confirmar um depósito manualmente; não há forma de o próprio
  utilizador (nem os testes automatizados com as contas de teste)
  completar o ciclo sozinho.

**Estado no app:** ambos os apps já chamam `payments/deposit/initiate` e
mostram a referência devolvida ao utilizador (ecrã "Carregar Saldo"), com
instruções para pagar via Multicaixa Express/ATM usando essa referência.
O saldo só é actualizado depois de confirmado do lado do backend — os
apps não tentam chamar `payments/webhook/simulate` (ficaria sempre 403
para utilizadores normais).

**Pedido (opcional):** se for útil para testes automatizados ou para o
próprio utilizador poder confirmar um pagamento real sem esperar por um
admin, seria bom ter uma forma de o `webhook/simulate` (ou um endpoint
equivalente) ser chamado automaticamente por um gateway de pagamento real,
ou disponibilizar credenciais de admin dedicadas só para os testes
automatizados confirmarem o ciclo completo em staging.

**Ciclo completo validado em 2026-07-14**: o dono do projecto aprovou
manualmente os dois pedidos de depósito (passageiro e motorista, 5.000 Kz
cada) através do painel admin — confirmámos via `GET users/me` que ambos
os saldos foram creditados correctamente (`0 → 5000`). O fluxo
`initiate` → aprovação manual → saldo creditado funciona de ponta a
ponta; só falta automatizar a aprovação (ver pedido acima).

---

## 11. Backend rejeita `isOnline: true` para motoristas não verificados — outra causa real de "motorista não está online"

**Endpoint:** `PUT users/me/status`

Ao investigar a reclamação do cliente de que o pagamento falha com
"motorista não está online" mesmo com o motorista a dizer que está
online, corrigimos uma dessincronização client-side (ver histórico de
commits — `APP MOTORISTA/lib/main.dart`, `_refreshFromApi`/
`_toggleOnlineStatus`). Mas ao **reproduzir o erro de ponta a ponta**
com as contas de teste (motorista inicia sessão, passageiro paga um
lugar), descobrimos uma **segunda causa, esta genuinamente do backend**:

`PUT users/me/status` com `{"isOnline": true}` devolve `403 Forbidden`
para a conta de teste do motorista (que tem `isVerified: false`):
```json
{"statusCode":403,"message":"Conta ainda não verificada. Conclua a verificação (QR do BI ou envio de documentos) antes de ficar online.","error":"Forbidden"}
```
Ou seja, um motorista **não verificado não consegue mesmo ficar online**
— o backend recusa sempre, não é um bug. Com a correcção que já fizemos
no app (reverter o estado local quando o backend recusa e mostrar o erro
numa SnackBar), um motorista nesta situação passa agora a **ver** a
mensagem real de "conta ainda não verificada" em vez de continuar
convencido de que está online. Isto por si só já deve resolver a maior
parte dos casos reportados pelo cliente, desde que os motoristas afectados
não tenham ainda completado a verificação de identidade (QR do BI /
envio de documentos) no app.

**Não é pedido nenhum ao backend** — este comportamento (exigir conta
verificada para ficar online) parece correcto e intencional. Este item
é só para registar a descoberta e ligar as duas causas (dessincronização
client-side + verificação de identidade em falta) que juntas explicam o
sintoma reportado.

**Estado no app:** nenhuma mudança adicional necessária além da já feita
(reverter/mostrar erro no toggle). Se o motorista de teste precisar de
ficar online para mais testes (ex. validar o item 7 com um pagamento de
lugar real), a conta precisa de ser marcada como verificada no painel
admin — não há forma de simular isto via API sem um QR de BI real.
