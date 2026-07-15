@echo off
cls
echo ============================================
echo   WINDOWS 11 RAM OPTIMIZER
echo   Requirement: run with Administrator privileges
echo ============================================
echo.

net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [!] Must be run as Administrator!
    echo     Right-click this file and select Run as administrator
    pause
    exit /b 1
)

echo [*] Starting RAM optimization...
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Optimize-RAM.ps1"

echo.
echo [XONG] Completed.
pause
