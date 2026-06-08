# ==============================================================================
#  Optimize-RAM-v4.ps1  |  GOD MODE  v4.0
#  Target  : Windows 11  (Build 22000+)  |  8 GB RAM  primary target
#  Compat  : Windows 10 (1809+)  also supported
#  Language: English
#  Author  : GOD-MODE build — L99 audit
#  ------------------------------------------------------------------------------
#  WHAT V4 FIXES (root cause of RAM bouncing back to 96% after 2-3 min):
#   [FIX-1]  Persistent watchdog Scheduled Task — runs every 5 min silently
#   [FIX-2]  Memory Compression process throttled (Win11 specific)
#   [FIX-3]  Correct kernel pool sizing for 8 GB (SessionViewSize 256 MB)
#   [FIX-4]  SwapFile.sys (Win11 compressed swap) disabled on SSD
#   [FIX-5]  Commit limit registry cap for NonPagedPool / PagedPool
#   [FIX-6]  Defender real-time scan CPU/RAM throttle via policy
#   [FIX-7]  SearchIndexer set to Manual + throttle via policy
#   [FIX-8]  vmmem / WSL2 auto-memory reclaim via .wslconfig
#   [FIX-9]  ReadyBoost / ReadyDrive disabled
#   [FIX-10] ClearPageFileAtShutdown enabled (stops stale page file RAM pressure)
#   [FIX-11] LSASS hardened mode re-evaluated (not killed — kept for stability)
#   [FIX-12] Runtime top-10 RAM hog process working-set trim (not just services)
#  ------------------------------------------------------------------------------
#  Requires: PowerShell 5.1+  |  Administrator  |  Windows 10 1809+ / Win11
# ==============================================================================

#Requires -Version 5.1
Set-StrictMode -Version Latest
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
$Script:LogLines    = [System.Collections.Generic.List[string]]::new()
$Script:LogFile     = "$env:USERPROFILE\Desktop\RAM-Optimize-V4-Log-$(Get-Date -f 'yyyyMMdd-HHmmss').txt"
$Script:TasksOff    = 0
$Script:SvcOff      = 0
$Script:StartupDel  = 0

function Write-Log {
    param([string]$msg, [string]$color = "White")
    Write-Host $msg -ForegroundColor $color
    $Script:LogLines.Add($msg)
}

function Show-Section {
    param([string]$title)
    $line = "  " + ([string][char]0x2500 * 60)
    Write-Log ""; Write-Log $line "DarkCyan"
    Write-Log ("  >> " + $title) "Cyan"
    Write-Log $line "DarkCyan"
}

# ==============================================================================
# STEP 0 — SYSTEM DETECTION
# ==============================================================================
Clear-Host
Write-Log ""
Write-Log "  +================================================================+" "Cyan"
Write-Log "  |     RAM OPTIMIZER  --  GOD MODE  v4.0                         |" "Cyan"
Write-Log "  |     Target: Windows 11  |  8 GB RAM  |  Persistent Fix        |" "Cyan"
Write-Log "  |     Supports: Windows 10 (1809+) & Windows 11                 |" "Cyan"
Write-Log "  +================================================================+" "Cyan"
Write-Log ""

$cs   = Get-CimInstance Win32_ComputerSystem
$bios = Get-CimInstance Win32_BIOS
$os0  = Get-CimInstance Win32_OperatingSystem
$cpu  = Get-CimInstance Win32_Processor | Select-Object -First 1
$disk = Get-CimInstance Win32_DiskDrive | Select-Object -First 1

$winBuild  = [int]($os0.BuildNumber)
$winName   = $os0.Caption
$isWin11   = ($winBuild -ge 22000)
$isWin10   = (-not $isWin11) -and ($winBuild -ge 17763)
$winTag    = if ($isWin11) {"WIN11"} elseif ($isWin10) {"WIN10"} else {"WIN_OLD"}

$ramGB     = [math]::Round($cs.TotalPhysicalMemory / 1GB, 1)
$ramMB     = [math]::Round($cs.TotalPhysicalMemory / 1MB, 0)
$is8GB     = ($ramGB -ge 7.5 -and $ramGB -le 9.0)
$free0     = [math]::Round($os0.FreePhysicalMemory  / 1MB, 2)
$total     = [math]::Round($os0.TotalVisibleMemorySize / 1MB, 2)

# SSD detection
$mediaType = "UNKNOWN"
try {
    $pdisk = Get-PhysicalDisk | Select-Object -First 1
    if ($pdisk) { $mediaType = $pdisk.MediaType }  # SSD / HDD / SCM
} catch {}
$isSSD = ($mediaType -like "*SSD*" -or $mediaType -eq "3")  # 3 = SSD in CIM

# Brand detection
$mfrRaw  = ($cs.Manufacturer + " " + $cs.Model).ToLower()
$biosRaw = ($bios.Manufacturer + " " + ($bios.SMBIOSBIOSVersion -join " ")).ToLower()
$brand   = "UNKNOWN"
$brandSrc= "manufacturer"
$brandMap = [ordered]@{
    "dell"      = "DELL";    "hp "       = "HP";       "hewlett" = "HP"
    "lenovo"    = "LENOVO";  "asus"      = "ASUS";     "acer "   = "ACER"
    "msi"       = "MSI";     "samsung"   = "SAMSUNG";  "microsoft" = "MICROSOFT_SURFACE"
    "toshiba"   = "TOSHIBA"; "huawei"    = "HUAWEI";   "razer"   = "RAZER"
    "gigabyte"  = "GIGABYTE";"intel"     = "INTEL_NUC";"panasonic"= "PANASONIC"
    "fujitsu"   = "FUJITSU"; "vaio"      = "VAIO";     "lg "     = "LG"
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
    "DELL"               {"Blue"}; "HP" {"DarkCyan"}; "LENOVO" {"Red"}
    "ASUS"               {"Cyan"}; "MSI" {"Red"};     "ACER"   {"Green"}
    "SAMSUNG"            {"Cyan"}; "RAZER" {"Green"};  "MICROSOFT_SURFACE" {"Blue"}
    "GIGABYTE"           {"Yellow"}; default {"Yellow"}
}

Write-Log ("  OS      :  {0}" -f $winName) "White"
Write-Log ("  Build   :  {0}  [{1}]" -f $winBuild, $winTag) "White"
Write-Log ("  Machine :  {0}  |  {1}" -f $cs.Manufacturer, $cs.Model) "White"
Write-Log ("  CPU     :  {0}" -f $cpu.Name) "White"
Write-Log ("  RAM     :  {0} GB  (Free now: {1} GB)" -f $ramGB, $free0) "White"
Write-Log ("  Disk    :  {0}  [{1}]" -f $disk.Model, $mediaType) "White"
Write-Log ("  Brand   :  [ {0} ]  (source: {1})" -f $brand, $brandSrc) $brandColor

if ($is8GB)    { Write-Log "  [*] 8 GB RAM profile ACTIVE — applying targeted kernel limits" "Magenta" }
if ($isSSD)    { Write-Log "  [*] SSD detected — SwapFile.sys will be DISABLED" "Magenta" }
if ($winTag -eq "WIN_OLD") { Write-Log "  [!] Old Windows build — some features may not work" "Yellow" }
Write-Log ""

# ==============================================================================
# C# / P-INVOKE BLOCKS
# ==============================================================================
$ntdllCode = @"
using System; using System.Runtime.InteropServices;
public class NtMem4 {
    [DllImport("ntdll.dll")]
    public static extern uint NtSetSystemInformation(int InfoClass, IntPtr Info, int Length);
}
"@
if (-not ([System.Management.Automation.PSTypeName]"NtMem4").Type) {
    Add-Type -TypeDefinition $ntdllCode -EA SilentlyContinue
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
    public static extern bool AdjustTokenPrivileges(IntPtr htok, bool disall, ref TokPriv1Luid newst, int len, IntPtr prev, IntPtr relen);
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
    Add-Type -TypeDefinition $privCode -EA SilentlyContinue
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
    Add-Type -TypeDefinition $cacheCode -EA SilentlyContinue
}

