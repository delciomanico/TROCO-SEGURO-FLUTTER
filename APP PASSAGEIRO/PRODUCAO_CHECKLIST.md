# ✅ Checklist de Produção - Troco Seguro

## 🚨 **CRÍTICO - DEVE FAZER ANTES DE DEPLOY**

### 1. **Bundle IDs & Package Names** ⚠️
```
[ ] Android: Mudar de "com.example.troco_seguro" para ID real
    - Arquivo: android/app/build.gradle.kts (linha 23)
    - Padrão: com.empresa.troço_seguro ou com.troco.seguro
    
[ ] iOS: Configurar Bundle ID correto
    - Arquivo: ios/Runner.xcodeproj/project.pbxproj
    - Ou via XCode: Runner > Build Settings > Product Bundle Identifier
    - Padrão: com.empresa.trocoSeguro
```

**Impacto:** Sem isso, NÃO conseguirá publicar na Play Store / App Store

---

### 2. **Assinatura de Aplicativo (Signing)** ⚠️

#### **Android - Criar Keystore para Produção:**
```bash
# Criar chave de produção (ONE TIME ONLY)
keytool -genkey -v -keystore ~/key.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload_key

# Armazenar com segurança (Backup importante!)
# Caminho sugerido: ~/.android/troco_seguro_prod.jks
```

**Arquivo a atualizar:** `android/app/build.gradle.kts`
```kotlin
// Adicionar antes de buildTypes:
signingConfigs {
    release {
        keyAlias = "upload_key"
        keyPassword = "SUA_SENHA_AQUI"  // ⚠️ Use variáveis de ambiente em CI/CD
        storeFile = file("/caminho/para/key.jks")
        storePassword = "SENHA_STORE_AQUI"
    }
}

buildTypes {
    release {
        signingConfig = signingConfigs.release
    }
}
```

#### **iOS - Configurar Code Signing:**
```
[ ] Ir em XCode > Runner > Build Settings
[ ] Code Sign Identity: "iPhone Distribution"
[ ] Team ID: Seu Team Apple ID
[ ] Provisioning Profile: Criar em Apple Developer
[ ] Certificate: Baixar de Apple Developer Portal
```

**Impacto:** Sem assinatura, não pode publicar nem testar em device real

---

### 3. **Versioning - Aumentar para Produção**

#### **Arquivo:** `pubspec.yaml`
```yaml
# Atual:
version: 1.0.4+1

# Para produção (primeira release):
version: 1.0.0+1

# Padrão semântico: MAJOR.MINOR.PATCH+BUILD_NUMBER
# Incrementar para próximas releases:
# 1.0.1+2, 1.0.2+3, 1.1.0+4, etc
```

**iOS + Android Automático:**
- Flutter lê `version` do pubspec.yaml
- `1.0.0` = Release Version
- `+1` = Build Number

---

### 4. **Remover Métodos Não Utilizados**

#### **Arquivo:** `lib/main.dart`
- [ ] Remover método `_buildScannerModal()` (linha 537) - não é usado
- [ ] Remover método `_buildVirtualCardsModal()` (linha 589) - não é usado

**Por quê?** Código limpo = menos bugs, melhor performance, app store aceita melhor

---

### 5. **Configurar ProGuard/R8 para Android** (Obfuscação)

#### **Arquivo:** `android/app/build.gradle.kts`
```kotlin
android {
    // ... existing config
    
    buildTypes {
        release {
            signingConfig = signingConfigs.release
            
            // Adicionar obfuscação
            shrinkResources true
            minifyEnabled true
            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
        }
    }
}
```

**Benefícios:**
- Reduz tamanho APK (~30-40%)
- Obfusca código (segurança)
- Remove código não utilizado

---

### 6. **Testar Build Release Localmente**

#### **Android:**
```bash
# Build APK
flutter build apk --release

# Ou AAB (recomendado para Play Store)
flutter build appbundle --release

# Output: build/app/outputs/flutter-apk/app-release.apk
#         build/app/outputs/bundle/release/app-release.aab
```

#### **iOS:**
```bash
flutter build ios --release
# Depois em XCode: Product > Archive
```

---

## ⚠️ **IMPORTANTE - SEGURANÇA**

### 7. **Variáveis de Ambiente Sensíveis**

NÃO coloque em código:
```dart
❌ const String API_KEY = "sk_live_123456"
❌ static const String HMAC_SECRET = "meu_segredo_aqui"
```

**Fazer corretamente:**
```dart
// Usar arquivo .env (não commitar)
// Ou carregar de backend seguro
// Ou Android Keystore / iOS Keychain
```

---

### 8. **Revisão de Segurança**

- [ ] PIN armazenado em `FlutterSecureStorage` ✅ (já implementado)
- [ ] Nenhuma senha em logs/prints ✅
- [ ] QR validation com HMAC ✅ (implementado)
- [ ] Biometria optional ✅
- [ ] Rate limiting de PIN (5 tentativas) ✅

