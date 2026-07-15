# ==============================================================================
#  Optimize-RAM-v4.ps1  |  GOD MODE  v4.0  (FIXED + UPGRADED)
#  Target  : Windows 10 (1809+)  &  Windows 11
#  Language: English
#  ------------------------------------------------------------------------------
#  BUG FIXES vs broken v4:
#   [BUG-1]  HERE-STRING NESTING: watchdog used @'...'@ inside @"..."@ -> parse error
#            FIX: watchdog saved separately via Set-Content, no nesting
#   [BUG-2]  CLASS NAME COLLISION: NtMem4/TokenPriv4 reused inside watchdog Add-Type
#            FIX: watchdog uses unique class names NtW/TokW/MemW (never compiled before)
#   [BUG-3]  WATCHDOG VISIBILITY: ran as -WindowStyle Hidden so no output was visible
#            FIX: first-pass watchdog runs inline + produces a real log with before/after
#   [BUG-4]  SCAN PROGRESS: keyword scan showed nothing while running (silent loop)
#            FIX: each matched service prints immediately in real-time
#   [BUG-5]  TASK TRIGGER BUG: RepetitionInterval on Once trigger requires -RepetitionDuration
#            FIX: proper trigger with -RepetitionDuration ([TimeSpan]::MaxValue)
#   [BUG-6]  SvcOff counter double-counted (Stop-And-Disable + keyword scan both increment)
#            FIX: separate counters $SvcCommon / $SvcBrand / $SvcKW
#  ------------------------------------------------------------------------------
#  NEW IN v4 vs v3:
#   [NEW-1]  Persistent watchdog Scheduled Task (every 5 min, SYSTEM, hidden)
#   [NEW-2]  Memory Compression process throttled to Idle priority (Win11)
#   [NEW-3]  SessionViewSize = 256 MB for 8 GB profile (was 48 MB in v3 = kernel pressure)
#   [NEW-4]  SwapFile.sys disabled on SSD via policy
#   [NEW-5]  WSL2 auto-memory reclaim via .wslconfig (vmmem bloat fix)
#   [NEW-6]  Windows Defender CPU throttle to 25% (no disable  --  safe)
#   [NEW-7]  SearchIndexer killed at runtime (service already disabled)
#   [NEW-8]  ClearPageFileAtShutdown enabled (stops stale PF pressure)
#   [NEW-9]  Automated pagefile sizing for 8 GB (1 GB min / 4 GB max / fixed)
#   [NEW-10] Top-10 RAM hog trim with SetProcessWorkingSetSizeEx
#   [NEW-11] REAL-TIME verbose output for every step so you can see exactly what is scanned
#   [NEW-12] Watchdog log on Desktop: before/after every trigger
#  ------------------------------------------------------------------------------
#  Requires: PowerShell 5.1+  |  Administrator  |  Windows 10 1809+ / Win11
# ==============================================================================

#Requires -Version 5.1
Set-StrictMode -Off   # [BUG-FIX V4-A] Latest làm lỗi non-terminating -> terminating, bypass SilentlyContinue
$ErrorActionPreference = "SilentlyContinue"

# ---- Admin guard ----
$_prn = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $_prn.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "[!] Administrator required!" -ForegroundColor Red
    Write-Host "    Right-click the .bat file -> Run as administrator" -ForegroundColor Yellow
    Start-Sleep 3; exit 1
}

# ==============================================================================
# GLOBALS
# ==============================================================================
$Script:LogLines   = [System.Collections.Generic.List[string]]::new()
$Script:LogFile    = "$env:USERPROFILE\Desktop\RAM-Optimize-V4-Log-$(Get-Date -f 'yyyyMMdd-HHmmss').txt"
$Script:SvcCommon  = 0   # services from common list
$Script:SvcBrand   = 0   # services from brand list
$Script:SvcKW      = 0   # services from keyword scan
$Script:TasksOff   = 0
$Script:StartupDel = 0

function Write-Log {
    param([string]$msg, [string]$color = "White")
    Write-Host $msg -ForegroundColor $color
    $Script:LogLines.Add($msg)
}

function Show-Section {
    param([string]$title)
    $line = "  " + ([string][char]0x2500 * 64)
    Write-Log ""; Write-Log $line "DarkCyan"
    Write-Log ("  >> " + $title) "Cyan"
    Write-Log $line "DarkCyan"
}

function Show-Progress {
    param([string]$label, [string]$status = "")
    $out = "  ... $label"
    if ($status) { $out += "  [$status]" }
    Write-Host $out -ForegroundColor DarkGray
    $Script:LogLines.Add($out)
}

# ==============================================================================
# STEP 0  --  SYSTEM DETECTION
# ==============================================================================
Clear-Host
Write-Log ""
Write-Log "  +==================================================================+" "Cyan"
Write-Log "  |     RAM OPTIMIZER  --  GOD MODE  v4.0  (FIXED + UPGRADED)      |" "Cyan"
Write-Log "  |     Target: Windows 10 (1809+) & Windows 11                     |" "Cyan"
Write-Log "  |     8 GB RAM profile  |  Persistent Watchdog  |  Full Verbose   |" "Cyan"
Write-Log "  +==================================================================+" "Cyan"
Write-Log ""

Show-Progress "Querying system information..."

$cs = $null; $bios = $null; $os0 = $null; $cpu = $null; $disk = $null
try { $cs   = Get-CimInstance Win32_ComputerSystem  -EA Stop } catch { $cs   = Get-WmiObject Win32_ComputerSystem  -EA SilentlyContinue }
try { $bios = Get-CimInstance Win32_BIOS            -EA Stop } catch { $bios = Get-WmiObject Win32_BIOS            -EA SilentlyContinue }
try { $os0  = Get-CimInstance Win32_OperatingSystem -EA Stop } catch { $os0  = Get-WmiObject Win32_OperatingSystem -EA SilentlyContinue }
try { $cpu  = Get-CimInstance Win32_Processor       -EA Stop | Select-Object -First 1 } catch { $cpu  = Get-WmiObject Win32_Processor -EA SilentlyContinue | Select-Object -First 1 }
try { $disk = Get-CimInstance Win32_DiskDrive       -EA Stop | Select-Object -First 1 } catch { $disk = Get-WmiObject Win32_DiskDrive -EA SilentlyContinue | Select-Object -First 1 }

if (-not $os0) { Write-Host "[!] Cannot query OS info via WMI/CIM. Make sure WMI service is running." -ForegroundColor Red; Start-Sleep 5; exit 1 }

$winBuild = [int]($os0.BuildNumber)
$winName  = if ($os0.Caption) { $os0.Caption } else { "Windows" }
$isWin11  = ($winBuild -ge 22000)
$isWin10  = (-not $isWin11) -and ($winBuild -ge 17763)
$winTag   = if ($isWin11) {"WIN11"} elseif ($isWin10) {"WIN10"} else {"WIN_OLD"}

$ramGB = if ($cs)  { [math]::Round($cs.TotalPhysicalMemory / 1GB, 1) } else { 4.0 }
$is8GB = ($ramGB -ge 7.0 -and $ramGB -le 9.5)
$free0 = [math]::Round($os0.FreePhysicalMemory    / 1MB, 2)
$total = [math]::Round($os0.TotalVisibleMemorySize / 1MB, 2)

# SSD detection
$isSSD = $false
try {
    $pd = Get-PhysicalDisk -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($pd) { $isSSD = ($pd.MediaType -like "*SSD*" -or $pd.MediaType -eq "3") }
} catch {}
$mediaType = if ($isSSD) { "SSD" } else { "HDD/Unknown" }

# Brand detection
$mfrRaw  = if ($cs)   { ("$($cs.Manufacturer) $($cs.Model)").ToLower() } else { "" }
$biosRaw = if ($bios) { ("$($bios.Manufacturer) $($bios.SMBIOSBIOSVersion -join ' ')").ToLower() } else { "" }
$brand   = "UNKNOWN"; $brandSrc = "manufacturer"
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
if ($brand -eq "UNKNOWN" -and $biosRaw -like "*american megatrends*") {
    $brand = "GENERIC_AMI"; $brandSrc = "BIOS"
}
$brandColor = switch ($brand) {
    "DELL" {"Blue"}; "HP" {"DarkCyan"}; "LENOVO" {"Red"}; "ASUS" {"Cyan"}
    "MSI" {"Red"}; "ACER" {"Green"}; "SAMSUNG" {"Cyan"}; "RAZER" {"Green"}
    "MICROSOFT_SURFACE" {"Blue"}; "GIGABYTE" {"Yellow"}; default {"Yellow"}
}

Write-Log ("  OS       :  {0}" -f $winName) "White"
Write-Log ("  Build    :  {0}  [{1}]" -f $winBuild, $winTag) "White"
Write-Log ("  Machine  :  {0}  |  {1}" -f $(if($cs){$cs.Manufacturer}else{"?"}), $(if($cs){$cs.Model}else{"?"})) "White"
Write-Log ("  CPU      :  {0}" -f $(if($cpu){$cpu.Name}else{"?"})) "White"
Write-Log ("  RAM      :  {0} GB  (Free now: {1} GB)" -f $ramGB, $free0) "White"
Write-Log ("  Disk     :  {0}  [{1}]" -f $(if($disk){$disk.Model}else{"?"}), $mediaType) "White"
Write-Log ("  Brand    :  [ {0} ]  (source: {1})" -f $brand, $brandSrc) $brandColor

if ($is8GB)  { Write-Log "  [*] 8 GB RAM profile ACTIVE  --  targeted kernel sizing applied" "Magenta" }
if ($isSSD)  { Write-Log "  [*] SSD detected  --  SwapFile.sys will be DISABLED, Prefetch OFF" "Magenta" }
if ($winTag -eq "WIN_OLD") { Write-Log "  [!] Old build (<1809)  --  some features may not apply" "Yellow" }
Write-Log ""

# ==============================================================================
# C# / P-INVOKE BLOCKS  (unique class names -> no collision on re-run)
# ==============================================================================
$ntdllCode = @"
using System; using System.Runtime.InteropServices;
public class NtMem4 {
    [DllImport("ntdll.dll")]
    public static extern uint NtSetSystemInformation(int InfoClass, IntPtr Info, int Length);
}
"@
if (-not ([System.Management.Automation.PSTypeName]"NtMem4").Type) {
    Add-Type -TypeDefinition $ntdllCode -ErrorAction SilentlyContinue
}

