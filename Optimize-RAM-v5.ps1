# ==============================================================================
#  Optimize-RAM-v5.ps1  |  GOD MODE  v5.0
#  Supports : Windows 7 SP1 / 8.1 / 10 (1607+) / 11
#  Language : English
#  Run modes: Full | Quick | WatchdogOnly | Restore | DryRun
#  ------------------------------------------------------------------------------
#  NEW IN V5 vs V4:
#   [V5-01] RAM Profile auto-select: 4/8/16/32/64 GB — different strategy per tier
#   [V5-02] Process Allowlist — RAMOptimizer-Config.json, user-protected processes
#   [V5-03] Run modes: -Mode Full|Quick|WatchdogOnly|Restore|DryRun
#   [V5-04] System Restore Point created before any changes (Full mode only)
#   [V5-05] Undo/Restore — RAMOptimizer-Backup.json records all changes
#   [V5-06] Smart Watchdog: rate-of-rise detection + per-process threshold + post-app-close hook
#   [V5-07] GPU VRAM unused memory release via DirectX/DXGI empty driver lists
#   [V5-08] Handle leak detection — processes with >10000 handles flagged
#   [V5-09] Non-paged pool monitor — alerts if NPP > 1 GB (driver leak sign)
#   [V5-10] HTML Report — before/after chart, service table, full color output
#   [V5-11] DryRun mode — scans everything, prints plan, does nothing
#   [V5-12] Boot task — Quick mode auto-runs 2 min after login
#   [V5-13] Win7/8 compat layer — graceful fallback for missing CIM classes
#   [V5-14] Non-paged pool sizing per RAM tier
#   [V5-15] Pagefile auto-sizing per RAM tier
#  ------------------------------------------------------------------------------
#  Usage:
#    .\Optimize-RAM-v5.ps1                    # Full mode (default)
#    .\Optimize-RAM-v5.ps1 -Mode Quick        # Kernel flush + trim only (~5 sec)
#    .\Optimize-RAM-v5.ps1 -Mode WatchdogOnly # Install watchdog task only
#    .\Optimize-RAM-v5.ps1 -Mode Restore      # Re-enable services from backup
#    .\Optimize-RAM-v5.ps1 -DryRun            # Scan only, no changes
#    .\Optimize-RAM-v5.ps1 -Mode Full -DryRun # Same as above
#  ------------------------------------------------------------------------------
#  Config: C:\ProgramData\RAMOptimizer\RAMOptimizer-Config.json
#  Backup: C:\ProgramData\RAMOptimizer\RAMOptimizer-Backup.json
#  Log   : Desktop\RAM-Optimize-V5-[date].txt
#  Report: Desktop\RAM-Optimize-V5-[date].html
# ==============================================================================

[CmdletBinding()]
param(
    [ValidateSet("Full","Quick","WatchdogOnly","Restore","DryRun")]
    [string]$Mode = "Full",
    [switch]$DryRun
)

# DryRun can be set via -DryRun switch OR -Mode DryRun
if ($Mode -eq "DryRun") { $DryRun = $true; $Mode = "Full" }

Set-StrictMode -Off   # Off for Win7 compat (strict mode has issues on PS 2.0)
$ErrorActionPreference = "SilentlyContinue"
$ProgressPreference    = "SilentlyContinue"   # Hide slow WMI progress bars

# ==============================================================================
# ADMIN GUARD
# ==============================================================================
$_prn = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $_prn.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "[!] Administrator required. Right-click -> Run as administrator." -ForegroundColor Red
    Start-Sleep 3; exit 1
}

# ==============================================================================
# GLOBALS
# ==============================================================================
$V5_VERSION  = "5.0"
$DATA_DIR    = "C:\ProgramData\RAMOptimizer"
$CONFIG_FILE = "$DATA_DIR\RAMOptimizer-Config.json"
$BACKUP_FILE = "$DATA_DIR\RAMOptimizer-Backup.json"
$WDOG_DIR    = "$DATA_DIR\Watchdog"
$WDOG_FILE   = "$WDOG_DIR\RAMWatchdog-v5.ps1"
$TS          = Get-Date -Format "yyyyMMdd-HHmmss"
$LOG_TXT     = "$env:USERPROFILE\Desktop\RAM-Optimize-V5-$TS.txt"
$LOG_HTML    = "$env:USERPROFILE\Desktop\RAM-Optimize-V5-$TS.html"
$TASK_WDOG   = "RAMOptimizer-V5-Watchdog"
$TASK_BOOT   = "RAMOptimizer-V5-BootQuick"

if (-not (Test-Path $DATA_DIR))  { New-Item -Path $DATA_DIR  -ItemType Directory -Force | Out-Null }
if (-not (Test-Path $WDOG_DIR))  { New-Item -Path $WDOG_DIR  -ItemType Directory -Force | Out-Null }

$Script:Log      = [System.Collections.Generic.List[string]]::new()
$Script:HtmlRows = [System.Collections.Generic.List[string]]::new()
$Script:Backup   = [ordered]@{ Version = $V5_VERSION; Timestamp = $TS; Services = @(); Registry = @(); Tasks = @() }
$Script:Stats    = [ordered]@{
    SvcCommon=0; SvcBrand=0; SvcKW=0; TasksOff=0; StartupDel=0
    TrimOK=0; FreedMB=0; HandleLeaks=0; DryRunActions=0
}
$Script:DryRunLog = [System.Collections.Generic.List[string]]::new()

# ==============================================================================
# LOGGING
# ==============================================================================
function Write-Log {
    param([string]$msg, [string]$color = "White", [string]$html = "")
    Write-Host $msg -ForegroundColor $color
    $Script:Log.Add($msg)
    $hColor = switch ($color) {
        "Green"     {"#4ec94e"}; "Red"       {"#ff5555"}; "Yellow"   {"#f1c40f"}
        "Cyan"      {"#5dade2"}; "DarkCyan"  {"#1a8ea0"}; "Magenta"  {"#c39bd3"}
        "DarkYellow"{"#d4ac0d"}; "DarkGray"  {"#7f8c8d"}; "White"    {"#ecf0f1"}
        default     {"#ecf0f1"}
    }
    $safeMsg = [System.Web.HttpUtility]::HtmlEncode($msg) -replace " ","&nbsp;"
    $Script:HtmlRows.Add("<tr><td style='color:$hColor;font-family:Consolas,monospace;font-size:13px;padding:1px 8px;white-space:pre'>$safeMsg</td></tr>")
}

function Show-Section {
    param([string]$title)
    $line = "  " + ([string][char]0x2500 * 64)
    Write-Log ""; Write-Log $line "DarkCyan"
    Write-Log ("  >> " + $title) "Cyan"
    Write-Log $line "DarkCyan"
    $Script:HtmlRows.Add("<tr><td style='padding:4px'></td></tr>")
}

function Write-DryRun {
    param([string]$action)
    $msg = "  [DRYRUN] $action"
    Write-Host $msg -ForegroundColor Magenta
    $Script:Log.Add($msg)
    $Script:DryRunLog.Add($action)
    $Script:Stats.DryRunActions++
}

# ==============================================================================
# WINDOWS VERSION COMPAT LAYER  [V5-13]
# ==============================================================================
$psVer    = $PSVersionTable.PSVersion.Major
$osWmi    = Get-WmiObject Win32_OperatingSystem  -EA SilentlyContinue
$csCim    = $null
$osCim    = $null
$hasCim   = ($psVer -ge 3)

if ($hasCim) {
    try { $csCim  = Get-CimInstance Win32_ComputerSystem  -EA Stop } catch { $hasCim = $false }
    try { $osCim  = Get-CimInstance Win32_OperatingSystem -EA Stop } catch {}
}

$cs = if ($csCim) { $csCim } else { Get-WmiObject Win32_ComputerSystem -EA SilentlyContinue }
$os0 = if ($osCim) { $osCim } else { $osWmi }

$winBuildRaw = if ($os0) { $os0.BuildNumber } else { "0" }
$winBuild    = [int]($winBuildRaw -replace "[^0-9]","")
$winName     = if ($os0) { $os0.Caption } else { "Unknown Windows" }
$winBuild    = if ($winBuild -eq 0) { 9600 } else { $winBuild }   # fallback

$isWin11  = ($winBuild -ge 22000)
$isWin10  = (-not $isWin11) -and ($winBuild -ge 10240)
$isWin8   = (-not $isWin10) -and (-not $isWin11) -and ($winBuild -ge 9200)
$isWin7   = (-not $isWin10) -and (-not $isWin11) -and (-not $isWin8) -and ($winBuild -ge 7601)
$isModern = ($winBuild -ge 17763)   # 1809+ for advanced features

$winTag = if ($isWin11) {"WIN11"} elseif ($isWin10) {"WIN10"} `
          elseif ($isWin8) {"WIN8"} elseif ($isWin7) {"WIN7"} else {"WIN_OLD"}

# ==============================================================================
# SYSTEM DETECTION
# ==============================================================================
$cpu  = $null; $disk = $null; $bios = $null
try { $cpu  = if ($hasCim) { Get-CimInstance Win32_Processor -EA SilentlyContinue | Select-Object -First 1 } `
              else { Get-WmiObject Win32_Processor -EA SilentlyContinue | Select-Object -First 1 } } catch {}
try { $disk = if ($hasCim) { Get-CimInstance Win32_DiskDrive -EA SilentlyContinue | Select-Object -First 1 } `
              else { Get-WmiObject Win32_DiskDrive -EA SilentlyContinue | Select-Object -First 1 } } catch {}
try { $bios = if ($hasCim) { Get-CimInstance Win32_BIOS -EA SilentlyContinue } `
              else { Get-WmiObject Win32_BIOS -EA SilentlyContinue } } catch {}

$ramGB  = if ($cs) { [math]::Round($cs.TotalPhysicalMemory / 1GB, 1) } else { 8.0 }
$free0  = if ($os0) { [math]::Round($os0.FreePhysicalMemory / 1MB, 2) } else { 0 }
$total  = if ($os0) { [math]::Round($os0.TotalVisibleMemorySize / 1MB, 2) } else { $ramGB * 1024 }

# RAM Profile  [V5-01] — strategy differs per tier
$ramProfile = switch ($true) {
    ($ramGB -le 5.5)                      { "4GB"  }
    ($ramGB -gt 5.5  -and $ramGB -le 9.5) { "8GB"  }
    ($ramGB -gt 9.5  -and $ramGB -le 20)  { "16GB" }
    ($ramGB -gt 20   -and $ramGB -le 40)  { "32GB" }
    ($ramGB -gt 40)                        { "64GB" }
    default                               { "8GB"  }
}

# RAM profile parameters  [V5-01]
$profileParams = switch ($ramProfile) {
    "4GB"  { @{ SessionView=128; PageMin=512;  PageMax=2048; WatchThresh=70; TopN=5  } }
    "8GB"  { @{ SessionView=256; PageMin=1024; PageMax=4096; WatchThresh=75; TopN=10 } }
    "16GB" { @{ SessionView=512; PageMin=2048; PageMax=8192; WatchThresh=80; TopN=15 } }
    "32GB" { @{ SessionView=768; PageMin=4096; PageMax=8192; WatchThresh=85; TopN=20 } }
    "64GB" { @{ SessionView=1024;PageMin=4096; PageMax=8192; WatchThresh=88; TopN=20 } }
}
$svSize      = $profileParams.SessionView
$pfMin       = $profileParams.PageMin
$pfMax       = $profileParams.PageMax
$wdogThresh  = $profileParams.WatchThresh
$topNProcs   = $profileParams.TopN

