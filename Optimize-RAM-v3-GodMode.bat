@echo off
cls
echo.
echo  +==============================================================+
echo  ^|    RAM OPTIMIZER  --  GOD MODE  v3.0                       ^|
echo  ^|    Supports: Windows 10 (1809+) ^& Windows 11              ^|
echo  ^|    Brand detection + Service killer + Deep cleanup          ^|
echo  +==============================================================+
echo.

net session >nul 2>&1
if %errorLevel% neq 0 (
    echo  [!] ADMINISTRATOR REQUIRED!
    echo.
    echo      How to run correctly:
    echo      RIGHT-CLICK this file
    echo      Select:  Run as administrator
    echo.
    pause
    exit /b 1
)

echo  [i] Checking Windows version...
for /f "tokens=4-5 delims=. " %%i in ('ver') do set VERSION=%%i.%%j
echo  [i] Windows Version: %VERSION%
echo.

echo  [*] Starting RAM Optimizer God Mode v3.0...
echo.
echo      Steps that will run:
echo      [1]  Flush Standby List + Kernel Cache
echo      [2]  Flush File System Cache
echo      [3]  Trim Working Set of all processes
echo      [4]  Disable unnecessary Windows services
echo      [5]  Disable vendor services (auto brand detection)
echo      [6]  Keyword scan + disable remaining vendor services
echo      [7]  Disable vendor Startup items + Scheduled Tasks
echo      [8]  Registry tweaks: Memory / Telemetry / Visual FX
echo      [9]  Deep system junk cleanup
echo      [10] Version-specific tweaks: Win10 / Win11
echo.
echo  Press any key to start...
pause >nul

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Optimize-RAM-v3-EN.ps1"
set PS_EXIT=%errorLevel%

if %PS_EXIT% neq 0 (
    echo.
    echo  [!] Exit code: %PS_EXIT%
    echo  [!] Make sure Optimize-RAM-v3-EN.ps1 is in the SAME folder as this .bat
    echo.
)

echo.
echo  +==============================================================+
echo  ^|  DONE  --  God Mode v3.0                                   ^|
echo  ^|  Recommended: RESTART your PC for full effect              ^|
echo  ^|  LOG file saved to Desktop                                 ^|
echo  +==============================================================+
echo.
pause
