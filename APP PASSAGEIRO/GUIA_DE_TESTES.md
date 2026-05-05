# 🧪 Guia de Testes - Design Responsivo Troco Seguro

## Visão Geral
Este guia fornece instruções passo a passo para testar todas as telas e componentes responsivos do aplicativo Troco Seguro em diferentes dispositivos e tamanhos de tela.

---

## 🏗️ Configuração do Ambiente

### Pré-requisitos:
- Flutter SDK instalado e configurado
- Android SDK e/ou iOS SDK
- Emulador ou dispositivo físico
- Android Studio ou VS Code com Flutter extension

### Passos iniciais:
```bash
cd flutter_troco_seguro
flutter pub get
flutter pub upgrade
flutter clean
```

---

## 📱 Testes em Android

### 1. Executar em Emulador
```bash
# Ver dispositivos disponíveis
flutter devices

# Iniciar teste em emulador padrão
flutter run

# Iniciar em emulador específico
flutter run -d emulator-5554
```

### 2. Testar em Diferentes Resoluções
**Android Studio > AVD Manager > Crie múltiplos emuladores:**

| Dispositivo | Resolução | Densidade |
|-----------|-----------|----------|
| Nexus S | 480x800 | mdpi |
| Nexus 5 | 1080x1920 | xxhdpi |
| Pixel 4a | 1080x2340 | xxhdpi |
| Pixel 6 Pro | 1440x3200 | xxxhdpi |
| Nexus 7 Tablet | 800x1280 | mdpi |
| Nexus 10 Tablet | 2560x1600 | mdpi |

### 3. Testar em Dispositivo Físico
```bash
# Conectar dispositivo via USB
adb devices

# Instalar e executar
flutter run -d <device_id>
```

---

## 🍎 Testes em iOS

### 1. Executar em Simulador
```bash
# Ver simuladores disponíveis
xcrun simctl list devices

# Abrir simulador específico
open -a Simulator --args -CurrentDeviceUDID <udid>

# Executar no simulador
flutter run -d <simulator_id>
```

### 2. Testar em Diferentes Dispositivos
**Xcode > Simulator > Device > Manage Devices:**

| Dispositivo | Resolução |
|-----------|-----------|
| iPhone SE | 375x667 |
| iPhone 13 | 390x844 |
| iPhone 14 Pro Max | 430x932 |
| iPad mini | 768x1024 |
| iPad Pro 12.9" | 1024x1366 |

### 3. Testar em Dispositivo Físico
```bash
# Conectar via USB/Wireless
flutter run -d <device_id>
```

---

## ✅ Checklist de Testes por Tela

### 1️⃣ AuthScreen (Tela de Autenticação)

#### Teste em Resolução Pequena (360x640):
- [ ] Modo seleção (Criar/Entrar) visível completo
- [ ] Títulos não cortados
- [ ] Botões não estão um sobre o outro
- [ ] Inputs têm altura adequada (48px)
- [ ] PIN display com 4 circles visíveis
- [ ] Teclado numérico cabe na tela
- [ ] Sem scroll horizontal desnecessário

#### Teste em Resolução Média (412x915):
- [ ] Todos elementos centralizados
- [ ] Espaçamento proporcional
- [ ] Inputs com boa altura
- [ ] Teclado bem distribuído

#### Teste em Tablet (768x1024):
- [ ] Diálogo não é muito estreito
- [ ] Teclado numérico tem maxWidth constraint
- [ ] Espaçamento aumentado apropriadamente
- [ ] Título com fonte maior

#### Teste em Landscape:
- [ ] Elementos não ficam fora da tela
- [ ] Scroll não é necessário para campos
- [ ] Layout se adapta bem

**Cenários de teste:**
- ✅ Entrar no modo login
- ✅ Preencher email válido
- ✅ Preencher PIN
- ✅ Mudar para modo criar conta
- ✅ Preencher dados (nome, email, PIN)

---

### 2️⃣ HomeScreen (Dashboard)

