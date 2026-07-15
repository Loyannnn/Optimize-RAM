@echo off
setlocal EnableExtensions DisableDelayedExpansion
title Optimize RAM v5 Ultimate Edition
color 0B

rem ===================================================================
rem  Optimize RAM v5 Ultimate Edition
rem  Safe memory cleanup for Windows 7 / 8.1 / 10 / 11
rem  Launcher modes: Quick | Full | WatchdogOnly | Restore | DryRun
rem ===================================================================

set "SCRIPT_DIR=%~dp0"
set "PS1=%SCRIPT_DIR%Optimize-RAM-v5.ps1"
set "PSEXE=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
set "ORIG_ARGS=%*"
set "MODE="
set "PSVER_MAJOR="
set "PSVER_FULL="
set "WINVER="
set "EXITCODE=0"

for /f "delims=" %%A in ('ver') do set "WINVER=%%A"

if exist "%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe" (
    set "PSEXE=%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe"
)

if not exist "%PS1%" (
    echo.
    echo   +======================================================================+
    echo   ^|  Missing engine file:                                               ^|
    echo   ^|  %PS1%                                                               ^|
    echo   +======================================================================+
    echo.
    pause
    exit /b 1
)

if not "%~1"=="" (
    call :MapArg "%~1"
    if /I "%MODE%"=="HELP" goto :ShowHelp
    if not defined MODE goto :ShowHelp
)

call :ResolvePowerShell || exit /b 1
call :CheckPowerShell || exit /b 1

if not defined MODE (
    call :ShowBanner
    call :ShowMenu
)

call :RequireAdmin || exit /b 1
call :RunEngine
exit /b %EXITCODE%

:ResolvePowerShell
if exist "%PSEXE%" exit /b 0

for /f "delims=" %%P in ('where powershell.exe 2^>nul') do (
    if not defined PSEXE set "PSEXE=%%P"
)

if exist "%PSEXE%" exit /b 0

echo.
echo   +======================================================================+
echo   ^|  PowerShell was not found on this system.                            ^|
echo   ^|  Windows PowerShell 3.0 or newer is required.                       ^|
echo   +======================================================================+
echo.
pause
exit /b 1

:RequireAdmin
net session >nul 2>&1
if %errorlevel%==0 exit /b 0

echo.
echo   [!] Administrator privileges are required.
echo       Re-launching with UAC...
echo.

if "%ORIG_ARGS%"=="" (
    "%PSEXE%" -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs" >nul 2>&1
) else (
    "%PSEXE%" -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -ArgumentList '%ORIG_ARGS%' -Verb RunAs" >nul 2>&1
)

exit /b 1

:CheckPowerShell

"%PSEXE%" -NoLogo -NoProfile -Command "exit 0" >nul 2>&1

if errorlevel 1 (
    echo.
    echo ============================================================
    echo  Windows PowerShell cannot be started.
    echo ============================================================
    echo.
    pause
    exit /b 1
)

exit /b 0

:MapArg
set "ARG=%~1"
set "ARG=%ARG: =%"
set "ARG=%ARG:/=%"
set "ARG=%ARG:-=%"
set "ARG=%ARG:_=%"

if /I "%ARG%"=="Q"            (set "MODE=Quick"        & exit /b 0)
if /I "%ARG%"=="QUICK"        (set "MODE=Quick"        & exit /b 0)
if /I "%ARG%"=="F"            (set "MODE=Full"         & exit /b 0)
if /I "%ARG%"=="FULL"         (set "MODE=Full"         & exit /b 0)
if /I "%ARG%"=="W"            (set "MODE=WatchdogOnly" & exit /b 0)
if /I "%ARG%"=="WATCHDOG"     (set "MODE=WatchdogOnly" & exit /b 0)
if /I "%ARG%"=="WATCHDOGONLY" (set "MODE=WatchdogOnly" & exit /b 0)
if /I "%ARG%"=="R"            (set "MODE=Restore"      & exit /b 0)
if /I "%ARG%"=="RESTORE"      (set "MODE=Restore"      & exit /b 0)
if /I "%ARG%"=="D"            (set "MODE=DryRun"       & exit /b 0)
if /I "%ARG%"=="DRY"          (set "MODE=DryRun"       & exit /b 0)
if /I "%ARG%"=="DRYRUN"       (set "MODE=DryRun"       & exit /b 0)
if /I "%ARG%"=="?"            (set "MODE=HELP"         & exit /b 0)
if /I "%ARG%"=="H"            (set "MODE=HELP"         & exit /b 0)
if /I "%ARG%"=="HELP"         (set "MODE=HELP"         & exit /b 0)

exit /b 0

:ShowBanner
cls
echo.
echo   +==============================================================================+
echo   ^|                    OPTIMIZE RAM v5  --  ULTIMATE EDITION                  ^|
echo   ^|                Safe memory cleanup for Windows 7 / 8.1 / 10 / 11           ^|
echo   ^|                Quick / Full / WatchdogOnly / Restore / DryRun               ^|
echo   +==============================================================================+
echo.
echo   System
echo   ------
echo   Computer   : %COMPUTERNAME%
echo   Windows    : %WINVER%
echo   PowerShell : %PSVER_FULL%
echo   Folder     : %SCRIPT_DIR%
echo.
echo   Protected core services
echo   ------------------------
echo   Bluetooth ^| WLAN AutoConfig ^| Mobile Hotspot / ICS ^| DHCP ^| DNS ^| RPC ^| Plug and Play
echo.
exit /b 0

:ShowMenu
echo   Choose a mode:
echo.
echo   [F] Full         - complete optimization, watchdog and restore-safe profile
echo   [Q] Quick        - fastest cleanup only; recommended for daily use
echo   [W] WatchdogOnly  - install or refresh the watchdog task only
echo   [R] Restore       - restore previously backed-up service states
echo   [D] DryRun       - scan and print the plan without changing anything
echo.
choice /C FQWRD /T 12 /D Q /N /M "Select mode [default: Quick] "
if errorlevel 5 set "MODE=DryRun"
if errorlevel 4 set "MODE=Restore"
if errorlevel 3 set "MODE=WatchdogOnly"
if errorlevel 2 set "MODE=Quick"
if errorlevel 1 set "MODE=Full"
exit /b 0

:ShowHelp
echo.
echo   Usage:
echo     %~nx0 [quick|full|watchdog|restore|dryrun]
echo.
echo   Examples:
echo     %~nx0
echo     %~nx0 quick
echo     %~nx0 full
echo     %~nx0 restore
echo.
echo   Tip:
echo     If you are on Windows 7, install WMF 5.1 if PowerShell 3+ is missing.
echo.
pause
exit /b 1

:RunEngine
if not defined MODE set "MODE=Quick"

echo.
echo   [*] Selected mode : %MODE%
echo   [*] Launching engine...
echo.

"%PSEXE%" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%PS1%" -Mode %MODE%
set "EXITCODE=%errorlevel%"

echo.
if "%EXITCODE%"=="0" (
    echo   +==============================================================================+
    echo   ^|  Finished successfully. Check the Desktop log and HTML report.             ^|
    echo   ^|  Exit code: 0                                                              ^|
    echo   +==============================================================================+
) else (
    echo   +==============================================================================+
    echo   ^|  Finished with errors. Review the log file and try DryRun / Restore.       ^|
    echo   ^|  Exit code: %EXITCODE%                                                     ^|
    echo   +==============================================================================+
)
echo.
pause
exit /b %EXITCODE%
