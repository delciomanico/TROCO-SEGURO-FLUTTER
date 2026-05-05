#!/bin/bash

# Script de Build e Deploy - Troco Seguro Motorista
# Uso: ./scripts/build_and_deploy.sh [android|ios|web|all]

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Variáveis
APP_NAME="Troco Seguro - Motorista"
VERSION="1.0.0"

# Funções de utilidade
print_header() {
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}$1${NC}"
    echo -e "${GREEN}========================================${NC}"
}

print_info() {
    echo -e "${YELLOW}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Verificar dependências
check_dependencies() {
    print_header "Verificando dependências"
    
    if ! command -v flutter &> /dev/null; then
        print_error "Flutter não está instalado"
        exit 1
    fi
    
    print_success "Flutter: $(flutter --version | head -n 1)"
    
    if [ "$BUILD_PLATFORM" == "ios" ] || [ "$BUILD_PLATFORM" == "all" ]; then
        if ! command -v xcodebuild &> /dev/null; then
            print_error "Xcode não está instalado"
            exit 1
        fi
        print_success "Xcode instalado"
    fi
}

# Limpar builds anteriores
clean_build() {
    print_header "Limpando builds anteriores"
    flutter clean
    flutter pub get
    print_success "Limpeza concluída"
}

# Build Android
build_android() {
    print_header "Building Android APK"
    
    flutter build apk --release
    
    if [ -f "build/app/outputs/flutter-apk/app-release.apk" ]; then
        APK_SIZE=$(ls -lh build/app/outputs/flutter-apk/app-release.apk | awk '{print $5}')
        print_success "APK gerado com sucesso (${APK_SIZE})"
        echo -e "${YELLOW}Localização: build/app/outputs/flutter-apk/app-release.apk${NC}"
    else
        print_error "Falha ao gerar APK"
        exit 1
    fi
}

# Build Android Bundle (para Google Play)
build_android_bundle() {
    print_header "Building Android App Bundle"
    
    flutter build appbundle --release
    
    if [ -f "build/app/outputs/bundle/release/app-release.aab" ]; then
        AAB_SIZE=$(ls -lh build/app/outputs/bundle/release/app-release.aab | awk '{print $5}')
        print_success "App Bundle gerado com sucesso (${AAB_SIZE})"
        echo -e "${YELLOW}Localização: build/app/outputs/bundle/release/app-release.aab${NC}"
    else
        print_error "Falha ao gerar App Bundle"
        exit 1
    fi
}

# Build iOS
build_ios() {
    print_header "Building iOS"
    
    flutter build ios --release
    
    if [ -d "build/ios/iphoneos/Runner.app" ]; then
        print_success "iOS Build concluído"
        echo -e "${YELLOW}Localização: build/ios/iphoneos/${NC}"
        print_info "Use Xcode para fazer o upload para App Store:"
        echo "  1. Abrir Xcode"
        echo "  2. Product > Archive"
        echo "  3. Validate e Upload"
    else
        print_error "Falha ao gerar iOS build"
        exit 1
    fi
}

# Build Web
build_web() {
    print_header "Building Web"
    
    flutter build web --release
    
    if [ -d "build/web" ]; then
        WEB_SIZE=$(du -sh build/web | awk '{print $1}')
        print_success "Web build concluído (${WEB_SIZE})"
        echo -e "${YELLOW}Localização: build/web/${NC}"
    else
        print_error "Falha ao gerar Web build"
        exit 1
    fi
}

# Executar testes
run_tests() {
    print_header "Executando testes"
    
    if flutter test 2>/dev/null; then
        print_success "Todos os testes passaram"
    else
        print_error "Alguns testes falharam"
        exit 1
    fi
}

# Gerar relatório de cobertura
generate_coverage() {
    print_header "Gerando relatório de cobertura"
    
    flutter test --coverage
    
    if command -v lcov &> /dev/null; then
        genhtml coverage/lcov.info -o coverage/html
        print_success "Relatório de cobertura gerado em coverage/html/"
    fi
}

# Menu principal
show_menu() {
    echo ""
    echo "Selecione o tipo de build:"
    echo "1) Android (APK)"
    echo "2) Android (App Bundle)"
    echo "3) iOS"
    echo "4) Web"
    echo "5) Tudo"
    echo "6) Tudo + Testes"
    echo "0) Sair"
    echo ""
}

# Script principal
main() {
    print_header "🚀 Build & Deploy Script - ${APP_NAME}"
    print_info "Versão: ${VERSION}"
    
    BUILD_PLATFORM="${1:-menu}"
    
    # Se nenhum argumento, mostrar menu
    if [ "$BUILD_PLATFORM" == "menu" ]; then
        show_menu
        read -p "Opção: " choice
        case $choice in
            1) BUILD_PLATFORM="android" ;;
            2) BUILD_PLATFORM="android-bundle" ;;
            3) BUILD_PLATFORM="ios" ;;
            4) BUILD_PLATFORM="web" ;;
            5) BUILD_PLATFORM="all" ;;
            6) BUILD_PLATFORM="all-tests" ;;
            0) exit 0 ;;
            *) print_error "Opção inválida"; exit 1 ;;
        esac
    fi
    
    # Verificar dependências
    check_dependencies
    
    # Limpar builds
    read -p "Deseja limpar builds anteriores? (s/n): " clean_choice
    if [ "$clean_choice" == "s" ] || [ "$clean_choice" == "S" ]; then
        clean_build
    fi
    
    # Executar builds conforme pedido
    case $BUILD_PLATFORM in
        android)
            build_android
            ;;
        android-bundle)
            build_android_bundle
            ;;
        ios)
            build_ios
            ;;
        web)
            build_web
            ;;
        all)
            build_android_bundle
            build_ios
            ;;
        all-tests)
            run_tests
            build_android_bundle
            build_ios
            ;;
        *)
            print_error "Platform desconhecida: $BUILD_PLATFORM"
            exit 1
            ;;
    esac
    
    print_header "✅ Build concluído com sucesso!"
    print_info "Próximos passos:"
    echo "  1. Testar com Device/Emulator"
    echo "  2. Revisar logs e performance"
    echo "  3. Fazer upload para lojas (Play Store/App Store)"
}

# Executar script
main "$@"
