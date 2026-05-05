#!/bin/bash
# Script de Checklist Pré-Deploy
# Executar antes de fazer upload para lojas

echo "╔════════════════════════════════════════════════════════════╗"
echo "║        CHECKLIST PRÉ-DEPLOY - TROCO SEGURO MOTORISTA     ║"
echo "║                    v1.0.0+1                               ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Array para rastrear status
checks=()
results=()

# Função para adicionar check
add_check() {
    checks+=("$1")
    if [ $2 -eq 0 ]; then
        results+=("✅")
    else
        results+=("❌")
    fi
}

# VERIFICAÇÕES

echo "🔍 Executando verificações..."
echo ""

# 1. Verificar Flutter
flutter --version &>/dev/null
add_check "Flutter instalado e operacional" $?

# 2. Verificar Dart
dart --version &>/dev/null
add_check "Dart instalado e operacional" $?

# 3. Verificar dependências
if [ -f "pubspec.yaml" ]; then
    add_check "pubspec.yaml existe" 0
else
    add_check "pubspec.yaml existe" 1
fi

# 4. Verificar estrutura de pastas
if [ -d "lib" ] && [ -d "android" ] && [ -d "ios" ]; then
    add_check "Estrutura de projeto correta" 0
else
    add_check "Estrutura de projeto correta" 1
fi

# 5. Verificar utilitários de configuração
if [ -f "lib/utils/environment_config.dart" ]; then
    add_check "Environment Config implementado" 0
else
    add_check "Environment Config implementado" 1
fi

# 6. Verificar logger
if [ -f "lib/utils/logger.dart" ]; then
    add_check "Logger implementado" 0
else
    add_check "Logger implementado" 1
fi

# 7. Verificar error handler
if [ -f "lib/utils/error_handler.dart" ]; then
    add_check "Error Handler implementado" 0
else
    add_check "Error Handler implementado" 1
fi

# 8. Verificar validadores
if [ -f "lib/utils/validators.dart" ]; then
    add_check "Validadores implementados" 0
else
    add_check "Validadores implementados" 1
fi

# 9. Verificar health check
if [ -f "lib/utils/app_health_check.dart" ]; then
    add_check "Health Check implementado" 0
else
    add_check "Health Check implementado" 1
fi

# 10. Verificar main.dart
if [ -f "lib/main.dart" ]; then
    add_check "main.dart existe" 0
else
    add_check "main.dart existe" 1
fi

# 11. Verificar API Service
if [ -f "lib/services/api_service.dart" ]; then
    add_check "API Service implementado" 0
else
    add_check "API Service implementado" 1
fi

# 12. Verificar documentação
if [ -f "PRODUCAO_COMPLETO.md" ]; then
    add_check "Documentação de produção" 0
else
    add_check "Documentação de produção" 1
fi

# 13. Verificar scripts de build
if [ -f "scripts/build_and_deploy.sh" ]; then
    add_check "Build scripts criados" 0
else
    add_check "Build scripts criados" 1
fi

# 14. Verificar se há arquivo de versão
if grep -q "version: 1.0.0" pubspec.yaml 2>/dev/null; then
    add_check "Versão correta no pubspec.yaml" 0
else
    add_check "Versão correta no pubspec.yaml" 1
fi

# Mostrar resultados
echo "════════════════════════════════════════════════════════════"
echo "📋 RESULTADOS DO CHECKLIST"
echo "════════════════════════════════════════════════════════════"
echo ""

passed=0
total=${#checks[@]}

for i in "${!checks[@]}"; do
    echo "${results[$i]} ${checks[$i]}"
    if [ "${results[$i]}" == "✅" ]; then
        ((passed++))
    fi
done

echo ""
echo "════════════════════════════════════════════════════════════"
echo "Total: $passed/$total verificações passaram"
echo "════════════════════════════════════════════════════════════"
echo ""

if [ $passed -eq $total ]; then
    echo "🎉 TUDO PRONTO PARA DEPLOY!"
    echo ""
    echo "Próximas etapas:"
    echo "  1. flutter clean && flutter pub get"
    echo "  2. flutter test"
    echo "  3. ./scripts/build_and_deploy.sh android-bundle"
    echo "  4. ./scripts/build_and_deploy.sh ios"
    echo "  5. Upload para lojas"
    exit 0
else
    echo "❌ Alguns itens precisam ser corrigidos:"
    echo ""
    for i in "${!checks[@]}"; do
        if [ "${results[$i]}" == "❌" ]; then
            echo "  • ${checks[$i]}"
        fi
    done
    exit 1
fi
