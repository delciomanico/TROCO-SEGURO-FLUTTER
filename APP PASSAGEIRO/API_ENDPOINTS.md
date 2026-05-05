# TROCO SEGURO - Endpoints da API (Atualizado)

**URL Base:** `https://troco-seguro.onrender.com`  
**Documentação Swagger:** `https://troco-seguro.onrender.com/api-docs`

---

## Autenticação

### POST /auth/register
Registar novo utilizador.

**Request:**
```json
{
  "fullName": "João Passageiro",
  "phoneNumber": "+244926283434",
  "password": "000000",
  "role": "PASSENGER"
}
```
- `password`: PIN de 6 dígitos
- `role`: PASSENGER | DRIVER | ADMIN | FLEET_MANAGER (default: PASSENGER)

**Response (201):**
```json
{
  "message": "Utilizador criado com sucesso."
}
```

---

### POST /auth/verify-otp
Verificar código SMS.

**Request:**
```json
{
  "phoneNumber": "+244923456789",
  "otpCode": "123456"
}
```

**Response (200):**
```json
{
  "accessToken": "eyJhbGc...",
  "refreshToken": "eyJhbGc..."
}
```

---

### POST /auth/login
Login no sistema.

**Headers:** `user-agent: TrocoSeguroApp/1.0`

**Request:**
```json
{
  "phoneNumber": "+244926283434",
  "password": "000000"
}
```

**Response (200):**
```json
{
  "accessToken": "eyJhbGc...",
  "refreshToken": "eyJhbGc..."
}
```

---

### POST /auth/logout
Logout (invalida token).

**Headers:** `Authorization: Bearer <token>`

**Response (200):** `{}`

---

### POST /auth/refresh
Renovar token.

**Headers:** `user-agent: TrocoSeguroApp/1.0`

**Request:**
```json
{
  "refreshToken": "eyJhbGc..."
}
```

**Response (200):**
```json
{
  "accessToken": "eyJhbGc...",
  "refreshToken": "eyJhbGc..."
}
```

---

### POST /auth/verify-pin
Verificar PIN do utilizador.

**Headers:** `Authorization: Bearer <token>`

**Request:**
```json
{
  "pin": "123456"
}
```

**Response (200):**
```json
{
  "valid": true
}
```

---

### GET /auth/profile
Perfil do utilizador logado (com saldo da carteira).

**Headers:** `Authorization: Bearer <token>`

**Response (200):**
```json
{
  "id": "uuid",
  "fullName": "João Passageiro",
  "phoneNumber": "+244923456789",
  "email": "joao@email.com",
  "role": "PASSENGER",
  "wallet": {
    "balance": 15000
  }
}
```

---

## Utilizadores

### GET /users/me
Dados do utilizador logado.

**Headers:** `Authorization: Bearer <token>`

---

### PUT /users/me
Atualizar perfil.

**Request:**
```json
{
  "fullName": "João Novo Nome",
  "email": "joao@email.com"
}
```

---

### PUT /users/me/pin
Alterar PIN.

**Request:**
```json
{
  "currentPin": "123456",
  "newPin": "654321"
}
```

---

### POST /users/upload-docs
Upload de documentos (taxista).

**Content-Type:** `multipart/form-data`

**Campos:**
- `license`: Arquivo da carta de condução
- `bi`: Arquivo do BI

---

### GET /users/drivers/{id}
Detalhes do motorista.

---

## Transações Financeiras

### POST /transactions/deposit
Carregar carteira (simulação).

**Request:**
```json
{
  "amount": 5000,
  "reference": "MCX-REF-998877"
}
```

**Response (201):**
```json
{
  "message": "Saldo atualizado com sucesso.",
  "newBalance": 20000
}
```

---

### POST /transactions/transfer
Transferência P2P (pagamento de táxi).

**Request:**
```json
{
  "amount": 1500,
  "receiverId": "uuid-do-taxista",
  "description": "Pagamento Corrida Aeroporto"
}
```

**Response (201):**
```json
{
  "transactionId": "uuid",
  "amount": 1500,
  "newBalance": 18500
}
```

---

### GET /transactions/history
Extrato de transações.

**Response (200):**
```json
{
  "transactions": [
    {
      "id": "uuid",
      "type": "TRANSFER",
      "amount": -1500,
      "description": "Pagamento Corrida",
      "createdAt": "2026-01-24T18:30:00Z"
    }
  ]
}
```

