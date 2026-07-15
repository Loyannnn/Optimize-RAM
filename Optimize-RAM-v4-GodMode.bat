@echo off
cls
echo.
echo  +==================================================================+
echo  ^|    RAM OPTIMIZER  --  GOD MODE  v4.0                           ^|
echo  ^|    Target: Windows 10 (1809+) ^& Windows 11                     ^|
echo  ^|    8 GB RAM optimized  ^|  Persistent Watchdog Fix              ^|
echo  +==================================================================+
echo.

net session >nul 2>&1
if %errorLevel% neq 0 (
    echo  [!] Requesting administrator privileges...
    echo      ^(Windows UAC dialog will appear -- click Yes to continue^)
    echo.
    PowerShell -NoProfile -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b 0
)

echo  [i] Checking Windows version...
for /f "tokens=4-5 delims=. " %%i in ('ver') do set VERSION=%%i.%%j
echo  [i] Windows Version: %VERSION%
echo.
echo  [*] Starting RAM Optimizer God Mode v4.0...
echo.
echo  Press any key to start...
pause >nul
cls

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Optimize-RAM-v4.ps1"
set PS_EXIT=%errorLevel%

if %PS_EXIT% neq 0 (
    echo.
    echo  [!] Error code: %PS_EXIT%
    echo  [!] Make sure Optimize-RAM-v4.ps1 is in the SAME folder as this .bat
    echo.
)

echo.
echo  +==================================================================+
echo  ^|  Done! Review the results above.                                ^|
echo  ^|  Press any key to close this window.                           ^|
echo  +==================================================================+
pause >nul