---

## 📊 **RECOMENDAÇÕES - PERFORMANCE**

### 9. **Otimizações Sugeridas**

#### **Firebase Performance Monitoring** (Opcional)
```bash
flutter pub add firebase_performance
```
- Monitorar latência de transações
- Detectar crashes em produção

#### **Sentry para Error Tracking** (Recomendado)
```bash
flutter pub add sentry_flutter
```
- Capturar erros em produção
- Rastrear sessões do usuário

#### **Análise de APK**
```bash
# Ver tamanho de APK
flutter build apk --release
# Analisar em: bundletool.dev
```

---

## 🎯 **ANTES DE PUBLICAR - TESTES**

### 10. **Testes em Device Real** ⚠️

```bash
# Conectar device físico Android
adb devices
flutter run --release -d <device_id>

# Testar cenários:
[ ] Login (criar novo usuário + PIN)
[ ] Pagamento (QR Scanner + PIN)
[ ] Transferência
[ ] Topup
[ ] Cartões Virtuais
[ ] Logout
[ ] Biometria (se device tem)
[ ] Offline (desativar WiFi/data)
[ ] Mudança de orientação (landscape/portrait)
[ ] Zoom 150-200% (accessibility)
```

---

## 📱 **PUBLICAÇÃO ANDROID**

### 11. **Play Store - Requerimentos**

```
[ ] Criar conta Google Play Console
[ ] Criar aplicação
[ ] Gerar AAB (App Bundle)
    flutter build appbundle --release
    
[ ] Upload para Internal Testing
[ ] Teste com Google Play Testers
[ ] Configurar loja (descrição, screenshots, rating)
[ ] Submeter para review
    
⏱️ Tempo de review: 2-4 horas (geralmente)
```

**App Store Listing Necessário:**
- Ícone: 512x512px
- Screenshots: 5-8 em diferentes orientações
- Descrição curta
- Descrição completa
- Palavras-chave

---

## 🍎 **PUBLICAÇÃO iOS**

### 12. **App Store - Requerimentos**

```
[ ] Conta Apple Developer ($99/ano)
[ ] Certificate de distribuição
[ ] Provisioning Profile
[ ] XCode Archive
    flutter build ios --release
    (abrir em XCode e fazer Archive)
    
[ ] Enviado via TestFlight (beta)
[ ] Configurar App Store Connect
[ ] Submeter para review
    
⏱️ Tempo de review: 1-3 dias
```

---

## 📋 **CONFIGURAÇÕES FINAIS**

### 13. **Privacy & Terms**

```
[ ] Privacy Policy URL
    - Descrever: coleta de PIN (seguro), permissões de câmera
    - Usar: privacypolicygenerator.info
    
[ ] Terms of Service
    - Responsabilidade, uso do app, refunds
    
[ ] GDPR Compliance (se tem usuários EU)
    - Direito ao esquecimento
    - Data export
```

---

### 14. **Comunicação com Backend**

Se usar API backend:
```dart
// Trocar URLs de desenvolvimento para produção
const String API_BASE = "https://api.troco-seguro.ao/v1"
// Em vez de:
// const String API_BASE = "http://localhost:8000"
```

---

## ✅ **CHECKLIST FINAL**

### Antes de Publicar:

```
[ ] ✅ Bundle ID único (Android + iOS)
[ ] ✅ Assinatura configurada (Keystore + Certificates)
[ ] ✅ Versão atualizada (1.0.0+1)
[ ] ✅ Código limpo (sem métodos mortos)
[ ] ✅ Sem logs de debug
[ ] ✅ ProGuard/R8 configurado
[ ] ✅ Build release testado localmente
[ ] ✅ Testado em device real (todos cenários)
[ ] ✅ Privacy Policy & Terms of Service
[ ] ✅ Screenshots prontos
[ ] ✅ App Store Listing completo
[ ] ✅ Backup de Keystore/Certificates (seguro!)
[ ] ✅ Plano de suporte/feedback

🚀 PRONTO PARA DEPLOY!
```

---

## 🔗 **Recursos Úteis**

- Flutter Build: https://flutter.dev/docs/deployment
- Android App Release: https://developer.android.com/studio/publish/app-signing
- iOS Distribution: https://help.apple.com/xcode/mac/current/#/dev60b3677c5f
- Google Play Console: https://play.google.com/console
- App Store Connect: https://appstoreconnect.apple.com

---

## 📞 **Suporte**

Se tiver dúvidas:
1. Consulte documentação Flutter oficial
2. Verificar Google Play Developer Docs
3. Apple Developer Support

---

**Data:** 25 de janeiro de 2026  
**Status:** 📋 Checklist Preparado  
**Próximo Passo:** Configurar Bundle IDs e Signing
