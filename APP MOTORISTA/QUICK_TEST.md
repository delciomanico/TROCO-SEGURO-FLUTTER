# ⚡ Quick Start - Testar em Device

## 📱 Android

### Via Emulador
```bash
# 1. Verificar emuladores disponíveis
flutter emulators

# 2. Iniciar um emulador
flutter emulators --launch emulator-5554

# 3. Executar em release
flutter run --release

# 4. Executar em debug (mais rápido para dev)
flutter run
```

### Via Device Físico
```bash
# 1. Conectar USB
# 2. Habilitar "USB Debugging" nas configurações
# 3. Autorizar no prompt
# 4. Verificar conexão
flutter devices

# 5. Executar
flutter run --release
```

### Testar APK Compilado
```bash
# 1. Build APK
flutter build apk --release

# 2. Instalar em device
adb install build/app/outputs/flutter-apk/app-release.apk

# 3. Executar (opcional, já está instalado)
# Procurar na Play Store do device
```

---

## 🍎 iOS

### Via Simulador (macOS only)
```bash
# 1. Listar simuladores
open -a Simulator

# 2. Build e execute
flutter run --release
```

### Via Device Físico (macOS only)
```bash
# 1. Conectar via USB
# 2. Se pedido, "Trust" no device
# 3. Executar
flutter run --release

# 4. Ou usar Xcode
open ios/Runner.xcworkspace
# Xcode > Product > Run
```

---

## 🧪 Testar Funcionalidades

### Autenticação
```
1. Abrir app
2. Inserir número: +244912345678
3. Inserir senha: TestPass123
4. Receber SMS com OTP
5. Inserir código OTP
```

### QR Code
```
1. Na home, tocar "Gerar QR"
2. Inserir valor: 1000 AKZ
3. QR aparece na tela
4. Testar scan com outro device
```

### Saques
```
1. Ir para Carteira
2. Tocar "Sacar"
3. Inserir valor: 5000 AKZ
4. Selecionar método
5. Confirmar
```

### Biometria
```
1. Ir para Perfil
2. Configurar biometria
3. Usar face/fingerprint para confirmar
```

---

## 🔍 Debugging

### Logs
```bash
# Ver logs em tempo real
flutter logs

# Logs filtrados
flutter logs -c  # Com cores
flutter logs -t flutter  # Só Flutter
```

### Device Info
```bash
# Informações do device
flutter devices -v
```

### Performance
```bash
# Recording de performance
flutter run --profile

# Timeline (DevTools)
flutter pub global activate devtools
devtools
```

### DevTools
```bash
# Abrir DevTools
flutter pub global activate devtools
flutter pub global run devtools

# Usar com app em execução
flutter run -d <device_id>
```

---

## 📝 Checklist de Teste

- [ ] Login/OTP funciona
- [ ] Perfil carrega corretamente
- [ ] Histórico de transações aparece
- [ ] QR Code gera e lê
- [ ] Saques processam
- [ ] Biometria funciona
- [ ] Sem crashes
- [ ] Performance aceitável
- [ ] UI responsiva

---

## 🆘 Troubleshooting

### App não inicia
```bash
flutter clean
flutter pub get
flutter run
```

### Device não aparece
```bash
# Android
adb devices
adb kill-server
adb start-server

# iOS
xcrun instruments -s devices
```

### Erro de versão
```bash
flutter upgrade
flutter pub get
```

### Porta em uso
```bash
# Android
adb kill-server

# iOS
killall -9 com.apple.CoreSimulator.CoreSimulatorService
```

---

## 📊 Performance Metrics

**Verificar em DevTools:**
- Memory usage < 200MB
- Frame rate 60 FPS
- No jank/stutter
- Startup time < 3s

**Em Debug:**
- Geralmente mais lento (normal)
- Usar `--profile` para teste realista

**Em Release:**
- 2-3x mais rápido que debug
- 30-50% menor memória

---

## 💡 Dicas

1. **Sempre testar em release** antes de deploy
2. **Testar em device físico**, não apenas emulador
3. **Verificar logs** regularmente
4. **Usar Profile** para medir performance real
5. **DevTools** para profiling avançado

---

## 🚀 Próximas Etapas

✅ Testar em device
⏳ Corrigir bugs encontrados
⏳ Build final para lojas
⏳ Submit para review
⏳ Monitorar após launch

---

**Boa sorte! 🎉**
