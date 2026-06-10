@echo off
cls
echo.
echo  +====================================================================+
echo  ^|   RAM OPTIMIZER  --  GOD MODE  v5.0                              ^|
echo  ^|   Win7 / Win8 / Win10 / Win11  ^|  All RAM sizes                 ^|
echo  ^|   Modes: Full / Quick / WatchdogOnly / Restore / DryRun          ^|
echo  +====================================================================+
echo.

net session >nul 2>&1
if %errorLevel% neq 0 (
    echo  [!] ADMINISTRATOR REQUIRED!
    echo      RIGHT-CLICK this file -^> Run as administrator
    echo.
    pause
    exit /b 1
)

echo  [i] Checking Windows version...
for /f "tokens=4-5 delims=. " %%i in ('ver') do set VERSION=%%i.%%j
echo  [i] Windows Version: %VERSION%
echo.
echo  +--------------------------------------------------------------------+
echo  ^|  USAGE:  (default = Full mode)                                    ^|
echo  ^|                                                                    ^|
echo  ^|  Full mode      (default) : all 12 steps + watchdog + boot task   ^|
echo  ^|  Quick mode     (-Q key)  : kernel flush + trim only (~5 sec)     ^|
echo  ^|  WatchdogOnly   (-W key)  : install watchdog task only            ^|
echo  ^|  Restore        (-R key)  : re-enable services from backup        ^|
echo  ^|  DryRun         (-D key)  : scan only, NO changes                 ^|
echo  +--------------------------------------------------------------------+
echo.
echo  Press a key to select mode:
echo    [ENTER]  Full mode (default)
echo    [Q]      Quick mode
echo    [W]      WatchdogOnly
echo    [R]      Restore
echo    [D]      DryRun
echo.

set MODE=Full
choice /C QWRDEN /T 10 /D E /N /M "Select [Q/W/R/D/E(enter)]:  "
if %errorLevel%==1 set MODE=Quick
if %errorLevel%==2 set MODE=WatchdogOnly
if %errorLevel%==3 set MODE=Restore
if %errorLevel%==4 set MODE=DryRun
if %errorLevel%==5 set MODE=Full

echo.
echo  [*] Starting in mode: %MODE%
echo.
pause >nul
cls

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Optimize-RAM-v5.ps1" -Mode %MODE%
set PS_EXIT=%errorLevel%

if %PS_EXIT% neq 0 (
    echo.
    echo  [!] Error code: %PS_EXIT%
    echo  [!] Make sure Optimize-RAM-v5.ps1 is in the SAME folder as this .bat
    echo.
)

echo.
echo  +====================================================================+
echo  ^|  Done! Review results above. HTML report saved to Desktop.        ^|
echo  ^|  Press any key to close.                                          ^|
echo  +====================================================================+
pause >nul