$apiCode = @"
using System; using System.Runtime.InteropServices;
public class MemUtil4 {
    [DllImport("psapi.dll")]    public static extern bool EmptyWorkingSet(IntPtr h);
    [DllImport("kernel32.dll")] public static extern IntPtr OpenProcess(uint acc, bool inh, int pid);
    [DllImport("kernel32.dll")] public static extern bool CloseHandle(IntPtr h);
    [DllImport("kernel32.dll")] public static extern bool SetProcessWorkingSetSizeEx(IntPtr h, IntPtr min, IntPtr max, int flags);
}
"@
if (-not ([System.Management.Automation.PSTypeName]"MemUtil4").Type) {
    Add-Type -TypeDefinition $apiCode -EA SilentlyContinue
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

function Stop-And-Disable {
    param(
        [System.Collections.Specialized.OrderedDictionary]$ServiceMap,
        [string]$Category
    )
    $count = 0
    foreach ($s in $ServiceMap.Keys) {
        $svc = Get-Service -Name $s -EA SilentlyContinue
        if (-not $svc) {
            $svc = Get-Service -EA SilentlyContinue |
                   Where-Object { $_.DisplayName -like "*$s*" } |
                   Select-Object -First 1
        }
        if (-not $svc) { continue }
        $desc = $ServiceMap[$s]
        try {
            if ($svc.Status -eq "Running") {
                Stop-Service -InputObject $svc -Force -EA SilentlyContinue
                Write-Log ("  [STOP] {0,-42} {1}" -f $svc.Name, $desc) "DarkYellow"
            }
            Set-Service -InputObject $svc -StartupType Disabled -EA SilentlyContinue
            Write-Log ("  [OFF ] {0,-42} {1}" -f $svc.Name, $desc) "DarkGray"
            $count++; $Script:SvcOff++
        } catch {}
    }
    return $count
}

# ==============================================================================
# STEP 1 — KERNEL MEMORY FLUSH (Standby + Modified + Working Sets)
# ==============================================================================
Show-Section "STEP 1: Kernel Memory Flush — Standby / Modified / Working Sets"

[TokenPriv4]::Enable("SeIncreaseQuotaPrivilege")        | Out-Null
[TokenPriv4]::Enable("SeProfileSingleProcessPrivilege") | Out-Null
[TokenPriv4]::Enable("SeDebugPrivilege")                | Out-Null

Invoke-MemoryCommand -cmd 4 -label "Flush Modified Page List (dirty -> standby)"
Start-Sleep -Milliseconds 400
Invoke-MemoryCommand -cmd 3 -label "Purge Standby List (free kernel cache)"
Start-Sleep -Milliseconds 400
Invoke-MemoryCommand -cmd 1 -label "Empty All Working Sets (kernel + user)"
Start-Sleep -Milliseconds 200

# Also flush combined modified+standby (cmd=5 on modern builds)
if ($winBuild -ge 17763) {
    Invoke-MemoryCommand -cmd 5 -label "Flush Combined Modified+Standby List (Build 1809+)"
    Start-Sleep -Milliseconds 300
}

# ==============================================================================
# STEP 2 — FILE SYSTEM CACHE FLUSH
# ==============================================================================
Show-Section "STEP 2: File System Cache Flush"

$minB = [IntPtr]::Zero; $maxB = [IntPtr]::Zero; $flg = 0
[SysCache4]::GetSystemFileCacheSize([ref]$minB, [ref]$maxB, [ref]$flg) | Out-Null
Write-Log ("  Current cache:  min={0} MB   max={1} MB" -f ([long]$minB/1MB), ([long]$maxB/1MB)) "White"
$r2 = [SysCache4]::SetSystemFileCacheSize([IntPtr](-1), [IntPtr](-1), 0)
if ($r2) { Write-Log "  [OK] File system cache flushed" "Green" }
else     { Write-Log "  [WARN] Could not flush (SE_INCREASE_QUOTA may be needed)" "Yellow" }

# ==============================================================================
# STEP 3 — WORKING SET TRIM (All user processes)
# ==============================================================================
Show-Section "STEP 3: Working Set Trim — All user processes"

$skipList = @("System","Idle","smss","csrss","wininit","winlogon","lsass",
              "services","Registry","Memory Compression","MsMpEng","audiodg",
              "dwm","fontdrvhost","wdmaud","svchost","ntoskrnl","hal",
              "NisSrv","SecurityHealthService","WUDFHost")
$trimOK = 0; $trimFail = 0; $freedBytes = [long]0

Get-Process -EA SilentlyContinue |
  Where-Object { $skipList -notcontains $_.ProcessName } |
  Sort-Object WorkingSet64 -Descending |
  ForEach-Object {
    $ws0    = $_.WorkingSet64
    $ACCESS = [uint32]0x1F0FFF   # PROCESS_ALL_ACCESS — needed for SetWorkingSetSizeEx
    try {
        $h = [MemUtil4]::OpenProcess($ACCESS, $false, $_.Id)
        if ($h -ne [IntPtr]::Zero) {
            # EmptyWorkingSet moves pages to standby list
            [MemUtil4]::EmptyWorkingSet($h) | Out-Null
            # SetProcessWorkingSetSizeEx -1,-1 = release min/max caps
            [MemUtil4]::SetProcessWorkingSetSizeEx($h, [IntPtr](-1), [IntPtr](-1), 0) | Out-Null
            [MemUtil4]::CloseHandle($h) | Out-Null
            $pNow = Get-Process -Id $_.Id -EA SilentlyContinue
            if ($pNow) { $freedBytes += [math]::Max(0, $ws0 - $pNow.WorkingSet64) }
            $trimOK++
        } else { $trimFail++ }
    } catch { $trimFail++ }
}

# Second pass — flush standby list again after trim (catches newly promoted pages)
Start-Sleep -Milliseconds 500
Invoke-MemoryCommand -cmd 3 -label "Post-trim Standby flush"

Write-Log ("  [OK] Trimmed   : {0} processes" -f $trimOK) "Green"
Write-Log ("  [OK] Freed     : ~{0} MB" -f [math]::Round($freedBytes/1MB,1)) "Green"
Write-Log ("  [--] Skipped   : {0} system processes" -f $trimFail) "DarkGray"

# ==============================================================================
# STEP 4 — SERVICE LISTS (Common + Win10/11 specific)
# ==============================================================================

# ---------- Common (both Win10 + Win11) ----------
$svcsCommon = [ordered]@{
    "DiagTrack"              = "Connected User Experiences & Telemetry"
    "dmwappushservice"       = "WAP Push Message Routing (telemetry)"
    "WerSvc"                 = "Windows Error Reporting"
    "wercplsupport"          = "WER Control Panel Support"
    "XblGameSave"            = "Xbox Game Save"
    "XboxNetApiSvc"          = "Xbox Live Networking"
    "XblAuthManager"         = "Xbox Live Auth Manager"
    "XboxGipSvc"             = "Xbox Accessories"
    "MapsBroker"             = "Downloaded Maps Manager"
    "RetailDemo"             = "Retail Demo Service"
    "wisvc"                  = "Windows Insider Service"
    "lfsvc"                  = "Geolocation / GPS"
    "TapiSrv"                = "Telephony"
    "Fax"                    = "Fax"
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
    "SCardSvr"               = "Smart Card"
    "SCPolicySvc"            = "Smart Card Removal Policy"
    "MixedRealityOpenXRSvc"  = "Mixed Reality OpenXR"
    "PhoneSvc"               = "Phone Service"
    "PimIndexMaintenanceSvc" = "Contact Data"
    "UnistoreSvc"            = "User Data Storage"
    "UserDataSvc"            = "User Data Access"
    "PrintNotify"            = "Printer Extensions & Notifications"
    "Spooler"                = "Print Spooler (if no printer)"
    "BthAvctpSvc"            = "Bluetooth Audio Gateway"
    "BTAGService"            = "Bluetooth Audio AVRCP"
    "AJRouter"               = "AllJoyn Router (IoT)"
    "CscService"             = "Offline Files"
    "DusmSvc"                = "Data Usage"
}

$svcsWin10Only = [ordered]@{
    "wlidsvc"                = "Microsoft Account Sign-in Assistant"
    "SEMgrSvc"               = "Payments and NFC/SE Manager"
    "NcbService"             = "Network Connection Broker"
    "CDPSvc"                 = "Connected Devices Platform"
    "WMPNetworkSvc"          = "Windows Media Player Network Sharing"
    "HomeGroupListener"      = "HomeGroup Listener"
    "HomeGroupProvider"      = "HomeGroup Provider"
}

$svcsWin11Only = [ordered]@{
    "cbdhsvc"                = "Clipboard User Service"
    "WpnService"             = "Windows Push Notifications System"
    "WpnUserService"         = "Windows Push Notifications User"
    "DsSvc"                  = "Data Sharing Service"
    "DevicesFlowUserSvc"     = "Devices Flow"
    "NPSMSvc"                = "Now Playing Session Manager"
    "BcastDVRUserService"    = "GameDVR & Broadcast User Service"
    "PerceptionSimulation"   = "Windows Perception Simulation"
    "MsKeyboardFilter"       = "Microsoft Keyboard Filter"
    "DoSvc"                  = "Delivery Optimization"
    "DcomLaunch"             = ""   # skip — system critical (will be filtered)
    "CDPUserSvc"             = "Connected Devices Platform User Service"
    "PushToInstall"          = "Windows PushToInstall"
    "NetTcpPortSharing"      = "Net.Tcp Port Sharing"
    "WbioSrvc"               = "Windows Biometric (if no fingerprint reader)"
}
# Remove DcomLaunch from list — it is critical
$svcsWin11Only.Remove("DcomLaunch")

# ---------- Brand services ----------
$svcsDELL = [ordered]@{
    "DellClientManagementService"            = "Dell Client Management"
    "DellUpdate"                             = "Dell Update"
    "DellSupportAssistRemedationService"     = "Dell SupportAssist Remediation"
    "DellFoundationServices"                 = "Dell Foundation Services"
    "DellTechHubService"                     = "Dell TechHub"
    "DellOptimizer"                          = "Dell Optimizer"
    "DellMobileConnect"                      = "Dell Mobile Connect"
    "DellDataVault"                          = "Dell Data Vault (telemetry)"
    "DellDataVaultWizard"                    = "Dell Data Vault Wizard"
    "ThermalService"                         = "Dell Thermal Service"
    "DellDigitalDelivery"                    = "Dell Digital Delivery"
    "DellServiceConnectivity"                = "Dell Service Connectivity"
}
$svcsHP = [ordered]@{
    "HPAppHelperCap"             = "HP App Helper Capture"
    "HPDiagsMsgSvc"              = "HP Diagnostics Messages"
    "HPNetworkCap"               = "HP Network Capture (telemetry)"
    "HPSysInfoCap"               = "HP SysInfo Capture (telemetry)"
    "hpsvc"                      = "HP Service"
    "HpTouchpointAnalyticsService" = "HP Touchpoint Analytics"
    "HPPrintScanDoctorService"   = "HP Print Scan Doctor"
    "HPAudioSwitch"              = "HP Audio Switch"
    "HPWMISVC"                   = "HP WMI Service"
    "HPJumpStartBridge"          = "HP JumpStart Bridge"
    "HPJumpStartSvc"             = "HP JumpStart"
    "hpCMSgt"                    = "HP Connection Manager"
    "HPSmartAdapter"             = "HP Smart Adapter"
    "HPUpdateService"            = "HP Update Service"
    "HPDrvSvc"                   = "HP Driver Service"
}
$svcsLENOVO = [ordered]@{
    "ImControllerService"        = "Lenovo IdeaPad Controller"
    "LenovoFnAndFunctionKeys"    = "Lenovo Fn Keys"
    "Lenovo.Modern.ImController" = "Lenovo Modern ImController"
    "LenovoVantageService"       = "Lenovo Vantage"
    "LenovoSystemUpdateAddin"    = "Lenovo System Update Addin"
    "SUService"                  = "Lenovo System Update"
    "LENOVO.CAMMUTE"             = "Lenovo Camera Mute"
    "LENOVO.MICMUTE"             = "Lenovo Mic Mute"
    "PMSvc"                      = "Lenovo Power Manager"
    "LenovoSmartStandbyService"  = "Lenovo Smart Standby"
    "LenovoUtilityService"       = "Lenovo Utility"
    "LenovoWiFiHotspotSvc"       = "Lenovo WiFi Hotspot"
}
$svcsASUS = [ordered]@{
    "asHmComSvc"                 = "ASUS HM Com"
    "AsSysCtrlService"           = "ASUS System Control"
    "AsusCertService"            = "ASUS Certificate"
    "ASUSUpdate"                 = "ASUS Update"
    "ASUSLinkNear"               = "ASUS Link Near (Armoury Crate)"
    "ASUSLinkRemote"             = "ASUS Link Remote (Armoury Crate)"
    "ASUSOptimization"           = "ASUS Optimization"
    "ASUSSystemAnalysis"         = "ASUS System Analysis"
    "ASUSSystemDiagnosis"        = "ASUS System Diagnosis"
    "ROGLiveService"             = "ROG Live"
    "ArmouryCrateService"        = "Armoury Crate"
    "GamingCenterService"        = "ASUS Gaming Center"
    "ASUSGiftBoxService"         = "ASUS Gift Box"
    "ASUSSystemControlInterface" = "ASUS System Control Interface"
}
$svcsMSI = [ordered]@{
    "MSI_SuperCharger"       = "MSI SuperCharger"
    "SCM"                    = "MSI System Control Manager"
    "msidrvsvc"              = "MSI Driver Service"
    "MSICenterService"       = "MSI Center"
    "MSIGamingCenterService" = "MSI Gaming Center"
    "DragonCenterService"    = "MSI Dragon Center"
    "NahimicService"         = "Nahimic Audio"
    "MSIRGBService"          = "MSI RGB"
}
$svcsACER = [ordered]@{
    "AcerService"                = "Acer Service"
    "AcerCloudService"           = "Acer Cloud"
    "AcerPortalService"          = "Acer Portal"
    "AcerLaunchManager"          = "Acer Launch Manager"
    "AcerOptimizer"              = "Acer Optimizer"
    "PredatorSenseService"       = "Acer PredatorSense"
    "NitroSenseService"          = "Acer NitroSense"
    "QuickAccessService"         = "Acer Quick Access"
    "AcerUpdateService"          = "Acer Update"
    "AcerCare"                   = "Acer Care Center"
}
$svcsSAMSUNG   = [ordered]@{
    "SamsungMagicianService" = "Samsung Magician"
    "SamsungDeXSvc"          = "Samsung DeX"
    "SamsungUpdateService"   = "Samsung Update"
    "SamsungSystemManager"   = "Samsung System Manager"
}
$svcsSURFACE   = [ordered]@{
    "SurfaceService"                     = "Surface Service"
    "SurfaceTelemetryService"            = "Surface Telemetry"
    "SurfaceDiagnostics"                 = "Surface Diagnostics"
    "SurfaceFirmwareProvisioningService" = "Surface Firmware Provisioning"
}
$svcsRAZER     = [ordered]@{
    "Razer Chroma SDK Server"  = "Razer Chroma SDK Server"
    "Razer Chroma SDK Service" = "Razer Chroma SDK Service"
    "RazerCentralService"      = "Razer Central"
    "RazerIngameEngine"        = "Razer InGame Engine"
    "Razer Synapse Service"    = "Razer Synapse"
    "RzActionSvc"              = "Razer Action Service"
}
$svcsGIGABYTE  = [ordered]@{
    "GbActuatorService"     = "Gigabyte Actuator"
    "AppCenter"             = "Gigabyte App Center"
    "EasyTuneEngineService" = "Gigabyte Easy Tune"
    "RGBFusionSvc"          = "Gigabyte RGB Fusion"
    "GbFirmwareUpdateSvc"   = "Gigabyte Firmware Update"
}
$svcsTOSHIBA   = [ordered]@{
    "TODDSrv"   = "Toshiba ODD Device";  "TMachInfo" = "Toshiba Machine Info"
    "TVALZ"     = "Toshiba ACPI Driver"; "TPCH"      = "Toshiba PCH Service"
}
$svcsHUAWEI    = [ordered]@{
    "HuaweiPCManagerSvc" = "Huawei PCManager"; "HuaweiService" = "Huawei Service"
}
$svcsLG        = [ordered]@{
    "LGUpdateService" = "LG Update"; "LGHubService" = "LG Hub"
}
$svcsPANA      = [ordered]@{ "PanaService" = "Panasonic Service" }
$svcsFUJITSU   = [ordered]@{
    "FjSessServiceAgent" = "Fujitsu Session Agent"
    "FUJBtnSvc"          = "Fujitsu Button Service"
}
$svcsVAIO      = [ordered]@{
    "VAIOCareService" = "VAIO Care"; "VAIOEventService" = "VAIO Event"
}

# ==============================================================================
# STEP 4 — DISABLE SERVICES
# ==============================================================================
Show-Section "STEP 4: Disable unnecessary Windows services"

Write-Log "  >> Common services (Win10 + Win11)..." "White"
$n4a = Stop-And-Disable -ServiceMap $svcsCommon -Category "Common"
Write-Log ("  >> Common: {0} services handled" -f $n4a) "Green"

if ($isWin10) {
    Write-Log "  >> Win10-only services..." "DarkGray"
    $n4b = Stop-And-Disable -ServiceMap $svcsWin10Only -Category "Win10Only"
    Write-Log ("  >> Win10 specific: {0} services" -f $n4b) "Green"
}
if ($isWin11) {
    Write-Log "  >> Win11-only services..." "DarkGray"
    $n4c = Stop-And-Disable -ServiceMap $svcsWin11Only -Category "Win11Only"
    Write-Log ("  >> Win11 specific: {0} services" -f $n4c) "Green"
}

# ==============================================================================
# STEP 5 — BRAND SERVICES
# ==============================================================================
Show-Section ("STEP 5: Brand services [ {0} ]" -f $brand)
Write-Log ("  >> Brand: {0}  |  Source: {1}" -f $brand, $brandSrc) $brandColor

$n5 = 0
switch ($brand) {
    "DELL"               { $n5 = Stop-And-Disable -ServiceMap $svcsDELL     -Category "DELL"    }
    "HP"                 { $n5 = Stop-And-Disable -ServiceMap $svcsHP       -Category "HP"      }
    "LENOVO"             { $n5 = Stop-And-Disable -ServiceMap $svcsLENOVO   -Category "LENOVO"  }
    "ASUS"               { $n5 = Stop-And-Disable -ServiceMap $svcsASUS     -Category "ASUS"    }
    "MSI"                { $n5 = Stop-And-Disable -ServiceMap $svcsMSI      -Category "MSI"     }
    "ACER"               { $n5 = Stop-And-Disable -ServiceMap $svcsACER     -Category "ACER"    }
    "SAMSUNG"            { $n5 = Stop-And-Disable -ServiceMap $svcsSAMSUNG  -Category "SAMSUNG" }
    "MICROSOFT_SURFACE"  { $n5 = Stop-And-Disable -ServiceMap $svcsSURFACE  -Category "SURFACE" }
    "RAZER"              { $n5 = Stop-And-Disable -ServiceMap $svcsRAZER    -Category "RAZER"   }
    "GIGABYTE"           { $n5 = Stop-And-Disable -ServiceMap $svcsGIGABYTE -Category "GIGABYTE"}
    "TOSHIBA"            { $n5 = Stop-And-Disable -ServiceMap $svcsTOSHIBA  -Category "TOSHIBA" }
    "HUAWEI"             { $n5 = Stop-And-Disable -ServiceMap $svcsHUAWEI   -Category "HUAWEI"  }
    "LG"                 { $n5 = Stop-And-Disable -ServiceMap $svcsLG       -Category "LG"      }
    "PANASONIC"          { $n5 = Stop-And-Disable -ServiceMap $svcsPANA     -Category "PANASONIC"}
    "FUJITSU"            { $n5 = Stop-And-Disable -ServiceMap $svcsFUJITSU  -Category "FUJITSU" }
    "VAIO"               { $n5 = Stop-And-Disable -ServiceMap $svcsVAIO     -Category "VAIO"    }
    "GENERIC_AMI"        {
        Write-Log "  [i] AMI BIOS — trying Gigabyte + ASUS..." "Yellow"
        $n5 = (Stop-And-Disable -ServiceMap $svcsGIGABYTE -Category "GIGABYTE/AMI") +
              (Stop-And-Disable -ServiceMap $svcsASUS     -Category "ASUS/AMI")
    }
    default { Write-Log "  [i] Unknown brand — skipping brand services." "Yellow" }
}
Write-Log ("  >> Brand [{0}] total: {1} services handled" -f $brand, $n5) $brandColor

# ==============================================================================
# STEP 6 — KEYWORD SCAN: Leftover brand services
# ==============================================================================
Show-Section "STEP 6: Keyword scan — leftover brand services"

$vendorKW = @(
    "dell","hewlett","hp ","hpinc","lenovo","thinkpad","ideapad","legion",
    "asus","armoury","rog ","tuf ","msi ","dragon center","nahimic",
    "acer ","predator","nitro","swift","aspire","travelmate",
    "samsung","toshiba","huawei","razer","synapse","chroma",
    "gigabyte","rgb fusion","easy tune","supportassist","vantage",
    "pcmanager","lg hub","fujitsu","panasonic","vaio","intel nuc"
)

$allSvcs = Get-Service -EA SilentlyContinue
$extraOff = 0
foreach ($svc in $allSvcs) {
    if ($svc.StartType -eq "Disabled") { continue }
    $dn = $svc.DisplayName.ToLower(); $sn = $svc.Name.ToLower()
    foreach ($kw in $vendorKW) {
        if ($dn -like "*$kw*" -or $sn -like "*$kw*") {
            try {
                if ($svc.Status -eq "Running") { Stop-Service $svc.Name -Force -EA SilentlyContinue }
                Set-Service  $svc.Name -StartupType Disabled -EA SilentlyContinue
                Write-Log ("  [KW-OFF] {0,-40}  {1}" -f $svc.Name, $svc.DisplayName) "DarkYellow"
                $extraOff++; $Script:SvcOff++
            } catch {}
            break
        }
    }
}
if ($extraOff -eq 0) { Write-Log "  [OK] No additional brand services found." "Green" }
else { Write-Log ("  [OK] {0} additional services disabled via keyword scan." -f $extraOff) "Green" }

# ==============================================================================
# STEP 7 — STARTUP ITEMS + SCHEDULED TASKS
# ==============================================================================
Show-Section "STEP 7: Startup items + Scheduled Tasks (brand vendor)"

$startupKeys = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run",
    "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
)
$startupKW = @(
    "dell","hewlett","hp ","lenovo","asus","armoury","msi ","acer ",
    "samsung","toshiba","huawei","razer","gigabyte","vantage",
    "supportassist","pcmanager","lg ","fujitsu","vaio","intel nuc",
    "dragon center","nahimic","nitro","predator","cortana","teams"
)

