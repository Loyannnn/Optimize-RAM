# Optimize-RAM.ps1 -- Windows 11 RAM Optimizer (any RAM capacity)
# Run with: powershell -ExecutionPolicy Bypass -File Optimize-RAM.ps1
# Requirement: Administrator

# ---- Admin check ----
$ap = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $ap.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "[!] Administrator privileges required!" -ForegroundColor Red
    pause; exit
}

# ---- RAM snapshot before optimization ----
$os0      = Get-CimInstance Win32_OperatingSystem
$free0    = [math]::Round($os0.FreePhysicalMemory  / 1MB, 2)
$total    = [math]::Round($os0.TotalVisibleMemorySize / 1MB, 2)
Write-Host ""
Write-Host "  Total RAM: ${total} GB   Available: ${free0} GB" -ForegroundColor White

# ==============================================================
# STEP 1 -- XA STANDBY LIST + MODIFIED LIST (kernel cache)
# This is the largest portion: tren may 32GB Windows giu 4-8GB Standby
# Using NtSetSystemInformation with SystemMemoryListCommand
# 4 = MemoryFlushModifiedList
# 3 = MemoryPurgeStandbyList
# 1 = MemoryEmptyWorkingSets (tat ca process, khong phan biet kich co)
# ==============================================================
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  STEP 1: Clear Standby List + Kernel Cache" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$ntdllCode = @"
using System;
using System.Runtime.InteropServices;
public class NtMem {
    [DllImport("ntdll.dll")]
    public static extern uint NtSetSystemInformation(int InfoClass, IntPtr Info, int Length);
    [DllImport("kernel32.dll")]
    public static extern IntPtr GetCurrentProcess();
}
"@
if (-not ([System.Management.Automation.PSTypeName]"NtMem").Type) {
    Add-Type -TypeDefinition $ntdllCode -ErrorAction SilentlyContinue
}

# Requires SE_INCREASE_QUOTA_NAME and SE_PROFILE_SINGLE_PROCESS_NAME
# Obtained via AdjustTokenPrivileges
$privCode = @"
using System;
using System.Runtime.InteropServices;
public class TokenPriv {
    [StructLayout(LayoutKind.Sequential, Pack=1)]
    public struct TokPriv1Luid {
        public int    Count;
        public long   Luid;
        public int    Attr;
    }
    [DllImport("kernel32.dll", ExactSpelling=true)]
    public static extern IntPtr GetCurrentProcess();
    [DllImport("advapi32.dll", ExactSpelling=true, SetLastError=true)]
    public static extern bool OpenProcessToken(IntPtr h, int acc, ref IntPtr phtok);
    [DllImport("advapi32.dll", SetLastError=true)]
    public static extern bool LookupPrivilegeValue(string host, string name, ref long pluid);
    [DllImport("advapi32.dll", ExactSpelling=true, SetLastError=true)]
    public static extern bool AdjustTokenPrivileges(IntPtr htok, bool disall,
        ref TokPriv1Luid newst, int len, IntPtr prev, IntPtr relen);
    public static bool EnablePrivilege(string privilege) {
        IntPtr hproc = GetCurrentProcess();
        IntPtr htok  = IntPtr.Zero;
        if (!OpenProcessToken(hproc, 0x28, ref htok)) return false;
        TokPriv1Luid tp;
        tp.Count = 1; tp.Luid = 0; tp.Attr = 2;
        if (!LookupPrivilegeValue(null, privilege, ref tp.Luid)) return false;
        return AdjustTokenPrivileges(htok, false, ref tp, 0, IntPtr.Zero, IntPtr.Zero);
    }
}
"@
if (-not ([System.Management.Automation.PSTypeName]"TokenPriv").Type) {
    Add-Type -TypeDefinition $privCode -ErrorAction SilentlyContinue
}