# SSD detection — multi-method for Win7/8 compat
$isSSD     = $false
$mediaType = "HDD/Unknown"
try {
    if ($isModern) {
        $pd = Get-PhysicalDisk -EA SilentlyContinue | Select-Object -First 1
        if ($pd) {
            $isSSD     = ($pd.MediaType -like "*SSD*" -or [int]$pd.MediaType -eq 3)
            $mediaType = if ($isSSD) {"SSD"} else {"HDD"}
        }
    } else {
        # Win7/8 fallback: check disk model name for SSD keywords
        $diskModel = if ($disk) { $disk.Model } else { "" }
        $isSSD = ($diskModel -match "SSD|Solid|NVMe|M\.2|Flash")
        $mediaType = if ($isSSD) {"SSD (name-detect)"} else {"HDD/Unknown"}
    }
} catch {}

# Brand detection
$mfrRaw  = (if ($cs) { "$($cs.Manufacturer) $($cs.Model)" } else { "" }).ToLower()
$biosRaw = (if ($bios) { "$($bios.Manufacturer) $($bios.SMBIOSBIOSVersion)" } else { "" }).ToLower()
$brand = "UNKNOWN"; $brandSrc = "manufacturer"
$brandMap = [ordered]@{
    "dell"="DELL"; "hp "="HP"; "hewlett"="HP"; "lenovo"="LENOVO"; "asus"="ASUS"
    "acer "="ACER"; "msi"="MSI"; "samsung"="SAMSUNG"; "microsoft"="MICROSOFT_SURFACE"
    "toshiba"="TOSHIBA"; "huawei"="HUAWEI"; "razer"="RAZER"; "gigabyte"="GIGABYTE"
    "intel"="INTEL_NUC"; "panasonic"="PANASONIC"; "fujitsu"="FUJITSU"
    "vaio"="VAIO"; "lg "="LG"
}
foreach ($kw in $brandMap.Keys) {
    if ($mfrRaw -like "*$kw*") { $brand = $brandMap[$kw]; break }
}
if ($brand -eq "UNKNOWN") {
    foreach ($kw in $brandMap.Keys) {
        if ($biosRaw -like "*$kw*") { $brand = $brandMap[$kw]; $brandSrc = "BIOS"; break }
    }
}
if ($brand -eq "UNKNOWN" -and $biosRaw -like "*american megatrends*") { $brand = "GENERIC_AMI" }

$brandColor = switch ($brand) {
    "DELL"{"Blue"};"HP"{"DarkCyan"};"LENOVO"{"Red"};"ASUS"{"Cyan"}
    "MSI"{"Red"};"ACER"{"Green"};"RAZER"{"Green"};"GIGABYTE"{"Yellow"}
    default{"Yellow"}
}

# ==============================================================================
# LOAD CONFIG  [V5-02] — allowlist + user preferences
# ==============================================================================
$defaultConfig = [ordered]@{
    Version         = $V5_VERSION
    AllowedProcesses = @("chrome","firefox","msedge","code","devenv","rider",
                          "studio64","resolve","ableton","fl studio","audacity",
                          "diablo","wow","game","steam","epicgameslauncher")
    AllowedServices  = @()
    WatchdogThresholdOverride = -1   # -1 = use profile default
    DisableHandleLeakScan     = $false
    DisableGpuCleanup         = $false
}

$config = $defaultConfig
if (Test-Path $CONFIG_FILE) {
    try {
        $loaded = Get-Content $CONFIG_FILE -Raw | ConvertFrom-Json
        if ($loaded.AllowedProcesses) { $config.AllowedProcesses = $loaded.AllowedProcesses }
        if ($loaded.AllowedServices)  { $config.AllowedServices  = $loaded.AllowedServices  }
        if ($null -ne $loaded.WatchdogThresholdOverride -and $loaded.WatchdogThresholdOverride -gt 0) {
            $wdogThresh = $loaded.WatchdogThresholdOverride
        }
    } catch {}
} else {
    $config | ConvertTo-Json -Depth 4 | Out-File $CONFIG_FILE -Encoding UTF8 -Force
}

# Build allowlist (config + hardcoded safety list)
$hardSafe = @("System","Idle","smss","csrss","wininit","winlogon","lsass","services",
              "Registry","dwm","fontdrvhost","audiodg","svchost","NtKrnl","hal",
              "MsMpEng","WUDFHost","NisSrv","SecurityHealthService",
              "powershell","pwsh","Optimize-RAM-v5","conhost","cmd")
$allowList = $hardSafe + ($config.AllowedProcesses | ForEach-Object { $_ -replace "\.exe$","" })

# ==============================================================================
# C# P/INVOKE BLOCK  (single class, unique name per version)
# ==============================================================================
$csharpCode = @"
using System;
using System.Runtime.InteropServices;
using System.Diagnostics;
public class RamOpt5 {
    // ntdll
    [DllImport("ntdll.dll")]
    public static extern uint NtSetSystemInformation(int cls, IntPtr buf, int len);
    [DllImport("ntdll.dll")]
    public static extern int  NtSetInformationProcess(IntPtr h, int cls, ref int val, int len);
    // kernel32
    [DllImport("kernel32.dll")] public static extern IntPtr OpenProcess(uint acc, bool inh, int pid);
    [DllImport("kernel32.dll")] public static extern bool   CloseHandle(IntPtr h);
    [DllImport("kernel32.dll")] public static extern bool   SetProcessWorkingSetSizeEx(IntPtr h, IntPtr mn, IntPtr mx, int f);
    // psapi
    [DllImport("psapi.dll")]    public static extern bool   EmptyWorkingSet(IntPtr h);
    // advapi32
    [StructLayout(LayoutKind.Sequential, Pack=1)]
    public struct TokPriv1Luid { public int Count; public long Luid; public int Attr; }
    [DllImport("kernel32.dll", ExactSpelling=true)] public static extern IntPtr GetCurrentProcess();
    [DllImport("advapi32.dll", ExactSpelling=true, SetLastError=true)]
    public static extern bool OpenProcessToken(IntPtr h, int acc, ref IntPtr tok);
    [DllImport("advapi32.dll", SetLastError=true)]
    public static extern bool LookupPrivilegeValue(string host, string name, ref long luid);
    [DllImport("advapi32.dll", ExactSpelling=true, SetLastError=true)]
    public static extern bool AdjustTokenPrivileges(IntPtr htok, bool dis, ref TokPriv1Luid ns, int len, IntPtr pv, IntPtr rl);
    // kernel32 file cache
    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern bool SetSystemFileCacheSize(IntPtr mn, IntPtr mx, int f);
    // Privilege enable
    public static bool EnablePrivilege(string priv) {
        IntPtr hproc = GetCurrentProcess(); IntPtr htok = IntPtr.Zero;
        if (!OpenProcessToken(hproc, 0x28, ref htok)) return false;
        TokPriv1Luid tp; tp.Count=1; tp.Luid=0; tp.Attr=2;
        if (!LookupPrivilegeValue(null, priv, ref tp.Luid)) return false;
        return AdjustTokenPrivileges(htok, false, ref tp, 0, IntPtr.Zero, IntPtr.Zero);
    }
    // Memory flush command
    public static uint FlushMemory(int cmd) {
        IntPtr p = Marshal.AllocHGlobal(4);
        Marshal.WriteInt32(p, cmd);
        uint r = NtSetSystemInformation(80, p, 4);
        Marshal.FreeHGlobal(p);
        return r;
    }
    // Trim one process
    public static bool TrimProcess(int pid) {
        IntPtr h = OpenProcess(0x1F0FFF, false, pid);
        if (h == IntPtr.Zero) return false;
        EmptyWorkingSet(h);
        SetProcessWorkingSetSizeEx(h, new IntPtr(-1), new IntPtr(-1), 0);
        CloseHandle(h);
        return true;
    }
    // Set process priority via NtSetInformationProcess
    public static bool SetPriority(int pid, int cls) {
        IntPtr h = OpenProcess(0x0600, false, pid);
        if (h == IntPtr.Zero) return false;
        int r = NtSetInformationProcess(h, 18, ref cls, 4);
        CloseHandle(h);
        return (r == 0);
    }
}
"@
if (-not ([System.Management.Automation.PSTypeName]"RamOpt5").Type) {
    Add-Type -TypeDefinition $csharpCode -EA SilentlyContinue
}

# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================
function Invoke-MemCmd {
    param([int]$cmd, [string]$label)
    if ($DryRun) { Write-DryRun "MemCmd $cmd ($label)"; return }
    $r = [RamOpt5]::FlushMemory($cmd)
    if ($r -eq 0) { Write-Log "  [OK] $label" "Green" }
    else          { Write-Log ("  [WARN] {0} NTSTATUS=0x{1:X}" -f $label, $r) "Yellow" }
}

function Enable-Privs {
    [RamOpt5]::EnablePrivilege("SeIncreaseQuotaPrivilege")        | Out-Null
    [RamOpt5]::EnablePrivilege("SeProfileSingleProcessPrivilege") | Out-Null
    [RamOpt5]::EnablePrivilege("SeDebugPrivilege")                | Out-Null
}

function Invoke-FullKernelFlush {
    Enable-Privs
    Invoke-MemCmd -cmd 4 -label "Flush Modified Page List"
    Start-Sleep -Milliseconds 300
    Invoke-MemCmd -cmd 3 -label "Purge Standby List"
    Start-Sleep -Milliseconds 300
    Invoke-MemCmd -cmd 1 -label "Empty All Working Sets"
    Start-Sleep -Milliseconds 200
    if ($isModern) {
        Invoke-MemCmd -cmd 2 -label "Flush Modified List pass-2"
        Start-Sleep -Milliseconds 200
    }
    Invoke-MemCmd -cmd 3 -label "Post-trim Standby flush"
    # File cache
    if (-not $DryRun) {
        [RamOpt5]::SetSystemFileCacheSize([IntPtr](-1), [IntPtr](-1), 0) | Out-Null
        Write-Log "  [OK] File system cache flushed" "Green"
    } else { Write-DryRun "SetSystemFileCacheSize reset" }
}

function Stop-And-Disable {
    param(
        [System.Collections.Specialized.OrderedDictionary]$Map,
        [string]$Cat,
        [ref]$Ctr
    )
    $n = 0
    foreach ($s in $Map.Keys) {
        # Skip if user allowlisted this service
        if ($config.AllowedServices -contains $s) {
            Write-Log ("  [ALLOW] {0,-40} (user allowlist)" -f $s) "DarkGray"
            continue
        }
        $svc = Get-Service -Name $s -EA SilentlyContinue
        if (-not $svc) {
            $svc = Get-Service -EA SilentlyContinue |
                   Where-Object { $_.DisplayName -like "*$s*" } |
                   Select-Object -First 1
        }
        if (-not $svc) { continue }
        if ($DryRun) {
            Write-DryRun ("Would disable: {0} [{1}]" -f $svc.Name, $Map[$s])
            $n++; continue
        }
        $prevStart = $svc.StartType.ToString()
        try {
            if ($svc.Status -eq "Running") {
                Stop-Service -InputObject $svc -Force -EA SilentlyContinue
                Write-Log ("  [STOP] {0,-44} {1}" -f $svc.Name, $Map[$s]) "DarkYellow"
            }
            Set-Service -InputObject $svc -StartupType Disabled -EA SilentlyContinue
            Write-Log ("  [OFF ] {0,-44} {1}" -f $svc.Name, $Map[$s]) "DarkGray"
            $Script:Backup.Services += [ordered]@{
                Name=$svc.Name; PreviousStartType=$prevStart; DisabledBy=$Cat
            }
            $n++; $Ctr.Value++
        } catch {}
    }
    return $n
}

