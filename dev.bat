@echo off
REM Matjark Development Helper Batch Script
REM This is a simple wrapper around the PowerShell helper script

setlocal enabledelayedexpansion

if "%1"=="" (
    echo.
    echo MATJARK - Development Helper
    echo.
    echo Usage: dev.bat [command]
    echo.
    echo Commands:
    echo   dev           - Start full development environment
    echo   emulators     - Start only Firebase emulators
    echo   app           - Start only Next.js app
    echo   clean         - Kill all Node processes
    echo   admin         - Create admin account
    echo   build         - Build the app
    echo   status        - Show environment status
    echo   help          - Show this message
    echo.
    echo Examples:
    echo   dev.bat dev
    echo   dev.bat admin
    echo   dev.bat build
    echo.
    goto end
)

REM Change to the matjark directory
cd /d D:\matjark

REM Run the PowerShell helper script
powershell -NoProfile -ExecutionPolicy Bypass -Command "& '.\dev-helper.ps1' -Command '%1'"

:end
pause