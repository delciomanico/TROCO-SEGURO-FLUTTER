# Correcções de Backend — Troco Seguro

Lista de pendências para a equipa de backend/painel administrativo,
ordenada por prioridade (mais urgente primeiro). Itens já corrigidos e
confirmados a funcionar foram removidos deste documento — consultar
`git log -- BACKEND_PENDING_CHANGES.md` para o histórico completo.

**Actualizado em 2026-08-22.**

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

## 4. 💬 API de reclamações não expõe o texto da resposta do suporte, nem liga a notificação à reclamação

**Contexto:** o utilizador reportou que reclamações submetidas no APP
PASSAGEIRO não pareciam chegar ao painel administrativo. Ao investigar,
uma reclamação de teste criada no dia anterior **já tinha sido processada**
pela equipa de suporte — o que indica que o item original está resolvido
ou nunca foi um bug real (as reclamações chegam e são processadas):

- `GET complaints` mostrou o `status` da reclamação de teste a mudar de
  `"open"` para `"in-progress"`.
- `GET notifications` tinha uma notificação nova, com o `createdAt` a
  bater exactamente com o `updatedAt` da reclamação:
  ```json
  {"title":"Resposta à sua reclamação","message":"A equipa de atendimento respondeu à sua reclamação.","type":"support_update"}
  ```

**O que falta de facto (novo, confirmado ao vivo):**
- Não existe nenhum sub-recurso para consultar o texto da resposta —
  testados `GET complaints/:id/messages`, `/replies` e `/comments`,
  todos devolvem `404 Cannot GET` (rota inexistente). `GET complaints/:id`
  só devolve `id, userId, category, reasonCode, description,
  transactionId, tripId, metadata, status, createdAt, updatedAt` — sem
  nenhum campo com o conteúdo da resposta do suporte.
- A notificação `support_update` de resposta **não inclui o ID da
  reclamação** (ao contrário da notificação de "Reclamação Recebida",
  que inclui o ID em texto simples na mensagem) — não há como ligar a
  notificação a uma reclamação específica com fiabilidade.
- Não existe `GET notifications/:id` para tentar obter mais detalhe
  (também `404`).

**Implementar:** expor o texto da resposta do suporte (ex.: campo
`responseText`/`resolutionNote` em `GET complaints/:id`, ou um
sub-recurso `GET complaints/:id/messages`) e incluir o `complaintId` no
payload da notificação `support_update`.

**No app:** como paliativo, o ecrã de reclamações do APP PASSAGEIRO já
mostra o estado (`Aberta`/`Em progresso`/`Resolvida`) devolvido pela API,
e tocar na notificação "Resposta à sua reclamação" abre directamente a
lista de reclamações (não dá para abrir a reclamação exacta, por falta
do ID na notificação). O texto da resposta em si continua por mostrar,
por não existir na API.

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

---

## 7. 🔴 [FRONTEND — App Motorista] Envio de documentos (Carta de Condução) nunca funciona — falta metade do payload que a API exige

**Reportado pelo utilizador:** no App Motorista, ecrã Perfil →
Documentos, enviar a Carta de Condução (para validar a conta e poder
efectuar transacções) não funciona. Isto **não é um bug do backend** —
confirmado ao vivo contra a API de produção com a conta de teste do
motorista QA que `POST users/upload-docs` exige, numa única submissão,
muito mais do que a app hoje envia:

- Enviando só `license` (1 ficheiro, o que a app faz hoje) →
  `400 Bad Request`:
  ```json
  {"message":"É obrigatório enviar: Carta frente (license), Carta verso (licenseBack), BI frente (bi), BI verso (biBack) e Selfie (selfie)."}
  ```
- Enviando os 5 ficheiros mas sem os números → `400 Bad Request`:
  ```json
  {"message":"Os campos biNumber e licenseNumber são obrigatórios."}
  ```
- Enviando os 5 ficheiros (`license`, `licenseBack`, `bi`, `biBack`,
  `selfie`) **e** os 2 campos de texto (`biNumber`, `licenseNumber`) na
  mesma submissão → `200 OK`, "Documentos enviados com sucesso. Aguarde
  aprovação."

