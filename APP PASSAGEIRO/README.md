# Troco Seguro - Flutter

Aplicativo de pagamento digital para táxis em Luanda, Angola - versão Flutter.

## 📱 Sobre o Projeto

Este é um aplicativo de carteira digital desenvolvido em Flutter que replica completamente as interfaces do app original em React. O Troco Seguro facilita pagamentos de corridas de táxi através de QR Code, eliminando a necessidade de troco físico.

## ✨ Funcionalidades

- **Onboarding interativo** - Apresentação do app para novos usuários
- **Autenticação segura** - Cadastro e login com PIN de 4 dígitos
- **Tela Home** - Visualização do saldo e ações rápidas
- **Scanner QR Code** - Pagamento rápido através de QR Code
- **Carteira Digital** - Gestão de saldo e transações
- **Cartões Virtuais** - Criação de cartões com limites para família
- **Histórico de Viagens** - Acompanhamento de todas as corridas
- **Perfil do Usuário** - Edição de dados pessoais e configurações

## 🚀 Como Executar

### Pré-requisitos

- Flutter SDK (>=3.0.0)
- Dart SDK
- Android Studio / VS Code
- Dispositivo Android/iOS ou Emulador

### Instalação

1. Clone o repositório:
```bash
cd flutter_troco_seguro
```

2. Instale as dependências:
```bash
flutter pub get
```

3. Execute o aplicativo:
```bash
flutter run
```

## 📂 Estrutura do Projeto

```
lib/
├── main.dart                 # Ponto de entrada e navegação principal
├── models/                   # Modelos de dados
│   ├── user.dart
│   ├── transaction.dart
│   ├── trip.dart
│   ├── virtual_card.dart
│   └── faq_item.dart
├── screens/                  # Telas do aplicativo
│   ├── onboarding_screen.dart
│   ├── auth_screen.dart
│   ├── home_screen.dart
│   ├── wallet_screen.dart
│   ├── trips_screen.dart
│   └── profile_screen.dart
├── widgets/                  # Componentes reutilizáveis
│   └── custom_widgets.dart
└── utils/                    # Utilitários e constantes
    ├── theme.dart
    └── constants.dart
```

## 🎨 Design

O aplicativo segue um design system consistente com:

- **Cores primárias**: Laranja (#FF9500)
- **Tipografia**: Inter (Black, Bold, Medium)
- **Componentes**: Cards arredondados, botões com shadow
- **Animações**: Transições suaves entre telas

## 📦 Dependências Principais

- `shared_preferences` - Persistência de dados local
- `intl` - Formatação de números e moedas
- `qr_code_scanner` - Leitura de QR Codes
- `qr_flutter` - Geração de QR Codes

## 🔐 Segurança

- Autenticação com PIN de 4 dígitos
- Armazenamento local criptografado
- Validação de transações

## 📱 Compatibilidade

- ✅ Android 5.0+
- ✅ iOS 11.0+

## 👨‍💻 Desenvolvimento

O app foi desenvolvido replicando fielmente as interfaces do projeto original em React/TypeScript, mantendo:

- Mesma estrutura de componentes
- Mesma paleta de cores e tipografia
- Mesmas funcionalidades e fluxos de navegação
- Mesma experiência de usuário

## 📄 Licença

Versão 1.0.4 • Desenvolvido para Luanda, Angola

---

**Nota**: Este é um projeto de demonstração. Para uso em produção, implemente autenticação real, integração com APIs de pagamento e criptografia adequada.
