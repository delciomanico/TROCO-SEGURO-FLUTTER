# Guia de Teste - Fluxo de Pagamento

## 🧪 Testando Localmente

### Pré-requisitos
- ✅ App compilado e rodando
- ✅ Usuário autenticado
- ✅ PIN configurado
- ✅ Saldo na carteira

## 📱 Cenários de Teste

### Teste 1: Fluxo Completo de Sucesso

**Objetivo**: Validar pagamento inteiro

**Passos**:
1. Clique em "Iniciar Pagamento" (ícone de câmera)
2. Escaneia ou ingira um QR code válido:
   ```
   {"type":"PROFILE","userId":"550e8400-e29b-41d4-a716-446655440000"}
   ```
3. Veja feedback "Validando QR Code..."
4. Espere "QR Code validado com sucesso!"
5. Modal de confirmação abre com dados do taxista
6. Revise: nome do taxista, placa, avaliação, origem/destino
7. Digite seu PIN (ex: 123456)
8. Clique "CONFIRMAR"
9. Veja "Processando pagamento..."
10. Veja "Pagamento realizado com sucesso!"
11. Saldo atualiza na carteira

**Resultado Esperado**: ✅ Transação completa

---

### Teste 2: QR Code Inválido

**Objetivo**: Validar rejeição de QR inválido

**Passos**:
1. Clique em "Iniciar Pagamento"
2. Ingra um QR inválido:
   ```
   XPTO123INVALIDO
   ```
3. Veja feedback vermelho: "QR Code inválido ou expirado"
4. Scanner reabre para tentar novo

**Resultado Esperado**: ✅ Erro tratado corretamente

---

### Teste 3: PIN Incorreto

**Objetivo**: Validar rejeição de PIN

**Passos**:
1. Escaneie QR válido
2. Modal de confirmação abre
3. Digite PIN errado (ex: 000000)
4. Clique "CONFIRMAR"
5. Veja erro: "PIN inválido"
6. Tente novamente com PIN correto

**Resultado Esperado**: ✅ PIN rejeitado, transação não processada

---

### Teste 4: Cancelar Pagamento

**Objetivo**: Validar cancelamento em diferentes etapas

**Etapa 1 - Durante Scanner**:
- Clique em "FECHAR"
- Modal fecha

**Etapa 2 - Durante Confirmação**:
- Clique em "CANCELAR"
- Modal fecha, scanner não reabre

**Resultado Esperado**: ✅ Cancelamento limpo

---

### Teste 5: PIN com Diferentes Padrões

**Teste 5A - PIN com zeros**:
- PIN: 000000
- Resultado: Aceito se correto

**Teste 5B - PIN numérico sequencial**:
- PIN: 123456
- Resultado: Aceito se correto

**Teste 5C - PIN repetido**:
- PIN: 111111
- Resultado: Aceito se correto

**Resultado Esperado**: ✅ Todos os padrões funcionam

---

### Teste 6: Responsividade

**Objetivo**: Validar layout em diferentes resoluções