**Contrato real de `POST users/upload-docs` (multipart/form-data):**
| Campo | Tipo | Descrição |
|---|---|---|
| `license` | ficheiro | Carta de Condução — frente |
| `licenseBack` | ficheiro | Carta de Condução — verso |
| `bi` | ficheiro | Bilhete de Identidade — frente |
| `biBack` | ficheiro | Bilhete de Identidade — verso |
| `selfie` | ficheiro | Selfie do motorista |
| `licenseNumber` | texto | Número da Carta de Condução |
| `biNumber` | texto | Número do Bilhete de Identidade |

Todos os 7 campos são obrigatórios na mesma submissão — não há envio
parcial/incremental.

**Gap na app hoje:** o ecrã "Documentos"
(`APP MOTORISTA/lib/main.dart`, `_showDocumentsSheet`/`_uploadLicense`)
só tira 1 foto (a carta, frente) e chama
`ApiService.uploadDocuments(license: ...)`, que só suporta os
parâmetros `license` e `bi` — faltam `licenseBack`, `biBack`, `selfie`,
`licenseNumber` e `biNumber` inteiramente. Por isto o envio falha
sempre com 400, para qualquer motorista, sem excepção. O caminho de
verificação automática do BI por QR (`verifyBiQr`, ver item mais
recente no histórico deste ficheiro) é um atalho separado e continua a
funcionar — só cobre o BI, não a Carta de Condução.

**Decisão do utilizador (2026-08-21): deixar pendente.** Requer
reconstruir o ecrã "Documentos" como um assistente de vários passos (5
fotos + 2 números, submetidos juntos) — âmbito maior do que uma
correcção pontual. Não implementado nesta ronda.

---

## 8. 🔴 `POST transactions/withdraw` rejeita sempre o levantamento via Multicaixa Express — só aceita IBAN real

**Reportado pelo utilizador:** no APP PASSAGEIRO, o levantamento por
Multicaixa Express nunca é aceite, só o levantamento por IBAN. Confirmado
ao vivo contra a API de produção com a conta de teste do passageiro QA
(o mesmo endpoint e o mesmo payload são usados por ambos os apps, o bug
não é específico do passageiro):

- Levantamento com um IBAN de exemplo mal formado →
  `400 Bad Request`: `"IBAN angolano inválido (formato ou dígito de
  verificação incorrecto). Exemplo electrónico: AO060040000012345678901
  23"`.
- Levantamento com o método "MCX Express" seleccionado, enviando o
  número de telefone (`+244900000011`) no mesmo campo `iban` (é assim
  que ambos os apps implementam este método — não há campo separado) →
  **exactamente o mesmo erro** de IBAN inválido.

Ou seja, `transactions/withdraw` valida `iban` estritamente como um
IBAN angolano real em todos os casos — não existe, hoje, nenhuma forma
de o cliente accionar um levantamento por Multicaixa Express com
sucesso.

**Implementar:** ou (a) `transactions/withdraw` aceitar um campo
`method`/`type` (`bank` vs `mcx_express`) e, quando for `mcx_express`,
validar `iban` como número de telefone em vez de IBAN; ou (b) expor um
endpoint/parâmetro dedicado para levantamento por Multicaixa Express.

**No app (2026-08-22):** como o levantamento por MCX Express nunca
completa com sucesso, a opção passou de seleccionável para desactivada
e marcada "Em desenvolvimento" em ambos os apps
(`APP PASSAGEIRO/lib/screens/wallet_screen.dart`, `_WithdrawalMethodOption`
e `APP MOTORISTA/lib/widgets/withdrawal_modal.dart`, `_MethodOption`) —
toca-se na opção e aparece um aviso a dizer para usar o levantamento por
IBAN por agora, em vez de deixar o utilizador tentar e receber o erro
confuso de "IBAN inválido". A lógica de envio por `+244...` fica no
código, pronta a reactivar-se assim que o contrato acima existir.
