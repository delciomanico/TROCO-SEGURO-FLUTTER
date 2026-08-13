# Correcções de Backend — Troco Seguro

Lista de pendências para a equipa de backend/painel administrativo,
ordenada por prioridade (mais urgente primeiro). Itens já corrigidos e
confirmados a funcionar foram removidos deste documento — consultar
`git log -- BACKEND_PENDING_CHANGES.md` para o histórico completo.

**Actualizado em 2026-07-25.**

---

## 1. 🔴 URGENTE — `GET wallet/balance-by-qr/:qrId` devolve 500 para o `cardNumber` do QR real

**Reportado pelo utilizador:** "erro interno no servidor" ao testar a
consulta de saldo de um cartão externo no APP MOTORISTA (ecrã "Saldo do
Cartão", via QR).

**Confirmado ao vivo** contra `trocoseguro.wemof.tech`, com um cartão
virtual criado de propósito para o teste:

- O QR gerado por `GET virtual-cards/{id}/qr` codifica este JSON (decodificado
  a partir da imagem PNG devolvida):
  ```json
  {"type":"VIRTUAL_CARD_TRANSFER","cardNumber":"4830124046261068","cardName":"...","userName":"..."}
  ```
  **Não contém `id`/`qrId`/`cardId`** — só `cardNumber`. É a única forma
  que a app (ou qualquer utilizador) tem de identificar o cartão a partir
  de uma leitura real de QR.
- `GET wallet/balance-by-qr/{cardNumber}` (o valor que o QR realmente
  contém) → `500 {"message":"Erro interno do servidor"}`.
- `GET wallet/balance-by-qr/{id}` (o UUID interno do cartão, que a app
  **nunca tem acesso** ao ler o QR de outra pessoa) → `200`, funciona
  correctamente.
- Ou seja: o endpoint só resolve pelo UUID interno, mas a única coisa que
  chega de um QR real é o `cardNumber` — a funcionalidade está inutilizável
  tal como está hoje, para qualquer cartão que não seja o próprio.

**Implementar:** `GET wallet/balance-by-qr/:qrId` deve também resolver por
`cardNumber` (não só pelo `id` interno), já que é o único valor disponível
a partir de uma leitura de QR real. Devolver `404` (não `500`) quando o
identificador realmente não corresponder a nenhum cartão.

**Estado no app:** corrigido um bug relacionado do lado do Flutter —
`CardBalanceModal._load()` (`APP MOTORISTA/lib/widgets/wallet_transfer_modals.dart`)
tentava extrair `qrId`/`id`/`cardId` do QR decodificado, campos que nunca
existem no QR real; passou a extrair `cardNumber` primeiro. Ainda assim,
a funcionalidade só voltará a funcionar de ponta a ponta depois da
correcção acima no backend — confirmado ao testar com o `cardNumber` real:
continua a dar 500.

---

## 2. 🔴 Painel administrativo — "Lucros do Sistema" mostra o total levantado pelos UTILIZADORES, não da plataforma

**Reportado pelo utilizador**, com capturas de ecrã do painel web:

- Ecrã "Lucros do Sistema": `TOTAL JÁ LEVANTADO: 6.500 AOA`.
- Ecrã de levantamentos (aprovados): 2.500 + 2.000 + 1.000 + 1.000 =
  **6.500 AOA** — bate exactamente com o valor acima.

Ou seja, o campo "Total já levantado" nos lucros do sistema está, na
prática, a somar os levantamentos aprovados dos **utilizadores**
(motoristas/passageiros), não o lucro/comissão que a própria plataforma
já levantou. **Implementar:** ligar este campo à soma dos levantamentos
da conta da plataforma, não à tabela de levantamentos dos utilizadores.

**Nota:** este ecrã não existe neste repositório (só `APP MOTORISTA` e
`APP PASSAGEIRO`) — é do painel administrativo web, mantido pela equipa
de backend. Nenhuma acção de código possível deste lado.

---

## 3. 🔴 Painel administrativo — notificação de pânico "ABRIR" não leva à localização

**Reportado pelo utilizador**, com captura de ecrã do painel web: ao
receber uma notificação "🚨 PÂNICO ATIVO — localização atualizada"
("Palmero Salazar reacionou o botão de emergência. Nova localização
disponível no painel."), tocar em "ABRIR" leva para o ecrã de
**"Notificação em Massa"** (enviar mensagens em lote), não para nenhum
mapa/localização do passageiro. Não há, aparentemente, nenhum sítio no
painel onde a localização reportada pelo botão de pânico possa
efectivamente ser vista.

**Implementar:** ligar o botão "ABRIR" desta notificação a um ecrã que
mostre a localização (mapa) do passageiro que acionou o pânico.

**Nota:** este ecrã não existe neste repositório — é do painel
administrativo web, fora do âmbito dos apps Flutter.

---

## 4. 💬 Pagamento de viagem via `wallet/transfer-to-user` volta com `type: "transfer"`, não distinguível de uma transferência P2P genérica

**Reportado pelo utilizador:** no APP PASSAGEIRO, pagar um motorista
identificado por QR (fluxo "Identificar Motorista" → "Transferir para
este motorista") aparecia no separador "Transferências" da Carteira, não
em "Pagamentos" — apesar de ser, do ponto de vista do utilizador, o
pagamento de uma viagem.

**Confirmado no código:** este fluxo chama `POST wallet/transfer-to-user`
(não `POST payments/process`), e o próprio `API_ENDPOINTS.md` já
documenta que pagamentos de viagem por transferência voltam com
`type: "TRANSFER"` genérico. Como a app também tem uma funcionalidade
**genuinamente** genérica de "Transferir" (enviar dinheiro a qualquer
número de telefone, `POST transactions/transfer`), não há hoje nenhum
campo que distinga as duas — só a descrição textual.

**Implementar (correcção definitiva):** `wallet/transfer-to-user` devolver
um `type`/`category` próprio (ex. `RIDE_PAYMENT`) quando a transferência
for iniciada a partir da identificação de um motorista por QR, distinto
do `TRANSFER` genérico usado por `transactions/transfer`.

**Estado no app:** aplicado um paliativo do lado do Flutter — o filtro
"Pagamentos" da Carteira também aceita transacções `type == "transfer"`
cuja descrição bate com o padrão usado por este fluxo específico
("Transferência directa"/"Transferência para ..."). É uma heurística de
texto, não substitui a correcção acima.

---

## 5. 💬 Pedido de negócio — dividir a taxa da plataforma entre passageiro e motorista

**Pedido do cliente:** hoje a taxa da plataforma (1%) só é retida do
lado do motorista — o passageiro paga o preço cheio do lugar (ex.
300 Kz) e o motorista recebe o valor líquido (ex. 297 Kz), confirmado
nas notificações reais de "Pagamento Recebido". O cliente quer poder
dividir essa taxa entre os dois lados (ex. 1% descontado ao passageiro +
1% descontado ao motorista = 2% para a plataforma no total), para que
nenhum dos lados sinta que está a perder demasiado — motorista a achar
que recebe pouco, passageiro a achar que paga demais.

**Não é bug — é uma nova regra de negócio**, que precisa de decisão e
implementação do lado do backend antes de qualquer mudança na app:
- O backend precisa de calcular e expor tanto o valor cobrado ao
  passageiro como o valor líquido do motorista, com uma percentagem de
  taxa configurável em cada lado (hoje só existe uma percentagem única,
  aplicada de um só lado).
- Isto afecta os endpoints de cotação/transacção já usados pela app
  (`transactions/quote`, `transactions/transfer`, `wallet/transfer-to-user`,
  etc.) — precisam de devolver a componente de taxa de cada lado
  separadamente, não só um `feeAmount`/`netReceived` agregado.

**No app:** sem alterações possíveis até o contrato acima existir — a UI
de "ver tarifa" em ambos os apps já está pronta para mostrar valores
adicionais assim que o backend os expuser.
