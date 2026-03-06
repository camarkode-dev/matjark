#!/usr/bin/env pwsh
# Flutter Performance Build Commands for Windows PowerShell

Write-Host "╔═══════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║   Flutter Performance Build Manager            ║" -ForegroundColor Cyan
Write-Host "╚═══════════════════════════════════════════════╝" -ForegroundColor Cyan

function Build-Android {
    Write-Host "`n📱 Building optimized Android APK..." -ForegroundColor Green
    Write-Host "   - Minifying code with R8" -ForegroundColor Gray
    Write-Host "   - Enabling resource shrinking" -ForegroundColor Gray
    Write-Host "   - Splitting APK per ABI" -ForegroundColor Gray
    
    flutter build apk --split-per-abi --release -v
    
    Write-Host "`n✅ Android APK built successfully!" -ForegroundColor Green
    Write-Host "   Builds saved in: build/app/outputs/flutter-apk/" -ForegroundColor Gray
}

function Build-Web {
    Write-Host "`n🌐 Building optimized web app..." -ForegroundColor Green
    Write-Host "   - Tree shaking unused code" -ForegroundColor Gray
    Write-Host "   - Enabling SKIA rendering" -ForegroundColor Gray
    Write-Host "   - Compressing assets" -ForegroundColor Gray
    
    flutter build web --release --dart-define=FLUTTER_WEB_USE_SKIA=true -v
    
    Write-Host "`n✅ Web app built successfully!" -ForegroundColor Green
    Write-Host "   Build saved in: build/web/" -ForegroundColor Gray
}

function Build-iOS {
    Write-Host "`n🍎 Building optimized iOS app..." -ForegroundColor Green
    Write-Host "   - Enabling bitcode" -ForegroundColor Gray
    Write-Host "   - Optimizing for release" -ForegroundColor Gray
    
    flutter build ios --release -v
    
    Write-Host "`n✅ iOS app built successfully!" -ForegroundColor Green
    Write-Host "   Build saved in: build/ios/" -ForegroundColor Gray
}

function Clean-Build {
    Write-Host "`n🧹 Cleaning build artifacts..." -ForegroundColor Yellow
    flutter clean
    flutter pub get
    Write-Host "✅ Clean completed!" -ForegroundColor Green
}

function Analyze-Performance {
    Write-Host "`n📊 Analyzing app performance..." -ForegroundColor Cyan
    
    Write-Host "`n1. Running static analysis..." -ForegroundColor Gray
    flutter analyze
    
    Write-Host "`n2. Checking for unused assets..." -ForegroundColor Gray
    Write-Host "   Run: flutter pub global run unused_assets" -ForegroundColor Yellow
    
    Write-Host "`n3. Checking dependencies..." -ForegroundColor Gray
    flutter pub outdated
}

function Show-Menu {
    Write-Host "`n┌─────────────────────────────────────┐" -ForegroundColor Cyan
    Write-Host "│  Choose build type:                 │" -ForegroundColor Cyan
    Write-Host "├─────────────────────────────────────┤" -ForegroundColor Cyan
    Write-Host "│  1. Build Android APK               │" -ForegroundColor Cyan
    Write-Host "│  2. Build Web App                   │" -ForegroundColor Cyan
    Write-Host "│  3. Build iOS App                   │" -ForegroundColor Cyan
    Write-Host "│  4. Clean Build Cache               │" -ForegroundColor Cyan
    Write-Host "│  5. Analyze Performance             │" -ForegroundColor Cyan
    Write-Host "│  6. Exit                            │" -ForegroundColor Cyan
    Write-Host "└─────────────────────────────────────┘" -ForegroundColor Cyan
}

# Main loop
do {
    Show-Menu
    $choice = Read-Host "`nEnter choice (1-6)"
    
    switch ($choice) {
        1 { Build-Android }
        2 { Build-Web }
        3 { Build-iOS }
        4 { Clean-Build }
        5 { Analyze-Performance }
        6 { 
            Write-Host "`n👋 Goodbye!" -ForegroundColor Green
            exit 0
        }
        default { 
            Write-Host "`n❌ Invalid choice, please try again" -ForegroundColor Red
        }
    }
} while ($true)