#### Teste em Resolução Pequena (360x640):
- [ ] Header com saldo visível
- [ ] Saldo não sofre overflow (no máximo 8 dígitos)
- [ ] Quick actions em 2 colunas
- [ ] Cards de driver listados corretamente
- [ ] Sem overflow horizontal

#### Teste em Resolução Média (412x915):
- [ ] Quick actions em 2 colunas bem espaçadas
- [ ] Driver cards com bom padding
- [ ] Saldo com fonte bem dimensionada

#### Teste em Tablet (768x1024):
- [ ] Quick actions em 3-4 colunas
- [ ] Mais espaçamento entre elementos
- [ ] Driver cards maior

#### Especiais:
- [ ] Saldo muito grande (99.999.999 Kz) - overflow tratado com ellipsis
- [ ] Sim com muitos drivers (scroll vertical funciona)

**Cenários de teste:**
- ✅ Carregar tela inicial
- ✅ Ver saldo atualizado
- ✅ Ver quick actions
- ✅ Scroll para ver drivers
- ✅ Scroll horizontal em quick actions

---

### 3️⃣ WalletScreen (Carteira)

#### Teste em Resolução Pequena (360x640):
- [ ] Saldo exibido sem overflow
- [ ] Filter buttons com scroll horizontal
- [ ] Transações listadas sem overflow de valores
- [ ] Cada transação cabe na tela
- [ ] Textos truncados com ellipsis se necessário

#### Teste em Resolução Média (412x915):
- [ ] Filter buttons visíveis (alguns pode ter scroll)
- [ ] Transações bem espaçadas
- [ ] Montantes monetários legíveis

#### Teste em Tablet (768x1024):
- [ ] Todos os filters visíveis sem scroll
- [ ] Transações com mais espaçamento
- [ ] Colunas de informações alinhadas

#### Especiais:
- [ ] Valor grande (99.999 Kz) - ellipsis ativado
- [ ] Muitas transações - scroll infinito
- [ ] Sem transações - mensagem vazia centralizada

**Cenários de teste:**
- ✅ Carregar carteira
- ✅ Ver saldo total
- ✅ Filtrar por tipo
- ✅ Scroll em transações
- ✅ Scroll em filtros (em tela pequena)

---

### 4️⃣ ProfileScreen (Perfil)

#### Teste em Resolução Pequena (360x640):
- [ ] Avatar dimensionado proporcionalmente
- [ ] Nome e email não estão cortados
- [ ] Settings listadas corretamente
- [ ] Sem overflow de nomes/valores
- [ ] Botão de logout visível

#### Teste em Resolução Média (412x915):
- [ ] Avatar maior proporcionalmente
- [ ] Mais espaçamento entre settings
- [ ] Texto do perfil bem legível

#### Teste em Tablet (768x1024):
- [ ] Avatar significativamente maior
- [ ] Settings com mais padding
- [ ] Card de perfil mais espaçoso

#### Especiais:
- [ ] Nome muito longo - ellipsis ativado
- [ ] Muitas settings - scroll vertical

**Cenários de teste:**
- ✅ Carregar perfil
- ✅ Ver avatar e dados
- ✅ Listar settings
- ✅ Editar perfil (se aplicável)
- ✅ Logout

---

### 5️⃣ TransferModal (Modal de Transferência)

#### Teste em Resolução Pequena (360x640):
- [ ] Modal não ultrapassa limites da tela
- [ ] Título visível
- [ ] Campos de entrada com boa altura (48px)
- [ ] Botões não estão um sobre o outro
- [ ] Scroll interno se necessário

#### Teste em Resolução Média (412x915):
- [ ] Modal bem centrado
- [ ] Campos e botões bem distribuídos
- [ ] Sem scroll desnecessário

#### Teste em Tablet (768x1024):
- [ ] Modal não ocupa a tela inteira
- [ ] maxWidth constraint ativado (500px)
- [ ] Modal centralizado
- [ ] Espaçamento aumentado