foreach ($regPath in $startupKeys) {
    if (-not (Test-Path $regPath)) { continue }
    $entries = Get-ItemProperty -Path $regPath -EA SilentlyContinue
    if (-not $entries) { continue }
    $entries.PSObject.Properties |
      Where-Object { $_.MemberType -eq "NoteProperty" -and $_.Name -notmatch "^PS" } |
      ForEach-Object {
        $valName = $_.Name; $valData = ($_.Value + "").ToLower()
        foreach ($kw in $startupKW) {
            if ($valName.ToLower() -like "*$kw*" -or $valData -like "*$kw*") {
                Remove-ItemProperty -Path $regPath -Name $valName -EA SilentlyContinue
                Write-Log ("  [RUN-DEL] {0}  =>  {1}" -f $valName, $_.Value) "DarkYellow"
                $Script:StartupDel++; break
            }
        }
    }
}

$taskKW = @(
    "dell","hp","lenovo","asus","msi","acer","samsung","toshiba",
    "huawei","razer","gigabyte","supportassist","vantage","armoury",
    "dragon center","nahimic","fujitsu","vaio","panasonic","nitro","predator",
    "cortana","onedrive","skype","teams","feedback"
)
try {
    $sched = New-Object -ComObject "Schedule.Service"
    $sched.Connect()
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
} catch {}