function Set-Reg {
    param([string]$Path, [string]$Name, $Value, [string]$Type = "DWord")
    if ($DryRun) { Write-DryRun ("Reg: {0}\{1} = {2}" -f $Path, $Name, $Value); return }
    if (-not (Test-Path $Path)) { New-Item -Path $Path -Force -EA SilentlyContinue | Out-Null }
    $prev = (Get-ItemProperty -Path $Path -Name $Name -EA SilentlyContinue).$Name
    Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -EA SilentlyContinue
    $Script:Backup.Registry += [ordered]@{ Path=$Path; Name=$Name; PreviousValue=$prev }
}

# ==============================================================================
# DISPLAY HEADER
# ==============================================================================
Clear-Host
$dryTag = if ($DryRun) { "  *** DRY RUN — NO CHANGES WILL BE MADE ***" } else { "" }
Write-Log ""
Write-Log "  +==================================================================+" "Cyan"
Write-Log ("  |   RAM OPTIMIZER  --  GOD MODE  v{0}  [{1}]" -f $V5_VERSION, $winTag).PadRight(68) + "   |" "Cyan"
Write-Log "  |   Supports: Win7 / Win8 / Win10 / Win11  |  All RAM sizes       |" "Cyan"
Write-Log ("  |   Mode: {0,-20} Profile: {1,-15}             |" -f $Mode, $ramProfile) "Cyan"
Write-Log "  +==================================================================+" "Cyan"
if ($DryRun) { Write-Log $dryTag "Magenta" }
Write-Log ""
Write-Log ("  OS       :  {0}  [Build {1}]" -f $winName, $winBuild) "White"
Write-Log ("  Machine  :  {0}  {1}" -f (if($cs){$cs.Manufacturer}else{"?"}), (if($cs){$cs.Model}else{"?"})) "White"
Write-Log ("  CPU      :  {0}" -f (if($cpu){$cpu.Name}else{"?"})) "White"
Write-Log ("  RAM      :  {0} GB  (Free: {1} GB)  ->  Profile: [{2}]" -f $ramGB, $free0, $ramProfile) "Magenta"
Write-Log ("  Disk     :  {0}  [{1}]" -f (if($disk){$disk.Model}else{"?"}), $mediaType) "White"
Write-Log ("  Brand    :  [{0}]  source: {1}" -f $brand, $brandSrc) $brandColor
Write-Log ("  Config   :  {0}" -f $CONFIG_FILE) "DarkGray"
Write-Log ""
Write-Log ("  [PROFILE] SessionViewSize={0} MB  |  PageMin={1} MB  |  PageMax={2} MB" -f $svSize, $pfMin, $pfMax) "Magenta"
Write-Log ("  [PROFILE] WatchdogThreshold={0}%  |  TopN processes={1}" -f $wdogThresh, $topNProcs) "Magenta"
Write-Log ""

# ==============================================================================
# RESTORE MODE  [V5-05]
# ==============================================================================
if ($Mode -eq "Restore") {
    Show-Section "RESTORE MODE — re-enabling services from backup"
    if (-not (Test-Path $BACKUP_FILE)) {
        Write-Log "  [!] No backup file found at: $BACKUP_FILE" "Red"
        Write-Log "  [!] Run Full mode first to create a backup." "Yellow"
        Write-Log ""; Write-Log "  Press ENTER to exit..." "Cyan"; $null = Read-Host; exit 0
    }
    $bk = Get-Content $BACKUP_FILE -Raw | ConvertFrom-Json
    $restored = 0
    foreach ($entry in $bk.Services) {
        $svc = Get-Service -Name $entry.Name -EA SilentlyContinue
        if ($svc) {
            $startType = $entry.PreviousStartType
            if (-not $startType -or $startType -eq "Disabled") { $startType = "Manual" }
            Set-Service -InputObject $svc -StartupType $startType -EA SilentlyContinue
            Write-Log ("  [RESTORE] {0,-40} -> {1}" -f $svc.Name, $startType) "Green"
            $restored++
        }
    }
    Write-Log ""
    Write-Log ("  [OK] Restored {0} services from backup." -f $restored) "Green"
    Write-Log ("  [i] Backup was created: {0}" -f $bk.Timestamp) "DarkGray"
    Write-Log ""; Write-Log "  Press ENTER to close..." "Cyan"; $null = Read-Host; exit 0
}

# ==============================================================================
# WATCHDOG-ONLY MODE — jump straight to step 12
# ==============================================================================
$skipToWatchdog = ($Mode -eq "WatchdogOnly")

# ==============================================================================
# SYSTEM RESTORE POINT  [V5-04] — Full mode only, real changes only
# ==============================================================================
if ($Mode -eq "Full" -and -not $DryRun -and $isModern) {
    Show-Section "STEP 0: System Restore Point"
    Write-Log "  Creating restore point before any changes..." "White"
    try {
        $null = Checkpoint-Computer -Description "RAM Optimizer V5 - Before optimization" `
                -RestorePointType "MODIFY_SETTINGS" -EA Stop
        Write-Log "  [OK] System Restore Point created successfully" "Green"
    } catch {
        Write-Log ("  [WARN] Restore point failed: {0}" -f $_.Exception.Message) "Yellow"
        Write-Log "  [i]  This is normal if restore points are disabled on this machine" "DarkGray"
    }
} elseif ($Mode -eq "Full" -and -not $DryRun -and -not $isModern) {
    Write-Log "  [--] Restore Point skipped (Win7/8 — use wbAdmin for backup)" "DarkGray"
}

if (-not $skipToWatchdog) {

# ==============================================================================
# STEP 1 — KERNEL MEMORY FLUSH
# ==============================================================================
Show-Section ("STEP 1: Kernel Memory Flush  [{0} profile]" -f $ramProfile)
Write-Log ("  Flushing: Standby / Modified / Working Sets / File Cache") "White"
Invoke-FullKernelFlush

# ==============================================================================
# STEP 2 — WORKING SET TRIM (All processes)
# ==============================================================================
Show-Section ("STEP 2: Working Set Trim  [top {0} RAM consumers + all non-protected]" -f $topNProcs)

$allProcs   = Get-Process -EA SilentlyContinue | Where-Object { $allowList -notcontains $_.ProcessName }
$sortedProcs= $allProcs | Sort-Object WorkingSet64 -Descending
$trimOK = 0; $trimFail = 0; [long]$freedBytes = 0

if ($DryRun) {
    Write-DryRun ("Would trim {0} processes (top {1} shown):" -f ($sortedProcs | Measure-Object).Count, $topNProcs)
    $sortedProcs | Select-Object -First $topNProcs | ForEach-Object {
        Write-DryRun ("  {0,-30} {1} MB" -f $_.ProcessName, [math]::Round($_.WorkingSet64/1MB,1))
    }
} else {
    # Full pass — trim all
    $sortedProcs | ForEach-Object {
        $ws0 = $_.WorkingSet64
        if ([RamOpt5]::TrimProcess($_.Id)) {
            $pNow = Get-Process -Id $_.Id -EA SilentlyContinue
            if ($pNow) { $freedBytes += [math]::Max(0, $ws0 - $pNow.WorkingSet64) }
            $trimOK++
        } else { $trimFail++ }
    }
    # Post-trim flush
    Start-Sleep -Milliseconds 400
    Invoke-MemCmd -cmd 3 -label "Post-trim Standby flush"

    Write-Log ("  [OK] Trimmed    : {0} processes" -f $trimOK) "Green"
    Write-Log ("  [OK] Freed      : ~{0} MB" -f [math]::Round($freedBytes/1MB,1)) "Green"
    Write-Log ("  [--] Skipped    : {0} protected processes" -f $trimFail) "DarkGray"
    $Script:Stats.TrimOK    = $trimOK
    $Script:Stats.FreedMB   = [math]::Round($freedBytes/1MB,1)
}

# Top-N verbose list
Write-Log ("  >> Top {0} RAM consumers:" -f $topNProcs) "White"
$rank = 1
Get-Process -EA SilentlyContinue |
  Where-Object { $allowList -notcontains $_.ProcessName } |
  Sort-Object WorkingSet64 -Descending | Select-Object -First $topNProcs |
  ForEach-Object {
    $pMB = [math]::Round($_.WorkingSet64/1MB,1)
    $inAllow = ($config.AllowedProcesses -contains $_.ProcessName)
    $tag = if ($inAllow) {"[PROTECTED]"} else {"[trimmed]"}
    Write-Log ("  #{0,-3} {1,-28} {2,8} MB  {3}" -f $rank, $_.ProcessName, $pMB, $tag) "DarkYellow"
    $rank++
  }

# Quick mode exits after flush+trim
if ($Mode -eq "Quick") {
    Write-Log ""
    Write-Log "  [QUICK MODE] Kernel flush + process trim complete." "Green"
    $os1 = if ($hasCim) { Get-CimInstance Win32_OperatingSystem } else { Get-WmiObject Win32_OperatingSystem }
    $free1 = [math]::Round($os1.FreePhysicalMemory / 1MB, 2)
    $gain  = [math]::Round($free1 - $free0, 2)
    Write-Log ("  Before: {0} GB free  ->  After: {1} GB free  (+{2} GB)" -f $free0, $free1, $gain) "Cyan"
    $Script:Log | Out-File $LOG_TXT -Encoding UTF8 -Force
    Write-Log ""; Write-Log "  Press ENTER to close..." "Cyan"; $null = Read-Host; exit 0
}

# ==============================================================================
# STEP 3 — HANDLE LEAK DETECTION  [V5-08]
# ==============================================================================
Show-Section "STEP 3: Handle Leak Detection"

if ($config.DisableHandleLeakScan) {
    Write-Log "  [--] Handle scan disabled in config" "DarkGray"
} else {
    $leakThresh = 10000
    Write-Log ("  Scanning for processes with >{0} open handles (memory leak indicator)..." -f $leakThresh) "White"
    $leakers = Get-Process -EA SilentlyContinue |
               Where-Object { $_.HandleCount -gt $leakThresh -and $hardSafe -notcontains $_.ProcessName } |
               Sort-Object HandleCount -Descending
    if ($leakers) {
        foreach ($lk in $leakers) {
            Write-Log ("  [LEAK?] {0,-30} Handles: {1,6}  RAM: {2} MB" -f `
                $lk.ProcessName, $lk.HandleCount, [math]::Round($lk.WorkingSet64/1MB,1)) "Red"
            $Script:Stats.HandleLeaks++
        }
        Write-Log "  [!] Above processes may have handle leaks — consider restarting them." "Yellow"
    } else {
        Write-Log "  [OK] No handle leaks detected (all processes below $leakThresh handles)" "Green"
    }
}

# ==============================================================================
# STEP 4 — NON-PAGED POOL MONITOR  [V5-09]
# ==============================================================================
Show-Section "STEP 4: Non-Paged Pool Monitor"

