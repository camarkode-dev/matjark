# Matjark Development Helper Script
# Run this to easily manage the development environment

param(
    [string]$Command = "help"
)

function Show-Banner {
    Write-Host "╔════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║   MATJARK - Multi-Vendor Marketplace  ║" -ForegroundColor Cyan
    Write-Host "║        Development Helper Script      ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
}

function Show-Help {
    Show-Banner
    Write-Host "Available Commands:" -ForegroundColor Green
    Write-Host ""
    Write-Host "  dev              Start development environment (emulators + app)" -ForegroundColor Yellow
    Write-Host "  emulators        Start only Firebase emulators" -ForegroundColor Yellow
    Write-Host "  app              Start only Next.js app" -ForegroundColor Yellow
    Write-Host "  clean            Kill all node processes" -ForegroundColor Yellow
    Write-Host "  admin            Create admin account (interactive)" -ForegroundColor Yellow
    Write-Host "  build            Build the Next.js app" -ForegroundColor Yellow
    Write-Host "  deploy:rules     Deploy Firestore rules" -ForegroundColor Yellow
    Write-Host "  deploy:functions Deploy Cloud Functions" -ForegroundColor Yellow
    Write-Host "  logs             Show recent logs" -ForegroundColor Yellow
    Write-Host "  status           Show current status" -ForegroundColor Yellow
    Write-Host "  help             Show this help message" -ForegroundColor Yellow
    Write-Host ""
}

function Start-Dev {
    Show-Banner
    Write-Host "Starting Development Environment..." -ForegroundColor Green
    Write-Host "This will open 2 terminals:" -ForegroundColor Cyan
    Write-Host "  1. Firebase Emulators (Firestore + Auth)" -ForegroundColor Green
    Write-Host "  2. Next.js Development Server" -ForegroundColor Green
    Write-Host ""
    Write-Host "Press any key to continue..." -ForegroundColor Yellow
    Read-Host
    
    # Kill existing processes first
    Write-Host "Cleaning up existing processes..." -ForegroundColor Yellow
    Get-Process | Where-Object {$_.ProcessName -like "*node*"} | Stop-Process -Force -ErrorAction SilentlyContinue 2>$null
    Start-Sleep -Seconds 2
    
    # Start emulators in new window
    Write-Host "Starting Firebase Emulators..." -ForegroundColor Green
    Start-Process PowerShell -ArgumentList "-NoExit", "-Command", "cd D:\matjark; npx firebase emulators:start --only firestore,auth"
    
    Start-Sleep -Seconds 3
    
    # Start dev server in new window
    Write-Host "Starting Next.js Development Server..." -ForegroundColor Green
    Start-Process PowerShell -ArgumentList "-NoExit", "-Command", "cd D:\matjark\web-app; npm run dev"
    
    Write-Host ""
    Write-Host "✅ Development environment started!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Access the application:" -ForegroundColor Cyan
    Write-Host "  - App: http://localhost:3000" -ForegroundColor Yellow
    Write-Host "  - Firebase UI: http://localhost:9093" -ForegroundColor Yellow
    Write-Host ""
}

function Start-Emulators {
    Show-Banner
    Write-Host "Starting Firebase Emulators..." -ForegroundColor Green
    Write-Host ""
    
    # Kill existing processes
    Write-Host "Cleaning up existing processes..." -ForegroundColor Yellow
    Get-Process | Where-Object {$_.ProcessName -like "*node*"} | Stop-Process -Force -ErrorAction SilentlyContinue 2>$null
    Start-Sleep -Seconds 2
    
    Write-Host "Firestore: http://localhost:9090" -ForegroundColor Cyan
    Write-Host "Auth: http://localhost:9099" -ForegroundColor Cyan
    Write-Host "UI: http://localhost:9093" -ForegroundColor Cyan
    Write-Host ""
    
    cd D:\matjark
    npx firebase emulators:start --only firestore,auth
}

function Start-App {
    Show-Banner
    Write-Host "Starting Next.js Development Server..." -ForegroundColor Green
    Write-Host ""
    Write-Host "App: http://localhost:3000" -ForegroundColor Cyan
    Write-Host ""
    
    cd D:\matjark\web-app
    npm run dev
}

function Clean-Processes {
    Show-Banner
    Write-Host "Killing all Node.js processes..." -ForegroundColor Yellow
    Get-Process | Where-Object {$_.ProcessName -like "*node*"} | Stop-Process -Force -ErrorAction SilentlyContinue 2>$null
    Write-Host "✅ All processes killed!" -ForegroundColor Green
}