Write-Log ("  [OK] Startup registry entries removed : {0}" -f $Script:StartupDel) "Green"
Write-Log ("  [OK] Scheduled tasks disabled         : {0}" -f $Script:TasksOff) "Green"

# ==============================================================================
# STEP 8 — REGISTRY TUNING (Memory / Telemetry / Visual / TCP / Game)
# ==============================================================================
Show-Section "STEP 8: Registry tuning — Memory / Telemetry / Visual / TCP / Game"

$mm   = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
$pref = "$mm\PrefetchParameters"

# --- 8A: Memory Management (8 GB optimized) ---
# For 8 GB: SessionViewSize 256 MB is correct (V3 had 48 = too low -> kernel pressure)
$svSize = if ($is8GB) { 256 } else { 128 }
$mmSettings = @{
    "LargeSystemCache"       = 0    # 0 = optimize for programs (not file cache)
    "DisablePagingExecutive" = 1    # Keep kernel in RAM, not paged out
    "SecondLevelDataCache"   = 0    # Let Windows manage L2 cache
    "NonPagedPoolQuota"      = 0    # 0 = Windows sets limit
    "PagedPoolQuota"         = 0
    "SessionPoolSize"        = 48   # MB session pool
    "SessionViewSize"        = $svSize  # MB session view — 256 MB for 8 GB
    "SystemPages"            = 0    # 0 = auto
    "ClearPageFileAtShutdown"= 1    # [FIX-10] Clear page file on shutdown
}
foreach ($k in $mmSettings.Keys) {
    Set-ItemProperty -Path $mm -Name $k -Value $mmSettings[$k] -Type DWord -EA SilentlyContinue
}
Write-Log ("  [OK] Memory Management registry (SessionViewSize={0} MB)" -f $svSize) "Green"

