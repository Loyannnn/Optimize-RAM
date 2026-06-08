@echo off
cls
echo.
echo  +==================================================================+
echo  ^|    RAM OPTIMIZER  --  GOD MODE  v4.0                           ^|
echo  ^|    Target: Windows 11  ^|  8 GB RAM  ^|  Persistent Fix          ^|
echo  ^|    Supports: Windows 10 (1809+) ^& Windows 11                   ^|
echo  +==================================================================+
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

echo  [*] Starting RAM Optimizer God Mode v4.0...
echo.
echo      Steps to be performed:
echo.
echo      [1]  Kernel memory flush — Standby / Modified / Working Sets
echo      [2]  File system cache flush
echo      [3]  Working Set trim — all user processes
echo      [4]  Disable unnecessary Windows services
echo      [5]  Disable brand-specific services (auto-detected)
echo      [6]  Keyword scan — leftover brand services
echo      [7]  Disable startup items + Scheduled Tasks (vendor)
echo      [8]  Registry tuning — Memory / Telemetry / Visual / TCP / Game
echo.
echo      [9]  8 GB Win11 GOD MODE fixes:
echo           - Memory Compression process throttled to IDLE priority
echo           - SwapFile.sys disabled (SSD detected)
echo           - WSL2 autoMemoryReclaim configured
echo           - SearchIndexer stopped + disabled
echo           - Defender CPU capped at 25%% + process priority lowered
echo           - Top-10 RAM consumers aggressively trimmed
echo.
echo      [10] System junk cleanup — Temp / Cache / Logs / DNS
echo      [11] Platform-specific tweaks (Win10 / Win11)
echo      [12] PERSISTENT WATCHDOG TASK — runs every 5 min automatically
echo           (This is the KEY fix for RAM bouncing back to 96%%)
echo.
echo  ----------------------------------------------------------------
echo  [i] WHAT IS NEW IN v4.0 vs v3:
echo.
echo      ROOT CAUSE identified: RAM bounced back because Windows
echo      Memory Compression + Standby List refill every 2-3 min.
echo      V4 installs a SILENT WATCHDOG TASK (SYSTEM account) that
echo      re-trims RAM automatically whenever usage exceeds 75%%.
echo      No window, no tray icon — fully background operation.
echo.
echo      Additional: SwapFile.sys killed on SSD, SessionViewSize
echo      corrected to 256 MB for 8 GB, WSL2 reclaim enabled,
echo      Defender throttled, SearchIndexer killed permanently.
echo  ----------------------------------------------------------------
echo.
echo  Press any key to start...
pause >nul

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Optimize-RAM-v4.ps1"

echo.
echo  +==================================================================+
echo  ^|  COMPLETE  --  God Mode v4.0                                    ^|
echo  ^|  Watchdog task is now ACTIVE — RAM maintained every 5 min      ^|
echo  ^|  Recommended: RESTART for registry changes to take full effect  ^|
echo  ^|  Log file saved to Desktop                                      ^|
echo  +==================================================================+
echo.
pause
