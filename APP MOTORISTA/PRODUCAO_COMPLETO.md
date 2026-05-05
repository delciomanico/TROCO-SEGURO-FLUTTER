# 🚀 Guia Completo de Produção - Troco Seguro Motorista

## 📋 Índice
1. [Configuração do Ambiente](#configuração-do-ambiente)
2. [Preparação para Produção](#preparação-para-produção)
3. [Build e Deploy](#build-e-deploy)
4. [Publicação em Lojas](#publicação-em-lojas)
5. [Monitoramento](#monitoramento)
6. [Troubleshooting](#troubleshooting)

---

## 🔧 Configuração do Ambiente

### Pré-requisitos
- **Flutter SDK**: 3.0.0 ou superior
- **Dart SDK**: 3.0.0 ou superior
- **Android Studio**: Com Android SDK & Build Tools
- **Xcode**: (Para iOS - apenas em macOS)
- **Git**: Para controle de versão
- **Node.js**: (Opcional, para ferramentas adicionais)

### Instalação Inicial

```bash
# 1. Clonar o repositório
git clone https://github.com/seu-repo/troco-seguro-motorista.git
cd "APP MOTORISTA"

# 2. Instalar dependências
flutter clean
flutter pub get

# 3. Verificar setup
flutter doctor

# 4. (Opcional) Fazer upgrade de pacotes
flutter upgrade
```

---

## ✅ Preparação para Produção

### 1. Variaveis de Ambiente

Atualmente, as URLs são gerenciadas automaticamente:

- **Development**: `https://troco-seguro-dev.onrender.com/api/v1/`
- **Staging**: `https://troco-seguro-staging.onrender.com/api/v1/`
- **Production**: `https://troco-seguro.onrender.com/api/v1/`

O app detecta automaticamente o ambiente baseado no modo (debug/release).

### 2. Verificações de Segurança

```dart
// Verificar se está tudo seguro para produção
import 'utils/validators.dart';

final securityCheck = SecurityPolicies.validateProductionSecurity();
print(securityCheck); // ✅ Segurança validada
```

### 3. Atualizar Versão

Editar `pubspec.yaml`:
```yaml
version: 1.0.1+2  # 1.0.1 is version, 2 is build number
```

### 4. Checklists Finais

**Funcionalidades:**
- [ ] Login/Register com OTP
- [ ] Autenticação biométrica
- [ ] QR Code payment
- [ ] Histórico de transações
- [ ] Sistema de saques
- [ ] Perfil do motorista
- [ ] Ratings e avaliações

**Performance:**
- [ ] Tempo de cold start < 3s
- [ ] Nenhum jank na UI
- [ ] Memória estável
- [ ] Battery drain aceitável

**Segurança:**
- [ ] Tokens seguros
- [ ] Sem credenciais hardcoded
- [ ] SSL/TLS ativo
- [ ] Proteção de PIN

---

## 🏗️ Build e Deploy

### Build para Android

#### Opção 1: APK (para testes)
```bash
# Build APK para produção
flutter build apk --release

# Saída: build/app/outputs/flutter-apk/app-release.apk
```

#### Opção 2: App Bundle (recomendado para Play Store)
```bash
# Build App Bundle
flutter build appbundle --release

# Saída: build/app/outputs/bundle/release/app-release.aab
```

### Build para iOS

```bash
# Build iOS
flutter build ios --release

# Fazer upload de macOS
# 1. Abrir build/ios/Runner.xcworkspace em Xcode
# 2. Product > Archive
# 3. Distribuir via App Store Connect
```

### Build para Web (se necessário)
```bash
flutter build web --release
# Saída: build/web/
```

### Scripts Automatizados

**Windows (PowerShell):**
```powershell
.\scripts\build_and_deploy.ps1 -Platform android-bundle
# Opções: android, android-bundle, ios, all, all-tests
```

**macOS/Linux (Bash):**
```bash
chmod +x scripts/build_and_deploy.sh
./scripts/build_and_deploy.sh android-bundle
```

---

## 📦 Publicação em Lojas

### Google Play Store

1. **Criar Conta**
   - Ir a [Google Play Console](https://play.google.com/console)
   - Pagar taxa única de $25
   - Configurar perfil de desenvolvedor

2. **Preparar Upload**
   ```bash
   flutter build appbundle --release
   # Arquivo: build/app/outputs/bundle/release/app-release.aab
   ```

3. **Fazer Upload**
   - Play Store Console > Criar novo app
   - Preencher informações (nome, descrição, screenshots)
   - Upload do `.aab`
   - Configurar pricing e distribuição
   - Enviar para revisão

4. **Revisão e Publicação**
   - Google Play revisa em 24-48h
   - Se aprovado, aparece em Play Store
   - Se rejeitado, corrigir e reenviar

**Requisitos:**
- Política de privacidade
- Termos de serviço
- Screenshots (2-5 por idioma)
- Descrição clara
- Ícone 512x512px
- Banner de feature

### Apple App Store

1. **Criar Conta**
   - Ir a [Apple Developer](https://developer.apple.com)
   - Pagar taxa anual de $99
   - Setcar certificados

2. **Preparar Certificados**
   ```bash
   # Gerar certificados em Xcode
   # Xcode > Preferences > Accounts > Manage Certificates
   # Criar "iOS Distribution Certificate"
   ```

3. **Fazer Upload**
   - Abrir `build/ios/Runner.xcworkspace` em Xcode
   - Configurar Team ID
   - Product > Archive
   - Distribuir via App Store Connect

4. **App Store Connect**
   - Preencher informações do app
   - Upload de screenshots
   - Configurar pricing
   - Submeter para revisão

**Requisitos:**
- Certificados válidos
- Privacy Policy
- Screenshots (2-5)
- Descrição clara
- Ícone 1024x1024px

---

## 📊 Monitoramento

### Logging em Produção

```dart
import 'utils/logger.dart';
import 'utils/environment_config.dart';

// Info logs sempre visíveis
Logger.info('Usuário login bem-sucedido');

// Error logs enviados para servidor remoto
Logger.error('Falha ao processar pagamento', error);

// Debug apenas em desenvolvimento
Logger.debug('Debugging message'); // Não aparece em produção
```

### Analytics

```dart
// Integrar com Firebase Analytics (quando implementado)
// FirebaseAnalytics.instance.logEvent(
//   name: 'user_login',
//   parameters: {'method': 'otp'},
// );
```

### Crash Reporting

```dart
// Integrar com Crashlytics (quando implementado)
// FirebaseCrashlytics.instance.recordError(error, stackTrace);
```

### Métricas para Monitorar

1. **Performance**
   - Startup time
   - API response time
   - Frame rate/jank
   - Memory usage

2. **Errors**
   - Crash rate
   - API errors
   - Network timeouts
   - Authentication issues

3. **Usage**
   - DAU (Daily Active Users)
   - Session duration
   - Feature usage
   - Retention rate

---

## 🆘 Troubleshooting

### Problema: App trava ao iniciar

**Solução:**
```bash
flutter clean
flutter pub get
flutter run --release
```

### Problema: Erro 401 em produção

**Verificar:**
- Token está sendo carregado corretamente
- URL de API está correta
- Certificado SSL válido

```dart
// Debug
Logger.info('API URL: ${ApiService.baseUrl}');
Logger.debug('Token: ${_api._accessToken}');
```

### Problema: Tamanho do APK muito grande

**Solução:**
```bash
# Usar obfuscation
flutter build apk --release -obfuscate --split-debug-info build/symbols

# Ou usar App Bundle (menor)
flutter build appbundle --release
```

### Problema: Conecta mas não sincroniza

**Verificar:**
```dart
// Testar conexão
final response = await _api.getProfile();
if (response.isSuccess) {
  Logger.info('API conectado');
} else {
  Logger.error('Erro: ${response.error}');
}
```

### Problema: Biometria não funciona

**Verificar permissões no AndroidManifest.xml:**
```xml
<uses-permission android:name="android.permission.USE_BIOMETRIC" />
```

**Verificar Info.plist no iOS:**
```xml
<key>NSFaceIDUsageDescription</key>
<string>Usar Face ID para autenticação segura</string>
```

---

## 📚 Recursos Adicionais

- [Flutter Documentation](https://flutter.dev/docs)
- [Google Play Console Help](https://support.google.com/googleplay)
- [App Store Connect Help](https://help.apple.com/app-store-connect)
- [Dio HTTP Client](https://pub.dev/packages/dio)
- [Flutter Secure Storage](https://pub.dev/packages/flutter_secure_storage)

---

## 📞 Suporte

Para dúvidas ou problemas:
- 📧 Email: dev@troco-seguro.ao
- 🐛 Issues: https://github.com/seu-repo/issues
- 💬 Discord: [Link do servidor]

---

**Última atualização:** 22 de Fevereiro de 2026  
**Versão do App:** 1.0.0  
**Flutter Version:** 3.0.0+