**Teste 6A - Celular pequeno (4")**:
- Abra em device de 4 polegadas
- Todos elementos visíveis
- Buttons clicáveis
- Texto legível

**Teste 6B - Tablet (10")**:
- Abra em tablet
- Layout se ajusta
- Espaçamento proporcional
- Teclado numérico grande

**Teste 6C - Landscape**:
- Rotacione device
- Layout se reajusta
- Sem overflow

**Resultado Esperado**: ✅ Totalmente responsivo

---

### Teste 7: Feedbacks Visuais

**Objetivo**: Validar sistema de feedback

**Feedbacks Esperados**:
- ✅ Verde: "QR Code validado com sucesso!"
- ✅ Azul: "Validando QR Code..."
- ✅ Azul: "Processando pagamento..."
- ❌ Vermelho: "QR Code inválido"
- ❌ Vermelho: "PIN inválido"
- ✅ Verde: "Pagamento realizado com sucesso!"

**Posição**: Todos no topo, acima de modais

**Duração**:
- Info: 2 seg
- Success: 3 seg
- Error: 4 seg

**Resultado Esperado**: ✅ Feedback correto em cada etapa

---

### Teste 8: Dark Mode

**Objetivo**: Validar tema escuro

**Passos**:
1. Ative modo escuro no sistema
2. Abra app
3. Abra fluxo de pagamento
4. Valide cores

**Cores Esperadas**:
- Fundo: #0F172A (dark blue)
- Texto: Branco
- Botões: Cores no tema
- Confirmação: Verde
- Erro: Vermelho

**Resultado Esperado**: ✅ Totalmente legível

---

### Teste 9: Erro de Conexão

**Objetivo**: Validar tratamento de erro de rede

**Passos**:
1. Desative WiFi/4G
2. Clique "Iniciar Pagamento"
3. Escaneie QR
4. Veja erro de conexão

**Erro Esperado**:
```
"Sem conexão com a internet."
ou
"Tempo de conexão esgotado."
```

**Resultado Esperado**: ✅ Erro tratado, user informado

---

### Teste 10: Saldo Insuficiente

**Objetivo**: Validar rejeição por saldo baixo

**Passos**:
1. Deixe saldo < 2500 Kz
2. Clique "Iniciar Pagamento"
3. Escaneie QR válido
4. Modal abre
5. Digite PIN
6. Confirme

**Erro Esperado**:
```
"Saldo insuficiente para esta transação"
```

**Resultado Esperado**: ✅ Transação rejeitada, saldo não alterado

---

## 📊 Matriz de Testes

| # | Cenário | Input | Esperado | Status |
|---|---------|-------|----------|--------|
| 1 | Sucesso completo | QR válido + PIN | Pagamento OK | 🟢 |
| 2 | QR inválido | QR ruim | Erro "inválido" | 🟢 |
| 3 | PIN errado | PIN incorreto | Erro "inválido" | 🟢 |
| 4 | Cancelar | Click em "CANCELAR" | Modal fecha | 🟢 |
| 5 | PIN padrões | Vários PINs | Todos funcionam | 🟢 |
| 6 | Responsividade | Diferentes resoluções | Layout OK | 🟢 |
| 7 | Feedbacks | Cada etapa | Feedbacks corretos | 🟢 |
| 8 | Dark mode | Sistema em dark | Cores OK | 🟢 |
| 9 | Sem internet | Connectivity off | Erro informado | 🟢 |
| 10 | Saldo baixo | Balance < 2500 | Transação recusada | 🟢 |

## 🔍 Checklist de Validação

### Validações Gerais
- [ ] App não crasha
- [ ] Sem erros de compilação
- [ ] Sem warnings significativos
- [ ] Performance boa (< 1 seg por operação)

### QR Scanner
- [ ] Scanner abre
- [ ] Camera permissão solicitada
- [ ] QR detectado corretamente
- [ ] Scanner fecha após scan

### Validação QR
- [ ] Feedback visual correto
- [ ] Dados do taxista carregam
- [ ] Avaliação exibida
- [ ] Placa exibida

### Modal de Confirmação
- [ ] Dados do taxista corretos
- [ ] Origem/destino corretos
- [ ] Valor correto (2500 Kz)
- [ ] PIN input funciona

### Teclado Numérico
- [ ] Aceita números
- [ ] Backspace funciona
- [ ] Máximo 6 dígitos
- [ ] Números ocultados com •

### Processamento
- [ ] PIN validado localmente
- [ ] API chamada corretamente
- [ ] Resposta processada
- [ ] Saldo atualizado

### Feedback Final
- [ ] Mensagem de sucesso
- [ ] Modal fecha
- [ ] Saldo visível na carteira
- [ ] UI atualizada

## 🐛 Bug Report Template

Se encontrar problemas:

```markdown
## Bug Report

**Título**: [Breve descrição]

**Severidade**: 
- 🔴 Crítico (app crasha)
- 🟠 Bloqueador (feature não funciona)
- 🟡 Importante (funciona com workaround)
- 🟢 Menor (cosmético)

**Passos para Reproduzir**:
1. [Passo 1]
2. [Passo 2]
3. [Passo 3]

**Resultado Esperado**: 
[O que deveria acontecer]

**Resultado Obtido**:
[O que realmente aconteceu]

**Screenshots**: [Anexe imagens]

**Logs**: [Cole erros do console]
```

## 📞 Suporte

Se tiver dúvidas durante os testes:

1. Revise `FLUXO_PAGAMENTO_IMPLEMENTADO.md`
2. Verifique logs no console
3. Teste em device físico (não apenas emulador)
4. Verifique conexão de internet

---

**Última Atualização**: 20 de Fevereiro de 2026
**Versão de Teste**: 1.0