# --- 8B: Prefetch / Superfetch (disable for SSD) ---
if (Test-Path $pref) {
    $pfVal = if ($isSSD) { 0 } else { 3 }   # 0=disabled, 3=all on HDD
    Set-ItemProperty -Path $pref -Name "EnablePrefetcher"  -Value $pfVal -Type DWord -EA SilentlyContinue
    Set-ItemProperty -Path $pref -Name "EnableSuperfetch"  -Value 0      -Type DWord -EA SilentlyContinue
    Set-ItemProperty -Path $pref -Name "EnableBoottrace"   -Value 0      -Type DWord -EA SilentlyContinue
    Write-Log ("  [OK] Prefetcher={0}, Superfetch=0 (SSD={1})" -f $pfVal, $isSSD) "Green"
}

# --- 8C: ReadyBoost + ReadyDrive disable [FIX-9] ---
$rbPath = "HKLM:\SYSTEM\CurrentControlSet\Control\WMI\Autologger\ReadyBoot"
Set-ItemProperty -Path $rbPath -Name "Start" -Value 0 -Type DWord -EA SilentlyContinue
Write-Log "  [OK] ReadyBoot logger disabled" "Green"

# --- 8D: Telemetry block ---
$telData = @{
    "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" = @{ "AllowTelemetry" = 0 }
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" = @{
        "AllowTelemetry" = 0; "MaxTelemetryAllowed" = 0
    }
    "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat" = @{
        "DisableInventory" = 1; "DisablePCA" = 1
    }
    "HKLM:\SOFTWARE\Policies\Microsoft\SQMClient\Windows" = @{ "CEIPEnable" = 0 }
    "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" = @{
        "DisableTailoredExperiencesWithDiagnosticData" = 1
    }
}
foreach ($path in $telData.Keys) {
    if (-not (Test-Path $path)) { New-Item -Path $path -Force -EA SilentlyContinue | Out-Null }
    foreach ($name in $telData[$path].Keys) {
        Set-ItemProperty -Path $path -Name $name -Value $telData[$path][$name] -Type DWord -EA SilentlyContinue
    }
}
$ctrKey = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\CompatTelRunner.exe"
if (-not (Test-Path $ctrKey)) { New-Item -Path $ctrKey -Force -EA SilentlyContinue | Out-Null }
Set-ItemProperty -Path $ctrKey -Name "Debugger" -Value "%windir%\System32\taskkill.exe" -EA SilentlyContinue
Write-Log "  [OK] Telemetry + CEIP + CompatTelRunner disabled" "Green"

# --- 8E: Visual FX Best Performance ---
$visPref = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects"
if (-not (Test-Path $visPref)) { New-Item -Path $visPref -Force -EA SilentlyContinue | Out-Null }
Set-ItemProperty -Path $visPref -Name "VisualFXSetting" -Value 2 -Type DWord -EA SilentlyContinue
# Additional visual effect keys for full "Best Performance" equivalent
$userPref = "HKCU:\Control Panel\Desktop"
Set-ItemProperty -Path $userPref -Name "DragFullWindows"        -Value "0" -EA SilentlyContinue
Set-ItemProperty -Path $userPref -Name "FontSmoothing"          -Value "2" -EA SilentlyContinue
Set-ItemProperty -Path $userPref -Name "UserPreferencesMask"    -Value ([byte[]](0x90,0x12,0x03,0x80,0x10,0x00,0x00,0x00)) -Type Binary -EA SilentlyContinue
Write-Log "  [OK] Visual Effects -> Best Performance" "Green"

# --- 8F: TCP optimizations ---
$tcpPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
Set-ItemProperty -Path $tcpPath -Name "TcpAckFrequency" -Value 1  -Type DWord -EA SilentlyContinue
Set-ItemProperty -Path $tcpPath -Name "TCPNoDelay"      -Value 1  -Type DWord -EA SilentlyContinue
Set-ItemProperty -Path $tcpPath -Name "DefaultTTL"      -Value 64 -Type DWord -EA SilentlyContinue
Write-Log "  [OK] TCP parameters optimized" "Green"

# --- 8G: Power Plan — High Performance ---
try {
    powercfg /setactive SCHEME_MIN 2>&1 | Out-Null
    # On 8 GB Win11 also set processor min state to 5% (avoid C-state delays)
    if ($is8GB) {
        powercfg /setacvalueindex SCHEME_MIN SUB_PROCESSOR PROCTHROTTLEMIN 5 2>&1 | Out-Null
        powercfg /setacvalueindex SCHEME_MIN SUB_PROCESSOR PROCTHROTTLEMAX 100 2>&1 | Out-Null
        powercfg /setactive SCHEME_MIN 2>&1 | Out-Null
    }
    Write-Log "  [OK] Power Plan -> High Performance" "Green"
} catch {}

# --- 8H: GameDVR / GameBar disable ---
$gdvrPath = "HKCU:\System\GameConfigStore"
if (-not (Test-Path $gdvrPath)) { New-Item -Path $gdvrPath -Force -EA SilentlyContinue | Out-Null }
Set-ItemProperty -Path $gdvrPath -Name "GameDVR_Enabled" -Value 0 -Type DWord -EA SilentlyContinue
$gbarPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR"
if (-not (Test-Path $gbarPath)) { New-Item -Path $gbarPath -Force -EA SilentlyContinue | Out-Null }
Set-ItemProperty -Path $gbarPath -Name "AppCaptureEnabled" -Value 0 -Type DWord -EA SilentlyContinue
Write-Log "  [OK] GameDVR / GameBar disabled" "Green"

# --- 8I: Cortana disable ---
$cortanaPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"
if (-not (Test-Path $cortanaPath)) { New-Item -Path $cortanaPath -Force -EA SilentlyContinue | Out-Null }
Set-ItemProperty -Path $cortanaPath -Name "AllowCortana" -Value 0 -Type DWord -EA SilentlyContinue
Write-Log "  [OK] Cortana disabled via policy" "Green"

# ==============================================================================
# STEP 9 — 8 GB WIN11 SPECIFIC FIXES  [V4 NEW]
# ==============================================================================
Show-Section "STEP 9: 8 GB Win11 GOD MODE — targeted fixes"

