# Script de Build e Deploy - Troco Seguro Motorista (Windows)
# Uso: .\scripts\build_and_deploy.ps1 -Platform android

param(
    [string]$Platform = "menu"
)

# Configurações
$AppName = "Troco Seguro - Motorista"
$Version = "1.0.0"

# Cores
function Write-Header {
    param([string]$Text)
    Write-Host "========================================" -ForegroundColor Green
    Write-Host $Text -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
}

function Write-Info {
    param([string]$Text)
    Write-Host "ℹ️  $Text" -ForegroundColor Yellow
}

function Write-Success {
    param([string]$Text)
    Write-Host "✅ $Text" -ForegroundColor Green
}

function Write-Error {
    param([string]$Text)
    Write-Host "❌ $Text" -ForegroundColor Red
}

# Verificar dependências
function Test-Dependencies {
    Write-Header "Verificando dependências"
    
    $flutter = flutter --version 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Flutter não está instalado"
        exit 1
    }
    
    Write-Success "Flutter: $($flutter[0])"
}

# Limpar builds
function Invoke-CleanBuild {
    Write-Header "Limpando builds anteriores"
    
    flutter clean
    flutter pub get
    
    Write-Success "Limpeza concluída"
}

# Build Android
function Invoke-AndroidBuild {
    Write-Header "Building Android APK"
    
    flutter build apk --release
    
    $apkPath = "build\app\outputs\flutter-apk\app-release.apk"
    if (Test-Path $apkPath) {
        $apkSize = (Get-Item $apkPath).Length / 1MB
        Write-Success "APK gerado com sucesso (${apkSize:F2} MB)"
        Write-Info "Localização: $apkPath"
    } else {
        Write-Error "Falha ao gerar APK"
        exit 1
    }
}

# Build Android Bundle
function Invoke-AndroidBundleBuild {
    Write-Header "Building Android App Bundle"
    
    flutter build appbundle --release
    
    $aabPath = "build\app\outputs\bundle\release\app-release.aab"
    if (Test-Path $aabPath) {
        $aabSize = (Get-Item $aabPath).Length / 1MB
        Write-Success "App Bundle gerado com sucesso (${aabSize:F2} MB)"
        Write-Info "Localização: $aabPath"
    } else {
        Write-Error "Falha ao gerar App Bundle"
        exit 1
    }
}

# Build iOS
function Invoke-iOSBuild {
    Write-Header "Building iOS"
    
    flutter build ios --release
    
    $iosPath = "build\ios\iphoneos\Runner.app"
    if (Test-Path $iosPath) {
        Write-Success "iOS Build concluído"
        Write-Info "Localização: $iosPath"
        Write-Host ""
        Write-Info "Próximos passos no macOS:"
        Write-Host "  1. Executar Xcode"
        Write-Host "  2. Product > Archive"
        Write-Host "  3. Validate e Upload para App Store"
    } else {
        Write-Error "Falha ao gerar iOS build"
        exit 1
    }
}

# Executar testes
function Invoke-Tests {
    Write-Header "Executando testes"
    
    flutter test
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Todos os testes passaram"
    } else {
        Write-Error "Alguns testes falharam"
        exit 1
    }
}

# Menu interativo
function Show-Menu {
    Write-Host ""
    Write-Host "Selecione o tipo de build:" -ForegroundColor Cyan
    Write-Host "1) Android (APK)"
    Write-Host "2) Android (App Bundle)"
    Write-Host "3) iOS"
    Write-Host "4) Tudo"
    Write-Host "5) Tudo + Testes"
    Write-Host "0) Sair"
    Write-Host ""
}

# Script principal
function Main {
    Write-Header "🚀 Build & Deploy Script - $AppName"
    Write-Info "Versão: $Version"
    
    # Se nenhuma platform especificada, mostrar menu
    if ($Platform -eq "menu") {
        Show-Menu
        $choice = Read-Host "Opção"
        
        switch ($choice) {
            "1" { $Platform = "android" }
            "2" { $Platform = "android-bundle" }
            "3" { $Platform = "ios" }
            "4" { $Platform = "all" }
            "5" { $Platform = "all-tests" }
            "0" { exit 0 }
            default {
                Write-Error "Opção inválida"
                exit 1
            }
        }
    }
    
    # Verificar dependências
    Test-Dependencies
    
    # Perguntar se quer limpar
    $cleanChoice = Read-Host "Deseja limpar builds anteriores? (s/n)"
    if ($cleanChoice -eq "s" -or $cleanChoice -eq "S") {
        Invoke-CleanBuild
    }
    
    # Executar builds conforme pedido
    switch ($Platform) {
        "android" {
            Invoke-AndroidBuild
        }
        "android-bundle" {
            Invoke-AndroidBundleBuild
        }
        "ios" {
            Invoke-iOSBuild
        }
        "all" {
            Invoke-AndroidBundleBuild
            Write-Host ""
            Invoke-iOSBuild
        }
        "all-tests" {
            Invoke-Tests
            Write-Host ""
            Invoke-AndroidBundleBuild
            Write-Host ""
            Invoke-iOSBuild
        }
        default {
            Write-Error "Platform desconhecida: $Platform"
            exit 1
        }
    }
    
    Write-Header "✅ Build concluído com sucesso!"
    Write-Info "Próximos passos:"
    Write-Host "  1. Testar com Device/Emulator"
    Write-Host "  2. Revisar logs e performance"
    Write-Host "  3. Fazer upload para lojas (Play Store/App Store)"
}

# Executar
Main