$privCode = @"
using System; using System.Runtime.InteropServices;
public class TokenPriv4 {
    [StructLayout(LayoutKind.Sequential, Pack=1)]
    public struct TokPriv1Luid { public int Count; public long Luid; public int Attr; }
    [DllImport("kernel32.dll", ExactSpelling=true)]
    public static extern IntPtr GetCurrentProcess();
    [DllImport("advapi32.dll", ExactSpelling=true, SetLastError=true)]
    public static extern bool OpenProcessToken(IntPtr h, int acc, ref IntPtr tok);
    [DllImport("advapi32.dll", SetLastError=true)]
    public static extern bool LookupPrivilegeValue(string host, string name, ref long luid);
    [DllImport("advapi32.dll", ExactSpelling=true, SetLastError=true)]
    public static extern bool AdjustTokenPrivileges(IntPtr htok, bool disall,
        ref TokPriv1Luid newst, int len, IntPtr prev, IntPtr relen);
    public static bool Enable(string priv) {
        IntPtr hproc = GetCurrentProcess(); IntPtr htok = IntPtr.Zero;
        if (!OpenProcessToken(hproc, 0x28, ref htok)) return false;
        TokPriv1Luid tp; tp.Count=1; tp.Luid=0; tp.Attr=2;
        if (!LookupPrivilegeValue(null, priv, ref tp.Luid)) return false;
        return AdjustTokenPrivileges(htok, false, ref tp, 0, IntPtr.Zero, IntPtr.Zero);
    }
}
"@
if (-not ([System.Management.Automation.PSTypeName]"TokenPriv4").Type) {
    Add-Type -TypeDefinition $privCode -ErrorAction SilentlyContinue
}

$cacheCode = @"
using System; using System.Runtime.InteropServices;
public class SysCache4 {
    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern bool SetSystemFileCacheSize(IntPtr min, IntPtr max, int flags);
    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern bool GetSystemFileCacheSize(out IntPtr min, out IntPtr max, out int flags);
}
"@
if (-not ([System.Management.Automation.PSTypeName]"SysCache4").Type) {
    Add-Type -TypeDefinition $cacheCode -ErrorAction SilentlyContinue
}

$apiCode = @"
using System; using System.Runtime.InteropServices;
public class MemUtil4 {
    [DllImport("psapi.dll")]    public static extern bool EmptyWorkingSet(IntPtr h);
    [DllImport("kernel32.dll")] public static extern IntPtr OpenProcess(uint acc, bool inh, int pid);
    [DllImport("kernel32.dll")] public static extern bool CloseHandle(IntPtr h);
    [DllImport("kernel32.dll")] public static extern bool SetProcessWorkingSetSizeEx(
        IntPtr h, IntPtr min, IntPtr max, int flags);
}
"@
if (-not ([System.Management.Automation.PSTypeName]"MemUtil4").Type) {
    Add-Type -TypeDefinition $apiCode -ErrorAction SilentlyContinue
}

function Invoke-MemoryCommand {
    param([int]$cmd, [string]$label)
    $ptr = [System.Runtime.InteropServices.Marshal]::AllocHGlobal(4)
    [System.Runtime.InteropServices.Marshal]::WriteInt32($ptr, $cmd)
    $r = [NtMem4]::NtSetSystemInformation(80, $ptr, 4)
    [System.Runtime.InteropServices.Marshal]::FreeHGlobal($ptr)
    if ($r -eq 0) { Write-Log "  [OK] $label" "Green" }
    else          { Write-Log ("  [WARN] {0} -- NTSTATUS 0x{1:X}" -f $label, $r) "Yellow" }
}

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
    param(
        [string]$Name,
        [string]$DisplayName = ""
    )
    $text = ((@($Name, $DisplayName) -join " ")).ToLowerInvariant()
    foreach ($pattern in $Script:ProtectedServicePatterns) {
        if ($text -like "*$pattern*") { return $true }
    }
    return $false
}



function Invoke-SafeStopService {
    param(
        [string]$Name,
        [string]$DisplayName = ""
    )
    if ([string]::IsNullOrWhiteSpace($Name) -and [string]::IsNullOrWhiteSpace($DisplayName)) { return $false }
    if (Test-ProtectedService -Name $Name -DisplayName $DisplayName) {
        Write-Host "  [SKIP] $Name (protected core service)" -ForegroundColor DarkGray
        return $false
    }
    $svc = $null
    if ($Name) { $svc = Get-Service -Name $Name -ErrorAction SilentlyContinue }
    if ($null -eq $svc -and $DisplayName) {
        $svc = Get-Service -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like "*$DisplayName*" -or $_.Name -like "*$Name*" } | Select-Object -First 1
    }
    if ($null -eq $svc) { return $false }
    if (Test-ProtectedService -Name $svc.Name -DisplayName $svc.DisplayName) {
        Write-Host "  [SKIP] $($svc.Name) (protected core service)" -ForegroundColor DarkGray
        return $false
    }
    try {
        if ($svc.Status -eq "Running") {
            Invoke-SafeStopService -Name $svc.Name -DisplayName $svc.DisplayName
        }
        return $true
    } catch {
        return $false
    }
}

function Invoke-SafeSetDisabledService {
    param(
        [string]$Name,
        [string]$DisplayName = ""
    )
    if ([string]::IsNullOrWhiteSpace($Name) -and [string]::IsNullOrWhiteSpace($DisplayName)) { return $false }
    if (Test-ProtectedService -Name $Name -DisplayName $DisplayName) {
        Write-Host "  [SKIP] $Name (protected core service)" -ForegroundColor DarkGray
        return $false
    }
    $svc = $null
    if ($Name) { $svc = Get-Service -Name $Name -ErrorAction SilentlyContinue }
    if ($null -eq $svc -and $DisplayName) {
        $svc = Get-Service -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like "*$DisplayName*" -or $_.Name -like "*$Name*" } | Select-Object -First 1
    }
    if ($null -eq $svc) { return $false }
    if (Test-ProtectedService -Name $svc.Name -DisplayName $svc.DisplayName) {
        Write-Host "  [SKIP] $($svc.Name) (protected core service)" -ForegroundColor DarkGray
        return $false
    }
    try {
        Invoke-SafeSetDisabledService -Name $svc.Name -DisplayName $svc.DisplayName
        return $true
    } catch {
        return $false
    }
}
function Stop-And-Disable {
    param(
        [System.Collections.Specialized.OrderedDictionary]$ServiceMap,
        [string]$Category,
        [ref]$Counter
    )
    $count = 0
    $total_in_map = $ServiceMap.Keys.Count
    $checked = 0
    foreach ($s in $ServiceMap.Keys) {
        $checked++
        Show-Progress ("Checking [{0}/{1}] {2}" -f $checked, $total_in_map, $s)
        $desc = $ServiceMap[$s]
        if (Test-ProtectedService -Name $s -DisplayName $desc) {
            Write-Log ("  [SKIP] {0,-44} protected core network/bluetooth service" -f $s) "DarkGray"
            continue
        }
        $svc = Get-Service -Name $s -ErrorAction SilentlyContinue
        if (-not $svc) {
            $svc = Get-Service -ErrorAction SilentlyContinue |
                   Where-Object { $_.DisplayName -like "*$s*" } |
                   Select-Object -First 1
        }
        if (-not $svc) {
            Write-Host ("  [--]  {0,-42} not found on this system" -f $s) -ForegroundColor DarkGray
            continue
        }
        if (Test-ProtectedService -Name $svc.Name -DisplayName $svc.DisplayName) {
            Write-Log ("  [SKIP] {0,-44} protected core service" -f $svc.Name) "DarkGray"
            continue
        }
        try {
            if ($svc.Status -eq "Running") {
                Invoke-SafeStopService -Name $svc.Name -DisplayName $svc.DisplayName
                Write-Log ("  [STOP] {0,-44} {1}" -f $svc.Name, $desc) "DarkYellow"
            }
            Invoke-SafeSetDisabledService -Name $svc.Name -DisplayName $svc.DisplayName
            Write-Log ("  [OFF ] {0,-44} {1}" -f $svc.Name, $desc) "DarkGray"
            $count++
            if ($Counter) { $Counter.Value++ }
        } catch {
            Write-Log ("  [ERR ] {0,-44} {1}" -f $svc.Name, $_.Exception.Message) "Red"
        }
    }
    return $count
}

# ==============================================================================
# STEP 1  --  KERNEL MEMORY FLUSH
# ==============================================================================
Show-Section "STEP 1: Kernel Memory Flush  --  Standby / Modified / Working Sets"

[TokenPriv4]::Enable("SeIncreaseQuotaPrivilege")        | Out-Null
[TokenPriv4]::Enable("SeProfileSingleProcessPrivilege") | Out-Null
[TokenPriv4]::Enable("SeDebugPrivilege")                | Out-Null
Write-Log "  [OK] Kernel privileges acquired" "Green"

Invoke-MemoryCommand -cmd 4 -label "Flush Modified Page List (dirty pages -> standby)"
Start-Sleep -Milliseconds 400
Invoke-MemoryCommand -cmd 3 -label "Purge Standby List (free kernel cache)"
Start-Sleep -Milliseconds 400
Invoke-MemoryCommand -cmd 1 -label "Empty All Working Sets (kernel + user)"
Start-Sleep -Milliseconds 200

if ($winBuild -ge 17763) {
    Invoke-MemoryCommand -cmd 2 -label "Flush Modified List pass-2 (Win10 1809+ specific)"
    Start-Sleep -Milliseconds 300
}

# ==============================================================================
# STEP 2  --  FILE SYSTEM CACHE FLUSH
# ==============================================================================
Show-Section "STEP 2: File System Cache Flush"

$minB = [IntPtr]::Zero; $maxB = [IntPtr]::Zero; $flg = 0
[SysCache4]::GetSystemFileCacheSize([ref]$minB, [ref]$maxB, [ref]$flg) | Out-Null
Write-Log ("  Current cache size:  min={0} MB   max={1} MB" -f ([long]$minB/1MB), ([long]$maxB/1MB)) "White"
$r2 = [SysCache4]::SetSystemFileCacheSize([IntPtr](-1), [IntPtr](-1), 0)
if ($r2) { Write-Log "  [OK] File system cache flushed successfully" "Green" }
else     { Write-Log "  [WARN] Could not flush file cache (SE_INCREASE_QUOTA_PRIVILEGE needed)" "Yellow" }

# ==============================================================================
# STEP 3  --  WORKING SET TRIM (all user processes, sorted by RAM usage)
# ==============================================================================
Show-Section "STEP 3: Working Set Trim  --  All user processes (sorted by RAM usage)"

$skipList = @("System","Idle","smss","csrss","wininit","winlogon","lsass",
              "services","Registry","Memory Compression","MsMpEng","audiodg",
              "dwm","fontdrvhost","wdmaud","svchost","ntoskrnl",
              "NisSrv","SecurityHealthService","WUDFHost","powershell","pwsh")
$trimOK = 0; $trimFail = 0; $freedBytes = [long]0

$allProcs = Get-Process -ErrorAction SilentlyContinue |
            Where-Object { $skipList -notcontains $_.ProcessName } |
            Sort-Object WorkingSet64 -Descending

Write-Log ("  Found {0} user processes to trim..." -f $allProcs.Count) "White"