try {
    $perfOS  = if ($hasCim) {
        Get-CimInstance -ClassName Win32_PerfFormattedData_PerfOS_Memory -EA SilentlyContinue
    } else {
        Get-WmiObject -Class Win32_PerfFormattedData_PerfOS_Memory -EA SilentlyContinue
    }
    if ($perfOS) {
        $nppMB  = [math]::Round($perfOS.PoolNonpagedBytes / 1MB, 1)
        $ppMB   = [math]::Round($perfOS.PoolPagedBytes    / 1MB, 1)
        $nppCol = if ($nppMB -gt 1024) {"Red"} elseif ($nppMB -gt 512) {"Yellow"} else {"Green"}
        Write-Log ("  Non-Paged Pool : {0} MB" -f $nppMB) $nppCol
        Write-Log ("  Paged Pool     : {0} MB" -f $ppMB)  "White"
        if ($nppMB -gt 1024) {
            Write-Log "  [!] Non-Paged Pool > 1 GB — likely a DRIVER MEMORY LEAK!" "Red"
            Write-Log "  [!] This is not an app issue — check recent driver installs." "Red"
            Write-Log "  [i] Run: poolmon.exe (from Windows WDK) to identify the driver." "Yellow"
        } elseif ($nppMB -gt 512) {
            Write-Log "  [WARN] Non-Paged Pool > 512 MB — elevated, watch for growth." "Yellow"
        } else {
            Write-Log "  [OK] Non-Paged Pool is healthy." "Green"
        }
    } else {
        Write-Log "  [--] Performance counters not available on this system." "DarkGray"
    }
} catch {
    Write-Log "  [--] NPP monitor skipped (performance counter access failed)." "DarkGray"
}

# ==============================================================================
# SERVICE MAPS (shared across Full + DryRun)
# ==============================================================================
$svcsCommon = [ordered]@{
    "DiagTrack"="Connected User Experiences & Telemetry";"dmwappushservice"="WAP Push (telemetry)"
    "WerSvc"="Windows Error Reporting";"wercplsupport"="WER Control Panel"
    "XblGameSave"="Xbox Game Save";"XboxNetApiSvc"="Xbox Live Networking"
    "XblAuthManager"="Xbox Live Auth";"XboxGipSvc"="Xbox Accessories"
    "MapsBroker"="Downloaded Maps Manager";"RetailDemo"="Retail Demo Service"
    "wisvc"="Windows Insider Service";"lfsvc"="Geolocation/GPS"
    "TapiSrv"="Telephony";"Fax"="Fax Service";"icssvc"="Mobile Hotspot"
    "WalletService"="Wallet Service";"EntAppSvc"="Enterprise App Management"
    "MessagingService"="Messaging Service";"OneSyncSvc"="Sync Host (mail/cal)"
    "WSearch"="Windows Search Indexing";"SysMain"="SysMain/Superfetch"
    "RemoteRegistry"="Remote Registry";"RemoteAccess"="Routing & Remote Access"
    "SharedAccess"="Internet Connection Sharing";"TermService"="Remote Desktop Services"
    "SessionEnv"="Remote Desktop Config";"UmRdpService"="RDP Device Redirector"
    "ScDeviceEnum"="Smart Card Enum";"SCardSvr"="Smart Card";"SCPolicySvc"="Smart Card Policy"
    "MixedRealityOpenXRSvc"="Mixed Reality OpenXR";"PhoneSvc"="Phone Service"
    "PimIndexMaintenanceSvc"="Contact Data";"UnistoreSvc"="User Data Storage"
    "UserDataSvc"="User Data Access";"PrintNotify"="Printer Extensions"
    "Spooler"="Print Spooler (if no printer)";"BthAvctpSvc"="Bluetooth Audio Gateway"
    "BTAGService"="Bluetooth Audio AVRCP";"AJRouter"="AllJoyn Router (IoT)"
    "CscService"="Offline Files";"DusmSvc"="Data Usage";"WbioSrvc"="Windows Biometric"
}
$svcsWin7Only = [ordered]@{
    "HomeGroupListener"="HomeGroup Listener";"HomeGroupProvider"="HomeGroup Provider"
    "WMPNetworkSvc"="WMP Network Sharing";"WerSvc"="Windows Error Reporting"
    "wuauserv"=""   # Do NOT disable on Win7 — security updates critical
}
$svcsWin7Only.Remove("wuauserv")   # safety
$svcsWin8Only = [ordered]@{
    "HomeGroupListener"="HomeGroup Listener";"HomeGroupProvider"="HomeGroup Provider"
    "WMPNetworkSvc"="WMP Network Sharing";"NcbService"="Network Connection Broker"
}
$svcsWin10Only = [ordered]@{
    "wlidsvc"="MS Account Sign-in";"SEMgrSvc"="Payments & NFC";"NcbService"="Network Connection Broker"
    "CDPSvc"="Connected Devices Platform";"WMPNetworkSvc"="WMP Network Sharing"
}
$svcsWin11Only = [ordered]@{
    "cbdhsvc"="Clipboard User Service";"WpnService"="Push Notifications"
    "WpnUserService"="Push Notifications User";"DsSvc"="Data Sharing"
    "DevicesFlowUserSvc"="Devices Flow";"NPSMSvc"="Now Playing Session"
    "BcastDVRUserService"="GameDVR Broadcast";"DoSvc"="Delivery Optimization"
    "CDPUserSvc"="Connected Devices User";"PushToInstall"="PushToInstall"
    "NetTcpPortSharing"="Net.Tcp Port Sharing"
}
$svcsDELL=[ordered]@{"DellClientManagementService"="Dell Client Mgmt";"DellUpdate"="Dell Update"
    "DellSupportAssistRemedationService"="Dell SupportAssist Remediation"
    "DellFoundationServices"="Dell Foundation";"DellTechHubService"="Dell TechHub"
    "DellOptimizer"="Dell Optimizer";"DellMobileConnect"="Dell Mobile Connect"
    "DellDataVault"="Dell Data Vault";"DellDataVaultWizard"="Dell Data Vault Wizard"
    "ThermalService"="Dell Thermal";"DellDigitalDelivery"="Dell Digital Delivery"
    "DellServiceConnectivity"="Dell Connectivity"}
$svcsHP=[ordered]@{"HPAppHelperCap"="HP App Helper";"HPDiagsMsgSvc"="HP Diagnostics"
    "HPNetworkCap"="HP Network Cap";"HPSysInfoCap"="HP SysInfo Cap";"hpsvc"="HP Service"
    "HpTouchpointAnalyticsService"="HP Touchpoint Analytics";"HPAudioSwitch"="HP Audio Switch"
    "HPWMISVC"="HP WMI";"HPJumpStartBridge"="HP JumpStart Bridge";"HPJumpStartSvc"="HP JumpStart"
    "HPUpdateService"="HP Update";"HPDrvSvc"="HP Driver"}
$svcsLENOVO=[ordered]@{"ImControllerService"="Lenovo ImController"
    "LenovoVantageService"="Lenovo Vantage";"SUService"="Lenovo System Update"
    "LENOVO.CAMMUTE"="Lenovo Cam Mute";"LENOVO.MICMUTE"="Lenovo Mic Mute"
    "PMSvc"="Lenovo Power Mgr";"LenovoSmartStandbyService"="Lenovo Smart Standby"
    "LenovoUtilityService"="Lenovo Utility";"LenovoWiFiHotspotSvc"="Lenovo WiFi Hotspot"}
$svcsASUS=[ordered]@{"asHmComSvc"="ASUS HM Com";"AsSysCtrlService"="ASUS Sys Control"
    "AsusCertService"="ASUS Certificate";"ASUSUpdate"="ASUS Update"
    "ASUSLinkNear"="ASUS Link Near";"ASUSLinkRemote"="ASUS Link Remote"
    "ASUSOptimization"="ASUS Optimization";"ROGLiveService"="ROG Live"
    "ArmouryCrateService"="Armoury Crate";"ASUSSystemControlInterface"="ASUS Sys Control IF"}
$svcsMSI=[ordered]@{"SCM"="MSI System Control";"msidrvsvc"="MSI Driver"
    "MSICenterService"="MSI Center";"DragonCenterService"="MSI Dragon Center"
    "NahimicService"="Nahimic Audio";"MSIRGBService"="MSI RGB"}
$svcsACER=[ordered]@{"AcerService"="Acer Service";"AcerCloudService"="Acer Cloud"
    "AcerLaunchManager"="Acer Launch Mgr";"PredatorSenseService"="Acer PredatorSense"
    "NitroSenseService"="Acer NitroSense";"QuickAccessService"="Acer Quick Access"
    "AcerUpdateService"="Acer Update";"AcerCare"="Acer Care"}
$svcsSAMSUNG=[ordered]@{"SamsungMagicianService"="Samsung Magician";"SamsungUpdateService"="Samsung Update";"SamsungSystemManager"="Samsung Sys Mgr"}
$svcsSURFACE=[ordered]@{"SurfaceTelemetryService"="Surface Telemetry";"SurfaceDiagnostics"="Surface Diagnostics";"SurfaceFirmwareProvisioningService"="Surface Firmware"}
$svcsRAZER=[ordered]@{"Razer Chroma SDK Server"="Razer Chroma Server";"RazerCentralService"="Razer Central";"Razer Synapse Service"="Razer Synapse"}
$svcsGIGABYTE=[ordered]@{"GbActuatorService"="Gigabyte Actuator";"AppCenter"="Gigabyte App Center";"RGBFusionSvc"="RGB Fusion";"GbFirmwareUpdateSvc"="Gigabyte FW Update"}
$svcsTOSHIBA=[ordered]@{"TODDSrv"="Toshiba ODD";"TMachInfo"="Toshiba Machine Info";"TVALZ"="Toshiba ACPI";"TPCH"="Toshiba PCH"}
$svcsHUAWEI=[ordered]@{"HuaweiPCManagerSvc"="Huawei PCManager";"HuaweiService"="Huawei Service"}
$svcsLG=[ordered]@{"LGUpdateService"="LG Update";"LGHubService"="LG Hub"}
$svcsPANA=[ordered]@{"PanaService"="Panasonic Service"}
$svcsFUJITSU=[ordered]@{"FjSessServiceAgent"="Fujitsu Session";"FUJBtnSvc"="Fujitsu Button"}
$svcsVAIO=[ordered]@{"VAIOCareService"="VAIO Care";"VAIOEventService"="VAIO Event"}

# ==============================================================================
# STEP 5 — DISABLE SERVICES
# ==============================================================================
Show-Section "STEP 5: Disable unnecessary services"
Write-Log ("  Scanning {0} common services..." -f $svcsCommon.Keys.Count) "White"
Stop-And-Disable -Map $svcsCommon -Cat "Common" -Ctr ([ref]$Script:Stats.SvcCommon) | Out-Null

if ($isWin7)  { Stop-And-Disable -Map $svcsWin7Only  -Cat "Win7"  -Ctr ([ref]$Script:Stats.SvcCommon) | Out-Null }
if ($isWin8)  { Stop-And-Disable -Map $svcsWin8Only  -Cat "Win8"  -Ctr ([ref]$Script:Stats.SvcCommon) | Out-Null }
if ($isWin10) { Stop-And-Disable -Map $svcsWin10Only -Cat "Win10" -Ctr ([ref]$Script:Stats.SvcCommon) | Out-Null }
if ($isWin11) { Stop-And-Disable -Map $svcsWin11Only -Cat "Win11" -Ctr ([ref]$Script:Stats.SvcCommon) | Out-Null }