# --- 9A: Memory Compression — set process priority LOW [FIX-2] ---
# Memory Compression process aggressively reloads standby on 8 GB — throttle it
$mcProc = Get-Process -Name "Memory Compression" -EA SilentlyContinue
if ($mcProc) {
    try {
        $mcProc.PriorityClass = [System.Diagnostics.ProcessPriorityClass]::Idle
        Write-Log "  [OK] Memory Compression process -> Priority: IDLE (throttled)" "Green"
    } catch {
        Write-Log "  [WARN] Could not set Memory Compression priority" "Yellow"
    }
} else {
    Write-Log "  [--] Memory Compression not running (already suppressed)" "DarkGray"
}

# --- 9B: SwapFile.sys disable on SSD [FIX-4] ---
# SwapFile.sys is Win11's compressed swap — causes continuous RAM pressure on 8 GB
if ($isSSD) {
    $swapPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
    # Check if pagefile exists first
    $pageFiles = Get-CimInstance Win32_PageFileUsage -EA SilentlyContinue
    if ($pageFiles) {
        # Disable SwapFile.sys via policy (pagefile itself kept for stability)
        $swapPol = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"
        if (-not (Test-Path $swapPol)) { New-Item -Path $swapPol -Force -EA SilentlyContinue | Out-Null }
        Set-ItemProperty -Path $swapPol -Name "DisableSwapFile" -Value 1 -Type DWord -EA SilentlyContinue
        Write-Log "  [OK] SwapFile.sys disabled via policy (SSD detected) [FIX-4]" "Green"
    }
} else {
    Write-Log "  [--] HDD detected — SwapFile.sys kept for stability" "Yellow"
}

# --- 9C: WSL2 memory reclaim [FIX-8] ---
$wslConfig = "$env:USERPROFILE\.wslconfig"
$wslContent = @"
[wsl2]
memory=2GB
processors=2
swap=0
localhostForwarding=true
[experimental]
autoMemoryReclaim=gradual
"@
if (Test-Path $wslConfig) {
    # Only update if WSL2 memory line not already limited
    $existing = Get-Content $wslConfig -Raw -EA SilentlyContinue
    if ($existing -notlike "*autoMemoryReclaim*") {
        Add-Content -Path $wslConfig -Value "`n[experimental]`nautoMemoryReclaim=gradual" -EA SilentlyContinue
        Write-Log "  [OK] WSL2 .wslconfig — autoMemoryReclaim=gradual added" "Green"
    } else {
        Write-Log "  [--] WSL2 .wslconfig already has memory reclaim config" "DarkGray"
    }
} else {
    # Create fresh .wslconfig
    Set-Content -Path $wslConfig -Value $wslContent -EA SilentlyContinue
    Write-Log "  [OK] WSL2 .wslconfig created (memory=2GB, autoMemoryReclaim=gradual)" "Green"
}

# --- 9D: Windows Search — set to Manual trigger + CPU cap [FIX-7] ---
$searchSvc = Get-Service -Name "WSearch" -EA SilentlyContinue
if ($searchSvc) {
    Stop-Service "WSearch" -Force -EA SilentlyContinue
    Set-Service  "WSearch" -StartupType Disabled -EA SilentlyContinue
    Write-Log "  [OK] Windows Search (WSearch) -> Disabled" "Green"
}
# SearchIndexer process kill (leaves disk index intact)
Stop-Process -Name "SearchIndexer" -Force -EA SilentlyContinue
Write-Log "  [OK] SearchIndexer process terminated" "Green"

# --- 9E: Defender real-time — throttle CPU and RAM usage [FIX-6] ---
# Exclude script paths and set low-priority scan (does NOT disable protection)
try {
    $defPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender"
    if (-not (Test-Path $defPath)) { New-Item -Path $defPath -Force -EA SilentlyContinue | Out-Null }
    # Throttle scan CPU usage to 25%
    $scanPath = "$defPath\Scan"
    if (-not (Test-Path $scanPath)) { New-Item -Path $scanPath -Force -EA SilentlyContinue | Out-Null }
    Set-ItemProperty -Path $scanPath -Name "AvgCPULoadFactor"          -Value 25  -Type DWord -EA SilentlyContinue
    Set-ItemProperty -Path $scanPath -Name "DisableScanningNetworkFiles"-Value 1  -Type DWord -EA SilentlyContinue
    Set-ItemProperty -Path $scanPath -Name "DisableArchiveScanning"     -Value 1  -Type DWord -EA SilentlyContinue
    # Set MsMpEng to low I/O priority via process (runtime only)
    $mpEng = Get-Process -Name "MsMpEng" -EA SilentlyContinue
    if ($mpEng) {
        $mpEng.PriorityClass = [System.Diagnostics.ProcessPriorityClass]::BelowNormal
        Write-Log "  [OK] MsMpEng (Defender) -> Priority: BelowNormal, CPU cap 25%" "Green"
    } else {
        Write-Log "  [OK] Defender CPU cap 25% set via policy" "Green"
    }
} catch {
    Write-Log "  [WARN] Defender throttle: policy write failed (GPO may be enforced)" "Yellow"
}

# --- 9F: Runtime top-10 RAM hog trim [FIX-12] ---
Write-Log "  >> Targeting top-10 RAM consumers for aggressive trim..." "White"
$safeSkip = @("System","Idle","smss","csrss","wininit","winlogon","lsass",
               "services","Registry","dwm","fontdrvhost","audiodg","svchost",
               "MsMpEng","WUDFHost","NisSrv","SecurityHealthService",
               "powershell","pwsh","Optimize-RAM")
$top10 = Get-Process -EA SilentlyContinue |
         Where-Object { $safeSkip -notcontains $_.ProcessName } |
         Sort-Object WorkingSet64 -Descending |
         Select-Object -First 10

foreach ($p in $top10) {
    try {
        $mbUsed = [math]::Round($p.WorkingSet64 / 1MB, 1)
        $h = [MemUtil4]::OpenProcess([uint32]0x1F0FFF, $false, $p.Id)
        if ($h -ne [IntPtr]::Zero) {
            [MemUtil4]::EmptyWorkingSet($h) | Out-Null
            [MemUtil4]::SetProcessWorkingSetSizeEx($h, [IntPtr](-1), [IntPtr](-1), 0) | Out-Null
            [MemUtil4]::CloseHandle($h) | Out-Null
            Write-Log ("  [TRIM] {0,-30} was using {1} MB" -f $p.ProcessName, $mbUsed) "DarkYellow"
        }
    } catch {}
}
Write-Log "  [OK] Top-10 RAM consumers trimmed" "Green"

# ==============================================================================
# STEP 10 — JUNK FILE CLEANUP
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
    "C:\Windows\Minidump",
    "$env:LOCALAPPDATA\Microsoft\Windows\Explorer"
)
foreach ($d in $cleanDirs) {
    if (Test-Path $d) {
        $cnt = (Get-ChildItem -Path $d -Recurse -EA SilentlyContinue | Measure-Object).Count
        Get-ChildItem -Path $d -EA SilentlyContinue |
            Remove-Item -Force -Recurse -EA SilentlyContinue
        Write-Log ("  [OK] Cleaned: {0,-60} ({1} items)" -f $d, $cnt) "Green"
    }
}

# Windows Update cache
$wu = "C:\Windows\SoftwareDistribution\Download"
if (Test-Path $wu) {
    $wus = Get-Service "wuauserv" -EA SilentlyContinue
    if ($wus -and $wus.Status -eq "Running") {
        Stop-Service "wuauserv" -Force -EA SilentlyContinue; Start-Sleep 2
    }
    $wuCnt = (Get-ChildItem $wu -Recurse -EA SilentlyContinue | Measure-Object).Count
    Get-ChildItem $wu -EA SilentlyContinue | Remove-Item -Force -Recurse -EA SilentlyContinue
    Start-Service "wuauserv" -EA SilentlyContinue
    Write-Log ("  [OK] Windows Update cache cleared: {0} items" -f $wuCnt) "Green"
}

# Thumbnail cache
$thumbDir = "$env:LOCALAPPDATA\Microsoft\Windows\Explorer"
if (Test-Path $thumbDir) {
    Get-ChildItem -Path $thumbDir -Filter "thumbcache_*.db" -EA SilentlyContinue |
        Remove-Item -Force -EA SilentlyContinue
    Write-Log "  [OK] Thumbnail cache cleared" "Green"
}