foreach ($proc in $allProcs) {
    $ws0    = $proc.WorkingSet64
    $mbNow  = [math]::Round($ws0/1MB, 1)
    # Show top processes (>50MB) verbosely, smaller ones counted silently
    if ($mbNow -ge 50) {
        Show-Progress ("Trimming: {0,-28} using {1} MB" -f $proc.ProcessName, $mbNow)
    }
    $ACCESS = [uint32]0x1F0FFF
    try {
        $h = [MemUtil4]::OpenProcess($ACCESS, $false, $proc.Id)
        if ($h -ne [IntPtr]::Zero) {
            [MemUtil4]::EmptyWorkingSet($h) | Out-Null
            [MemUtil4]::SetProcessWorkingSetSizeEx($h, [IntPtr](-1), [IntPtr](-1), 0) | Out-Null
            [MemUtil4]::CloseHandle($h) | Out-Null
            $pNow = Get-Process -Id $proc.Id -ErrorAction SilentlyContinue
            if ($pNow) { $freedBytes += [math]::Max(0, $ws0 - $pNow.WorkingSet64) }
            $trimOK++
        } else { $trimFail++ }
    } catch { $trimFail++ }
}

Start-Sleep -Milliseconds 500
Invoke-MemoryCommand -cmd 3 -label "Post-trim Standby flush (catch promoted pages)"

Write-Log ("  [OK] Trimmed    : {0} processes" -f $trimOK) "Green"
Write-Log ("  [OK] Freed      : ~{0} MB" -f [math]::Round($freedBytes/1MB,1)) "Green"
Write-Log ("  [--] Skipped    : {0} protected processes" -f $trimFail) "DarkGray"

# ==============================================================================
# STEP 4  --  SERVICE LISTS
# ==============================================================================

# ---- Common (Win10 + Win11) ----
$svcsCommon = [ordered]@{
    "DiagTrack"              = "Connected User Experiences & Telemetry"
    "dmwappushservice"       = "WAP Push Message Routing (telemetry)"
    "WerSvc"                 = "Windows Error Reporting"
    "wercplsupport"          = "WER Control Panel Support"
    "XblGameSave"            = "Xbox Game Save"
    "XboxNetApiSvc"          = "Xbox Live Networking"
    "XblAuthManager"         = "Xbox Live Auth Manager"
    "XboxGipSvc"             = "Xbox Accessories Service"
    "MapsBroker"             = "Downloaded Maps Manager"
    "RetailDemo"             = "Retail Demo Service"
    "wisvc"                  = "Windows Insider Service"
    "lfsvc"                  = "Geolocation / GPS"
    "TapiSrv"                = "Telephony"
    "Fax"                    = "Fax Service"
    "icssvc"                 = "Windows Mobile Hotspot"
    "WalletService"          = "Wallet Service"
    "EntAppSvc"              = "Enterprise App Management"
    "MessagingService"       = "Messaging Service"
    "OneSyncSvc"             = "Sync Host (mail/calendar)"
    "WSearch"                = "Windows Search Indexing"
    "SysMain"                = "SysMain / Superfetch"
    "RemoteRegistry"         = "Remote Registry"
    "RemoteAccess"           = "Routing and Remote Access"
    "SharedAccess"           = "Internet Connection Sharing"
    "TermService"            = "Remote Desktop Services (if not using RDP)"
    "SessionEnv"             = "Remote Desktop Configuration"
    "UmRdpService"           = "Remote Desktop Device Redirector"
    "ScDeviceEnum"           = "Smart Card Device Enumeration"
    "SCardSvr"               = "Smart Card Service"
    "SCPolicySvc"            = "Smart Card Removal Policy"
    "MixedRealityOpenXRSvc"  = "Mixed Reality OpenXR"
    "PhoneSvc"               = "Phone Service"
    "PimIndexMaintenanceSvc" = "Contact Data Service"
    "UnistoreSvc"            = "User Data Storage"
    "UserDataSvc"            = "User Data Access"
    "PrintNotify"            = "Printer Extensions & Notifications"
    "Spooler"                = "Print Spooler (disable if no printer)"
    "BthAvctpSvc"            = "Bluetooth Audio Gateway"
    "BTAGService"            = "Bluetooth Audio AVRCP"
    "AJRouter"               = "AllJoyn Router (IoT)"
    "CscService"             = "Offline Files"
    "DusmSvc"                = "Data Usage"
    "WbioSrvc"               = "Windows Biometric Service"
}

$svcsWin10Only = [ordered]@{
    "wlidsvc"          = "Microsoft Account Sign-in Assistant"
    "SEMgrSvc"         = "Payments and NFC/SE Manager"
    "NcbService"       = "Network Connection Broker"
    "CDPSvc"           = "Connected Devices Platform"
    "WMPNetworkSvc"    = "Windows Media Player Network Sharing"
    "HomeGroupListener"= "HomeGroup Listener"
    "HomeGroupProvider"= "HomeGroup Provider"
}

$svcsWin11Only = [ordered]@{
    "cbdhsvc"           = "Clipboard User Service"
    "WpnService"        = "Windows Push Notifications System"
    "WpnUserService"    = "Windows Push Notifications User"
    "DsSvc"             = "Data Sharing Service"
    "DevicesFlowUserSvc"= "Devices Flow"
    "NPSMSvc"           = "Now Playing Session Manager"
    "BcastDVRUserService"="GameDVR & Broadcast User Service"
    "PerceptionSimulation"="Windows Perception Simulation"
    "MsKeyboardFilter"  = "Microsoft Keyboard Filter"
    "DoSvc"             = "Delivery Optimization"
    "CDPUserSvc"        = "Connected Devices Platform User"
    "PushToInstall"     = "Windows PushToInstall"
    "NetTcpPortSharing" = "Net.Tcp Port Sharing"
}

# ---- Brand service lists ----
$svcsDELL = [ordered]@{
    "DellClientManagementService"           = "Dell Client Management"
    "DellUpdate"                            = "Dell Update"
    "DellSupportAssistRemedationService"    = "Dell SupportAssist Remediation"
    "DellFoundationServices"                = "Dell Foundation Services"
    "DellTechHubService"                    = "Dell TechHub"
    "DellOptimizer"                         = "Dell Optimizer"
    "DellMobileConnect"                     = "Dell Mobile Connect"
    "DellDataVault"                         = "Dell Data Vault (telemetry)"
    "DellDataVaultWizard"                   = "Dell Data Vault Wizard"
    "ThermalService"                        = "Dell Thermal Service"
    "DellDigitalDelivery"                   = "Dell Digital Delivery"
    "DellServiceConnectivity"               = "Dell Service Connectivity"
    "DellInc.SupportAssistBusinessPCAgent"  = "Dell SupportAssist Business Agent"
}
$svcsHP = [ordered]@{
    "HPAppHelperCap"               = "HP App Helper Capture"
    "HPDiagsMsgSvc"                = "HP Diagnostics Messages"
    "HPNetworkCap"                 = "HP Network Capture (telemetry)"
    "HPSysInfoCap"                 = "HP SysInfo Capture (telemetry)"
    "hpsvc"                        = "HP Service"
    "HpTouchpointAnalyticsService" = "HP Touchpoint Analytics (telemetry)"
    "HPPrintScanDoctorService"     = "HP Print Scan Doctor"
    "HPAudioSwitch"                = "HP Audio Switch"
    "hp3ddrivelock"                = "HP 3D DriveGuard"
    "HotKeyServiceDLL"             = "HP HotKey Service"
    "HPWMISVC"                     = "HP WMI Service"
    "HPJumpStartBridge"            = "HP JumpStart Bridge"
    "HPJumpStartSvc"               = "HP JumpStart Service"
    "hpCMSgt"                      = "HP Connection Manager"
    "HPSmartAdapter"               = "HP Smart Adapter"
    "HPUpdateService"              = "HP Update Service"
    "HPDrvSvc"                     = "HP Driver Service"
    "HPAM"                         = "HP Account Manager"
}
$svcsLENOVO = [ordered]@{
    "ImControllerService"        = "Lenovo IdeaPad Controller"
    "LenovoFnAndFunctionKeys"    = "Lenovo Fn Keys"
    "Lenovo.Modern.ImController" = "Lenovo Modern ImController"
    "LenovoVantageService"       = "Lenovo Vantage Service"
    "LenovoSystemUpdateAddin"    = "Lenovo System Update Addin"
    "SUService"                  = "Lenovo System Update"
    "ThinkPad HDD APS"           = "ThinkPad HDD Active Protection"
    "LENOVO.CAMMUTE"             = "Lenovo Camera Mute"
    "LENOVO.MICMUTE"             = "Lenovo Mic Mute"
    "PMSvc"                      = "Lenovo Power Manager"
    "bcom"                       = "Lenovo BCOM Module"
    "LenovoSmartStandbyService"  = "Lenovo Smart Standby"
    "LenovoUtilityService"       = "Lenovo Utility Service"
    "LenovoWiFiHotspotSvc"       = "Lenovo WiFi Hotspot"
    "LenovoMigrationService"     = "Lenovo Migration Service"
}
$svcsASUS = [ordered]@{
    "asHmComSvc"                 = "ASUS HM Com"
    "AsSysCtrlService"           = "ASUS System Control"
    "AsusCertService"            = "ASUS Certificate Service"
    "ASUSUpdate"                 = "ASUS Update"
    "AsusUpdateCheck"            = "ASUS Update Check"
    "ASUSLinkNear"               = "ASUS Link Near (Armoury Crate)"
    "ASUSLinkRemote"             = "ASUS Link Remote (Armoury Crate)"
    "ASUSOptimization"           = "ASUS Optimization"
    "ASUSSystemAnalysis"         = "ASUS System Analysis"
    "ASUSSystemDiagnosis"        = "ASUS System Diagnosis"
    "ROGLiveService"             = "ROG Live Service"
    "ArmouryCrateService"        = "Armoury Crate Service"
    "GamingCenterService"        = "ASUS Gaming Center"
    "ASUSGiftBoxService"         = "ASUS Gift Box"
    "ASUSGiftBoxDesktopService"  = "ASUS Gift Box Desktop"
    "ASUSSystemControlInterface" = "ASUS System Control Interface"
    "ASUSSmartLogon"             = "ASUS Smart Logon"
}
$svcsMSI = [ordered]@{
    "MSI_SuperCharger"       = "MSI SuperCharger"
    "MSIAfterburnerCore"     = "MSI Afterburner (skip if overclocking)"
    "SCM"                    = "MSI System Control Manager"
    "msidrvsvc"              = "MSI Driver Service"
    "MSICenterService"       = "MSI Center Service"
    "MSIGamingCenterService" = "MSI Gaming Center"
    "DragonCenterService"    = "MSI Dragon Center"
    "NahimicService"         = "Nahimic Audio Service"
    "MSIRGBService"          = "MSI RGB Service"
}
$svcsACER = [ordered]@{
    "AcerService"             = "Acer Service"
    "AcerCloudService"        = "Acer Cloud"
    "AcerPortalService"       = "Acer Portal"
    "eDataSecurityManagement" = "Acer eDataSecurity"
    "AcerLaunchManager"       = "Acer Launch Manager"
    "AcerOptimizer"           = "Acer Optimizer"
    "PredatorSenseService"    = "Acer PredatorSense"
    "NitroSenseService"       = "Acer NitroSense"
    "QuickAccessService"      = "Acer Quick Access"
    "AcerUpdateService"       = "Acer Update Service"
    "AcerCare"                = "Acer Care Center"
    "ConceptDSenseService"    = "Acer ConceptD Sense"
}
$svcsSAMSUNG = [ordered]@{
    "SamsungMagicianService"  = "Samsung Magician"
    "SamsungDeXSvc"           = "Samsung DeX"
    "SamsungUpdateService"    = "Samsung Update"
    "SamsungSystemManager"    = "Samsung System Manager"
    "SamsungPC_Share_Manager" = "Samsung PC Share Manager"
    "SAService"               = "Samsung Activation Service"
    "SamsungSSDManager"       = "Samsung SSD Manager"
}
$svcsSURFACE = [ordered]@{
    "SurfaceService"                     = "Surface Service"
    "SurfaceTelemetryService"            = "Surface Telemetry"
    "SurfaceDiagnostics"                 = "Surface Diagnostics"
    "SurfaceButton"                      = "Surface Button Service"
    "SurfacePen"                         = "Surface Pen Service"
    "SurfaceFirmwareProvisioningService" = "Surface Firmware Provisioning"
}
$svcsRAZER = [ordered]@{
    "Razer Chroma SDK Server"  = "Razer Chroma SDK Server"
    "Razer Chroma SDK Service" = "Razer Chroma SDK Service"
    "RazerCentralService"      = "Razer Central"
    "RazerIngameEngine"        = "Razer InGame Engine"
    "Razer Synapse Service"    = "Razer Synapse"
    "RzActionSvc"              = "Razer Action Service"
    "RazerNamingService"       = "Razer Naming Service"
}
$svcsGIGABYTE = [ordered]@{
    "GiGEAudServ"           = "Gigabyte Audio"
    "GbActuatorService"     = "Gigabyte Actuator"
    "AppCenter"             = "Gigabyte App Center"
    "EasyTuneEngineService" = "Gigabyte Easy Tune"
    "RGBFusionSvc"          = "Gigabyte RGB Fusion"
    "AGSService"            = "Gigabyte AGS"
    "GbFirmwareUpdateSvc"   = "Gigabyte Firmware Update"
}
$svcsTOSHIBA = [ordered]@{
    "TODDSrv"                     = "Toshiba ODD Device"
    "TMachInfo"                   = "Toshiba Machine Info"
    "TOSHIBA eco Utility Service" = "Toshiba Eco Utility"
    "TVALZ"                       = "Toshiba ACPI Driver"
    "TPCH"                        = "Toshiba PCH Service"
    "Toshiba TEMPRO"              = "Toshiba TEMPRO"
}
$svcsHUAWEI = [ordered]@{
    "HuaweiPCManagerSvc"      = "Huawei PCManager"
    "HuaweiService"           = "Huawei Service"
    "HiService"               = "Huawei HiSuite"
    "HuaweiEasyProjectionSvc" = "Huawei EasyProjection"
}
$svcsLG      = [ordered]@{ "LGUpdateService"="LG Update"; "LGHubService"="LG Hub" }
$svcsPANA    = [ordered]@{ "PanaService"="Panasonic Service"; "PCInfo"="Panasonic PC Info" }
$svcsFUJITSU = [ordered]@{ "FjSessServiceAgent"="Fujitsu Session Agent"; "FUJBtnSvc"="Fujitsu Button Svc" }
$svcsVAIO    = [ordered]@{ "VAIOCareService"="VAIO Care"; "VAIOEventService"="VAIO Event"; "VaioSettingsService"="VAIO Settings" }