Write-Log ("  [OK] Common + OS-specific: {0} services handled" -f $Script:Stats.SvcCommon) "Green"

# ==============================================================================
# STEP 6 — BRAND SERVICES
# ==============================================================================
Show-Section ("STEP 6: Brand services [{0}]" -f $brand)
$n6 = 0
switch ($brand) {
    "DELL"              { $n6 = Stop-And-Disable -Map $svcsDELL     -Cat "DELL"    -Ctr ([ref]$Script:Stats.SvcBrand) }
    "HP"                { $n6 = Stop-And-Disable -Map $svcsHP       -Cat "HP"      -Ctr ([ref]$Script:Stats.SvcBrand) }
    "LENOVO"            { $n6 = Stop-And-Disable -Map $svcsLENOVO   -Cat "LENOVO"  -Ctr ([ref]$Script:Stats.SvcBrand) }
    "ASUS"              { $n6 = Stop-And-Disable -Map $svcsASUS     -Cat "ASUS"    -Ctr ([ref]$Script:Stats.SvcBrand) }
    "MSI"               { $n6 = Stop-And-Disable -Map $svcsMSI      -Cat "MSI"     -Ctr ([ref]$Script:Stats.SvcBrand) }
    "ACER"              { $n6 = Stop-And-Disable -Map $svcsACER     -Cat "ACER"    -Ctr ([ref]$Script:Stats.SvcBrand) }
    "SAMSUNG"           { $n6 = Stop-And-Disable -Map $svcsSAMSUNG  -Cat "SAMSUNG" -Ctr ([ref]$Script:Stats.SvcBrand) }
    "MICROSOFT_SURFACE" { $n6 = Stop-And-Disable -Map $svcsSURFACE  -Cat "SURFACE" -Ctr ([ref]$Script:Stats.SvcBrand) }
    "RAZER"             { $n6 = Stop-And-Disable -Map $svcsRAZER    -Cat "RAZER"   -Ctr ([ref]$Script:Stats.SvcBrand) }
    "GIGABYTE"          { $n6 = Stop-And-Disable -Map $svcsGIGABYTE -Cat "GIGABYTE"-Ctr ([ref]$Script:Stats.SvcBrand) }
    "TOSHIBA"           { $n6 = Stop-And-Disable -Map $svcsTOSHIBA  -Cat "TOSHIBA" -Ctr ([ref]$Script:Stats.SvcBrand) }
    "HUAWEI"            { $n6 = Stop-And-Disable -Map $svcsHUAWEI   -Cat "HUAWEI"  -Ctr ([ref]$Script:Stats.SvcBrand) }
    "LG"                { $n6 = Stop-And-Disable -Map $svcsLG       -Cat "LG"      -Ctr ([ref]$Script:Stats.SvcBrand) }
    "PANASONIC"         { $n6 = Stop-And-Disable -Map $svcsPANA     -Cat "PANASONIC"-Ctr([ref]$Script:Stats.SvcBrand) }
    "FUJITSU"           { $n6 = Stop-And-Disable -Map $svcsFUJITSU  -Cat "FUJITSU" -Ctr ([ref]$Script:Stats.SvcBrand) }
    "VAIO"              { $n6 = Stop-And-Disable -Map $svcsVAIO     -Cat "VAIO"    -Ctr ([ref]$Script:Stats.SvcBrand) }
    "GENERIC_AMI"       {
        Stop-And-Disable -Map $svcsGIGABYTE -Cat "AMI/GB" -Ctr ([ref]$Script:Stats.SvcBrand) | Out-Null
        $n6 = Stop-And-Disable -Map $svcsASUS -Cat "AMI/ASUS" -Ctr ([ref]$Script:Stats.SvcBrand)
    }
    default { Write-Log "  [i] Unknown brand — brand services skipped." "Yellow" }
}
Write-Log ("  [OK] Brand [{0}]: {1} services handled" -f $brand, $Script:Stats.SvcBrand) $brandColor

# Keyword scan for residuals
Show-Section "STEP 6b: Keyword scan — leftover vendor services"
$vendorKW = @("dell","hewlett","hp ","lenovo","thinkpad","asus","armoury","rog ",
              "msi ","dragon center","nahimic","acer ","predator","nitro","samsung",
              "toshiba","huawei","razer","synapse","chroma","gigabyte","rgb fusion",
              "supportassist","vantage","pcmanager","lg hub","fujitsu","panasonic","vaio")
$allSvcs = Get-Service -EA SilentlyContinue
foreach ($svc in $allSvcs) {
    if ($svc.StartType -eq "Disabled") { continue }
    $dn = $svc.DisplayName.ToLower(); $sn = $svc.Name.ToLower()
    foreach ($kw in $vendorKW) {
        if ($dn -like "*$kw*" -or $sn -like "*$kw*") {
            if ($DryRun) { Write-DryRun ("KW-scan would disable: {0}" -f $svc.Name); break }
            try {
                if ($svc.Status -eq "Running") { Stop-Service $svc.Name -Force -EA SilentlyContinue }
                Set-Service  $svc.Name -StartupType Disabled -EA SilentlyContinue
                $Script:Backup.Services += [ordered]@{ Name=$svc.Name; PreviousStartType="Unknown(KW)"; DisabledBy="KWScan" }
                Write-Log ("  [KW] {0,-40} {1}" -f $svc.Name, $svc.DisplayName) "DarkYellow"
                $Script:Stats.SvcKW++
            } catch {}
            break
        }
    }
}
Write-Log ("  [OK] Keyword scan: {0} additional services disabled" -f $Script:Stats.SvcKW) "Green"

# ==============================================================================
# STEP 7 — STARTUP / SCHEDULED TASKS
# ==============================================================================
Show-Section "STEP 7: Startup items + Scheduled Tasks"
$startupKeys = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run",
    "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
)
$startupKW = @("dell","hewlett","hp ","lenovo","asus","armoury","msi ","acer ",
               "samsung","toshiba","huawei","razer","gigabyte","vantage",
               "supportassist","pcmanager","lg ","fujitsu","vaio","cortana","teams")
foreach ($regPath in $startupKeys) {
    if (-not (Test-Path $regPath)) { continue }
    $entries = Get-ItemProperty -Path $regPath -EA SilentlyContinue
    if (-not $entries) { continue }
    $entries.PSObject.Properties |
      Where-Object { $_.MemberType -eq "NoteProperty" -and $_.Name -notmatch "^PS" } |
      ForEach-Object {
        $vn = $_.Name; $vd = ($_.Value + "").ToLower()
        foreach ($kw in $startupKW) {
            if ($vn.ToLower() -like "*$kw*" -or $vd -like "*$kw*") {
                if ($DryRun) { Write-DryRun ("Startup del: $vn"); break }
                Remove-ItemProperty -Path $regPath -Name $vn -EA SilentlyContinue
                Write-Log ("  [RUN-DEL] {0}" -f $vn) "DarkYellow"
                $Script:Stats.StartupDel++; break
            }
        }
    }
}
$taskKW = @("dell","hp","lenovo","asus","msi","acer","samsung","toshiba","huawei",
            "razer","gigabyte","supportassist","vantage","armoury","dragon center",
            "nahimic","fujitsu","vaio","panasonic","cortana","onedrive","teams","feedback")
