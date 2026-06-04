@echo off
cls
echo ============================================
echo   TOI UU RAM WINDOWS 11
echo   Yeu cau: chay voi quyen Administrator
echo ============================================
echo.

net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [!] Can chay voi quyen Administrator!
    echo     Nhan chuot phai vao file nay, chon Run as administrator
    pause
    exit /b 1
)

echo [*] Bat dau toi uu RAM...
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Optimize-RAM.ps1"

echo.
echo [XONG] Hoan tat.
pause