#### Especiais:
- [ ] Saldo muito grande - exibe completo ou ellipsis
- [ ] Valor de transferência incorreto - erro mostrado
- [ ] Telefone inválido - feedback visual

**Cenários de teste:**
- ✅ Abrir modal de transferência
- ✅ Preencher número de telefone
- ✅ Preencher montante
- ✅ Ver saldo atualizado
- ✅ Confirmar transferência
- ✅ Cancelar

---

### 6️⃣ PaymentModal (Modal de Pagamento)

#### Teste em Resolução Pequena (360x640):
- [ ] Ícone QR visível
- [ ] Valores de pré-visualização legíveis
- [ ] Botões (Cancelar/Confirmar) lado a lado
- [ ] PIN display com 4 circles
- [ ] Teclado numérico cabe na tela
- [ ] Scroll vertical se necessário

#### Teste em Resolução Média (412x915):
- [ ] Todos elementos bem distribuídos
- [ ] PIN display bem dimensionado
- [ ] Teclado com boa distribuição

#### Teste em Tablet (768x1024):
- [ ] Modal com maxWidth constraint
- [ ] Teclado com maxWidth também
- [ ] Espaçamento proporcional

#### Especiais:
- [ ] Valor com muitos dígitos (99.999 Kz) - ellipsis
- [ ] PIN incorreto 3x - feedback de erro
- [ ] Modo landscape

**Cenários de teste:**
- ✅ Abrir modal de pagamento
- ✅ Ver detalhes do pagamento
- ✅ Confirmar (indo para PIN)
- ✅ Digitar PIN incorreto
- ✅ Digitar PIN correto
- ✅ Cancelar

---

### 7️⃣ TopupModal (Modal de Recarga)

#### Teste em Resolução Pequena (360x640):
- [ ] Saldo atual visível
- [ ] Botões de montante em 2 colunas
- [ ] Novo saldo calculado e mostrado
- [ ] Campo de entrada customizado
- [ ] Botões (Cancelar/Recarregar) lado a lado

#### Teste em Resolução Média (412x915):
- [ ] Botões bem distribuídos
- [ ] Saldo legível
- [ ] Novo saldo em destaque

#### Teste em Tablet (768x1024):
- [ ] Modal com maxWidth
- [ ] Botões em 3 colunas
- [ ] Mais espaçamento

#### Especiais:
- [ ] Valor máximo permitido - feedback
- [ ] Valor customizado inválido - feedback
- [ ] Saldo grande (99.999.999 Kz)

**Cenários de teste:**
- ✅ Abrir modal de recarga
- ✅ Selecionar montante pré-definido
- ✅ Ver novo saldo atualizado
- ✅ Inserir montante customizado
- ✅ Confirmar recarga
- ✅ Cancelar

---

### 8️⃣ VirtualCardsModal (Modal de Cartões Virtuais)

#### Teste em Resolução Pequena (360x640):
- [ ] Título e fechar ícone visíveis
- [ ] Cards listados sem overflow
- [ ] Nomes truncados com ellipsis
- [ ] Botões de ação (deletar) acessíveis
- [ ] Botão "+ NOVO CARTÃO" visível

#### Teste em Resolução Média (412x915):
- [ ] Cards bem formatados
- [ ] Informações legíveis
- [ ] Formulário com campos bem distribuídos

#### Teste em Tablet (768x1024):
- [ ] Modal com bom tamanho
- [ ] Cards com mais espaçamento
- [ ] Formulário de criação organizado

#### Especiais:
- [ ] Nome do cartão muito longo - ellipsis
- [ ] Muitos cartões - scroll vertical
- [ ] Criar novo cartão - validação

**Cenários de teste:**
- ✅ Abrir modal de cartões virtuais
- ✅ Ver lista de cartões
- ✅ Deletar cartão
- ✅ Criar novo cartão
- ✅ Preencher formulário
- ✅ Confirmar criação

---

## 🔍 Checklist Geral de Responsividade

Para cada tela/modal, verificar:

- [ ] **Sem Overflow Horizontal**: Nenhum widget sai da tela
- [ ] **Sem Overflow Vertical Necessário**: Scroll apenas quando apropriado
- [ ] **Texto Legível**: FontSize adequado para cada dispositivo
- [ ] **Toque Fácil**: Botões com mínimo 48x48dp
- [ ] **Espaçamento**: Proporcional ao tamanho da tela
- [ ] **Imagens**: Escaladas proporcionalmente
- [ ] **Modals**: Tamanho apropriado para cada tela
- [ ] **Landscape**: Layout se adapta bem
- [ ] **Zoom/A11y**: Funciona com zoom 150-200%

---

## 🎬 Cenários de Teste Integrados

### Cenário 1: Fluxo de Login Responsivo
1. Abrir app
2. Testar em 5 tamanhos diferentes de tela
3. Preencher login em cada uma
4. Verificar layout mantém integridade

### Cenário 2: Fluxo de Transação
1. Fazer login
2. Ir para HomeScreen
3. Abrir TransferModal
4. Preencher dados
5. Confirmar (abre PaymentModal)
6. Entrar PIN
7. Completar pagamento
- **Teste em**: 360x640, 412x915, 768x1024

### Cenário 3: Teste de Tablet
1. Emular tablet 768x1024
2. Abrir cada tela
3. Verificar maxWidth constraints
4. Verificar espaçamento aumentado
5. Verificar layout não sente falta de conteúdo

### Cenário 4: Teste de Devices Reais
Se possível, testar em:
- 1 phone pequeno
- 1 phone médio
- 1 phone grande
- 1 tablet

---

## 🐛 Debugging Responsividade

### Ativar debug mode Flutter:
```bash
flutter run -v
```

### Verificar dimensões em tempo real:
```dart
// Adicionar no build method temporariamente:
print('Screen: ${MediaQuery.of(context).size}');
print('DevicePixelRatio: ${MediaQuery.of(context).devicePixelRatio}');
print('Is Mobile: ${ResponsiveHelper(context).isMobile}');
```

### Testar com acessibilidade:
- Android: Settings > Accessibility > Font size > Huge
- iOS: Settings > Display & Brightness > Text Size > Largest
- Verificar se layout se adapta

---

## 📊 Tabela de Resultados de Teste

Use esta tabela para documentar testes:

```
┌─────────────────┬────────────────┬────────────────┬────────────────┐
│ Tela/Modal      │ 360x640 (✓/✗)  │ 768x1024 (✓/✗) │ Landscape (✓/✗)│
├─────────────────┼────────────────┼────────────────┼────────────────┤
│ AuthScreen      │                │                │                │
│ HomeScreen      │                │                │                │
│ WalletScreen    │                │                │                │
│ ProfileScreen   │                │                │                │
│ TransferModal   │                │                │                │
│ PaymentModal    │                │                │                │
│ TopupModal      │                │                │                │
│ VirtualCards    │                │                │                │
└─────────────────┴────────────────┴────────────────┴────────────────┘
```

---

## 🚀 Build para Produção

### Android Release:
```bash
flutter build apk --release
flutter build appbundle --release
```

### iOS Release:
```bash
flutter build ios --release
# Depois abrir em Xcode:
open ios/Runner.xcworkspace
```

### Testar Release Builds:
```bash
flutter run --release
```

---

## 📝 Reporte de Bugs

Se encontrar problemas responsivos:

1. **Documentar:**
   - Tamanho da tela
   - Sistema operacional
   - Descrição do problema
   - Screenshot

2. **Exemplo de relatório:**
   ```
   Tela: WalletScreen
   Dispositivo: Pixel 4a (1080x2340)
   Problema: Saldo fica cortado com valores > 99.999
   Esperado: Mostrar com ellipsis ou quebra de linha
   Atual: Text overflow na direita
   ```

---

## ✨ Conclusão

Este guia completo de testes garante que todas as mudanças responsivas funcionem perfeitamente em diferentes dispositivos. Execute os testes regularmente, especialmente antes de releases.

**Sucesso! 🎉**