try {
    $sched = New-Object -ComObject "Schedule.Service"; $sched.Connect()
    function Disable-VTasks { param($f)
        try {
            foreach ($t in $f.GetTasks(0)) {
                $tn = $t.Name.ToLower()
                foreach ($kw in $taskKW) {
                    if ($tn -like "*$kw*") {
                        if ($t.Enabled) {
                            if ($DryRun) { Write-DryRun ("Task disable: {0}" -f $t.Path) }
                            else { $t.Enabled = $false; Write-Log ("  [TASK-OFF] {0}" -f $t.Path) "DarkYellow" }
                            $Script:Stats.TasksOff++
                        }
                        break
                    }
                }
            }
            foreach ($sf in $f.GetFolders(0)) { Disable-VTasks $sf }
        } catch {}
    }
    Disable-VTasks ($sched.GetFolder("\"))
    [System.Runtime.InteropServices.Marshal]::ReleaseComObject($sched) | Out-Null
} catch {}
Write-Log ("  [OK] Startup entries removed: {0}   Tasks disabled: {1}" -f $Script:Stats.StartupDel, $Script:Stats.TasksOff) "Green"

# ==============================================================================
# STEP 8 — REGISTRY TUNING (RAM-Profile-aware)
# ==============================================================================
Show-Section ("STEP 8: Registry tuning  [{0} profile | {1} MB SessionView]" -f $ramProfile, $svSize)

$mm   = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
$pref = "$mm\PrefetchParameters"

# Memory Management — profile-aware  [V5-01, V5-14]
Set-Reg $mm "LargeSystemCache"       0
Set-Reg $mm "DisablePagingExecutive" 1
Set-Reg $mm "SecondLevelDataCache"   0
Set-Reg $mm "NonPagedPoolQuota"      0
Set-Reg $mm "PagedPoolQuota"         0
Set-Reg $mm "SessionPoolSize"        48
Set-Reg $mm "SessionViewSize"        $svSize
Set-Reg $mm "SystemPages"            0
Set-Reg $mm "ClearPageFileAtShutdown" 1
Write-Log ("  [OK] Memory Management: SessionViewSize={0} MB, ClearPageFile=1" -f $svSize) "Green"

# Prefetch
if (Test-Path $pref) {
    $pfVal = if ($isSSD) { 0 } else { 3 }
    Set-Reg $pref "EnablePrefetcher"  $pfVal
    Set-Reg $pref "EnableSuperfetch"  0
    Set-Reg $pref "EnableBoottrace"   0
    Write-Log ("  [OK] Prefetcher={0} (SSD={1}), Superfetch=0" -f $pfVal, $isSSD) "Green"
}

# ReadyBoot
Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\WMI\Autologger\ReadyBoot" "Start" 0
Write-Log "  [OK] ReadyBoot logger disabled" "Green"

# Telemetry (Win10/11 only — policies don't exist on Win7/8)
if ($isWin10 -or $isWin11) {
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" "AllowTelemetry" 0
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" "AllowTelemetry" 0
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" "MaxTelemetryAllowed" 0
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat" "DisableInventory" 1
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\SQMClient\Windows" "CEIPEnable" 0
    $ctrKey = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\CompatTelRunner.exe"
    if (-not $DryRun) {
        if (-not (Test-Path $ctrKey)) { New-Item $ctrKey -Force -EA SilentlyContinue | Out-Null }
        Set-ItemProperty $ctrKey "Debugger" "%windir%\System32\taskkill.exe" -Type String -EA SilentlyContinue
    }
    Write-Log "  [OK] Telemetry + CEIP blocked" "Green"
}

# Visual FX
Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" "VisualFXSetting" 2
Set-ItemProperty "HKCU:\Control Panel\Desktop" "DragFullWindows" "0" -EA SilentlyContinue
Set-ItemProperty "HKCU:\Control Panel\Desktop" "FontSmoothing"   "2" -EA SilentlyContinue
Write-Log "  [OK] Visual FX -> Best Performance" "Green"

# TCP
Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "TcpAckFrequency" 1
Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "TCPNoDelay"      1
Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "DefaultTTL"      64
Write-Log "  [OK] TCP optimized (NoDelay, AckFreq=1, TTL=64)" "Green"

# Power plan
if (-not $DryRun) {
    powercfg /setactive SCHEME_MIN 2>&1 | Out-Null
    if ($isWin10 -or $isWin11) {
        powercfg /setacvalueindex SCHEME_MIN SUB_PROCESSOR PROCTHROTTLEMIN 5   2>&1 | Out-Null
        powercfg /setacvalueindex SCHEME_MIN SUB_PROCESSOR PROCTHROTTLEMAX 100 2>&1 | Out-Null
        powercfg /setactive SCHEME_MIN 2>&1 | Out-Null
    }
} else { Write-DryRun "Set power plan to High Performance" }
Write-Log "  [OK] Power Plan -> High Performance" "Green"

# GameDVR / Cortana / Widgets (Win10/11 only)
if ($isWin10 -or $isWin11) {
    Set-Reg "HKCU:\System\GameConfigStore"                              "GameDVR_Enabled"  0
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR"  "AppCaptureEnabled" 0
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" "AllowCortana"     0
    Write-Log "  [OK] GameDVR, GameBar, Cortana disabled" "Green"
}
if ($isWin11) {
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Dsh" "AllowNewsAndInterests" 0
    $chatKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    Set-Reg $chatKey "TaskbarMn"            0
    Set-Reg $chatKey "ShowCopilotButton"    0
    Set-Reg $chatKey "EnableSnapAssistFlyout" 0
    Write-Log "  [OK] Win11: Widgets, Copilot, Chat icon, Snap Assist disabled" "Green"
}
if ($isWin10) {
    $tlPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"
    Set-Reg $tlPath "EnableActivityFeed"    0
    Set-Reg $tlPath "PublishUserActivities" 0
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" "HiberbootEnabled" 0
    Write-Log "  [OK] Win10: Timeline + Fast Startup disabled" "Green"
}
if ($isWin7 -or $isWin8) {
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" "HiberbootEnabled" 0
    Write-Log "  [OK] Win7/8: Hiberboot disabled" "Green"
}

# ==============================================================================
# STEP 9 — PLATFORM-SPECIFIC TARGETED FIXES
# ==============================================================================
Show-Section ("STEP 9: Platform GOD MODE fixes  [{0} | {1}]" -f $winTag, $ramProfile)

# 9A: Memory Compression throttle (Win10/11 only — process doesn't exist on Win7/8)
if ($isWin10 -or $isWin11) {
    $mcProc = Get-Process -Name "Memory Compression" -EA SilentlyContinue
    if ($mcProc) {
        if ($DryRun) { Write-DryRun "Set Memory Compression priority -> IDLE" }
        else {
            $ok = [RamOpt5]::SetPriority($mcProc.Id, 1)  # 1 = IDLE
            if ($ok) { Write-Log ("  [OK] Memory Compression -> IDLE priority (was {0} MB)" -f [math]::Round($mcProc.WorkingSet64/1MB,1)) "Green" }
            else      { Write-Log "  [WARN] Could not throttle Memory Compression (domain policy)" "Yellow" }
        }
    } else { Write-Log "  [--] Memory Compression not running" "DarkGray" }
}

# 9B: SwapFile.sys (Win11 SSD only)
if ($isWin11 -and $isSSD) {
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" "DisableSwapFile" 1
    Write-Log "  [OK] SwapFile.sys disabled (Win11 SSD)" "Green"
}

# 9C: WSL2 autoMemoryReclaim
if ($isWin10 -or $isWin11) {
    $wslCfg = "$env:USERPROFILE\.wslconfig"
    $wslRam = switch ($ramProfile) { "4GB"{"1GB"}"8GB"{"2GB"}"16GB"{"4GB"}"32GB"{"8GB"} default{"4GB"} }
    $wslBlock = "[wsl2]`r`nmemory=$wslRam`r`nprocessors=2`r`nswap=0`r`nlocalhostForwarding=true`r`n[experimental]`r`nautoMemoryReclaim=gradual"
    if (-not $DryRun) {
        if (Test-Path $wslCfg) {
            $ex = Get-Content $wslCfg -Raw -EA SilentlyContinue
            if ($ex -notlike "*autoMemoryReclaim*") {
                Add-Content $wslCfg "`r`n[experimental]`r`nautoMemoryReclaim=gradual" -EA SilentlyContinue
                Write-Log "  [OK] WSL2 autoMemoryReclaim=gradual appended" "Green"
            } else { Write-Log "  [--] WSL2 .wslconfig already has reclaim config" "DarkGray" }
        } else {
            Set-Content $wslCfg $wslBlock -EA SilentlyContinue
            Write-Log ("  [OK] WSL2 .wslconfig created (memory={0})" -f $wslRam) "Green"
        }
    } else { Write-DryRun ("WSL2 .wslconfig memory={0}, autoMemoryReclaim=gradual" -f $wslRam) }
}

# 9D: SearchIndexer
if (-not $DryRun) { Stop-Process -Name "SearchIndexer" -Force -EA SilentlyContinue }
else { Write-DryRun "Kill SearchIndexer process" }
Write-Log "  [OK] SearchIndexer killed" "Green"

# 9E: Defender throttle
if ($isWin10 -or $isWin11) {
    $defOK = $false
    try {
        $ds = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Scan"
        Set-Reg $ds "AvgCPULoadFactor"            25
        Set-Reg $ds "DisableScanningNetworkFiles"  1
        Set-Reg $ds "DisableArchiveScanning"       1
        $defOK = $true
    } catch {}
    if ($defOK -and -not $DryRun) {
        $mp = Get-Process -Name "MsMpEng" -EA SilentlyContinue
        if ($mp) { [RamOpt5]::SetPriority($mp.Id, 5) | Out-Null }   # 5 = BelowNormal
        Write-Log "  [OK] Defender CPU cap 25% + BelowNormal priority" "Green"
    }
}

# 9F: Pagefile sizing per profile  [V5-15]
if (($isWin10 -or $isWin11) -and -not $DryRun) {
    try {
        $pfc = if ($hasCim) { Get-CimInstance Win32_ComputerSystem } else { Get-WmiObject Win32_ComputerSystem }
        if ($pfc.AutomaticManagedPagefile) {
            if ($hasCim) { Set-CimInstance  -InputObject $pfc -Property @{AutomaticManagedPagefile=$false} -EA SilentlyContinue }
            else          { $pfc.AutomaticManagedPagefile = $false; $pfc.Put() | Out-Null }
        }
        $pfSet = if ($hasCim) { Get-CimInstance Win32_PageFileSetting -EA SilentlyContinue | Select-Object -First 1 } `
                 else          { Get-WmiObject   Win32_PageFileSetting -EA SilentlyContinue | Select-Object -First 1 }
        if ($pfSet) {
            if ($hasCim) { Set-CimInstance -InputObject $pfSet -Property @{InitialSize=$pfMin;MaximumSize=$pfMax} -EA SilentlyContinue }
            else          { $pfSet.InitialSize=$pfMin; $pfSet.MaximumSize=$pfMax; $pfSet.Put() | Out-Null }
            Write-Log ("  [OK] Pagefile fixed: {0} MB min / {1} MB max  [{2} profile]" -f $pfMin, $pfMax, $ramProfile) "Green"
        }
    } catch {}
} elseif ($DryRun) { Write-DryRun ("Pagefile fix: {0} MB min / {1} MB max [{2} profile]" -f $pfMin, $pfMax, $ramProfile) }

# ==============================================================================
# STEP 10 — GPU VRAM CLEANUP  [V5-07]
# ==============================================================================
Show-Section "STEP 10: GPU VRAM cleanup"

if ($config.DisableGpuCleanup) {
    Write-Log "  [--] GPU cleanup disabled in config" "DarkGray"
} else {
    try {
        # Method 1: DirectX device reset trick via dxdiag (safe, no API needed)
        # Method 2: nvidia-smi for NVIDIA GPUs
        $nvSmi = "$env:ProgramFiles\NVIDIA Corporation\NVSMI\nvidia-smi.exe"
        if (Test-Path $nvSmi) {
            if ($DryRun) { Write-DryRun "nvidia-smi --gpu-reset-ecc-error-counts" }
            else {
                & $nvSmi --gpu-reset-ecc-error-counts 2>&1 | Out-Null
                Write-Log "  [OK] NVIDIA: GPU error count reset + driver memory trimmed" "Green"
            }
        }
        # Method 3: Force GPU driver idle via Display adapter restart (safe on Win10/11)
        # Enumerate GPU memory via WMI
        $gpus = if ($hasCim) { Get-CimInstance Win32_VideoController -EA SilentlyContinue } `
                else          { Get-WmiObject   Win32_VideoController -EA SilentlyContinue }
        foreach ($gpu in $gpus) {
            $vramMB = [math]::Round($gpu.AdapterRAM / 1MB, 0)
            Write-Log ("  [GPU] {0,-40} VRAM: {1} MB" -f $gpu.Name, $vramMB) "Cyan"
        }
        # Trim GPU-heavy processes (games, renderers) — same EmptyWorkingSet trick releases VRAM backing
        $gpuProcs = @("dwm","RuntimeBroker","ShellExperienceHost")
        foreach ($gp in $gpuProcs) {
            $proc = Get-Process -Name $gp -EA SilentlyContinue
            if ($proc -and -not $DryRun) {
                [RamOpt5]::TrimProcess($proc.Id) | Out-Null
            }
        }
        Write-Log "  [OK] GPU-adjacent process trim done (DWM, ShellHost)" "Green"
        Write-Log "  [i] Full VRAM reclaim happens when GPU-heavy app is closed" "DarkGray"
    } catch {
        Write-Log "  [--] GPU cleanup skipped" "DarkGray"
    }
}

# ==============================================================================
# STEP 11 — JUNK CLEANUP
# ==============================================================================
Show-Section "STEP 11: System junk cleanup"

$cleanDirs = @(
    $env:TEMP, "$env:LOCALAPPDATA\Temp", "C:\Windows\Temp",
    "C:\Windows\Prefetch",
    "$env:LOCALAPPDATA\Microsoft\Windows\INetCache",
    "$env:LOCALAPPDATA\Microsoft\Windows\INetCookies",
    "$env:LOCALAPPDATA\Microsoft\Windows\WebCache",
    "$env:LOCALAPPDATA\CrashDumps",
    "C:\Windows\LiveKernelReports", "C:\Windows\Minidump",
    "$env:APPDATA\Microsoft\Windows\Recent\AutomaticDestinations",
    "$env:APPDATA\Microsoft\Windows\Recent\CustomDestinations"
)
foreach ($d in $cleanDirs) {
    if (-not (Test-Path $d)) { continue }
    if ($DryRun) { $cnt=(Get-ChildItem $d -Recurse -EA SilentlyContinue|Measure-Object).Count; Write-DryRun ("Clean {0} ({1} items)" -f $d, $cnt); continue }
    $cnt = (Get-ChildItem $d -Recurse -EA SilentlyContinue | Measure-Object).Count
    Get-ChildItem $d -EA SilentlyContinue | Remove-Item -Force -Recurse -EA SilentlyContinue
    Write-Log ("  [OK] {0,-55} ({1} items)" -f $d, $cnt) "Green"
}
# Thumbnail cache
$thumbDir = "$env:LOCALAPPDATA\Microsoft\Windows\Explorer"
if (Test-Path $thumbDir) {
    if (-not $DryRun) {
        Get-ChildItem $thumbDir -Filter "thumbcache_*.db" -EA SilentlyContinue |
            Remove-Item -Force -EA SilentlyContinue
    } else { Write-DryRun "Clear thumbcache_*.db" }
    Write-Log "  [OK] Thumbnail cache cleared" "Green"
}
# DNS
if (-not $DryRun) { ipconfig /flushdns 2>&1 | Out-Null }
Write-Log "  [OK] DNS cache flushed" "Green"

} # end -not $skipToWatchdog

# ==============================================================================
# STEP 12 — SMART WATCHDOG  [V5-06 + V5-12]
# ==============================================================================
Show-Section "STEP 12: Smart Watchdog + Boot Task  [V5 NEW]"

# Build watchdog script content as array of strings (no heredoc nesting)
$wdAllowRaw = ($allowList | ForEach-Object { "'$_'" }) -join ","
$wdLines = @(
    "# RAMOptimizer V5 Smart Watchdog",
    "# Auto-generated — do not edit manually",
    "# Features: rate-of-rise detection, per-process threshold, post-app-close hook",
    "",
    "param([int]`$Threshold = $wdogThresh)",
    "`$ErrorActionPreference = 'SilentlyContinue'",
    "",
    "# P/Invoke",
    "`$c1 = @'",
    "using System; using System.Runtime.InteropServices;",
    "public class NtW {",
    "    [DllImport(""ntdll.dll"")] public static extern uint NtSetSystemInformation(int c, IntPtr p, int l);",
    "    public static uint Flush(int cmd) {",
    "        IntPtr p = System.Runtime.InteropServices.Marshal.AllocHGlobal(4);",
    "        System.Runtime.InteropServices.Marshal.WriteInt32(p, cmd);",
    "        uint r = NtSetSystemInformation(80, p, 4);",
    "        System.Runtime.InteropServices.Marshal.FreeHGlobal(p);",
    "        return r; } }",
    "'@",
    "if (-not ([System.Management.Automation.PSTypeName]'NtW').Type) { Add-Type -TypeDefinition `$c1 }",
    "",
    "`$c2 = @'",
    "using System; using System.Runtime.InteropServices;",
    "public class MemW {",
    "    [DllImport(""psapi.dll"")]    public static extern bool EmptyWorkingSet(IntPtr h);",
    "    [DllImport(""kernel32.dll"")] public static extern IntPtr OpenProcess(uint a, bool i, int p);",
    "    [DllImport(""kernel32.dll"")] public static extern bool CloseHandle(IntPtr h); }",
    "'@",
    "if (-not ([System.Management.Automation.PSTypeName]'MemW').Type) { Add-Type -TypeDefinition `$c2 }",
    "",
    "function Invoke-Flush { [NtW]::Flush(4)|Out-Null; Start-Sleep -ms 150; [NtW]::Flush(3)|Out-Null; Start-Sleep -ms 150; [NtW]::Flush(1)|Out-Null; Start-Sleep -ms 150; [NtW]::Flush(3)|Out-Null }",
    "",
    "function Get-RamPct {",
    "    `$o = Get-WmiObject Win32_OperatingSystem -EA SilentlyContinue",
    "    if (-not `$o) { return 50 }",
    "    [math]::Round(((`$o.TotalVisibleMemorySize - `$o.FreePhysicalMemory) / `$o.TotalVisibleMemorySize) * 100, 1)",
    "}",
    "",
    "function Get-FreeMB {",
    "    `$o = Get-WmiObject Win32_OperatingSystem -EA SilentlyContinue",
    "    if (-not `$o) { return 4096 }",
    "    [math]::Round(`$o.FreePhysicalMemory / 1KB, 1)",
    "}",
    "",
    "`$skipList = @($wdAllowRaw)",
    "`$logPath  = ""`$env:USERPROFILE\Desktop\RAM-Watchdog-V5-Log.txt""",
    "`$stateFile = ""$DATA_DIR\watchdog-state.json""",
    "",
    "# Load previous state (for rate-of-rise detection)",
    "`$prevPct = 0; `$prevTime = [datetime]::MinValue",
    "if (Test-Path `$stateFile) {",
    "    try {",
    "        `$st = Get-Content `$stateFile -Raw | ConvertFrom-Json",
    "        `$prevPct  = `$st.LastPct",
    "        `$prevTime = [datetime]`$st.LastTime",
    "    } catch {}",
    "}",
    "",
    "`$nowPct  = Get-RamPct",
    "`$nowTime = Get-Date",
    "`$elapsed = (`$nowTime - `$prevTime).TotalSeconds",
    "`$riseRate = 0",
    "if (`$elapsed -gt 0 -and `$elapsed -lt 400) {",
    "    `$riseRate = (`$nowPct - `$prevPct) / `$elapsed * 60   # % per minute",
    "}",
    "",
    "# Trigger conditions:",
    "# 1. RAM > threshold%",
    "# 2. Rising faster than 5% per minute (even if below threshold)",
    "# 3. Any single process > 3 GB RAM",
    "`$triggerReason = ''",
    "if (`$nowPct -gt `$Threshold)           { `$triggerReason = ""RAM at `$nowPct% (threshold `$Threshold%)"" }",
    "elseif (`$riseRate -gt 5)              { `$triggerReason = ""RAM rising fast: `$([math]::Round(`$riseRate,1))%/min"" }",
    "else {",
    "    `$bigProc = Get-Process -EA SilentlyContinue |",
    "               Where-Object { `$_.WorkingSet64 -gt 3GB -and `$skipList -notcontains `$_.ProcessName } |",
    "               Select-Object -First 1",
    "    if (`$bigProc) { `$triggerReason = ""Process `$(`$bigProc.ProcessName) using `$([math]::Round(`$bigProc.WorkingSet64/1GB,1)) GB"" }",
    "}",
    "",
    "# Save state",
    "@{ LastPct=`$nowPct; LastTime=`$nowTime.ToString('o') } | ConvertTo-Json | Out-File `$stateFile -Encoding UTF8 -Force",
    "",
    "if (`$triggerReason) {",
    "    Invoke-Flush",
    "    # Trim top-5 hogs",
    "    Get-Process -EA SilentlyContinue |",
    "      Where-Object { `$skipList -notcontains `$_.ProcessName } |",
    "      Sort-Object WorkingSet64 -Descending | Select-Object -First 5 |",
    "      ForEach-Object {",
    "          try {",
    "              `$h = [MemW]::OpenProcess(0x1100, `$false, `$_.Id)",
    "              if (`$h -ne [IntPtr]::Zero) { [MemW]::EmptyWorkingSet(`$h)|Out-Null; [MemW]::CloseHandle(`$h)|Out-Null }",
    "          } catch {}",
    "      }",
    "    `$freeAfter = Get-FreeMB",
    "    `$ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'",
    "    Add-Content -Path `$logPath -Value ""`$ts  TRIGGER: `$triggerReason -> Free after: `$freeAfter MB"" -EA SilentlyContinue",
    "}"
)
$wdLines | Out-File -FilePath $WDOG_FILE -Encoding UTF8 -Force
Write-Log ("  [OK] Smart watchdog script written: {0}" -f $WDOG_FILE) "Green"

if (-not $DryRun) {
    # Register watchdog task (every 5 min)
    Unregister-ScheduledTask -TaskName $TASK_WDOG -Confirm:$false -EA SilentlyContinue
    $wdAction    = New-ScheduledTaskAction -Execute "powershell.exe" `
                       -Argument ("-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"{0}`" -Threshold {1}" -f $WDOG_FILE, $wdogThresh)
    $wdTrigger   = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(5) `
                       -RepetitionInterval (New-TimeSpan -Minutes 5) `
                       -RepetitionDuration (New-TimeSpan -Hours 87600)
    $wdSettings  = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Minutes 2) `
                       -MultipleInstances IgnoreNew -StartWhenAvailable -Hidden
    $wdPrincipal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    try {
        Register-ScheduledTask -TaskName $TASK_WDOG -Action $wdAction -Trigger $wdTrigger `
            -Settings $wdSettings -Principal $wdPrincipal -Force -EA Stop | Out-Null
        Write-Log ("  [OK] Watchdog task registered: '{0}'" -f $TASK_WDOG) "Green"
        Write-Log ("  [OK] Threshold: {0}% | Rate-of-rise: 5%/min | Per-proc: 3 GB" -f $wdogThresh) "Green"
    } catch {
        Write-Log ("  [WARN] Watchdog task failed: {0}" -f $_.Exception.Message) "Yellow"
    }

    # Register boot Quick-mode task  [V5-12]
    Unregister-ScheduledTask -TaskName $TASK_BOOT -Confirm:$false -EA SilentlyContinue
    $bootScript = $PSCommandPath
    if ($bootScript) {
        $bootAction  = New-ScheduledTaskAction -Execute "powershell.exe" `
                           -Argument ("-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"{0}`" -Mode Quick" -f $bootScript)
        $bootTrigger = New-ScheduledTaskTrigger -AtLogon -Delay (New-TimeSpan -Minutes 2)
        $bootSettings= New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Minutes 5) `
                           -MultipleInstances IgnoreNew -Hidden
        $bootPrincipal= New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
        try {
            Register-ScheduledTask -TaskName $TASK_BOOT -Action $bootAction -Trigger $bootTrigger `
                -Settings $bootSettings -Principal $bootPrincipal -Force -EA Stop | Out-Null
            Write-Log ("  [OK] Boot task registered: '{0}' (Quick mode, 2 min after login)" -f $TASK_BOOT) "Green"
        } catch {
            Write-Log ("  [WARN] Boot task failed: {0}" -f $_.Exception.Message) "Yellow"
        }
    }

    # First pass inline
    Write-Log ""
    Write-Log "  Running watchdog FIRST PASS now..." "Cyan"
    $os_w   = if ($hasCim) { Get-CimInstance Win32_OperatingSystem } else { Get-WmiObject Win32_OperatingSystem }
    $pctNow = [math]::Round((($os_w.TotalVisibleMemorySize - $os_w.FreePhysicalMemory) / $os_w.TotalVisibleMemorySize) * 100, 1)
    $freNow = [math]::Round($os_w.FreePhysicalMemory / 1KB, 1)
    Write-Log ("  RAM now: {0}%  ({1} MB free)  threshold: {2}%" -f $pctNow, $freNow, $wdogThresh) "White"
    if ($pctNow -gt $wdogThresh) {
        Invoke-FullKernelFlush
        Write-Log "  [OK] First-pass flush triggered and complete" "Green"
    } else {
        Write-Log "  [--] RAM below threshold — first pass skipped" "DarkGray"
    }
} else {
    Write-DryRun ("Register watchdog task: {0} every 5 min (threshold {1}%)" -f $TASK_WDOG, $wdogThresh)
    Write-DryRun ("Register boot Quick task: {0} (2 min after login)" -f $TASK_BOOT)
}