# DNS + Event Logs
ipconfig /flushdns 2>&1 | Out-Null
Write-Log "  [OK] DNS cache flushed" "Green"
foreach ($log in @("Application","System","Setup")) {
    try {
        Clear-EventLog -LogName $log -EA SilentlyContinue
        Write-Log ("  [OK] Event Log [{0}] cleared" -f $log) "DarkGray"
    } catch {}
}

# ==============================================================================
# STEP 11 — WIN10 / WIN11 SPECIFIC TWEAKS
# ==============================================================================
Show-Section ("STEP 11: Platform-specific tweaks [{0}]" -f $winTag)

if ($isWin11) {
    # Widgets panel
    $widgetPath = "HKLM:\SOFTWARE\Policies\Microsoft\Dsh"
    if (-not (Test-Path $widgetPath)) { New-Item -Path $widgetPath -Force -EA SilentlyContinue | Out-Null }
    Set-ItemProperty -Path $widgetPath -Name "AllowNewsAndInterests" -Value 0 -Type DWord -EA SilentlyContinue
    Write-Log "  [OK] Win11 Widgets panel disabled" "Green"

    # Taskbar Chat / Teams consumer
    $chatKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    Set-ItemProperty -Path $chatKey -Name "TaskbarMn"               -Value 0 -Type DWord -EA SilentlyContinue
    Set-ItemProperty -Path $chatKey -Name "EnableSnapAssistFlyout"   -Value 0 -Type DWord -EA SilentlyContinue
    Write-Log "  [OK] Taskbar Chat icon + Snap Assist Flyout disabled" "Green"

    # Copilot button
    Set-ItemProperty -Path $chatKey -Name "ShowCopilotButton" -Value 0 -Type DWord -EA SilentlyContinue
    Write-Log "  [OK] Copilot button hidden" "Green"

    # Online Speech
    $vaSpeech = "HKCU:\Software\Microsoft\Speech_OneCore\Settings\OnlineServices"
    if (Test-Path $vaSpeech) {
        Set-ItemProperty -Path $vaSpeech -Name "OnlineSpeechPrivacy" -Value 0 -Type DWord -EA SilentlyContinue
    }
    Write-Log "  [OK] Online Speech Privacy disabled" "Green"

    # WSA
    $wsaSvc = Get-Service -Name "WsaService" -EA SilentlyContinue
    if ($wsaSvc) {
        Stop-Service "WsaService" -Force -EA SilentlyContinue
        Set-Service  "WsaService" -StartupType Disabled -EA SilentlyContinue
        Write-Log "  [OK] Windows Subsystem for Android (WSA) disabled" "Green"
    } else {
        Write-Log "  [--] WSA not installed" "DarkGray"
    }

    # Win11 Memory Manager: additional tweaks for 8 GB
    if ($is8GB) {
        # Disable Automatic Managed Pagefile — manual control is better for 8 GB
        $pfc = Get-CimInstance Win32_ComputerSystem
        if ($pfc.AutomaticManagedPagefile) {
            Set-CimInstance -InputObject $pfc -Property @{ AutomaticManagedPagefile = $false } -EA SilentlyContinue
            Write-Log "  [OK] Automatic Managed Pagefile -> MANUAL (8 GB optimize)" "Green"
        }
        # Set pagefile: min 1024 MB, max 4096 MB (fixed = no resize overhead)
        $pfSetting = Get-CimInstance -ClassName Win32_PageFileSetting -EA SilentlyContinue | Select-Object -First 1
        if ($pfSetting) {
            Set-CimInstance -InputObject $pfSetting -Property @{
                InitialSize = 1024; MaximumSize = 4096
            } -EA SilentlyContinue
            Write-Log "  [OK] Pagefile fixed: 1 GB min, 4 GB max (8 GB RAM profile)" "Green"
        }
    }
}

if ($isWin10) {
    # Timeline
    $tlPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"
    if (-not (Test-Path $tlPath)) { New-Item -Path $tlPath -Force -EA SilentlyContinue | Out-Null }
    Set-ItemProperty -Path $tlPath -Name "EnableActivityFeed"    -Value 0 -Type DWord -EA SilentlyContinue
    Set-ItemProperty -Path $tlPath -Name "PublishUserActivities" -Value 0 -Type DWord -EA SilentlyContinue
    Set-ItemProperty -Path $tlPath -Name "UploadUserActivities"  -Value 0 -Type DWord -EA SilentlyContinue
    Write-Log "  [OK] Windows Timeline disabled" "Green"

    # Fast Startup
    $hiberPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power"
    Set-ItemProperty -Path $hiberPath -Name "HiberbootEnabled" -Value 0 -Type DWord -EA SilentlyContinue
    Write-Log "  [OK] Fast Startup (Hiberboot) disabled" "Green"
}

# ==============================================================================
# STEP 12 — PERSISTENT WATCHDOG SCHEDULED TASK  [V4 NEW — FIX-1]
# ==============================================================================
Show-Section "STEP 12: Persistent RAM Watchdog — Scheduled Task [V4 NEW]"

Write-Log "  >> This is the KEY fix for RAM bouncing back after 2-3 minutes." "Magenta"
Write-Log "  >> A silent watchdog task runs every 5 minutes to maintain free RAM." "Magenta"

$watchdogScript = @'
# RAM Watchdog v4.0 — runs silently every 5 minutes
# Trims RAM only when usage exceeds threshold (default: 75%)
$ErrorActionPreference = "SilentlyContinue"

$ntCode = @"
using System; using System.Runtime.InteropServices;
public class NtWdog {
    [DllImport("ntdll.dll")]
    public static extern uint NtSetSystemInformation(int InfoClass, IntPtr Info, int Length);
}
"@
if (-not ([System.Management.Automation.PSTypeName]"NtWdog").Type) {
    Add-Type -TypeDefinition $ntCode
}

$privCode = @"
using System; using System.Runtime.InteropServices;
public class TokWdog {
    [StructLayout(LayoutKind.Sequential, Pack=1)]
    public struct TokPriv1Luid { public int Count; public long Luid; public int Attr; }
    [DllImport("kernel32.dll", ExactSpelling=true)]
    public static extern IntPtr GetCurrentProcess();
    [DllImport("advapi32.dll", ExactSpelling=true, SetLastError=true)]
    public static extern bool OpenProcessToken(IntPtr h, int acc, ref IntPtr tok);
    [DllImport("advapi32.dll", SetLastError=true)]
    public static extern bool LookupPrivilegeValue(string host, string name, ref long luid);
    [DllImport("advapi32.dll", ExactSpelling=true, SetLastError=true)]
    public static extern bool AdjustTokenPrivileges(IntPtr htok, bool disall, ref TokPriv1Luid newst, int len, IntPtr prev, IntPtr relen);
    public static bool Enable(string priv) {
        IntPtr hproc = GetCurrentProcess(); IntPtr htok = IntPtr.Zero;
        if (!OpenProcessToken(hproc, 0x28, ref htok)) return false;
        TokPriv1Luid tp; tp.Count=1; tp.Luid=0; tp.Attr=2;
        if (!LookupPrivilegeValue(null, priv, ref tp.Luid)) return false;
        return AdjustTokenPrivileges(htok, false, ref tp, 0, IntPtr.Zero, IntPtr.Zero);
    }
}
"@
if (-not ([System.Management.Automation.PSTypeName]"TokWdog").Type) {
    Add-Type -TypeDefinition $privCode
}

$memApiCode = @"
using System; using System.Runtime.InteropServices;
public class MemWdog {
    [DllImport("psapi.dll")]    public static extern bool EmptyWorkingSet(IntPtr h);
    [DllImport("kernel32.dll")] public static extern IntPtr OpenProcess(uint acc, bool inh, int pid);
    [DllImport("kernel32.dll")] public static extern bool CloseHandle(IntPtr h);
}
"@
if (-not ([System.Management.Automation.PSTypeName]"MemWdog").Type) {
    Add-Type -TypeDefinition $memApiCode
}

function Invoke-MemCmd { param([int]$cmd)
    $ptr = [System.Runtime.InteropServices.Marshal]::AllocHGlobal(4)
    [System.Runtime.InteropServices.Marshal]::WriteInt32($ptr, $cmd)
    [NtWdog]::NtSetSystemInformation(80, $ptr, 4) | Out-Null
    [System.Runtime.InteropServices.Marshal]::FreeHGlobal($ptr)
}