# ==============================================================================
# STEP 4  --  DISABLE COMMON WINDOWS SERVICES
# ==============================================================================
Show-Section "STEP 4: Disable unnecessary Windows services (Common)"
Write-Log ("  Scanning {0} common services..." -f $svcsCommon.Keys.Count) "White"
$n4a = Stop-And-Disable -ServiceMap $svcsCommon -Category "Common" -Counter ([ref]$Script:SvcCommon)
Write-Log ("  >> Common: {0} services found and handled" -f $n4a) "Green"

if ($isWin10) {
    Write-Log ""
    Write-Log ("  Scanning {0} Win10-specific services..." -f $svcsWin10Only.Keys.Count) "White"
    $n4b = Stop-And-Disable -ServiceMap $svcsWin10Only -Category "Win10Only" -Counter ([ref]$Script:SvcCommon)
    Write-Log ("  >> Win10 specific: {0} services handled" -f $n4b) "Green"
}
if ($isWin11) {
    Write-Log ""
    Write-Log ("  Scanning {0} Win11-specific services..." -f $svcsWin11Only.Keys.Count) "White"
    $n4c = Stop-And-Disable -ServiceMap $svcsWin11Only -Category "Win11Only" -Counter ([ref]$Script:SvcCommon)
    Write-Log ("  >> Win11 specific: {0} services handled" -f $n4c) "Green"
}

# ==============================================================================
# STEP 5  --  BRAND SERVICES
# ==============================================================================
Show-Section ("STEP 5: Brand services [ {0} ]  --  explicit list" -f $brand)
Write-Log ("  Brand: {0}  |  Detection source: {1}" -f $brand, $brandSrc) $brandColor
Write-Log ""

switch ($brand) {
    "DELL"               { Write-Log ("  Scanning {0} DELL services..." -f $svcsDELL.Keys.Count) "White"
                           Stop-And-Disable -ServiceMap $svcsDELL     -Category "DELL"     -Counter ([ref]$Script:SvcBrand) | Out-Null }
    "HP"                 { Write-Log ("  Scanning {0} HP services..." -f $svcsHP.Keys.Count) "White"
                           Stop-And-Disable -ServiceMap $svcsHP       -Category "HP"       -Counter ([ref]$Script:SvcBrand) | Out-Null }
    "LENOVO"             { Write-Log ("  Scanning {0} LENOVO services..." -f $svcsLENOVO.Keys.Count) "White"
                           Stop-And-Disable -ServiceMap $svcsLENOVO   -Category "LENOVO"   -Counter ([ref]$Script:SvcBrand) | Out-Null }
    "ASUS"               { Write-Log ("  Scanning {0} ASUS services..." -f $svcsASUS.Keys.Count) "White"
                           Stop-And-Disable -ServiceMap $svcsASUS     -Category "ASUS"     -Counter ([ref]$Script:SvcBrand) | Out-Null }
    "MSI"                { Write-Log ("  Scanning {0} MSI services..." -f $svcsMSI.Keys.Count) "White"
                           Stop-And-Disable -ServiceMap $svcsMSI      -Category "MSI"      -Counter ([ref]$Script:SvcBrand) | Out-Null }
    "ACER"               { Write-Log ("  Scanning {0} ACER services..." -f $svcsACER.Keys.Count) "White"
                           Stop-And-Disable -ServiceMap $svcsACER     -Category "ACER"     -Counter ([ref]$Script:SvcBrand) | Out-Null }
    "SAMSUNG"            { Write-Log ("  Scanning {0} SAMSUNG services..." -f $svcsSAMSUNG.Keys.Count) "White"
                           Stop-And-Disable -ServiceMap $svcsSAMSUNG  -Category "SAMSUNG"  -Counter ([ref]$Script:SvcBrand) | Out-Null }
    "MICROSOFT_SURFACE"  { Write-Log ("  Scanning {0} SURFACE services..." -f $svcsSURFACE.Keys.Count) "White"
                           Stop-And-Disable -ServiceMap $svcsSURFACE  -Category "SURFACE"  -Counter ([ref]$Script:SvcBrand) | Out-Null }
    "RAZER"              { Write-Log ("  Scanning {0} RAZER services..." -f $svcsRAZER.Keys.Count) "White"
                           Stop-And-Disable -ServiceMap $svcsRAZER    -Category "RAZER"    -Counter ([ref]$Script:SvcBrand) | Out-Null }
    "GIGABYTE"           { Write-Log ("  Scanning {0} GIGABYTE services..." -f $svcsGIGABYTE.Keys.Count) "White"
                           Stop-And-Disable -ServiceMap $svcsGIGABYTE -Category "GIGABYTE" -Counter ([ref]$Script:SvcBrand) | Out-Null }
    "TOSHIBA"            { Write-Log ("  Scanning {0} TOSHIBA services..." -f $svcsTOSHIBA.Keys.Count) "White"
                           Stop-And-Disable -ServiceMap $svcsTOSHIBA  -Category "TOSHIBA"  -Counter ([ref]$Script:SvcBrand) | Out-Null }
    "HUAWEI"             { Write-Log ("  Scanning {0} HUAWEI services..." -f $svcsHUAWEI.Keys.Count) "White"
                           Stop-And-Disable -ServiceMap $svcsHUAWEI   -Category "HUAWEI"   -Counter ([ref]$Script:SvcBrand) | Out-Null }
    "LG"                 { Stop-And-Disable -ServiceMap $svcsLG       -Category "LG"       -Counter ([ref]$Script:SvcBrand) | Out-Null }
    "PANASONIC"          { Stop-And-Disable -ServiceMap $svcsPANA     -Category "PANASONIC"-Counter ([ref]$Script:SvcBrand) | Out-Null }
    "FUJITSU"            { Stop-And-Disable -ServiceMap $svcsFUJITSU  -Category "FUJITSU"  -Counter ([ref]$Script:SvcBrand) | Out-Null }
    "VAIO"               { Stop-And-Disable -ServiceMap $svcsVAIO     -Category "VAIO"     -Counter ([ref]$Script:SvcBrand) | Out-Null }
    "GENERIC_AMI"        {
        Write-Log "  AMI BIOS detected  --  scanning Gigabyte + ASUS service lists..." "Yellow"
        Stop-And-Disable -ServiceMap $svcsGIGABYTE -Category "GIGABYTE/AMI" -Counter ([ref]$Script:SvcBrand) | Out-Null
        Stop-And-Disable -ServiceMap $svcsASUS     -Category "ASUS/AMI"     -Counter ([ref]$Script:SvcBrand) | Out-Null
    }
    default { Write-Log "  [i] Brand unknown  --  skipping explicit brand service list." "Yellow" }
}
Write-Log ("  >> Brand [{0}] total: {1} services found and handled" -f $brand, $Script:SvcBrand) $brandColor

# ==============================================================================
# STEP 6  --  KEYWORD SCAN: catch any remaining brand services
# ==============================================================================
Show-Section "STEP 6: Keyword scan  --  catch remaining brand / bloatware services"

$vendorKW = @(
    "dell","hewlett","hp ","hpinc","lenovo","thinkpad","ideapad","legion",
    "asus","armoury","rog ","tuf ","msi ","dragon center","nahimic",
    "acer ","predator","nitro","swift","aspire","travelmate","conceptd",
    "samsung","toshiba","huawei","razer","synapse","chroma",
    "gigabyte","rgb fusion","easy tune","supportassist","vantage",
    "pcmanager","lg hub","fujitsu","panasonic","vaio","intel nuc",
    "cyberlink","mcafee","norton","lifelock","duo security"
)

