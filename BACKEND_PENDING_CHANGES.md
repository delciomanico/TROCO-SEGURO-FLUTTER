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

**Endpoints:** `GET qrcodes/session/seats` (REST — **500 corrigido em
2026-07-14**, confirmado a devolver 200 directamente contra a API) e
`qrcodes/session/seats-live` (stream SSE, ainda só envia agregados:
`totalSeats`/`paidSeats`/`availableSeats`/`revenue`).

**Parcialmente resolvido**: o bug do 500 no endpoint REST já não
acontece — testado em 2026-07-14 com a conta de teste do motorista
(sem sessão activa), devolveu `200` com
`{"active":false,"totalPayments":0,"totalSeats":0,"revenue":0}`. Ainda
**não confirmámos** se, com uma sessão activa, a resposta já inclui
detalhe por assento (`seats`) ou continua só agregada — falta testar com
uma sessão de cobrança real em curso.

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

## 10. Nota — `POST transactions/deposit` devolve 404 no staging actual

**Re-testado em 2026-07-14, continua 404.**

Confirmado pelo mesmo teste funcional: `POST transactions/deposit`
("carregamento simulado", usado pelo passageiro para testar sem gateway
de pagamento real) devolve 404 em `trocoseguro.wemof.tech` — só existe
documentado para o backend antigo (`troco-seguro.onrender.com`). Não é
necessariamente um bug (pode ser intencional não ter carregamento
simulado em staging) — mas sem ele não há forma de dar saldo a uma conta
de teste a partir do próprio app, o que limita testes automatizados de
funcionalidades que movimentam dinheiro. Se for útil ter uma forma de
carregar contas de teste sem gateway real, agradecemos indicação de como
fazê-lo (endpoint dedicado, acesso ao painel admin, etc.).