# Enable privileges
[TokenPriv]::EnablePrivilege("SeIncreaseQuotaPrivilege")   | Out-Null
[TokenPriv]::EnablePrivilege("SeProfileSingleProcessPrivilege") | Out-Null

function Invoke-MemoryCommand {
    param([int]$cmd, [string]$label)
    $ptr = [System.Runtime.InteropServices.Marshal]::AllocHGlobal(4)
    [System.Runtime.InteropServices.Marshal]::WriteInt32($ptr, $cmd)
    $r = [NtMem]::NtSetSystemInformation(80, $ptr, 4)  # 80 = SystemMemoryListInformation
    [System.Runtime.InteropServices.Marshal]::FreeHGlobal($ptr)
    if ($r -eq 0) {
        Write-Host "  [OK] $label" -ForegroundColor Green
    } else {
        Write-Host ("  [WARN] $label - NTSTATUS: 0x{0:X}" -f $r) -ForegroundColor Yellow
    }
}

Invoke-MemoryCommand -cmd 4 -label "Flush Modified List (dirty state -> standby)"
Start-Sleep -Milliseconds 200
Invoke-MemoryCommand -cmd 3 -label "Purge Standby List (free kernel cache)"
Start-Sleep -Milliseconds 200
Invoke-MemoryCommand -cmd 1 -label "Empty Working Sets (all processes)"

# ==============================================================
# STEP 2 -- XA FILE SYSTEM CACHE
# SetSystemFileCacheSize: ep Windows giam vung cache file xuong
# ==============================================================
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  STEP 2: Clear File System Cache" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$cacheCode = @"
using System;
using System.Runtime.InteropServices;
public class SysCache {
    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern bool SetSystemFileCacheSize(IntPtr min, IntPtr max, int flags);
    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern bool GetSystemFileCacheSize(out IntPtr min, out IntPtr max, out int flags);
}
"@
if (-not ([System.Management.Automation.PSTypeName]"SysCache").Type) {
    Add-Type -TypeDefinition $cacheCode -ErrorAction SilentlyContinue
}

$minB = [IntPtr]::Zero
$maxB = [IntPtr]::Zero
$flg  = 0
[SysCache]::GetSystemFileCacheSize([ref]$minB, [ref]$maxB, [ref]$flg) | Out-Null
Write-Host ("  Current cache: min={0}MB  max={1}MB" -f ([long]$minB/1MB), ([long]$maxB/1MB)) -ForegroundColor White

# Set to minimum value (forces Windows to release most cache)
$r2 = [SysCache]::SetSystemFileCacheSize([IntPtr](-1), [IntPtr](-1), 0)
if ($r2) {
    Write-Host "  [OK] File system cache cleared" -ForegroundColor Green
} else {
    Write-Host "  [WARN] Unable to clear file cache (higher privileges may be required)" -ForegroundColor Yellow
}

# ==============================================================
# STEP 3 -- TRIM WORKING SET TAT CA PROCESS (no MB limit)
# FIX: Old script only trimmed processes >100MB and missed many small processes
# ==============================================================
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  STEP 3: Trim Working Set all processes" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$apiCode = @"
using System;
using System.Runtime.InteropServices;
public class MemUtil2 {
    [DllImport("psapi.dll")]    public static extern bool EmptyWorkingSet(IntPtr h);
    [DllImport("kernel32.dll")] public static extern IntPtr OpenProcess(uint acc, bool inh, int pid);
    [DllImport("kernel32.dll")] public static extern bool CloseHandle(IntPtr h);
}
"@
if (-not ([System.Management.Automation.PSTypeName]"MemUtil2").Type) {
    Add-Type -TypeDefinition $apiCode -ErrorAction SilentlyContinue
}

$skip = @("System","Idle","smss","csrss","wininit","winlogon","lsass",
          "services","Registry","Memory Compression","MsMpEng","audiodg","dwm")
$trimOK = 0; $trimSkip = 0; $freedTotal = [long]0