---

## QR Code

### GET /qr-code/my-code
Gerar QR Code de identidade.

**Response (200):**
```json
{
  "qrCode": "data:image/png;base64,..."
}
```

---

### POST /qr-code/payment-request
Gerar QR Code de cobrança (taxista).

**Request:**
```json
{
  "amount": 2000
}
```

**Response (201):**
```json
{
  "qrCode": "data:image/png;base64,..."
}
```

---

## Pagamentos

### POST /payments/deposit/initiate
Iniciar depósito.

---

### POST /payments/webhook/simulate
Simular webhook de pagamento.

---

### GET /qrcodes/resolve?token=
Resolver um QR code ou token embutido no QR.

**Request:**
```
GET /qrcodes/resolve?token={tokenOrRawQr}
```

**Response (200):**
```json
{
  "valid": true,
  "driverId": "1a5225a9-e89b-407a-aea5-d6dd84a7e31c",
  "driverName": "Monarca",
  "amount": 2000,
  "currency": "AOA",
  "paymentToken": "eyJhbGciOiJIUzI1NiIsInR5c"
}
```

---

## Cartões Virtuais

### POST /virtual-cards
Criar cartão virtual.

**Request:**
```json
{
  "name": "Táxi Diário",
  "initialBalance": 5000,
  "dailyLimit": 10000,
  "pin": "123456"
}
```

---

### GET /virtual-cards
Listar cartões.

---

### GET /virtual-cards/{id}
Detalhes do cartão.

---

### DELETE /virtual-cards/{id}
Excluir cartão (saldo volta para carteira).

---

### POST /virtual-cards/{id}/topup
Recarregar cartão.

**Request:**
```json
{
  "amount": 5000
}
```

---

### PUT /virtual-cards/{id}/status
Congelar/ativar cartão.

**Request:**
```json
{
  "status": "frozen"
}
```
- `status`: active | frozen

---

### PUT /virtual-cards/{id}/limit
Alterar limite diário.

**Request:**
```json
{
  "dailyLimit": 20000
}
```

---

## Viagens

### GET /trips
Listar viagens.

---

### GET /trips/{id}
Detalhes da viagem.

---

## Avaliações

### POST /ratings
Avaliar utilizador.

**Request:**
```json
{
  "targetUserId": "uuid-do-taxista",
  "stars": 5,
  "comment": "Excelente condução!"
}
```
- `stars`: 1 a 5

---

### GET /ratings/{userId}
Ver avaliações de um utilizador.

---

## Segurança

### POST /safety/panic
Acionar botão de pânico.

**Request:**
```json
{
  "latitude": -8.839988,
  "longitude": 13.289437
}
```

---

## Notificações

### GET /notifications
Listar notificações.

---

### PUT /notifications/{id}/read
Marcar notificação como lida.

---

### PUT /notifications/read-all
Marcar todas como lidas.

---

## Admin (Backoffice)

### GET /admin/dashboard
Estatísticas gerais.

### GET /admin/drivers/pending
Taxistas pendentes de aprovação.

### PATCH /admin/drivers/approve/{id}
Aprovar taxista.

### GET /admin/users
Listar utilizadores.

### GET /admin/reports/transactions
Relatório de transações.

---

## FAQ

### GET /faq
Listar perguntas frequentes.

**Response (200):**
```json
{
  "items": [
    {
      "question": "Como carrego a carteira?",
      "answer": "Use o Multicaixa Express..."
    }
  ]
}
```

---

## Observações

- **Autenticação:** Bearer Token no header `Authorization`
- **Telefone:** Formato internacional `+244XXXXXXXXX`
- **PIN/Password:** 6 dígitos numéricos
- **Valores monetários:** Inteiros em Kwanzas (Kz)
- **Timeout:** 30 segundos para requisições

---

## Resumo de Endpoints

| Módulo | Quantidade |
|--------|-----------|
| Autenticação | 7 |
| Utilizadores | 5 |
| Transações | 3 |
| QR Code | 2 |
| Pagamentos | 3 |
| Cartões Virtuais | 7 |
| Viagens | 2 |
| Avaliações | 2 |
| Segurança | 1 |
| Notificações | 3 |
| Admin | 5 |
| FAQ | 1 |
| **Total** | **41** |
