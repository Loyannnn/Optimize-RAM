@echo off
cls
echo ============================================================
echo   RAM OPTIMIZATION WINDOWS 11 -- Version 2.0
echo   Nhan dien hang may va tat dich vu theo hang
echo   Requirement: chay voi quyen Administrator
echo ============================================================
echo.

net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [!] Administrator privileges required!
    echo     Nhan chuot PHAI vao file nay --^> Run as administrator
    echo.
    pause
    exit /b 1
)

echo [*] Successfullyng chay toi uu RAM v2.0...
echo     - Nhan dien hang may tu dong
echo     - Disable services he thong + dich vu hang
echo     - Don RAM + file rac
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Optimize-RAM-v2.ps1"

echo.
echo [XONG] Completed. Nen RESTART may de moi thay doi co hieu luc day du.
pause