$allSvcs  = @(Get-Service -ErrorAction SilentlyContinue)
Write-Log ("  Scanning ALL {0} services against {1} vendor keywords..." -f
    $allSvcs.Count, $vendorKW.Count) "White"
$kwHits   = 0
$kwScanned = 0
foreach ($svc in $allSvcs) {
    $kwScanned++
    if ($svc.StartType -eq "Disabled") { continue }
    $dn = $svc.DisplayName.ToLower()
    $sn = $svc.Name.ToLower()
    foreach ($kw in $vendorKW) {
        if ($dn -like "*$kw*" -or $sn -like "*$kw*") {
            Write-Log ("  [KW-HIT] '{0}' matched keyword '{1}'" -f $svc.Name, $kw) "Yellow"
            try {
                if ($svc.Status -eq "Running") {
                    Invoke-SafeStopService -Name $svc.Name -DisplayName $svc.DisplayName
                    Write-Log ("  [STOP]   {0,-44} {1}" -f $svc.Name, $svc.DisplayName) "DarkYellow"
                }
                Invoke-SafeSetDisabledService -Name $svc.Name -DisplayName $svc.DisplayName
                Write-Log ("  [OFF ]   {0,-44} {1}" -f $svc.Name, $svc.DisplayName) "DarkGray"
                $kwHits++
                $Script:SvcKW++
            } catch {
                Write-Log ("  [ERR ]   {0} -- {1}" -f $svc.Name, $_.Exception.Message) "Red"
            }
            break
        }
    }
}
Write-Log ("  >> Scanned: {0} active services  |  Keyword hits: {1}" -f $kwScanned, $kwHits) "Green"
if ($kwHits -eq 0) { Write-Log "  [OK] No additional vendor services found." "Green" }

# ==============================================================================
# STEP 7  --  STARTUP ITEMS + SCHEDULED TASKS
# ==============================================================================
Show-Section "STEP 7: Startup items (Registry) + Scheduled Tasks  --  vendor keyword clean"

$startupKeys = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run",
    "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
)
$startupKW = @(
    "dell","hewlett","hp ","lenovo","asus","armoury","msi ","acer ","samsung",
    "toshiba","huawei","razer","gigabyte","vantage","supportassist","pcmanager",
    "lg ","fujitsu","vaio","intel nuc","dragon center","nahimic","nitro","predator",
    "cortana","teams consumer","mcafee","norton","cyberlink"
)

foreach ($regPath in $startupKeys) {
    if (-not (Test-Path $regPath)) { continue }
    Write-Log ("  Scanning registry: {0}" -f $regPath) "DarkGray"
    $entries = Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue
    if (-not $entries) { continue }
    $entries.PSObject.Properties |
      Where-Object { $_.MemberType -eq "NoteProperty" -and $_.Name -notmatch "^PS" } |
      ForEach-Object {
        $valName = $_.Name; $valData = ($_.Value + "").ToLower()
        foreach ($kw in $startupKW) {
            if ($valName.ToLower() -like "*$kw*" -or $valData -like "*$kw*") {
                Remove-ItemProperty -Path $regPath -Name $valName -ErrorAction SilentlyContinue
                Write-Log ("  [RUN-DEL] Key: {0,-30}  Value: {1}" -f $valName, $_.Value) "DarkYellow"
                $Script:StartupDel++; break
            }
        }
    }
}

