# Correcções de Backend — Troco Seguro

Lista de pendências para a equipa de backend/painel administrativo,
ordenada por prioridade (mais urgente primeiro). Itens já corrigidos e
confirmados a funcionar foram removidos deste documento — consultar
`git log -- BACKEND_PENDING_CHANGES.md` para o histórico completo.

**Actualizado em 2026-08-20.**

---

## 1. 🔴 `POST fleet/vehicles` devolve 500 (em vez de erro de validação) ao registar uma matrícula já existente

**Reportado pelo utilizador:** no App Motorista, registar um segundo
veículo dava erro. Reproduzido diretamente contra a API ao vivo
(`https://trocoseguro.ao/api/v1`) com a conta de teste do motorista QA:

- Registar um veículo com uma matrícula nova → `201 Created`, normal.
- Registar novamente com a **mesma matrícula** de um veículo já existente
  na frota (comparação exacta, incluindo variações de maiúsculas/espaços
  passam) → `500 Internal Server Error`:
  ```json
  {"statusCode":500,"message":"Erro interno do servidor","error":"Internal Server Error"}
  ```
  em vez de um `400`/`409` de validação (ex. "Matrícula já registada").

Isto indica uma violação de constraint de unicidade (matrícula) na base
de dados que não está a ser apanhada/tratada no endpoint
`POST fleet/vehicles` — o erro passa por sem tratamento e vira 500.

**Implementar:** validar a matrícula antes do insert (ou apanhar o erro
de constraint única) e devolver um `400`/`409` com mensagem clara
("Matrícula já registada") em vez do 500 genérico.

**No app:** aplicado um paliativo do lado do Flutter — o formulário de
adicionar/editar veículo (`vehicles_screen.dart`) já valida localmente
se a matrícula introduzida coincide com a de outro veículo do próprio
motorista antes de submeter, evitando bater neste 500 no caso mais comum
(reintroduzir sem querer a mesma matrícula). Não cobre colisões com
matrículas de **outros** motoristas, cuja validação só pode acontecer no
backend.

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

## 4. 🔴 Reclamações criadas pelo utilizador não chegam ao painel administrativo

**Reportado pelo utilizador:** reclamações submetidas no APP PASSAGEIRO
(`POST complaints`) não aparecem no painel administrativo para a equipa
de suporte tratar.

**Confirmado que a reclamação É criada com sucesso do lado da API** — testado
directamente contra `https://trocoseguro.ao/api/v1` com a conta de teste:
`POST complaints` com categoria `OTHER` devolve `201` com um registo válido
(`id`, `status: "open"`, `createdAt`, etc.). O registo existe na base de
dados; o problema é o painel administrativo não os listar/mostrar.

**Nota:** este ecrã não existe neste repositório — é do painel
administrativo web, mantido pela equipa de backend. Nenhuma acção de
código possível deste lado além de confirmar (como acima) que a API já
está a gravar os registos correctamente.

---

## 5. 💬 Pagamento de viagem via `wallet/transfer-to-user` volta com `type: "transfer"`, não distinguível de uma transferência P2P genérica

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

## 6. 💬 Pedido de negócio — dividir a taxa da plataforma entre passageiro e motorista

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