Get-Process -ErrorAction SilentlyContinue | Where-Object { $skip -notcontains $_.ProcessName } |
ForEach-Object {
    $pid2    = $_.Id
    $pname   = $_.ProcessName
    $ws0     = $_.WorkingSet64
    $ACCESS  = [uint32]0x1100   # SET_QUOTA | QUERY_LIMITED_INFO
    try {
        $h = [MemUtil2]::OpenProcess($ACCESS, $false, $pid2)
        if ($h -ne [IntPtr]::Zero) {
            [MemUtil2]::EmptyWorkingSet($h) | Out-Null
            [MemUtil2]::CloseHandle($h)     | Out-Null
            $procNow = Get-Process -Id $pid2 -ErrorAction SilentlyContinue
            $after   = if ($procNow) { $procNow.WorkingSet64 } else { $null }
            if ($after -ne $null) {
                $diff = [math]::Max(0, $ws0 - $after)
                $freedTotal += $diff
            }
            $trimOK++
        } else { $trimSkip++ }
    } catch { $trimSkip++ }
}

Write-Host ("  [OK] Trim completed: {0} process, skip: {1}" -f $trimOK, $trimSkip) -ForegroundColor Green
Write-Host ("  [OK] Working set released: ~{0} MB" -f [math]::Round($freedTotal/1MB,1)) -ForegroundColor Green

# ==============================================================
# STEP 4 -- TAT DICH VU KHONG CAN THIET
# ==============================================================
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  STEP 4: Disable unnecessary services" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan


$Script:ProtectedServicePatterns = @(
    "bthserv"
    "bluetoothuserservice"
    "bthavctpsvc"
    "btagservice"
    "wlan"
    "wi-fi"
    "wireless"
    "sharedaccess"
    "internet connection sharing"
    "icssvc"
    "mobile hotspot"
    "dhcp"
    "dns client"
    "dnscache"
    "netman"
    "network connection"
    "network location awareness"
    "deviceassociationservice"
    "device association"
    "rasman"
    "rasauto"
    "nlasvc"
    "network list service"
    "wcmsvc"
    "bluetooth audio gateway"
    "bthhfsrv"
    "bluetooth support service"
    "wireless lan"
    "wwansvc"
    "netprofm"
    "devicesflowusersvc"
    "cdpsvc"
    "cdpusersvc"
    "wfdsconmgrsvc"
    "devquerybroker"
    "phonesvc"

)

function Test-ProtectedService {
    param([string]$Name)
    $text = $Name.ToLowerInvariant()
    foreach ($pattern in $Script:ProtectedServicePatterns) {
        if ($text -like "*$pattern*") { return $true }
    }
    return $false
}



function Invoke-SafeStopService {
    param(
        [string]$Name
    )
    if ([string]::IsNullOrWhiteSpace($Name)) { return $false }
    if (Test-ProtectedService -Name $Name) {
        Write-Host "  [SKIP] $Name (protected core service)" -ForegroundColor DarkGray
        return $false
    }
    $svc = Get-Service -Name $Name -ErrorAction SilentlyContinue
    if ($null -eq $svc) { return $false }
    if ($svc.Status -eq "Running") {
        Stop-Service -Name $svc.Name -Force -ErrorAction SilentlyContinue
    }
    return $true
}