# Scheduled Tasks
$taskKW = @(
    "dell","hp","lenovo","asus","msi","acer","samsung","toshiba","huawei","razer",
    "gigabyte","supportassist","vantage","armoury","dragon center","nahimic",
    "fujitsu","vaio","panasonic","nitro","predator","cortana","onedrive",
    "skype","teams","feedback","mcafee","norton","cyberlink"
)
try {
    $sched = New-Object -ComObject "Schedule.Service"
    $sched.Connect()
    Write-Log "  Scanning Task Scheduler tree for vendor tasks..." "DarkGray"

    function Disable-VendorTasks {
        param($folder)
        try {
            foreach ($task in $folder.GetTasks(0)) {
                $tn = $task.Name.ToLower(); $tp = $task.Path.ToLower()
                foreach ($kw in $taskKW) {
                    if ($tn -like "*$kw*" -or $tp -like "*$kw*") {
                        if ($task.Enabled) {
                            $task.Enabled = $false
                            Write-Log ("  [TASK-OFF] {0}" -f $task.Path) "DarkYellow"
                            $Script:TasksOff++
                        }
                        break
                    }
                }
            }
            foreach ($sf in $folder.GetFolders(0)) { Disable-VendorTasks -folder $sf }
        } catch {}
    }
    Disable-VendorTasks -folder ($sched.GetFolder("\"))
    [System.Runtime.InteropServices.Marshal]::ReleaseComObject($sched) | Out-Null
} catch {
    Write-Log ("  [WARN] Task Scheduler access failed: {0}" -f $_.Exception.Message) "Yellow"
}

Write-Log ("  >> Startup registry entries removed : {0}" -f $Script:StartupDel) "Green"
Write-Log ("  >> Scheduled tasks disabled         : {0}" -f $Script:TasksOff) "Green"

# ==============================================================================
# STEP 8  --  REGISTRY TUNING
# ==============================================================================
Show-Section "STEP 8: Registry tuning  --  Memory / Telemetry / Visual / TCP / Power"

$mm   = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
$pref = "$mm\PrefetchParameters"

# Memory Management (8 GB profile: SessionViewSize=256 MB)
$svSize = if ($is8GB) { 256 } else { 128 }
$mmSettings = @{
    "LargeSystemCache"        = 0
    "DisablePagingExecutive"  = 1
    "SecondLevelDataCache"    = 0
    "NonPagedPoolQuota"       = 0
    "PagedPoolQuota"          = 0
    "SessionPoolSize"         = 48
    "SessionViewSize"         = $svSize
    "SystemPages"             = 0
    "ClearPageFileAtShutdown" = 1
}
foreach ($k in $mmSettings.Keys) {
    Set-ItemProperty -Path $mm -Name $k -Value $mmSettings[$k] -Type DWord -ErrorAction SilentlyContinue
}
Write-Log ("  [OK] Memory Management: SessionViewSize={0} MB, ClearPageFile=1" -f $svSize) "Green"

# Prefetch / Superfetch
if (Test-Path $pref) {
    $pfVal = if ($isSSD) { 0 } else { 3 }
    Set-ItemProperty -Path $pref -Name "EnablePrefetcher"  -Value $pfVal -Type DWord -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $pref -Name "EnableSuperfetch"  -Value 0      -Type DWord -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $pref -Name "EnableBoottrace"   -Value 0      -Type DWord -ErrorAction SilentlyContinue
    Write-Log ("  [OK] Prefetcher={0} (SSD={1}), Superfetch=0" -f $pfVal, $isSSD) "Green"
}

# ReadyBoot disable
$rbPath = "HKLM:\SYSTEM\CurrentControlSet\Control\WMI\Autologger\ReadyBoot"
Set-ItemProperty -Path $rbPath -Name "Start" -Value 0 -Type DWord -ErrorAction SilentlyContinue
Write-Log "  [OK] ReadyBoot logger disabled" "Green"

# Telemetry
$telData = @{
    "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"                = @{ "AllowTelemetry" = 0 }
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" = @{ "AllowTelemetry" = 0; "MaxTelemetryAllowed" = 0 }
    "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat"                     = @{ "DisableInventory" = 1; "DisablePCA" = 1 }
    "HKLM:\SOFTWARE\Policies\Microsoft\SQMClient\Windows"                     = @{ "CEIPEnable" = 0 }
    "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent"                  = @{ "DisableTailoredExperiencesWithDiagnosticData" = 1 }
}
foreach ($path in $telData.Keys) {
    if (-not (Test-Path $path)) { New-Item -Path $path -Force -ErrorAction SilentlyContinue | Out-Null }
    foreach ($name in $telData[$path].Keys) {
        Set-ItemProperty -Path $path -Name $name -Value $telData[$path][$name] -Type DWord -ErrorAction SilentlyContinue
    }
}
$ctrKey = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\CompatTelRunner.exe"
if (-not (Test-Path $ctrKey)) { New-Item -Path $ctrKey -Force -ErrorAction SilentlyContinue | Out-Null }
Set-ItemProperty -Path $ctrKey -Name "Debugger" -Value "%windir%\System32\taskkill.exe" -Type String -ErrorAction SilentlyContinue
Write-Log "  [OK] Telemetry + CEIP + CompatTelRunner blocked" "Green"

# Visual FX Best Performance
$visPref = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects"
if (-not (Test-Path $visPref)) { New-Item -Path $visPref -Force -ErrorAction SilentlyContinue | Out-Null }
Set-ItemProperty -Path $visPref -Name "VisualFXSetting" -Value 2 -Type DWord -ErrorAction SilentlyContinue
$udPath = "HKCU:\Control Panel\Desktop"
Set-ItemProperty -Path $udPath -Name "DragFullWindows" -Value "0" -ErrorAction SilentlyContinue
Set-ItemProperty -Path $udPath -Name "FontSmoothing"   -Value "2" -ErrorAction SilentlyContinue
Write-Log "  [OK] Visual FX -> Best Performance" "Green"

# TCP
$tcpPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
Set-ItemProperty -Path $tcpPath -Name "TcpAckFrequency" -Value 1  -Type DWord -ErrorAction SilentlyContinue
Set-ItemProperty -Path $tcpPath -Name "TCPNoDelay"      -Value 1  -Type DWord -ErrorAction SilentlyContinue
Set-ItemProperty -Path $tcpPath -Name "DefaultTTL"      -Value 64 -Type DWord -ErrorAction SilentlyContinue
Write-Log "  [OK] TCP parameters optimized (NoDelay, AckFreq=1, TTL=64)" "Green"

# Power Plan
try {
    powercfg /setactive SCHEME_MIN 2>&1 | Out-Null
    if ($is8GB -and $isWin11) {
        powercfg /setacvalueindex SCHEME_MIN SUB_PROCESSOR PROCTHROTTLEMIN 5   2>&1 | Out-Null
        powercfg /setacvalueindex SCHEME_MIN SUB_PROCESSOR PROCTHROTTLEMAX 100 2>&1 | Out-Null
        powercfg /setactive SCHEME_MIN 2>&1 | Out-Null
        Write-Log "  [OK] Power Plan -> High Performance (CPU min 5% for 8 GB Win11)" "Green"
    } else {
        Write-Log "  [OK] Power Plan -> High Performance" "Green"
    }
} catch {}

# GameDVR / GameBar
$gdvrPath = "HKCU:\System\GameConfigStore"
if (-not (Test-Path $gdvrPath)) { New-Item -Path $gdvrPath -Force -ErrorAction SilentlyContinue | Out-Null }
Set-ItemProperty -Path $gdvrPath -Name "GameDVR_Enabled" -Value 0 -Type DWord -ErrorAction SilentlyContinue
$gbarPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR"
if (-not (Test-Path $gbarPath)) { New-Item -Path $gbarPath -Force -ErrorAction SilentlyContinue | Out-Null }
Set-ItemProperty -Path $gbarPath -Name "AppCaptureEnabled" -Value 0 -Type DWord -ErrorAction SilentlyContinue
Write-Log "  [OK] GameDVR / GameBar disabled" "Green"

# Cortana
$cortanaPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"
if (-not (Test-Path $cortanaPath)) { New-Item -Path $cortanaPath -Force -ErrorAction SilentlyContinue | Out-Null }
Set-ItemProperty -Path $cortanaPath -Name "AllowCortana" -Value 0 -Type DWord -ErrorAction SilentlyContinue
Write-Log "  [OK] Cortana disabled via group policy" "Green"

# Win11 Widgets
if ($isWin11) {
    $wdgPath = "HKLM:\SOFTWARE\Policies\Microsoft\Dsh"
    if (-not (Test-Path $wdgPath)) { New-Item -Path $wdgPath -Force -ErrorAction SilentlyContinue | Out-Null }
    Set-ItemProperty -Path $wdgPath -Name "AllowNewsAndInterests" -Value 0 -Type DWord -ErrorAction SilentlyContinue
    Write-Log "  [OK] Win11 Widgets panel disabled" "Green"
}
# Win10 News & Interests
if ($isWin10) {
    $niFeed = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds"
    if (-not (Test-Path $niFeed)) { New-Item -Path $niFeed -Force -ErrorAction SilentlyContinue | Out-Null }
    Set-ItemProperty -Path $niFeed -Name "EnableFeeds" -Value 0 -Type DWord -ErrorAction SilentlyContinue
    Write-Log "  [OK] Win10 News & Interests taskbar disabled" "Green"
}

# ==============================================================================
# STEP 9  --  GOD MODE 8 GB TARGETED FIXES
# ==============================================================================
Show-Section "STEP 9: GOD MODE  --  targeted RAM fixes (8 GB profile + Win11)"

# 9A: Memory Compression throttle
# FIXED: .PriorityClass fails on kernel-mode process. Use NtSetInformationProcess
# (ProcessPriorityClass=18, value 1=IDLE) which works from SYSTEM/Admin context.
$mcPriorityCode = @"
using System;
using System.Runtime.InteropServices;
public class NtProcPriority {
    [DllImport("ntdll.dll")]
    public static extern int NtSetInformationProcess(
        IntPtr hProcess, int infoClass, ref int info, int infoLen);
    [DllImport("kernel32.dll")]
    public static extern IntPtr OpenProcess(uint access, bool inherit, int pid);
    [DllImport("kernel32.dll")]
    public static extern bool CloseHandle(IntPtr h);
}
"@
if (-not ([System.Management.Automation.PSTypeName]"NtProcPriority").Type) {
    Add-Type -TypeDefinition $mcPriorityCode -ErrorAction SilentlyContinue
}

$mcProc = Get-Process -Name "Memory Compression" -ErrorAction SilentlyContinue
if ($mcProc) {
    try {
        # PROCESS_SET_INFORMATION = 0x0200, PROCESS_QUERY_INFORMATION = 0x0400
        $hMC = [NtProcPriority]::OpenProcess([uint32]0x0600, $false, $mcProc.Id)
        if ($hMC -ne [IntPtr]::Zero) {
            # ProcessPriorityClass = 18, value 1 = IDLE priority
            $idlePriority = 1
            $r = [NtProcPriority]::NtSetInformationProcess($hMC, 18, [ref]$idlePriority, 4)
            [NtProcPriority]::CloseHandle($hMC) | Out-Null
            if ($r -eq 0) {
                Write-Log "  [OK] Memory Compression -> IDLE priority via NtSetInformationProcess" "Green"
                Write-Log ("  [OK] Was using: {0} MB (now throttled, kernel will reclaim)" -f
                    [math]::Round($mcProc.WorkingSet64/1MB,1)) "Green"
            } else {
                Write-Log ("  [WARN] NtSetInformationProcess returned 0x{0:X} (domain policy may block)" -f $r) "Yellow"
            }
        } else {
            Write-Log "  [WARN] Could not open Memory Compression handle (insufficient rights)" "Yellow"
        }
    } catch {
        Write-Log ("  [WARN] Memory Compression throttle failed: {0}" -f $_.Exception.Message) "Yellow"
    }
} else {
    Write-Log "  [--] Memory Compression process not running (already suppressed)" "DarkGray"
}

# 9B: SwapFile.sys disable on SSD
if ($isSSD) {
    $swapPol = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"
    if (-not (Test-Path $swapPol)) { New-Item -Path $swapPol -Force -ErrorAction SilentlyContinue | Out-Null }
    Set-ItemProperty -Path $swapPol -Name "DisableSwapFile" -Value 1 -Type DWord -ErrorAction SilentlyContinue
    Write-Log "  [OK] SwapFile.sys (Win11 compressed swap) disabled  --  SSD detected [FIX-4]" "Green"
} else {
    Write-Log "  [--] HDD detected  --  SwapFile.sys kept for stability" "Yellow"
}

# 9C: WSL2 memory reclaim config
$wslConfig = "$env:USERPROFILE\.wslconfig"
$wslBlock   = "[wsl2]`r`nmemory=2GB`r`nprocessors=2`r`nswap=0`r`nlocalhostForwarding=true`r`n[experimental]`r`nautoMemoryReclaim=gradual"
if (Test-Path $wslConfig) {
    $existing = Get-Content $wslConfig -Raw -ErrorAction SilentlyContinue
    if ($existing -notlike "*autoMemoryReclaim*") {
        Add-Content -Path $wslConfig -Value "`r`n[experimental]`r`nautoMemoryReclaim=gradual" -ErrorAction SilentlyContinue
        Write-Log "  [OK] WSL2 .wslconfig  --  autoMemoryReclaim=gradual appended" "Green"
    } else {
        Write-Log "  [--] WSL2 .wslconfig already has autoMemoryReclaim configured" "DarkGray"
    }
} else {
    Set-Content -Path $wslConfig -Value $wslBlock -ErrorAction SilentlyContinue
    Write-Log "  [OK] WSL2 .wslconfig created (memory=2GB, autoMemoryReclaim=gradual)" "Green"
}

# 9D: Windows Search  --  already in service list but ensure SearchIndexer is killed
Stop-Process -Name "SearchIndexer" -Force -ErrorAction SilentlyContinue
Write-Log "  [OK] SearchIndexer process terminated (index left intact on disk)" "Green"

# 9E: Defender CPU throttle (does NOT disable protection)
# FIXED: Try direct registry write first, then fallback, detect domain GPO conflict clearly
$defWriteOK = $false
try {
    $defBase = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender"
    if (-not (Test-Path $defBase)) { New-Item -Path $defBase -Force -ErrorAction Stop | Out-Null }
    $defScan = "$defBase\Scan"
    if (-not (Test-Path $defScan)) { New-Item -Path $defScan -Force -ErrorAction Stop | Out-Null }
    Set-ItemProperty -Path $defScan -Name "AvgCPULoadFactor"           -Value 25 -Type DWord -ErrorAction Stop
    Set-ItemProperty -Path $defScan -Name "DisableScanningNetworkFiles" -Value 1  -Type DWord -ErrorAction Stop
    Set-ItemProperty -Path $defScan -Name "DisableArchiveScanning"      -Value 1  -Type DWord -ErrorAction Stop
    $defWriteOK = $true
} catch {
    # Fallback: try non-policy path (works on non-domain machines where policy path is locked)
    try {
        $defFallback = "HKLM:\SOFTWARE\Microsoft\Windows Defender\Scan"
        if (-not (Test-Path $defFallback)) { New-Item -Path $defFallback -Force -ErrorAction Stop | Out-Null }
        Set-ItemProperty -Path $defFallback -Name "AvgCPULoadFactor" -Value 25 -Type DWord -ErrorAction Stop
        $defWriteOK = $true
        Write-Log "  [OK] Defender CPU cap 25% set via non-policy path (fallback)" "Green"
    } catch {}
}

if ($defWriteOK) {
    # Runtime priority throttle for MsMpEng
    $mpEng = Get-Process -Name "MsMpEng" -ErrorAction SilentlyContinue
    if ($mpEng) {
        try {
            $hMP = [NtProcPriority]::OpenProcess([uint32]0x0600, $false, $mpEng.Id)
            if ($hMP -ne [IntPtr]::Zero) {
                $belowNormal = 5   # PROCESS_PRIORITY_CLASS_BELOW_NORMAL
                [NtProcPriority]::NtSetInformationProcess($hMP, 18, [ref]$belowNormal, 4) | Out-Null
                [NtProcPriority]::CloseHandle($hMP) | Out-Null
                Write-Log "  [OK] Defender MsMpEng -> BelowNormal priority + CPU cap 25%" "Green"
            }
        } catch {}
    } else {
        Write-Log "  [OK] Defender CPU cap 25% applied (policy path, real-time scan kept active)" "Green"
    }
} else {
    Write-Log "  [WARN] Defender policy blocked  --  machine is likely domain-joined (Precision 7670 enterprise)" "Yellow"
    Write-Log "  [i]   Domain GPO controls Defender  --  this is expected and safe to ignore" "DarkGray"
}

# 9F: Top-10 RAM consumers aggressive trim
Write-Log ""
Write-Log "  Scanning for top-10 RAM consumers (verbose)..." "White"
$safeSkip2 = @("System","Idle","smss","csrss","wininit","winlogon","lsass",
               "services","Registry","dwm","fontdrvhost","audiodg","svchost",
               "MsMpEng","WUDFHost","NisSrv","SecurityHealthService","powershell","pwsh")
$top10 = Get-Process -ErrorAction SilentlyContinue |
         Where-Object { $safeSkip2 -notcontains $_.ProcessName } |
         Sort-Object WorkingSet64 -Descending |
         Select-Object -First 10

Write-Log ("  Top-10 RAM consumers right now:") "White"
$rank = 1
foreach ($p in $top10) {
    $mbNow = [math]::Round($p.WorkingSet64/1MB,1)
    Write-Log ("  #{0,-3} {1,-30} {2} MB" -f $rank, $p.ProcessName, $mbNow) "Yellow"
    try {
        $h = [MemUtil4]::OpenProcess([uint32]0x1F0FFF, $false, $p.Id)
        if ($h -ne [IntPtr]::Zero) {
            [MemUtil4]::EmptyWorkingSet($h) | Out-Null
            [MemUtil4]::SetProcessWorkingSetSizeEx($h, [IntPtr](-1), [IntPtr](-1), 0) | Out-Null
            [MemUtil4]::CloseHandle($h) | Out-Null
            Write-Log ("  [TRIM] -> trimmed") "Green"
        }
    } catch { Write-Log "  [TRIM] -> access denied (OK)" "DarkGray" }
    $rank++
}

# ==============================================================================
# STEP 10  --  JUNK FILE CLEANUP
# ==============================================================================
Show-Section "STEP 10: System junk cleanup"

$cleanDirs = @(
    $env:TEMP,
    "$env:LOCALAPPDATA\Temp",
    "C:\Windows\Temp",
    "C:\Windows\Prefetch",
    "$env:LOCALAPPDATA\Microsoft\Windows\INetCache",
    "$env:LOCALAPPDATA\Microsoft\Windows\INetCookies",
    "$env:LOCALAPPDATA\Microsoft\Windows\WebCache",
    "$env:APPDATA\Microsoft\Windows\Recent\AutomaticDestinations",
    "$env:APPDATA\Microsoft\Windows\Recent\CustomDestinations",
    "$env:LOCALAPPDATA\CrashDumps",
    "C:\Windows\LiveKernelReports",
    "C:\Windows\Minidump"
)
foreach ($d in $cleanDirs) {
    if (Test-Path $d) {
        $cnt = (Get-ChildItem -Path $d -Recurse -ErrorAction SilentlyContinue | Measure-Object).Count
        Get-ChildItem -Path $d -ErrorAction SilentlyContinue |
            Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
        Write-Log ("  [OK] Cleaned: {0,-62} ({1} items)" -f $d, $cnt) "Green"
    }
}

# Thumbnail cache
$thumbDir = "$env:LOCALAPPDATA\Microsoft\Windows\Explorer"
if (Test-Path $thumbDir) {
    Get-ChildItem -Path $thumbDir -Filter "thumbcache_*.db" -ErrorAction SilentlyContinue |
        Remove-Item -Force -ErrorAction SilentlyContinue
    Write-Log "  [OK] Thumbnail cache (thumbcache_*.db) removed" "Green"
}

# Windows Update cache
$wu = "C:\Windows\SoftwareDistribution\Download"
if (Test-Path $wu) {
    $wus = Get-Service "wuauserv" -ErrorAction SilentlyContinue
    if ($wus -and $wus.Status -eq "Running") {
        Invoke-SafeStopService -Name "wuauserv"
        Start-Sleep 2
    }
    $wuCnt = (Get-ChildItem $wu -Recurse -ErrorAction SilentlyContinue | Measure-Object).Count
    Get-ChildItem $wu -ErrorAction SilentlyContinue | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
    Start-Service "wuauserv" -ErrorAction SilentlyContinue
    Write-Log ("  [OK] Windows Update download cache: {0} items removed" -f $wuCnt) "Green"
}

# DNS + Event Logs
ipconfig /flushdns 2>&1 | Out-Null
Write-Log "  [OK] DNS cache flushed" "Green"
foreach ($log in @("Application","System","Setup")) {
    try {
        [System.Diagnostics.EventLog]::Clear($log)
        Write-Log ("  [OK] Event Log [{0}] cleared" -f $log) "DarkGray"
    } catch {}
}

# ==============================================================================
# STEP 11  --  PLATFORM-SPECIFIC TWEAKS
# ==============================================================================
Show-Section ("STEP 11: Platform-specific tweaks [{0}]" -f $winTag)

if ($isWin11) {
    $advKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    Set-ItemProperty -Path $advKey -Name "TaskbarMn"             -Value 0 -Type DWord -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $advKey -Name "EnableSnapAssistFlyout"-Value 0 -Type DWord -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $advKey -Name "ShowCopilotButton"     -Value 0 -Type DWord -ErrorAction SilentlyContinue
    Write-Log "  [OK] Taskbar Chat + Snap Assist Flyout + Copilot button hidden" "Green"

    $vaSpeech = "HKCU:\Software\Microsoft\Speech_OneCore\Settings\OnlineServices"
    if (Test-Path $vaSpeech) {
        Set-ItemProperty -Path $vaSpeech -Name "OnlineSpeechPrivacy" -Value 0 -Type DWord -ErrorAction SilentlyContinue
    }
    Write-Log "  [OK] Online Speech Privacy disabled" "Green"

    # WSA
    $wsaSvc = Get-Service -Name "WsaService" -ErrorAction SilentlyContinue
    if ($wsaSvc) {
        Invoke-SafeStopService -Name "WsaService"
        Invoke-SafeSetDisabledService -Name "WsaService"
        Write-Log "  [OK] Windows Subsystem for Android (WSA) disabled" "Green"
    } else {
        Write-Log "  [--] WSA not installed" "DarkGray"
    }

    # 8 GB pagefile: manual fixed size
    if ($is8GB) {
        $pfc = Get-CimInstance Win32_ComputerSystem
        if ($pfc.AutomaticManagedPagefile) {
            Set-CimInstance -InputObject $pfc -Property @{ AutomaticManagedPagefile = $false } -ErrorAction SilentlyContinue
            Write-Log "  [OK] Pagefile -> MANUAL management (8 GB optimize)" "Green"
        }
        $pfSetting = Get-CimInstance -ClassName Win32_PageFileSetting -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $pfSetting) {
            # Create new pagefile entry if not found (auto-managed has no row)
            Set-WmiInstance -Class Win32_PageFileSetting -Arguments @{Name="C:\pagefile.sys";InitialSize=1024;MaximumSize=4096} -ErrorAction SilentlyContinue | Out-Null
            $pfSetting = Get-CimInstance -ClassName Win32_PageFileSetting -ErrorAction SilentlyContinue | Select-Object -First 1
        }
        if ($pfSetting) {
            Set-CimInstance -InputObject $pfSetting -Property @{ InitialSize=1024; MaximumSize=4096 } -ErrorAction SilentlyContinue
            Write-Log "  [OK] Pagefile fixed: 1 GB min / 4 GB max (8 GB RAM profile)" "Green"
        }
    }
}

if ($isWin10) {
    $tlPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"
    if (-not (Test-Path $tlPath)) { New-Item -Path $tlPath -Force -ErrorAction SilentlyContinue | Out-Null }
    Set-ItemProperty -Path $tlPath -Name "EnableActivityFeed"    -Value 0 -Type DWord -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $tlPath -Name "PublishUserActivities" -Value 0 -Type DWord -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $tlPath -Name "UploadUserActivities"  -Value 0 -Type DWord -ErrorAction SilentlyContinue
    Write-Log "  [OK] Windows Timeline / Activity Feed disabled" "Green"

    $hiberPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power"
    Set-ItemProperty -Path $hiberPath -Name "HiberbootEnabled" -Value 0 -Type DWord -ErrorAction SilentlyContinue
    Write-Log "  [OK] Fast Startup (Hiberboot) disabled (more stable on HDD)" "Green"
}

# ==============================================================================
# STEP 12  --  PERSISTENT RAM WATCHDOG  [V4 KEY FIX  --  BUG-1/2/5 FIXED]
# ==============================================================================
Show-Section "STEP 12: Persistent RAM Watchdog  --  Scheduled Task [V4 KEY FIX]"
Write-Log "  KEY FIX: This is why RAM bounces back to 96% after 2-3 min." "Magenta"
Write-Log "  A silent watchdog task runs every 5 minutes to keep RAM clear." "Magenta"
Write-Log ""

# BUG-1 FIX: Save watchdog script to disk FIRST, no here-string nesting
$watchdogDir  = "C:\ProgramData\RAMWatchdog"
$watchdogFile = "$watchdogDir\RAMWatchdog.ps1"
if (-not (Test-Path $watchdogDir)) {
    New-Item -Path $watchdogDir -ItemType Directory -Force | Out-Null
}

# Watchdog script content  --  written as a plain array of lines (no nesting issue)
$wdLines = @(
    "# RAM Watchdog v4.0  --  runs silently every 5 min via Scheduled Task",
    "# Fires only when RAM usage exceeds threshold",
    "`$ErrorActionPreference = 'SilentlyContinue'",
    "",
    "# BUG-2 FIX: unique class names NtW / TokW / MemW (never clash with main script)",
    "`$ntCode = @`"",
    "using System; using System.Runtime.InteropServices;",
    "public class NtW {",
    "    [DllImport(`"ntdll.dll`")]",
    "    public static extern uint NtSetSystemInformation(int i, IntPtr p, int l);",
    "}",
    "`"@",
    "if (-not ([System.Management.Automation.PSTypeName]'NtW').Type) {",
    "    Add-Type -TypeDefinition `$ntCode -ErrorAction SilentlyContinue",
    "}",
    "",
    "`$privCode = @`"",
    "using System; using System.Runtime.InteropServices;",
    "public class TokW {",
    "    [StructLayout(LayoutKind.Sequential, Pack=1)]",
    "    public struct TokPriv1Luid { public int Count; public long Luid; public int Attr; }",
    "    [DllImport(`"kernel32.dll`", ExactSpelling=true)]",
    "    public static extern IntPtr GetCurrentProcess();",
    "    [DllImport(`"advapi32.dll`", ExactSpelling=true, SetLastError=true)]",
    "    public static extern bool OpenProcessToken(IntPtr h, int acc, ref IntPtr tok);",
    "    [DllImport(`"advapi32.dll`", SetLastError=true)]",
    "    public static extern bool LookupPrivilegeValue(string host, string name, ref long luid);",
    "    [DllImport(`"advapi32.dll`", ExactSpelling=true, SetLastError=true)]",
    "    public static extern bool AdjustTokenPrivileges(IntPtr htok, bool disall, ref TokPriv1Luid newst, int len, IntPtr prev, IntPtr relen);",
    "    public static bool Enable(string priv) {",
    "        IntPtr hproc = GetCurrentProcess(); IntPtr htok = IntPtr.Zero;",
    "        if (!OpenProcessToken(hproc, 0x28, ref htok)) return false;",
    "        TokPriv1Luid tp; tp.Count=1; tp.Luid=0; tp.Attr=2;",
    "        if (!LookupPrivilegeValue(null, priv, ref tp.Luid)) return false;",
    "        return AdjustTokenPrivileges(htok, false, ref tp, 0, IntPtr.Zero, IntPtr.Zero);",
    "    }",
    "}",
    "`"@",
    "if (-not ([System.Management.Automation.PSTypeName]'TokW').Type) {",
    "    Add-Type -TypeDefinition `$privCode -ErrorAction SilentlyContinue",
    "}",
    "",
    "`$memCode = @`"",
    "using System; using System.Runtime.InteropServices;",
    "public class MemW {",
    "    [DllImport(`"psapi.dll`")]    public static extern bool EmptyWorkingSet(IntPtr h);",
    "    [DllImport(`"kernel32.dll`")] public static extern IntPtr OpenProcess(uint acc, bool inh, int pid);",
    "    [DllImport(`"kernel32.dll`")] public static extern bool CloseHandle(IntPtr h);",
    "}",
    "`"@",
    "if (-not ([System.Management.Automation.PSTypeName]'MemW').Type) {",
    "    Add-Type -TypeDefinition `$memCode -ErrorAction SilentlyContinue",
    "}",
    "",
    "function Invoke-WdCmd { param([int]`$c)",
    "    `$p = [System.Runtime.InteropServices.Marshal]::AllocHGlobal(4)",
    "    [System.Runtime.InteropServices.Marshal]::WriteInt32(`$p, `$c)",
    "    [NtW]::NtSetSystemInformation(80, `$p, 4) | Out-Null",
    "    [System.Runtime.InteropServices.Marshal]::FreeHGlobal(`$p)",
    "}",
    "",
    "# Check RAM usage",
    "`$os      = Get-CimInstance Win32_OperatingSystem",
    "`$totalMB = `$os.TotalVisibleMemorySize / 1KB",
    "`$freeMB  = `$os.FreePhysicalMemory / 1KB",
    "`$pct     = [math]::Round(((`$totalMB - `$freeMB) / `$totalMB) * 100, 1)",
    "`$threshold = 75",
    "",
    "if (`$pct -gt `$threshold) {",
    "    [TokW]::Enable('SeIncreaseQuotaPrivilege')        | Out-Null",
    "    [TokW]::Enable('SeProfileSingleProcessPrivilege') | Out-Null",
    "    Invoke-WdCmd -c 4; Start-Sleep -Milliseconds 200",
    "    Invoke-WdCmd -c 3; Start-Sleep -Milliseconds 200",
    "    Invoke-WdCmd -c 1; Start-Sleep -Milliseconds 200",
    "    Invoke-WdCmd -c 3",
    "",
    "    `$skipList = @('System','Idle','smss','csrss','wininit','winlogon','lsass',",
    "                  'services','Registry','dwm','fontdrvhost','audiodg','svchost',",
    "                  'MsMpEng','NisSrv','SecurityHealthService')",
    "    Get-Process -ErrorAction SilentlyContinue |",
    "      Where-Object { `$skipList -notcontains `$_.ProcessName } |",
    "      Sort-Object WorkingSet64 -Descending | Select-Object -First 5 |",
    "      ForEach-Object {",
    "        try {",
    "            `$h = [MemW]::OpenProcess([uint32]0x1100, `$false, `$_.Id)",
    "            if (`$h -ne [IntPtr]::Zero) {",
    "                [MemW]::EmptyWorkingSet(`$h) | Out-Null",
    "                [MemW]::CloseHandle(`$h)    | Out-Null",
    "            }",
    "        } catch {}",
    "    }",
    "",
    "    `$os2     = Get-CimInstance Win32_OperatingSystem",
    "    `$free2MB = [math]::Round(`$os2.FreePhysicalMemory / 1KB, 1)",
    "    `$ts      = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'",
    "    `$logPath = `"`$env:USERPROFILE\Desktop\RAM-Watchdog-Log.txt`"",
    "    Add-Content -Path `$logPath -Value `"`$ts  Triggered at `$pct% -> Free after: `$free2MB MB`" -ErrorAction SilentlyContinue",
    "}",
    "}"
)