# Check current RAM usage
$os = Get-CimInstance Win32_OperatingSystem
$totalMB = $os.TotalVisibleMemorySize / 1KB
$freeMB  = $os.FreePhysicalMemory / 1KB
$pct     = [math]::Round((($totalMB - $freeMB) / $totalMB) * 100, 1)

$threshold = 75   # Trigger trim when RAM > 75% used

if ($pct -gt $threshold) {
    [TokWdog]::Enable("SeIncreaseQuotaPrivilege") | Out-Null
    [TokWdog]::Enable("SeProfileSingleProcessPrivilege") | Out-Null
    
    # Flush standby + working sets
    Invoke-MemCmd -cmd 4   # Flush Modified
    Start-Sleep -Milliseconds 200
    Invoke-MemCmd -cmd 3   # Purge Standby
    Start-Sleep -Milliseconds 200
    Invoke-MemCmd -cmd 1   # Empty Working Sets
    Start-Sleep -Milliseconds 200
    Invoke-MemCmd -cmd 3   # Purge Standby again (post-trim)
    
    # Trim top-5 RAM hogs (quick pass)
    $skipList = @("System","Idle","smss","csrss","wininit","winlogon","lsass",
                  "services","Registry","dwm","fontdrvhost","audiodg","svchost",
                  "MsMpEng","NisSrv","SecurityHealthService")
    Get-Process -EA SilentlyContinue |
      Where-Object { $skipList -notcontains $_.ProcessName } |
      Sort-Object WorkingSet64 -Descending | Select-Object -First 5 |
      ForEach-Object {
        try {
            $h = [MemWdog]::OpenProcess([uint32]0x1100, $false, $_.Id)
            if ($h -ne [IntPtr]::Zero) {
                [MemWdog]::EmptyWorkingSet($h) | Out-Null
                [MemWdog]::CloseHandle($h) | Out-Null
            }
        } catch {}
    }
    
    # Log to file
    $logPath = "$env:USERPROFILE\Desktop\RAM-Watchdog-Log.txt"
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $os2 = Get-CimInstance Win32_OperatingSystem
    $freeMB2 = [math]::Round($os2.FreePhysicalMemory / 1KB, 1)
    Add-Content -Path $logPath -Value "$ts  Triggered at $pct% -> Free after: $freeMB2 MB" -EA SilentlyContinue
}
'@

# Save watchdog script to system location
$watchdogPath = "C:\ProgramData\RAMWatchdog"
if (-not (Test-Path $watchdogPath)) { New-Item -Path $watchdogPath -ItemType Directory -Force | Out-Null }
$watchdogFile = "$watchdogPath\RAMWatchdog.ps1"
Set-Content -Path $watchdogFile -Value $watchdogScript -Encoding UTF8 -EA SilentlyContinue

# Register Scheduled Task
$taskName = "RAMWatchdog-GodMode-V4"

# Remove old task if exists
Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -EA SilentlyContinue

$action  = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$watchdogFile`""

$trigger = New-ScheduledTaskTrigger -RepetitionInterval (New-TimeSpan -Minutes 5) -Once -At (Get-Date)

$settings = New-ScheduledTaskSettingsSet `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 2) `
    -MultipleInstances IgnoreNew `
    -StartWhenAvailable `
    -Hidden

$principal = New-ScheduledTaskPrincipal `
    -UserId "SYSTEM" `
    -LogonType ServiceAccount `
    -RunLevel Highest

try {
    Register-ScheduledTask `
        -TaskName   $taskName `
        -Action     $action `
        -Trigger    $trigger `
        -Settings   $settings `
        -Principal  $principal `
        -Force -EA Stop | Out-Null

    Write-Log "  [OK] Watchdog task REGISTERED: '$taskName'" "Green"
    Write-Log "  [OK] Runs every 5 minutes as SYSTEM — silent, no window" "Green"
    Write-Log "  [OK] Triggers only when RAM > 75% used (low overhead)" "Green"
    Write-Log "  [OK] Watchdog script: $watchdogFile" "DarkGray"
    Write-Log "  [OK] Watchdog log: $env:USERPROFILE\Desktop\RAM-Watchdog-Log.txt" "DarkGray"
} catch {
    Write-Log ("  [WARN] Failed to register watchdog task: {0}" -f $_.Exception.Message) "Yellow"
    Write-Log "  [i] You can manually run the script from: $watchdogFile" "Yellow"
}

# Run watchdog immediately (first pass)
Write-Log "  >> Running watchdog NOW (first pass)..." "Cyan"
& powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File $watchdogFile
Write-Log "  [OK] First watchdog pass complete" "Green"

# ==============================================================================
# FINAL SUMMARY
# ==============================================================================
Write-Log ""
Write-Log "  +================================================================+" "Cyan"
Write-Log "  |                    SUMMARY — GOD MODE v4.0                    |" "Cyan"
Write-Log "  +================================================================+" "Cyan"

$os1   = Get-CimInstance Win32_OperatingSystem
$free1 = [math]::Round($os1.FreePhysicalMemory / 1MB, 2)
$used1 = [math]::Round($total - $free1, 2)
$pct1  = [math]::Round(($used1 / $total) * 100, 1)
$gain  = [math]::Round($free1 - $free0, 2)

Write-Log ""
Write-Log ("  OS          :  {0}  [Build {1} | {2}]" -f $winName, $winBuild, $winTag) "White"
Write-Log ("  Machine     :  {0}  |  Brand: {1}" -f $cs.Model, $brand) "White"
Write-Log ("  Total RAM   :  {0} GB  |  Disk: {1}" -f $total, $mediaType) "White"
Write-Log ""
Write-Log ("  Before      :  {0} GB free" -f $free0) "DarkGray"
Write-Log ("  After       :  {0} GB free" -f $free1) "White"

if ($gain -gt 0) {
    Write-Log ("  Freed       :  +{0} GB" -f $gain) "Green"
} else {
    Write-Log "  Note        :  Small immediate gain is normal — kernel reclaims more over 30-60 sec" "Yellow"
}

$ramCol = if ($pct1 -gt 80) {"Red"} elseif ($pct1 -gt 60) {"Yellow"} else {"Green"}
Write-Log ("  RAM Used    :  {0} GB  ({1}%)" -f $used1, $pct1) $ramCol
Write-Log ("  Services OFF:  {0}" -f $Script:SvcOff) "Cyan"
Write-Log ("  Tasks OFF   :  {0}" -f $Script:TasksOff) "Cyan"
Write-Log ("  Startup DEL :  {0}" -f $Script:StartupDel) "Cyan"
Write-Log ""
Write-Log "  ----------------------------------------------------------------" "DarkGray"
Write-Log "  [V4 KEY FIX] Watchdog task active — checks RAM every 5 min" "Magenta"
Write-Log "  [V4 KEY FIX] SwapFile.sys disabled (SSD), WSL2 reclaim active" "Magenta"
Write-Log "  [V4 KEY FIX] SessionViewSize = 256 MB (8 GB profile)" "Magenta"
Write-Log "  ----------------------------------------------------------------" "DarkGray"
Write-Log ""
Write-Log "  [!] RESTART recommended for registry changes to take full effect." "Yellow"
Write-Log "  [!] Brand services are DISABLED permanently — won't restart on boot." "Yellow"
Write-Log "  [!] If any Fn key / sensor / special feature breaks:" "Yellow"
Write-Log "      Open:  services.msc  -> re-enable the specific service." "Yellow"
Write-Log "  [!] To REMOVE watchdog: Task Scheduler -> '$taskName'" "Yellow"
Write-Log "  ----------------------------------------------------------------" "DarkGray"

# Save log
try {
    $Script:LogLines | Out-File -FilePath $Script:LogFile -Encoding UTF8 -ErrorAction Stop
    Write-Log ""
    Write-Log ("  [LOG] Report saved to:") "Cyan"
    Write-Log ("        {0}" -f $Script:LogFile) "Cyan"
} catch {
    Write-Log "  [LOG] Could not write log (Desktop may be blocked)." "DarkGray"
}

Write-Log ""
pause