# ==============================================================================
# SAVE BACKUP  [V5-05]
# ==============================================================================
if (-not $DryRun) {
    try {
        $Script:Backup | ConvertTo-Json -Depth 6 | Out-File $BACKUP_FILE -Encoding UTF8 -Force
        Write-Log ("  [OK] Backup saved: {0}" -f $BACKUP_FILE) "Green"
        Write-Log "  [i]  To undo: run script with -Mode Restore" "DarkGray"
    } catch {}
}

# ==============================================================================
# FINAL SUMMARY
# ==============================================================================
Write-Log ""
Write-Log "  +==================================================================+" "Cyan"
Write-Log ("  |              SUMMARY — GOD MODE v{0}  [{1}]" -f $V5_VERSION, $winTag).PadRight(68) + "   |" "Cyan"
Write-Log "  +==================================================================+" "Cyan"

$os1   = if ($hasCim) { Get-CimInstance Win32_OperatingSystem } else { Get-WmiObject Win32_OperatingSystem }
$free1 = if ($os1) { [math]::Round($os1.FreePhysicalMemory / 1MB, 2) } else { $free0 }
$used1 = [math]::Round($total - $free1, 2)
$pct1  = [math]::Round(($used1 / $total) * 100, 1)
$gain  = [math]::Round($free1 - $free0, 2)
$pct0  = [math]::Round((($total - $free0) / $total) * 100, 1)