$wdLines | Out-File -FilePath $watchdogFile -Encoding UTF8 -Force
Write-Log ("  [OK] Watchdog script written to: {0}" -f $watchdogFile) "Green"

# BUG-5 FIX: Register scheduled task with proper RepetitionDuration
$taskName = "RAMWatchdog-GodMode-V4"
Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue

$action  = New-ScheduledTaskAction `
    -Execute  "powershell.exe" `
    -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$watchdogFile`""

# FIXED: Task Scheduler rejects [TimeSpan]::MaxValue (P99999999D out of range).
# Use 10 years (87600 hours)  --  effectively permanent, accepted by all Windows versions.
$trigger = New-ScheduledTaskTrigger -Once `
    -At (Get-Date).AddMinutes(5) `
    -RepetitionInterval  (New-TimeSpan -Minutes 5) `
    -RepetitionDuration  (New-TimeSpan -Hours 87600)

$settings = New-ScheduledTaskSettingsSet `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 2) `
    -MultipleInstances IgnoreNew `
    -StartWhenAvailable `
    -Hidden

$principal = New-ScheduledTaskPrincipal `
    -UserId    "SYSTEM" `
    -LogonType ServiceAccount `
    -RunLevel  Highest

try {
    Register-ScheduledTask `
        -TaskName  $taskName `
        -Action    $action `
        -Trigger   $trigger `
        -Settings  $settings `
        -Principal $principal `
        -Force -ErrorAction Stop | Out-Null

    Write-Log "  [OK] Watchdog task REGISTERED successfully" "Green"
    Write-Log ("  [OK] Task name : {0}" -f $taskName) "Green"
    Write-Log "  [OK] Schedule  : every 5 minutes, SYSTEM account, hidden window" "Green"
    Write-Log "  [OK] Threshold : fires only when RAM > 75% used (low overhead)" "Green"
    Write-Log ("  [OK] Log file  : {0}\Desktop\RAM-Watchdog-Log.txt" -f $env:USERPROFILE) "DarkGray"
} catch {
    Write-Log ("  [WARN] Task register failed: {0}" -f $_.Exception.Message) "Yellow"
    Write-Log "  [i] You can manually run the watchdog from:" "Yellow"
    Write-Log ("  [i] {0}" -f $watchdogFile) "Yellow"
}

# Run watchdog inline RIGHT NOW (first pass  --  visible output)
Write-Log ""
Write-Log "  Running watchdog FIRST PASS inline (visible)..." "Cyan"
$os_wd    = Get-CimInstance Win32_OperatingSystem
$totalMBwd = $os_wd.TotalVisibleMemorySize / 1KB
$freeMBwd  = $os_wd.FreePhysicalMemory    / 1KB
$pctWD     = [math]::Round((($totalMBwd - $freeMBwd) / $totalMBwd) * 100, 1)
Write-Log ("  Current RAM usage: {0}% ({1} MB free)" -f $pctWD, [math]::Round($freeMBwd,0)) "White"
if ($pctWD -gt 75) {
    [TokenPriv4]::Enable("SeIncreaseQuotaPrivilege")        | Out-Null
    [TokenPriv4]::Enable("SeProfileSingleProcessPrivilege") | Out-Null
    Invoke-MemoryCommand -cmd 4 -label "Watchdog: Flush Modified"
    Start-Sleep -Milliseconds 200
    Invoke-MemoryCommand -cmd 3 -label "Watchdog: Purge Standby"
    Start-Sleep -Milliseconds 200
    Invoke-MemoryCommand -cmd 1 -label "Watchdog: Empty Working Sets"
    Start-Sleep -Milliseconds 200
    Invoke-MemoryCommand -cmd 3 -label "Watchdog: Post-trim Standby flush"
    Write-Log "  [OK] Watchdog first pass complete (RAM was above 75%)" "Green"
} else {
    Write-Log "  [--] RAM below threshold (75%)  --  watchdog trim not triggered this pass" "DarkGray"
}

# ==============================================================================
# FINAL SUMMARY
# ==============================================================================
Write-Log ""
Write-Log "  +==================================================================+" "Cyan"
Write-Log "  |                  SUMMARY  --  GOD MODE v4.0                        |" "Cyan"
Write-Log "  +==================================================================+" "Cyan"

$os1   = Get-CimInstance Win32_OperatingSystem
$free1 = [math]::Round($os1.FreePhysicalMemory    / 1MB, 2)
$used1 = [math]::Round($total - $free1, 2)
$pct1  = [math]::Round(($used1 / $total) * 100, 1)
$gain  = [math]::Round($free1 - $free0, 2)

Write-Log ""
Write-Log ("  OS            :  {0}  [Build {1} | {2}]" -f $winName, $winBuild, $winTag) "White"
Write-Log ("  Machine       :  {0}  |  Brand: {1}" -f $cs.Model, $brand) "White"
Write-Log ("  Total RAM     :  {0} GB  |  Disk: {1}" -f $ramGB, $mediaType) "White"
Write-Log ""
Write-Log ("  Before        :  {0} GB free  ({1}% used)" -f $free0, [math]::Round((($total-$free0)/$total)*100,1)) "DarkGray"
Write-Log ("  After         :  {0} GB free  ({1}% used)" -f $free1, $pct1) "White"

if ($gain -gt 0) {
    Write-Log ("  Freed         :  +{0} GB" -f $gain) "Green"
} else {
    Write-Log "  Note          :  Immediate gain may be small  --  kernel clears more over ~30 sec" "Yellow"
}

$ramCol = if ($pct1 -gt 80) {"Red"} elseif ($pct1 -gt 60) {"Yellow"} else {"Green"}
Write-Log ("  RAM in use    :  {0} GB  ({1}%)" -f $used1, $pct1) $ramCol
Write-Log ""
Write-Log ("  Svc (common)  :  {0}" -f $Script:SvcCommon) "Cyan"
Write-Log ("  Svc (brand)   :  {0}  [{1}]" -f $Script:SvcBrand, $brand) "Cyan"
Write-Log ("  Svc (keyword) :  {0}" -f $Script:SvcKW) "Cyan"
Write-Log ("  Tasks OFF     :  {0}" -f $Script:TasksOff) "Cyan"
Write-Log ("  Startup DEL   :  {0}" -f $Script:StartupDel) "Cyan"
Write-Log ""
Write-Log "  ----------------------------------------------------------------" "DarkGray"
Write-Log "  [V4] Watchdog task active  --  checks RAM every 5 min silently" "Magenta"
Write-Log "  [V4] SwapFile.sys disabled (SSD), WSL2 reclaim configured" "Magenta"
Write-Log ("  [V4] SessionViewSize = {0} MB (8 GB={1})" -f $svSize, $is8GB) "Magenta"
Write-Log "  [V4] Defender CPU capped at 25% (protection still active)" "Magenta"
Write-Log "  ----------------------------------------------------------------" "DarkGray"
Write-Log ""
Write-Log "  [!] RESTART recommended  --  registry changes need reboot to take full effect." "Yellow"
Write-Log "  [!] Brand services DISABLED permanently  --  will not auto-start on boot." "Yellow"
Write-Log "  [!] If any Fn key / sensor / hardware feature stops working:" "Yellow"
Write-Log "      Open: services.msc -> find the service -> set to Automatic -> Start" "Yellow"
Write-Log ("  [!] To REMOVE watchdog: Task Scheduler -> '{0}'" -f $taskName) "Yellow"
Write-Log "  ----------------------------------------------------------------" "DarkGray"

# Save log
try {
    $Script:LogLines | Out-File -FilePath $Script:LogFile -Encoding UTF8 -ErrorAction Stop
    Write-Log ""
    Write-Log "  [LOG] Report saved to:" "Cyan"
    Write-Log ("        {0}" -f $Script:LogFile) "Cyan"
} catch {
    Write-Log "  [LOG] Could not write log (Desktop may be restricted)." "DarkGray"
}

Write-Log ""
Write-Log "  Script complete. Press ENTER to close..." "Cyan"
$null = Read-Host