function Create-Admin {
    Show-Banner
    Write-Host "Creating Admin Account..." -ForegroundColor Green
    Write-Host ""
    
    # Check if service account key exists
    if (-not (Test-Path "D:\matjark\web-app\scripts\serviceAccountKey.json")) {
        Write-Host "❌ Error: serviceAccountKey.json not found!" -ForegroundColor Red
        Write-Host ""
        Write-Host "Please download it from:" -ForegroundColor Yellow
        Write-Host "  https://console.firebase.google.com/project/matjark-7ebc7/settings/serviceaccounts/adminsdk" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Save as: web-app/scripts/serviceAccountKey.json" -ForegroundColor Yellow
        Write-Host ""
        return
    }
    
    Write-Host "Enter admin details:" -ForegroundColor Cyan
    $email = Read-Host "  Email"
    $password = Read-Host "  Password"
    $name = Read-Host "  Full Name"
    
    Write-Host ""
    Write-Host "Creating admin account..." -ForegroundColor Yellow
    
    cd D:\matjark\web-app\scripts
    node create-admin.js $email $password $name
    
    Write-Host ""
    Write-Host "✅ Admin account created successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Login with:" -ForegroundColor Cyan
    Write-Host "  Email: $email" -ForegroundColor Yellow
    Write-Host "  Password: $password" -ForegroundColor Yellow
}

function Build-App {
    Show-Banner
    Write-Host "Building Next.js Application..." -ForegroundColor Green
    cd D:\matjark\web-app
    npm run build
}

function Deploy-Rules {
    Show-Banner
    Write-Host "Deploying Firestore Rules..." -ForegroundColor Green
    Write-Host ""
    Write-Host "Note: Requires Blaze Plan for production" -ForegroundColor Yellow
    Write-Host ""
    cd D:\matjark
    npx firebase deploy --only firestore:rules
}

function Deploy-Functions {
    Show-Banner
    Write-Host "Deploying Cloud Functions..." -ForegroundColor Green
    Write-Host ""
    Write-Host "Note: Requires Blaze Plan" -ForegroundColor Yellow
    Write-Host ""
    cd D:\matjark
    npx firebase deploy --only functions
}

function Show-Logs {
    Show-Banner
    Write-Host "Recent Activity:" -ForegroundColor Green
    Write-Host ""
    
    $hasProcesses = Get-Process | Where-Object {$_.ProcessName -like "*node*"} | Measure-Object | Select-Object -ExpandProperty Count
    
    if ($hasProcesses -gt 0) {
        Write-Host "✅ Node processes running:" -ForegroundColor Green
        Get-Process | Where-Object {$_.ProcessName -like "*node*"} | Format-Table -Property ProcessName, Id, WorkingSet
    } else {
        Write-Host "⚠️  No Node processes running" -ForegroundColor Yellow
    }
    
    Write-Host ""
    Write-Host "Port Status:" -ForegroundColor Green
    
    $ports = @(3000, 9090, 9093, 9099)
    foreach ($port in $ports) {
        $connection = Test-NetConnection -ComputerName localhost -Port $port -WarningAction SilentlyContinue
        if ($connection.TcpTestSucceeded) {
            Write-Host "  ✅ Port $port: Open" -ForegroundColor Green
        } else {
            Write-Host "  ❌ Port $port: Closed" -ForegroundColor Yellow
        }
    }
}

function Show-Status {
    Show-Banner
    
    Write-Host "Development Environment Status:" -ForegroundColor Cyan
    Write-Host ""
    
    # Check directories
    Write-Host "Directories:" -ForegroundColor Green
    if (Test-Path "D:\matjark\web-app") {
        Write-Host "  ✅ Next.js App" -ForegroundColor Green
    }
    if (Test-Path "D:\matjark\web-app\functions") {
        Write-Host "  ✅ Cloud Functions" -ForegroundColor Green
    }
    if (Test-Path "D:\matjark\web-app\scripts") {
        Write-Host "  ✅ Scripts" -ForegroundColor Green
    }
    
    Write-Host ""
    
    # Check files
    Write-Host "Configuration Files:" -ForegroundColor Green
    if (Test-Path "D:\matjark\firebase.json") {
        Write-Host "  ✅ firebase.json" -ForegroundColor Green
    }
    if (Test-Path "D:\matjark\web-app\.env.local") {
        Write-Host "  ✅ .env.local" -ForegroundColor Green
    }
    if (Test-Path "D:\matjark\web-app\scripts\serviceAccountKey.json") {
        Write-Host "  ✅ serviceAccountKey.json" -ForegroundColor Green
    } else {
        Write-Host "  ❌ serviceAccountKey.json (missing)" -ForegroundColor Yellow
    }
    
    Write-Host ""
    
    # Check if npm is installed
    if (Get-Command npm -ErrorAction SilentlyContinue) {
        Write-Host "Dependencies:" -ForegroundColor Green
        Write-Host "  ✅ npm installed" -ForegroundColor Green
        $nodeVersion = node -v
        Write-Host "  ✅ Node.js $nodeVersion" -ForegroundColor Green
    }
    
    Write-Host ""
}

# Main command routing
Show-Banner

switch ($Command.ToLower()) {
    "dev" { Start-Dev }
    "emulators" { Start-Emulators }
    "app" { Start-App }
    "clean" { Clean-Processes }
    "admin" { Create-Admin }
    "build" { Build-App }
    "deploy:rules" { Deploy-Rules }
    "deploy:functions" { Deploy-Functions }
    "logs" { Show-Logs }
    "status" { Show-Status }
    "help" { Show-Help }
    default { 
        Show-Help
        Write-Host "Unknown command: $Command" -ForegroundColor Red
        Write-Host "Run with 'help' parameter for available commands" -ForegroundColor Yellow
    }
}

Write-Host ""