# Troco Seguro - App Motorista 🚗

Aplicativo Flutter para motoristas receberem pagamentos via QR Code no sistema Troco Seguro.

## 📱 Visão Geral

O **App Motorista** é o complemento do **App Passageiro**, permitindo que motoristas de táxi e transporte:
- Exibam QR Codes para receber pagamentos
- Acompanhem ganhos diários, semanais e mensais
- Solicitem saques para conta bancária ou MCX Express
- Gerenciem perfil e informações do veículo

## 🔗 Integração com App Passageiro

| App Passageiro | App Motorista |
|----------------|---------------|
| Escaneia QR Code | Exibe QR Code |
| Faz pagamentos | Recebe pagamentos |
| Cor: Laranja (#F6B415) | Cor: Verde (#2ECC71) |
| Histórico de viagens | Histórico de ganhos |

## 🎨 Design System

**Regra 60-30-10:**
- **60%** Branco/Fundo neutro
- **30%** Azul escuro (#1A3A5C)
- **10%** Verde (#2ECC71) - Cor de destaque

## 📂 Estrutura do Projeto

```
lib/
├── main.dart                 # Entry point, AppController, navegação
├── models/
│   ├── driver_user.dart      # Modelo do motorista
│   ├── passenger.dart        # Modelo do passageiro
│   ├── transaction.dart      # Modelo de transação
│   ├── trip.dart             # Modelo de viagem
│   ├── earnings.dart         # Modelo de ganhos
│   └── faq_item.dart         # Modelo de FAQ
├── screens/
│   ├── onboarding_screen.dart
│   ├── auth_screen.dart      # 4 etapas: telefone→PIN→veículo→OTP
│   ├── home_screen.dart      # Dashboard com QR Code
│   ├── earnings_screen.dart  # Acompanhamento de ganhos
│   ├── trips_screen.dart     # Histórico de viagens
│   ├── wallet_screen.dart    # Carteira e saques
│   └── profile_screen.dart   # Perfil e configurações
├── services/
│   ├── api_service.dart      # Comunicação com backend
│   ├── biometric_service.dart
│   ├── secure_storage_service.dart
│   └── theme_controller.dart
├── utils/
│   ├── constants.dart        # Cores, textos, dados mock
│   ├── theme.dart            # Temas light/dark
│   └── responsive_helper.dart
├── widgets/
│   ├── custom_widgets.dart   # Componentes reutilizáveis
│   ├── qr_display_modal.dart # Modal de exibição do QR
│   ├── withdrawal_modal.dart # Modal de saque
│   └── success_modal.dart    # Modal de sucesso
└── security/
    ├── pin_guard.dart        # Proteção contra brute force
    └── qr_generator.dart     # Gerador de QR Codes
```

## 🚀 Instalação

### Pré-requisitos
- Flutter SDK ≥ 3.0.0
- Dart SDK ≥ 3.0.0
- Android Studio / Xcode

### Passos

1. **Instalar dependências:**
```bash
cd "APP MOTORISTA"
flutter pub get
```

2. **Rodar em modo debug:**
```bash
flutter run
```

3. **Build para produção:**
```bash
# Android
flutter build apk --release

# iOS
flutter build ios --release
```

## 🔌 API Endpoints

Base URL: `https://troco-seguro.onrender.com`

| Endpoint | Método | Descrição |
|----------|--------|-----------|
| `/auth/send-otp` | POST | Enviar OTP |
| `/auth/verify-otp` | POST | Verificar OTP |
| `/drivers/profile` | GET | Obter perfil |
| `/drivers/profile` | PATCH | Atualizar perfil |
| `/drivers/status` | PATCH | Alterar status (online/offline) |
| `/drivers/earnings` | GET | Obter ganhos |
| `/wallet/balance` | GET | Obter saldo |
| `/wallet/transactions` | GET | Histórico de transações |
| `/wallet/withdraw` | POST | Solicitar saque |
| `/qr/generate` | POST | Gerar QR de pagamento |

## 🔒 Segurança

- **PIN de 6 dígitos** com proteção contra brute force
- **Biometria** (impressão digital / Face ID)
- **QR Codes** com assinatura HMAC-SHA256
- **Armazenamento seguro** via flutter_secure_storage

## 📦 Dependências

```yaml
dependencies:
  dio: ^5.9.1
  flutter_secure_storage: ^9.2.2
  local_auth: ^2.1.7
  qr_flutter: ^4.1.0
  shared_preferences: ^2.2.2
  intl: ^0.18.1
  uuid: ^4.2.1
  crypto: ^3.0.3
  share_plus: ^7.2.1
  path_provider: ^2.1.1
  screenshot: ^2.1.0
  http: ^1.1.0
```

## 🧪 Testes

```bash
# Testes unitários
flutter test

# Testes com cobertura
flutter test --coverage
```

## 📄 Licença

MIT License - Veja o arquivo LICENSE para detalhes.

## 👥 Equipe

Desenvolvido para o sistema Troco Seguro.