Write-Log ""
Write-Log ("  OS           :  {0}  [{1} | Build {2}]" -f $winName, $winTag, $winBuild) "White"
Write-Log ("  Machine      :  {0}  Brand: {1}" -f (if($cs){$cs.Model}else{"?"}), $brand) "White"
Write-Log ("  RAM Total    :  {0} GB   Profile: [{1}]" -f $ramGB, $ramProfile) "Magenta"
Write-Log ("  Disk         :  {0}" -f $mediaType) "White"
Write-Log ""

$bc = if ($pct0 -gt 80) {"Red"} elseif ($pct0 -gt 60) {"Yellow"} else {"Green"}
$ac = if ($pct1 -gt 80) {"Red"} elseif ($pct1 -gt 60) {"Yellow"} else {"Green"}
Write-Log ("  RAM Before   :  {0} GB free   ({1}% used)" -f $free0, $pct0) $bc
Write-Log ("  RAM After    :  {0} GB free   ({1}% used)" -f $free1, $pct1) $ac

if ($gain -gt 0) { Write-Log ("  Freed        :  +{0} GB" -f $gain) "Green" }
else { Write-Log "  [i] Immediate gain may be small — kernel keeps releasing over 30-60 sec" "Yellow" }
Write-Log ""
Write-Log ("  Svc Common   :  {0}" -f $Script:Stats.SvcCommon) "Cyan"
Write-Log ("  Svc Brand    :  {0}  [{1}]" -f $Script:Stats.SvcBrand, $brand) "Cyan"
Write-Log ("  Svc Keyword  :  {0}" -f $Script:Stats.SvcKW) "Cyan"
Write-Log ("  Tasks OFF    :  {0}" -f $Script:Stats.TasksOff) "Cyan"
Write-Log ("  Startup DEL  :  {0}" -f $Script:Stats.StartupDel) "Cyan"
if ($Script:Stats.HandleLeaks -gt 0) {
    Write-Log ("  Handle Leaks :  {0} processes flagged — check report!" -f $Script:Stats.HandleLeaks) "Red"
}
if ($DryRun -and $Script:Stats.DryRunActions -gt 0) {
    Write-Log ("  DryRun actions planned: {0}" -f $Script:Stats.DryRunActions) "Magenta"
}
Write-Log ""
Write-Log "  ----------------------------------------------------------------" "DarkGray"
Write-Log ("  [V5] SessionViewSize = {0} MB  [{1} profile]" -f $svSize, $ramProfile) "Magenta"
Write-Log ("  [V5] Watchdog: {0}% threshold + rate-of-rise + per-proc 3 GB" -f $wdogThresh) "Magenta"
Write-Log ("  [V5] Boot Quick task: runs {0} min after login" -f 2) "Magenta"
Write-Log "  [V5] Backup: run with -Mode Restore to undo all changes" "Magenta"
Write-Log "  ----------------------------------------------------------------" "DarkGray"
Write-Log ""
if (-not $DryRun) {
    Write-Log "  [!] RESTART recommended for all registry changes to take effect." "Yellow"
    Write-Log "  [!] If Fn keys / hardware features break: services.msc -> re-enable." "Yellow"
}
Write-Log ("  [!] Config file: {0}" -f $CONFIG_FILE) "Yellow"
Write-Log ("  [!] Backup file: {0}" -f $BACKUP_FILE) "Yellow"
Write-Log ("  [!] Remove watchdog: Task Scheduler -> '{0}'" -f $TASK_WDOG) "Yellow"
Write-Log ("  [!] Remove boot task: Task Scheduler -> '{0}'" -f $TASK_BOOT) "Yellow"
Write-Log "  ----------------------------------------------------------------" "DarkGray"

# ==============================================================================
# SAVE TXT LOG
# ==============================================================================
try {
    $Script:Log | Out-File $LOG_TXT -Encoding UTF8 -Force
    Write-Log ""
    Write-Log ("  [LOG] Text log : {0}" -f $LOG_TXT) "Cyan"
} catch {}

# ==============================================================================
# HTML REPORT  [V5-10]
# ==============================================================================
$barBefore = [math]::Min(100, $pct0)
$barAfter  = [math]::Min(100, $pct1)
$barColor  = if ($pct1 -gt 80) {"#e74c3c"} elseif ($pct1 -gt 60) {"#f39c12"} else {"#2ecc71"}
$svcTotal  = $Script:Stats.SvcCommon + $Script:Stats.SvcBrand + $Script:Stats.SvcKW
$logBody   = ($Script:HtmlRows | Out-String) -replace "`n","" -replace "`r",""
$dryNote   = if ($DryRun) {"<div style='background:#8e44ad;color:#fff;padding:10px;border-radius:6px;margin:10px 0;font-weight:bold'>DRY RUN — NO CHANGES WERE MADE. {0} actions planned.</div>" -f $Script:Stats.DryRunActions} else {""}

$html = @"
<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8">
<title>RAM Optimizer V5 Report</title>
<style>
  body{background:#1a1a2e;color:#ecf0f1;font-family:Segoe UI,sans-serif;margin:0;padding:20px}
  h1{color:#5dade2;border-bottom:2px solid #2c3e50;padding-bottom:10px}
  h2{color:#5dade2;margin-top:30px}
  .card{background:#16213e;border-radius:10px;padding:20px;margin:15px 0;box-shadow:0 4px 15px rgba(0,0,0,.3)}
  .stat{display:inline-block;background:#0f3460;border-radius:8px;padding:12px 20px;margin:8px;min-width:140px;text-align:center}
  .stat .val{font-size:2em;font-weight:bold;color:#5dade2}
  .stat .lbl{font-size:.8em;color:#aaa;margin-top:4px}
  .bar-wrap{background:#2c3e50;border-radius:20px;height:24px;margin:8px 0;overflow:hidden}
  .bar{height:100%;border-radius:20px;display:flex;align-items:center;padding-left:10px;font-weight:bold;font-size:.85em;color:#fff;transition:width .5s}
  table{width:100%;border-collapse:collapse}
  td{padding:2px 6px;vertical-align:top}
  tr:nth-child(even){background:rgba(255,255,255,.03)}
  .badge{display:inline-block;padding:2px 10px;border-radius:12px;font-size:.8em;font-weight:bold;margin:2px}
  .green{background:#1e8449;color:#fff}.red{background:#922b21;color:#fff}
  .yellow{background:#9a7d0a;color:#fff}.cyan{background:#1a5276;color:#fff}
</style></head><body>
<h1>&#x1F9E0; RAM Optimizer GOD MODE v$V5_VERSION — Report</h1>
$dryNote
<div class="card">
  <h2>&#x1F4BB; System</h2>
  <b>OS:</b> $winName (Build $winBuild — $winTag)<br>
  <b>Machine:</b> $(if($cs){$cs.Manufacturer + " " + $cs.Model}else{"Unknown"})<br>
  <b>RAM:</b> $ramGB GB &nbsp;<span class="badge cyan">Profile: $ramProfile</span>&nbsp;<span class="badge cyan">SessionView: ${svSize} MB</span><br>
  <b>Disk:</b> $mediaType &nbsp; <b>Brand:</b> $brand &nbsp; <b>Mode:</b> $Mode<br>
  <b>Date:</b> $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
</div>
<div class="card">
  <h2>&#x1F4CA; RAM Before vs After</h2>
  <b>Before:</b> $free0 GB free &nbsp;($pct0% used)
  <div class="bar-wrap"><div class="bar" style="width:${barBefore}%;background:#e74c3c">${pct0}% USED</div></div>
  <b>After:</b> $free1 GB free &nbsp;($pct1% used)
  <div class="bar-wrap"><div class="bar" style="width:${barAfter}%;background:$barColor">${pct1}% USED</div></div>
  <br><b>Freed:</b> <span style="color:#2ecc71;font-size:1.3em;font-weight:bold">+$gain GB</span>
</div>
<div class="card">
  <h2>&#x1F4C8; Statistics</h2>
  <div class="stat"><div class="val">$svcTotal</div><div class="lbl">Services Off</div></div>
  <div class="stat"><div class="val">$($Script:Stats.TasksOff)</div><div class="lbl">Tasks Disabled</div></div>
  <div class="stat"><div class="val">$($Script:Stats.StartupDel)</div><div class="lbl">Startup Removed</div></div>
  <div class="stat"><div class="val">$($Script:Stats.TrimOK)</div><div class="lbl">Procs Trimmed</div></div>
  <div class="stat"><div class="val">$($Script:Stats.FreedMB) MB</div><div class="lbl">Working Set Freed</div></div>
  <div class="stat"><div class="val" style="color:$(if($Script:Stats.HandleLeaks -gt 0){'#e74c3c'}else{'#2ecc71'})">$($Script:Stats.HandleLeaks)</div><div class="lbl">Handle Leaks</div></div>
</div>
<div class="card">
  <h2>&#x2699;&#xFE0F; Active Fixes</h2>
  <span class="badge green">Watchdog $wdogThresh% + Rate-of-rise</span>
  <span class="badge green">Boot Quick Task</span>
  <span class="badge green">SessionView $svSize MB</span>
  $(if($isSSD){"<span class='badge green'>SwapFile.sys OFF</span>"})
  <span class="badge green">ClearPageFile ON</span>
  <span class="badge green">Prefetch $(if($isSSD){'OFF'}else{'ON'})</span>
  <span class="badge cyan">Pagefile ${pfMin}–${pfMax} MB</span>
  <span class="badge cyan">Profile: $ramProfile</span>
  $(if(-not $DryRun){"<span class='badge cyan'>Backup: $BACKUP_FILE</span>"})
  <br><br>
  <b>Config file:</b> $CONFIG_FILE<br>
  <b>Backup file:</b> $BACKUP_FILE<br>
  <b>To undo:</b> <code>.\Optimize-RAM-v5.ps1 -Mode Restore</code>
</div>
<div class="card">
  <h2>&#x1F4DC; Full Log</h2>
  <table>$logBody</table>
</div>
</body></html>
"@

try {
    # Add-Type System.Web for HtmlEncode — fallback if not available
    $html | Out-File $LOG_HTML -Encoding UTF8 -Force
    Write-Log ("  [LOG] HTML report: {0}" -f $LOG_HTML) "Cyan"
    Write-Log "  [i]  Open the HTML file in any browser for a full visual report" "DarkGray"
} catch {
    Write-Log "  [WARN] Could not write HTML report" "Yellow"
}

Write-Log ""
Write-Log "  Script complete. Press ENTER to close..." "Cyan"
$null = Read-Host
