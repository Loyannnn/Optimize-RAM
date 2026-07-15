@echo off
cls
echo.
echo  +==============================================================+
echo  ^|    TOI UU RAM  --  GOD MODE  v3.0                          ^|
echo  ^|    Ho tro: Windows 10 (1809+) ^& Windows 11                ^|
echo  ^|    Nhan dien hang + Tat dich vu hang + Don RAM             ^|
echo  +==============================================================+
echo.

net session >nul 2>&1
if %errorLevel% neq 0 (
    echo  [!] KHONG CO QUYEN ADMINISTRATOR!
    echo.
    echo      Cach chay dung:
    echo      Nhan CHUOT PHAI vao file nay
    echo      Chon:  Run as administrator
    echo.
    pause
    exit /b 1
)

echo  [i] Dang kiem tra phien ban Windows...
for /f "tokens=4-5 delims=. " %%i in ('ver') do set VERSION=%%i.%%j
echo  [i] Windows Version: %VERSION%
echo.

echo  [*] Bat dau toi uu RAM God Mode v3.0...
echo.
echo      Cac buoc se thuc hien:
echo      [1] Xa Standby List + Kernel Cache
echo      [2] Xa File System Cache
echo      [3] Trim Working Set toan bo tien trinh
echo      [4] Tat dich vu Windows khong can thiet
echo      [5] Tat dich vu hang may (tu dong nhan dien)
echo      [6] Scan + tat dich vu hang con sot
echo      [7] Tat Startup items + Scheduled Tasks hang
echo      [8] Toi uu Registry (Memory / Telemetry / Visual)
echo      [9] Don file rac he thong
echo      [10] Toi uu dac thu theo phien ban Win10 / Win11
echo.
echo  Bam phim bat ky de bat dau...
pause >nul

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Optimize-RAM-v3.ps1"

echo.
echo  +==============================================================+
echo  ^|  HOAN TAT  --  God Mode v3.0                               ^|
echo  ^|  Khuyen nghi: RESTART may de co hieu luc day du            ^|
echo  ^|  File LOG da luu tren Desktop                              ^|
echo  +==============================================================+
echo.
pause
