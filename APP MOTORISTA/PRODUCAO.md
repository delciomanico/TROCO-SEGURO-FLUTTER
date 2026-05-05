# Guia de Produção - Troco Seguro Motorista

## ✅ Checklist Pré-Produção

### 1. **Segurança**
- [ ] Verificar todas as credenciais (API keys, tokens)
- [ ] Usar URLs de produção confirmadas
- [ ] SSL/TLS habilitado para todas as chamadas API
- [ ] Remover dados hardcoded sensíveis
- [ ] Verificar permissões Android e iOS
- [ ] Implementar Rate Limiting
- [ ] Validar todas as entradas do usuário

### 2. **API & Backend**
- [ ] Confirmar endpoint de produção: `https://troco-seguro.onrender.com/api/v1/`
- [ ] Testar todas as rotas de autenticação
- [ ] Verificar token refresh/expiration
- [ ] Validar tratamento de erros 401/403
- [ ] Testar paginação em endpoints that support it
- [ ] Confirmar timeouts apropriados (45s em produção)

### 3. **Performance**
- [ ] Build com `--release` flag
- [ ] Obfuscation habilitada
- [ ] Tree-shaking funcionando
- [ ] Size do APK/IPA aceitável
- [ ] Testar em dispositivos low-end
- [ ] Verificar memory leaks

### 4. **Características do App**
- [ ] Autenticação com OTP funcionando
- [ ] Biometria (Face/Fingerprint) testada
- [ ] Login/Register validado
- [ ] Perfil e atualização de dados
- [ ] QR Code generation & leitura
- [ ] Histórico de transações
- [ ] Sistema de saques
- [ ] Rating de passageiros

### 5. **Testes**
- [ ] Testes unitários passando
- [ ] Testes de integração com API
- [ ] Testes no device físico (Android & iOS)
- [ ] Testar em diferentes redes (WiFi, 4G, 3G)
- [ ] Testar com conexão intermitente
- [ ] QA aceitar funcionalidades

### 6. **Build & Release**
- [ ] Versão incrementada (1.0.0+1)
- [ ] Build assinado (keystore Android)
- [ ] Provisioning profile iOS atualizado
- [ ] Screenshots e descrição na loja
- [ ] Termos de serviço & privacidade prontos
- [ ] Contactos de suporte configurados

### 7. **Monitoramento & Analytics**
- [ ] Crashlytics/Sentry configurado
- [ ] Analytics implementado
- [ ] Error logging remoto
- [ ] Dashboard de monitoramento
- [ ] Alertas para crashes configurados

### 8. **Documentação**
- [ ] README.md atualizado
- [ ] Contribuição guide criado
- [ ] API documentation finalizada
- [ ] Troubleshooting guide
- [ ] Rollback procedures documentadas

## 🚀 Comandos de Build & Deploy

### Build Android
```bash
flutter clean
flutter pub get
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk

# Ou para gerenciador de versões internas
flutter build appbundle --release
# Output: build/app/outputs/bundle/release/app-release.aab
```

### Build iOS
```bash
flutter clean
flutter pub get
flutter build ios --release
# Build disponível em build/ios/iphoneos/
# Usar Xcode para assinar e fazer upload para TestFlight/App Store
```

### Build Web (se necessário)
```bash
flutter build web --release
# Output: build/web/
```

## 🔐 Configurações Críticas de Produção

### 1. **API URL**
- ✅ Configurado em `EnvironmentConfig`
- URL: `https://troco-seguro.onrender.com/api/v1/`
- Timeout: 45 segundos

### 2. **Autenticação**
- Token refresh automático
- Secure storage para credenciais
- Biometria habilitada

### 3. **Logging**
- Logs verbose desabilitados em produção
- Apenas errors/warnings enviados para remote logger
- Crashlytics integrado

## 📊 Monitoramento Pós-Produção

Depois do deploy, monitorar:
1. Taxa de crashes
2. Latência de API
3. Taxa de erro 401/403
4. Uso de memória
5. Taxa de desistência de login
6. Performance de QR code

## 🔄 Rollback Procedure

Se encontrar problemas críticos:
1. Retirar app da loja (Google Play/App Store)
2. Voltar para versão anterior (1.0.0)
3. Investigar logs
4. Deploy hotfix com versão (1.0.1)

## 📱 Publicação em Lojas

### Google Play Store
1. Criar conta de desenvolvedor
2. Fazer upload do `.aab`
3. Configurar screenshots, descrição
4. Submeter para review (24-48h)
5. Monitorar feedback

### Apple App Store
1. Provisioning profile e certificados
2. Fazer upload via Xcode
3. Submeter para review (24-48h)
4. Configurar release notes

## 🆘 Suporte & Contacto

- Email suporte: support@troco-seguro.ao
- Telefone: +244 XXX XXX XXX
- Website: https://troco-seguro.ao

---
**Última atualização:** 2026-02-22