function Invoke-SafeSetDisabledService {
    param(
        [string]$Name
    )
    if ([string]::IsNullOrWhiteSpace($Name)) { return $false }
    if (Test-ProtectedService -Name $Name) {
        Write-Host "  [SKIP] $Name (protected core service)" -ForegroundColor DarkGray
        return $false
    }
    $svc = Get-Service -Name $Name -ErrorAction SilentlyContinue
    if ($null -eq $svc) { return $false }
    Set-Service -Name $svc.Name -StartupType Disabled -ErrorAction SilentlyContinue
    return $true
}
$svcs = @(
    "DiagTrack","dmwappushservice","WerSvc","wercplsupport",
    "MapsBroker","SysMain","WSearch",
    "XblGameSave","XboxNetApiSvc","XblAuthManager",
    "RetailDemo","wisvc","lfsvc","TapiSrv","Fax",
    "TabletInputService","WbioSrvc"
)
foreach ($s in $svcs) {
    if (Test-ProtectedService -Name $s) {
        Write-Host "  [SKIP] $s (protected core service)" -ForegroundColor DarkGray
        continue
    }
    $svc = Get-Service -Name $s -ErrorAction SilentlyContinue
    if ($null -eq $svc) { continue }
    if ($svc.Status -eq "Running") {
        Stop-Service -Name $s -Force -ErrorAction SilentlyContinue
    }
    Set-Service -Name $s -StartupType Disabled -ErrorAction SilentlyContinue
    Write-Host "  [OFF] $s" -ForegroundColor DarkGray
}

# Tat Superfetch trong registry
$pref = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters"
if (Test-Path $pref) {
    Set-ItemProperty -Path $pref -Name "EnablePrefetcher"  -Value 0 -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $pref -Name "EnableSuperfetch"  -Value 0 -ErrorAction SilentlyContinue
}
$mm = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
Set-ItemProperty -Path $mm -Name "LargeSystemCache"       -Value 0 -ErrorAction SilentlyContinue
Set-ItemProperty -Path $mm -Name "DisablePagingExecutive" -Value 1 -ErrorAction SilentlyContinue
Write-Host "  [OK] Superfetch + Memory Management registry settings disabled" -ForegroundColor Green

# ==============================================================
# STEP 5 -- DON FILE RAC
# ==============================================================
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  STEP 5: Clean junk files" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$dirs = @($env:TEMP, "C:\Windows\Temp", "C:\Windows\Prefetch")
foreach ($d in $dirs) {
    if (Test-Path $d) {
        Get-ChildItem -Path $d -ErrorAction SilentlyContinue |
            Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
        Write-Host "  [OK] Cleaned: $d" -ForegroundColor Green
    }
}
$wu = "C:\Windows\SoftwareDistribution\Download"
if (Test-Path $wu) {
    $wus = Get-Service "wuauserv" -ErrorAction SilentlyContinue
    if ($wus -and $wus.Status -eq "Running") {
        Invoke-SafeStopService -Name "wuauserv"
        Start-Sleep -Seconds 2
    }
    Get-ChildItem $wu -ErrorAction SilentlyContinue |
        Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
    Start-Service "wuauserv" -ErrorAction SilentlyContinue
    Write-Host "  [OK] Windows Update cache cleaned" -ForegroundColor Green
}

# ==============================================================
# SUMMARY
# ==============================================================
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  SUMMARY" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$os1   = Get-CimInstance Win32_OperatingSystem
$free1 = [math]::Round($os1.FreePhysicalMemory / 1MB, 2)
$used1 = [math]::Round($total - $free1, 2)
$pct1  = [math]::Round(($used1 / $total) * 100, 1)
$gain  = [math]::Round($free1 - $free0, 2)

Write-Host "  Tong RAM      : ${total} GB" -ForegroundColor White
Write-Host "  Before         : ranh ${free0} GB" -ForegroundColor DarkGray
Write-Host "  Sau           : ranh ${free1} GB" -ForegroundColor White
if ($gain -gt 0) {
    Write-Host "  Da giai phong : +${gain} GB" -ForegroundColor Green
} else {
    Write-Host "  Thay doi      : nho (kernel se tu xa them sau vai giay)" -ForegroundColor Yellow
}
$col = if ($pct1 -gt 80) { "Red" } elseif ($pct1 -gt 60) { "Yellow" } else { "Green" }
Write-Host "  Dang dung     : ${used1} GB  ($pct1 %)" -ForegroundColor $col
Write-Host ""
Write-Host "  Luu y: Restart may de service changes co hieu luc day du." -ForegroundColor Yellow
Write-Host ""
pause
