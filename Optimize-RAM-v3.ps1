# ==========================================================================
#  Optimize-RAM-v3-EN.ps1  |  GOD MODE
#  Supports: Windows 10 (1809+) & Windows 11
#  Version: 3.0 (English)
#  --------------------------------------------------------------------------
#  FEATURES:
#   [0]  Detect Win10 / Win11, build number, activate version-specific tweaks
#   [1]  Flush Standby List, Modified List, Working Sets (kernel-level)
#   [2]  Flush File System Cache
#   [3]  Trim Working Set of all running processes
#   [4]  Auto-detect PC brand (Dell/HP/Lenovo/ASUS/MSI/Acer/Samsung/...)
#   [5]  Disable unnecessary Windows services (common + per-version)
#   [6]  Disable vendor services (per-brand service list)
#   [7]  Keyword scan to catch remaining vendor services
#   [8]  Disable vendor Startup Registry entries + Scheduled Tasks
#   [9]  Registry tweaks: Memory Mgmt, Telemetry, Visual FX, TCP, GameDVR
#   [10] Deep junk cleanup: Temp, Prefetch, WU cache, INet, Thumbnail, EventLog
#   [11] Version-specific tweaks: Win11 (Widgets, WSA, Chat) / Win10 (Timeline)
#   [12] Export detailed LOG report to Desktop
#  --------------------------------------------------------------------------
#  Requirements: PowerShell 5.1+  |  Administrator rights
# ==========================================================================

#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = "SilentlyContinue"

# ---- Admin guard ----
$_ap = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $_ap.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "[!] Administrator rights required!" -ForegroundColor Red
    Write-Host "    Right-click the .bat file and select: Run as administrator" -ForegroundColor Yellow
    Start-Sleep 3; exit 1
}

# ==========================================================================
# GLOBAL VARIABLES
# ==========================================================================
$Script:LogLines     = [System.Collections.Generic.List[string]]::new()
$Script:LogFile      = "$env:USERPROFILE\Desktop\RAM-Optimize-Log-$(Get-Date -f 'yyyyMMdd-HHmmss').txt"
$Script:taskDisabled = 0

function Write-Log {
    param([string]$msg, [string]$color = "White")
    Write-Host $msg -ForegroundColor $color
    $Script:LogLines.Add($msg)
}

function Show-Section {
    param([string]$title)
    $line = "  " + ([string][char]0x2500 * 56)
    Write-Log ""
    Write-Log $line "DarkCyan"
    Write-Log ("  >> " + $title) "Cyan"
    Write-Log $line "DarkCyan"
}

# ==========================================================================
# SECTION 0 -- SYSTEM DETECTION
# ==========================================================================
Clear-Host
Write-Log ""
Write-Log "  +========================================================+" "Cyan"
Write-Log "  |    RAM OPTIMIZER  --  GOD MODE  v3.0 (EN)             |" "Cyan"
Write-Log "  |    Supports: Windows 10 (1809+) & Windows 11          |" "Cyan"
Write-Log "  |    Brand detection + Service killer + Deep cleanup     |" "Cyan"
Write-Log "  +========================================================+" "Cyan"
Write-Log ""

$cs   = Get-CimInstance Win32_ComputerSystem
$bios = Get-CimInstance Win32_BIOS
$os0  = Get-CimInstance Win32_OperatingSystem
$cpu  = Get-CimInstance Win32_Processor | Select-Object -First 1

$winBuild = [int]($os0.BuildNumber)
$winName  = $os0.Caption

$isWin11 = ($winBuild -ge 22000)
$isWin10 = (-not $isWin11) -and ($winBuild -ge 17763)
$winTag  = if ($isWin11) { "WIN11" } elseif ($isWin10) { "WIN10" } else { "WIN_OLD" }

$free0 = [math]::Round($os0.FreePhysicalMemory    / 1MB, 2)
$total = [math]::Round($os0.TotalVisibleMemorySize / 1MB, 2)
$ramGB = [math]::Round($cs.TotalPhysicalMemory     / 1GB, 1)

Write-Log ("  OS      :  {0}" -f $winName) "White"
Write-Log ("  Build   :  {0}  [{1}]" -f $winBuild, $winTag) "White"
Write-Log ("  Machine :  {0}  |  {1}" -f $cs.Manufacturer, $cs.Model) "White"
Write-Log ("  BIOS    :  {0}  {1}" -f $bios.Manufacturer, ($bios.SMBIOSBIOSVersion -join " ")) "White"
Write-Log ("  CPU     :  {0}" -f $cpu.Name) "White"
Write-Log ("  RAM     :  {0} GB (Physical)  |  Currently free: {1} GB" -f $ramGB, $free0) "White"
Write-Log ""

if ($winTag -eq "WIN_OLD") {
    Write-Log "  [!] Windows build too old (<1809). Some features may not work correctly." "Yellow"
}

# --- Brand detection ---
$mfrRaw  = ($cs.Manufacturer + " " + $cs.Model).ToLower()
$biosRaw = ($bios.Manufacturer + " " + ($bios.SMBIOSBIOSVersion -join " ")).ToLower()

$brand    = "UNKNOWN"
$brandSrc = "manufacturer"

$brandMap = [ordered]@{
    "dell"      = "DELL"
    "hp "       = "HP"
    "hewlett"   = "HP"
    "lenovo"    = "LENOVO"
    "asus"      = "ASUS"
    "acer "     = "ACER"
    "msi"       = "MSI"
    "samsung"   = "SAMSUNG"
    "microsoft" = "MICROSOFT_SURFACE"
    "toshiba"   = "TOSHIBA"
    "huawei"    = "HUAWEI"
    "razer"     = "RAZER"
    "gigabyte"  = "GIGABYTE"
    "intel"     = "INTEL_NUC"
    "panasonic" = "PANASONIC"
    "fujitsu"   = "FUJITSU"
    "vaio"      = "VAIO"
    "lg "       = "LG"
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
    "DELL"               { "Blue"     }
    "HP"                 { "DarkCyan" }
    "LENOVO"             { "Red"      }
    "ASUS"               { "Cyan"     }
    "MSI"                { "Red"      }
    "ACER"               { "Green"    }
    "SAMSUNG"            { "Cyan"     }
    "RAZER"              { "Green"    }
    "MICROSOFT_SURFACE"  { "Blue"     }
    "GIGABYTE"           { "Yellow"   }
    default              { "Yellow"   }
}

Write-Log ("  [*] Detected brand: [ {0} ]  (source: {1})" -f $brand, $brandSrc) $brandColor
Write-Log ""

# ==========================================================================
# SERVICE LISTS
# ==========================================================================

# ---------- Common (Win10 + Win11) ----------
$svcsCommon = [ordered]@{
    "DiagTrack"              = "Connected User Experiences & Telemetry (Microsoft)"
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
    "OneSyncSvc"             = "Sync Host (mail/calendar sync)"
    "WSearch"                = "Windows Search Indexing"
    "SysMain"                = "SysMain / Superfetch"
    "RemoteRegistry"         = "Remote Registry"
    "RemoteAccess"           = "Routing and Remote Access"
    "SharedAccess"           = "Internet Connection Sharing"
    "TermService"            = "Remote Desktop Services (disable if not using RDP)"
    "SessionEnv"             = "Remote Desktop Configuration"
    "UmRdpService"           = "Remote Desktop Device Redirector"
    "ScDeviceEnum"           = "Smart Card Device Enumeration"
    "SCardSvr"               = "Smart Card"
    "SCPolicySvc"            = "Smart Card Removal Policy"
    "MixedRealityOpenXRSvc"  = "Mixed Reality OpenXR"
    "WbioSrvc"               = "Windows Biometric Service"
    "PhoneSvc"               = "Phone Service"
    "PimIndexMaintenanceSvc" = "Contact Data"
    "UnistoreSvc"            = "User Data Storage"
    "UserDataSvc"            = "User Data Access"
    "PrintNotify"            = "Printer Extensions & Notifications"
    "Spooler"                = "Print Spooler (disable if not printing)"
    "BthAvctpSvc"            = "Bluetooth Audio Gateway"
    "BTAGService"            = "Bluetooth Audio Gateway AVRCP"
}

# ---------- Windows 10 only ----------
$svcsWin10Only = [ordered]@{
    "AJRouter"               = "AllJoyn Router (IoT protocol)"
    "CscService"             = "Offline Files"
    "DusmSvc"                = "Data Usage"
    "wlidsvc"                = "Microsoft Account Sign-in Assistant"
    "SEMgrSvc"               = "Payments and NFC/SE Manager"
    "NcbService"             = "Network Connection Broker"
    "CDPSvc"                 = "Connected Devices Platform (Win10)"
}

# ---------- Windows 11 only ----------
$svcsWin11Only = [ordered]@{
    "cbdhsvc"                = "Clipboard User Service"
    "WpnService"             = "Windows Push Notifications System"
    "WpnUserService"         = "Windows Push Notifications User"
    "DsSvc"                  = "Data Sharing Service"
    "DevicesFlowUserSvc"     = "Devices Flow"
    "NPSMSvc"                = "Now Playing Session Manager"
    "BcastDVRUserService"    = "GameDVR & Broadcast User Service"
    "Clipboardsvc"           = "Clipboard User Service (alt)"
    "PerceptionSimulation"   = "Windows Perception Simulation"
    "MsKeyboardFilter"       = "Microsoft Keyboard Filter"
}

# ---------- DELL ----------
$svcsDELL = [ordered]@{
    "DellClientManagementService"            = "Dell Client Management Service"
    "DellUpdate"                             = "Dell Update"
    "DellSupportAssistRemedationService"     = "Dell SupportAssist Remediation"
    "DellFoundationServices"                 = "Dell Foundation Services"
    "DellTechHubService"                     = "Dell TechHub Service"
    "DellOptimizer"                          = "Dell Optimizer"
    "DellMobileConnect"                      = "Dell Mobile Connect"
    "DellDataVault"                          = "Dell Data Vault (telemetry)"
    "DellDataVaultWizard"                    = "Dell Data Vault Wizard"
    "ThermalService"                         = "Dell Thermal Service"
    "DellDigitalDelivery"                    = "Dell Digital Delivery"
    "DellServiceConnectivity"                = "Dell Service Connectivity"
    "DellInc.SupportAssistBusinessPCAgent"   = "Dell SupportAssist Business PC Agent"
}

# ---------- HP ----------
$svcsHP = [ordered]@{
    "HPAppHelperCap"               = "HP App Helper Capture"
    "HPDiagsMsgSvc"                = "HP Diagnostics Messages"
    "HPNetworkCap"                 = "HP Network Capture (telemetry)"
    "HPSysInfoCap"                 = "HP SysInfo Capture (telemetry)"
    "hpsvc"                        = "HP Service"
    "HpTouchpointAnalyticsService" = "HP Touchpoint Analytics (telemetry)"
    "HP Comm Recover"              = "HP Comm Recover"
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

# ---------- LENOVO ----------
$svcsLENOVO = [ordered]@{
    "ImControllerService"        = "Lenovo IdeaPad Controller"
    "LenovoFnAndFunctionKeys"    = "Lenovo Fn Function Keys"
    "Lenovo.Modern.ImController" = "Lenovo Modern ImController"
    "LenovoVantageService"       = "Lenovo Vantage Service"
    "LenovoSystemUpdateAddin"    = "Lenovo System Update Add-in"
    "SUService"                  = "Lenovo System Update"
    "ThinkPad HDD APS"           = "ThinkPad HDD Active Protection System"
    "LENOVO.CAMMUTE"             = "Lenovo Camera Mute"
    "LENOVO.MICMUTE"             = "Lenovo Microphone Mute"
    "PMSvc"                      = "Lenovo Power Manager"
    "bcom"                       = "Lenovo BCOM Module"
    "LenovoSmartStandbyService"  = "Lenovo Smart Standby"
    "LenovoUtilityService"       = "Lenovo Utility Service"
    "LenovoMigrationService"     = "Lenovo Migration Service"
    "LenovoWiFiHotspotSvc"       = "Lenovo WiFi Hotspot"
}

# ---------- ASUS ----------
$svcsASUS = [ordered]@{
    "asHmComSvc"                 = "ASUS HM Com Service"
    "AsSysCtrlService"           = "ASUS System Control Service"
    "AsusCertService"            = "ASUS Certificate Service"
    "ASUSUpdate"                 = "ASUS Update"
    "AsusUpdateCheck"            = "ASUS Update Check"
    "ASUSLinkNear"               = "ASUS Link Near (Armoury Crate)"
    "ASUSLinkRemote"             = "ASUS Link Remote (Armoury Crate)"
    "ASUSOptimization"           = "ASUS Optimization Service"
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

# ---------- MSI ----------
$svcsMSI = [ordered]@{
    "MSI_SuperCharger"       = "MSI SuperCharger"
    "MSIAfterburnerCore"     = "MSI Afterburner (disable if not overclocking GPU)"
    "SCM"                    = "MSI System Control Manager"
    "msidrvsvc"              = "MSI Driver Service"
    "MSICenterService"       = "MSI Center Service"
    "MSIKeyboard"            = "MSI Keyboard Service"
    "MSIGamingCenterService" = "MSI Gaming Center"
    "DragonCenterService"    = "MSI Dragon Center"
    "NahimicService"         = "Nahimic Audio Service (MSI)"
    "MSIRGBService"          = "MSI RGB Service"
}

# ---------- ACER ----------
$svcsACER = [ordered]@{
    "AcerService"             = "Acer Service"
    "AcerCloudService"        = "Acer Cloud Service"
    "AcerPortalService"       = "Acer Portal Service"
    "eDataSecurityManagement" = "Acer eDataSecurity Management"
    "AcerLaunchManager"       = "Acer Launch Manager"
    "AcerOptimizer"           = "Acer Optimizer"
    "PredatorSenseService"    = "Acer PredatorSense"
    "NitroSenseService"       = "Acer NitroSense"
    "QuickAccessService"      = "Acer Quick Access"
    "AcerUpdateService"       = "Acer Update Service"
    "AcerCare"                = "Acer Care Center"
    "ConceptDSenseService"    = "Acer ConceptD Sense"
}

# ---------- SAMSUNG ----------
$svcsSAMSUNG = [ordered]@{
    "SamsungMagicianService"  = "Samsung Magician"
    "SamsungDeXSvc"           = "Samsung DeX Service"
    "SamsungUpdateService"    = "Samsung Update Service"
    "SamsungSystemManager"    = "Samsung System Manager"
    "SamsungPC_Share_Manager" = "Samsung PC Share Manager"
    "SAService"               = "Samsung Activation Service"
    "SamsungSSDManager"       = "Samsung SSD Manager"
}

# ---------- SURFACE ----------
$svcsSURFACE = [ordered]@{
    "SurfaceService"                     = "Microsoft Surface Service"
    "SurfaceTelemetryService"            = "Surface Telemetry Service"
    "SurfaceDiagnostics"                 = "Surface Diagnostics"
    "SurfaceButton"                      = "Surface Button Service"
    "SurfacePen"                         = "Surface Pen Service"
    "SurfaceFirmwareProvisioningService" = "Surface Firmware Provisioning"
}

# ---------- RAZER ----------
$svcsRAZER = [ordered]@{
    "Razer Chroma SDK Server"  = "Razer Chroma SDK Server"
    "Razer Chroma SDK Service" = "Razer Chroma SDK Service"
    "RazerCentralService"      = "Razer Central Service"
    "RazerIngameEngine"        = "Razer InGame Engine"
    "Razer Synapse Service"    = "Razer Synapse Service"
    "RzActionSvc"              = "Razer Action Service"
    "RazerNamingService"       = "Razer Naming Service"
}

# ---------- GIGABYTE ----------
$svcsGIGABYTE = [ordered]@{
    "GiGEAudServ"           = "Gigabyte Audio Service"
    "GbActuatorService"     = "Gigabyte Actuator Service"
    "AppCenter"             = "Gigabyte App Center"
    "EasyTuneEngineService" = "Gigabyte Easy Tune"
    "RGBFusionSvc"          = "Gigabyte RGB Fusion"
    "AGSService"            = "Gigabyte AGS Service"
    "GbFirmwareUpdateSvc"   = "Gigabyte Firmware Update"
}

# ---------- TOSHIBA ----------
$svcsTOSHIBA = [ordered]@{
    "TODDSrv"                     = "Toshiba ODD Device Service"
    "TMachInfo"                   = "Toshiba Machine Information"
    "TOSHIBA eco Utility Service" = "Toshiba Eco Utility"
    "TVALZ"                       = "Toshiba ACPI Driver"
    "TPCH"                        = "Toshiba PCH Service"
    "Toshiba TEMPRO"              = "Toshiba TEMPRO"
}

# ---------- HUAWEI ----------
$svcsHUAWEI = [ordered]@{
    "HuaweiPCManagerSvc"      = "Huawei PCManager Service"
    "HuaweiService"           = "Huawei Service"
    "HiService"               = "Huawei HiSuite Service"
    "HuaweiEasyProjectionSvc" = "Huawei EasyProjection"
}

# ---------- LG ----------
$svcsLG = [ordered]@{
    "LGUpdateService" = "LG Update Service"
    "LGPCSuite"       = "LG PC Suite"
    "LGHubService"    = "LG Hub Service"
}

# ---------- PANASONIC ----------
$svcsPANA = [ordered]@{
    "PanaService" = "Panasonic Service"
    "PCInfo"      = "Panasonic PC Info"
}

# ---------- FUJITSU ----------
$svcsFUJITSU = [ordered]@{
    "FjSessServiceAgent" = "Fujitsu Session Service Agent"
    "FjDspService"       = "Fujitsu DSP Service"
    "FUJBtnSvc"          = "Fujitsu Button Service"
}

# ---------- VAIO ----------
$svcsVAIO = [ordered]@{
    "VAIOCareService"     = "VAIO Care Service"
    "VAIOAudioControl"    = "VAIO Audio Control"
    "VAIOEventService"    = "VAIO Event Service"
    "VaioSettingsService" = "VAIO Settings Service"
}

# ==========================================================================
# UTILITY FUNCTION -- Stop & Disable
# ==========================================================================
function Stop-And-Disable {
    param(
        [System.Collections.Specialized.OrderedDictionary]$ServiceMap,
        [string]$Category
    )
    $count = 0
    foreach ($s in $ServiceMap.Keys) {
        $svc = Get-Service -Name $s -ErrorAction SilentlyContinue
        if ($null -eq $svc) {
            $svc = Get-Service -ErrorAction SilentlyContinue |
                   Where-Object { $_.DisplayName -like "*$s*" } |
                   Select-Object -First 1
        }
        if ($null -eq $svc) { continue }
        $desc = $ServiceMap[$s]
        try {
            if ($svc.Status -eq "Running") {
                Stop-Service -InputObject $svc -Force -ErrorAction SilentlyContinue
                Write-Log ("  [STOP] {0,-40} {1}" -f $svc.Name, $desc) "DarkYellow"
            }
            Set-Service -InputObject $svc -StartupType Disabled -ErrorAction SilentlyContinue
            Write-Log ("  [OFF ] {0,-40} {1}" -f $svc.Name, $desc) "DarkGray"
            $count++
        } catch {}
    }
    return $count
}

# ==========================================================================
# COMPILE C# BLOCKS
# ==========================================================================
$ntdllCode = @"
using System;
using System.Runtime.InteropServices;
public class NtMem3 {
    [DllImport("ntdll.dll")]
    public static extern uint NtSetSystemInformation(int InfoClass, IntPtr Info, int Length);
}
"@
if (-not ([System.Management.Automation.PSTypeName]"NtMem3").Type) {
    Add-Type -TypeDefinition $ntdllCode -ErrorAction SilentlyContinue
}

$privCode = @"
using System;
using System.Runtime.InteropServices;
public class TokenPriv3 {
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
if (-not ([System.Management.Automation.PSTypeName]"TokenPriv3").Type) {
    Add-Type -TypeDefinition $privCode -ErrorAction SilentlyContinue
}

$cacheCode = @"
using System;
using System.Runtime.InteropServices;
public class SysCache3 {
    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern bool SetSystemFileCacheSize(IntPtr min, IntPtr max, int flags);
    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern bool GetSystemFileCacheSize(out IntPtr min, out IntPtr max, out int flags);
}
"@
if (-not ([System.Management.Automation.PSTypeName]"SysCache3").Type) {
    Add-Type -TypeDefinition $cacheCode -ErrorAction SilentlyContinue
}

$apiCode = @"
using System;
using System.Runtime.InteropServices;
public class MemUtil3 {
    [DllImport("psapi.dll")]    public static extern bool EmptyWorkingSet(IntPtr h);
    [DllImport("kernel32.dll")] public static extern IntPtr OpenProcess(uint acc, bool inh, int pid);
    [DllImport("kernel32.dll")] public static extern bool CloseHandle(IntPtr h);
}
"@
if (-not ([System.Management.Automation.PSTypeName]"MemUtil3").Type) {
    Add-Type -TypeDefinition $apiCode -ErrorAction SilentlyContinue
}

function Invoke-MemoryCommand {
    param([int]$cmd, [string]$label)
    $ptr = [System.Runtime.InteropServices.Marshal]::AllocHGlobal(4)
    [System.Runtime.InteropServices.Marshal]::WriteInt32($ptr, $cmd)
    $r = [NtMem3]::NtSetSystemInformation(80, $ptr, 4)
    [System.Runtime.InteropServices.Marshal]::FreeHGlobal($ptr)
    if ($r -eq 0) { Write-Log "  [OK] $label" "Green" }
    else          { Write-Log ("  [WARN] {0} -- NTSTATUS: 0x{1:X}" -f $label, $r) "Yellow" }
}

# ==========================================================================
# STEP 1 -- FLUSH STANDBY LIST + KERNEL CACHE
# ==========================================================================
Show-Section "STEP 1: Flush Standby List + Kernel Cache"

[TokenPriv3]::Enable("SeIncreaseQuotaPrivilege")        | Out-Null
[TokenPriv3]::Enable("SeProfileSingleProcessPrivilege") | Out-Null

Invoke-MemoryCommand -cmd 4 -label "Flush Modified List (dirty pages -> standby)"
Start-Sleep -Milliseconds 300
Invoke-MemoryCommand -cmd 3 -label "Purge Standby List (free kernel cache)"
Start-Sleep -Milliseconds 300
Invoke-MemoryCommand -cmd 1 -label "Empty All Process Working Sets"

# ==========================================================================
# STEP 2 -- FLUSH FILE SYSTEM CACHE
# ==========================================================================
Show-Section "STEP 2: Flush File System Cache"

$minB = [IntPtr]::Zero; $maxB = [IntPtr]::Zero; $flg = 0
[SysCache3]::GetSystemFileCacheSize([ref]$minB, [ref]$maxB, [ref]$flg) | Out-Null
Write-Log ("  Current cache:  min={0} MB   max={1} MB" -f ([long]$minB/1MB), ([long]$maxB/1MB)) "White"

$r2 = [SysCache3]::SetSystemFileCacheSize([IntPtr](-1), [IntPtr](-1), 0)
if ($r2) { Write-Log "  [OK] File system cache flushed" "Green" }
else     { Write-Log "  [WARN] Could not flush cache (may need SE_INCREASE_QUOTA privilege)" "Yellow" }

# ==========================================================================
# STEP 3 -- TRIM WORKING SET OF ALL PROCESSES
# ==========================================================================
Show-Section "STEP 3: Trim Working Set of all processes"

$skipList = @("System","Idle","smss","csrss","wininit","winlogon","lsass",
              "services","Registry","Memory Compression","MsMpEng","audiodg",
              "dwm","fontdrvhost","wdmaud","svchost")
$trimOK = 0; $trimFail = 0; $freedBytes = [long]0

Get-Process -ErrorAction SilentlyContinue |
  Where-Object { $skipList -notcontains $_.ProcessName } |
  ForEach-Object {
    $ws0    = $_.WorkingSet64
    $ACCESS = [uint32]0x1100
    try {
        $h = [MemUtil3]::OpenProcess($ACCESS, $false, $_.Id)
        if ($h -ne [IntPtr]::Zero) {
            [MemUtil3]::EmptyWorkingSet($h) | Out-Null
            [MemUtil3]::CloseHandle($h)     | Out-Null
            $pNow = Get-Process -Id $_.Id -ErrorAction SilentlyContinue
            if ($pNow) { $freedBytes += [math]::Max(0, $ws0 - $pNow.WorkingSet64) }
            $trimOK++
        } else { $trimFail++ }
    } catch { $trimFail++ }
}
Write-Log ("  [OK] Trimmed    : {0} processes" -f $trimOK)  "Green"
Write-Log ("  [OK] Freed      : ~{0} MB" -f [math]::Round($freedBytes/1MB,1)) "Green"
Write-Log ("  [--] Skipped    : {0} protected system processes" -f $trimFail) "DarkGray"

# ==========================================================================
# STEP 4 -- DISABLE UNNECESSARY WINDOWS SERVICES
# ==========================================================================
Show-Section "STEP 4: Disable unnecessary Windows services"

Write-Log "  >> Common services (Win10 + Win11)..." "White"
$n4 = Stop-And-Disable -ServiceMap $svcsCommon -Category "Common"
Write-Log ("  >> Common: {0} services processed" -f $n4) "Green"

if ($isWin10) {
    Write-Log "  >> Win10-only services..." "DarkGray"
    $n4b = Stop-And-Disable -ServiceMap $svcsWin10Only -Category "Win10Only"
    Write-Log ("  >> Win10-specific: {0} services" -f $n4b) "Green"
}
if ($isWin11) {
    Write-Log "  >> Win11-only services..." "DarkGray"
    $n4c = Stop-And-Disable -ServiceMap $svcsWin11Only -Category "Win11Only"
    Write-Log ("  >> Win11-specific: {0} services" -f $n4c) "Green"
}

# ==========================================================================
# STEP 5 -- DISABLE VENDOR SERVICES
# ==========================================================================
Show-Section ("STEP 5: Disable vendor services [ {0} ]" -f $brand)
Write-Log ("  >> Brand: {0}  |  Detection source: {1}" -f $brand, $brandSrc) $brandColor
Write-Log ""

$n5 = 0
switch ($brand) {
    "DELL"               { $n5 = Stop-And-Disable -ServiceMap $svcsDELL     -Category "DELL"     }
    "HP"                 { $n5 = Stop-And-Disable -ServiceMap $svcsHP       -Category "HP"       }
    "LENOVO"             { $n5 = Stop-And-Disable -ServiceMap $svcsLENOVO   -Category "LENOVO"   }
    "ASUS"               { $n5 = Stop-And-Disable -ServiceMap $svcsASUS     -Category "ASUS"     }
    "MSI"                { $n5 = Stop-And-Disable -ServiceMap $svcsMSI      -Category "MSI"      }
    "ACER"               { $n5 = Stop-And-Disable -ServiceMap $svcsACER     -Category "ACER"     }
    "SAMSUNG"            { $n5 = Stop-And-Disable -ServiceMap $svcsSAMSUNG  -Category "SAMSUNG"  }
    "MICROSOFT_SURFACE"  { $n5 = Stop-And-Disable -ServiceMap $svcsSURFACE  -Category "SURFACE"  }
    "RAZER"              { $n5 = Stop-And-Disable -ServiceMap $svcsRAZER    -Category "RAZER"    }
    "GIGABYTE"           { $n5 = Stop-And-Disable -ServiceMap $svcsGIGABYTE -Category "GIGABYTE" }
    "TOSHIBA"            { $n5 = Stop-And-Disable -ServiceMap $svcsTOSHIBA  -Category "TOSHIBA"  }
    "HUAWEI"             { $n5 = Stop-And-Disable -ServiceMap $svcsHUAWEI   -Category "HUAWEI"   }
    "LG"                 { $n5 = Stop-And-Disable -ServiceMap $svcsLG       -Category "LG"       }
    "PANASONIC"          { $n5 = Stop-And-Disable -ServiceMap $svcsPANA     -Category "PANASONIC"}
    "FUJITSU"            { $n5 = Stop-And-Disable -ServiceMap $svcsFUJITSU  -Category "FUJITSU"  }
    "VAIO"               { $n5 = Stop-And-Disable -ServiceMap $svcsVAIO     -Category "VAIO"     }
    "GENERIC_AMI"        {
        Write-Log "  [i] AMI BIOS detected -- trying Gigabyte + ASUS service lists..." "Yellow"
        $n5a = Stop-And-Disable -ServiceMap $svcsGIGABYTE -Category "GIGABYTE/AMI"
        $n5b = Stop-And-Disable -ServiceMap $svcsASUS     -Category "ASUS/AMI"
        $n5  = $n5a + $n5b
    }
    default {
        Write-Log "  [i] Brand not identified -- skipping vendor services." "Yellow"
    }
}
Write-Log ""
Write-Log ("  >> Total vendor [{0}] services processed: {1}" -f $brand, $n5) $brandColor

# ==========================================================================
# STEP 6 -- KEYWORD SCAN: Catch remaining vendor services
# ==========================================================================
Show-Section "STEP 6: Keyword scan -- catch remaining vendor services"

$vendorKW = @(
    "dell","hewlett","hp ","hpinc","lenovo","thinkpad","ideapad","legion",
    "asus","armoury","rog ","tuf ","msi ","dragon center","nahimic",
    "acer ","predator","nitro","swift","aspire","travelmate",
    "samsung","toshiba","huawei","razer","synapse","chroma",
    "gigabyte","rgb fusion","easy tune",
    "supportassist","vantage","pcmanager","lg hub",
    "fujitsu","panasonic","vaio","nec ","intel nuc"
)

$allSvcs    = Get-Service -ErrorAction SilentlyContinue
$extraFound = [System.Collections.Generic.List[object]]::new()

foreach ($svc in $allSvcs) {
    if ($svc.StartType -eq "Disabled") { continue }
    $dl = $svc.DisplayName.ToLower()
    $nl = $svc.Name.ToLower()
    foreach ($kw in $vendorKW) {
        if ($dl -like "*$kw*" -or $nl -like "*$kw*") {
            $extraFound.Add($svc); break
        }
    }
}

if ($extraFound.Count -gt 0) {
    Write-Log ("  [!] Found {0} additional vendor services:" -f $extraFound.Count) "Yellow"
    foreach ($sv in $extraFound) {
        Write-Log ("      {0,-40} [{1}]  {2}" -f $sv.Name, $sv.Status, $sv.DisplayName) "Yellow"
        try {
            if ($sv.Status -eq "Running") {
                Stop-Service -InputObject $sv -Force -ErrorAction SilentlyContinue
            }
            Set-Service -InputObject $sv -StartupType Disabled -ErrorAction SilentlyContinue
            Write-Log "      --> [DISABLED]" "DarkGray"
        } catch {}
    }
} else {
    Write-Log "  [OK] No additional vendor services found." "Green"
}

# ==========================================================================
# STEP 7 -- DISABLE VENDOR STARTUP ITEMS (Registry + Task Scheduler)
# ==========================================================================
Show-Section "STEP 7: Disable vendor Startup items (Registry + Task Scheduler)"

$startupKeys = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run",
    "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
)

$startupVendorKW = @(
    "dell","hewlett","hp ","lenovo","asus","armoury","msi ","acer ",
    "samsung","toshiba","huawei","razer","gigabyte","vantage",
    "supportassist","pcmanager","lg ","fujitsu","vaio","intel nuc",
    "dragon center","nahimic","nitro","predator"
)

$startupRemoved = 0
foreach ($regPath in $startupKeys) {
    if (-not (Test-Path $regPath)) { continue }
    $entries = Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue
    if ($null -eq $entries) { continue }
    $entries.PSObject.Properties |
      Where-Object { $_.MemberType -eq "NoteProperty" -and $_.Name -notmatch "^PS" } |
      ForEach-Object {
        $valName = $_.Name
        $valData = ($_.Value + "").ToLower()
        foreach ($kw in $startupVendorKW) {
            if ($valName.ToLower() -like "*$kw*" -or $valData -like "*$kw*") {
                Remove-ItemProperty -Path $regPath -Name $valName -ErrorAction SilentlyContinue
                Write-Log ("  [RUN-DEL] {0}  =>  {1}" -f $valName, $_.Value) "DarkYellow"
                $startupRemoved++
                break
            }
        }
    }
}

# Task Scheduler: disable vendor scheduled tasks
$taskVendorKW = @(
    "dell","hp","lenovo","asus","msi","acer","samsung","toshiba",
    "huawei","razer","gigabyte","supportassist","vantage","armoury",
    "dragon center","nahimic","fujitsu","vaio","panasonic","nitro","predator"
)

try {
    $sched = New-Object -ComObject "Schedule.Service"
    $sched.Connect()

    function Disable-VendorTasks {
        param($folder)
        try {
            foreach ($task in $folder.GetTasks(0)) {
                $tn = $task.Name.ToLower()
                $tp = $task.Path.ToLower()
                foreach ($kw in $taskVendorKW) {
                    if ($tn -like "*$kw*" -or $tp -like "*$kw*") {
                        if ($task.Enabled) {
                            $task.Enabled = $false
                            Write-Log ("  [TASK-OFF] {0}" -f $task.Path) "DarkYellow"
                            $Script:taskDisabled++
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

Write-Log ("  [OK] Startup registry entries removed : {0}" -f $startupRemoved) "Green"
Write-Log ("  [OK] Vendor scheduled tasks disabled  : {0}" -f $Script:taskDisabled) "Green"

# ==========================================================================
# STEP 8 -- REGISTRY TWEAKS
# ==========================================================================
Show-Section "STEP 8: Registry tweaks (Memory / Telemetry / Visual FX / TCP / Game)"

# --- Memory Management ---
$mm   = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
$pref = "$mm\PrefetchParameters"

$mmSettings = @{
    "LargeSystemCache"       = 0
    "DisablePagingExecutive" = 1
    "SecondLevelDataCache"   = 0
    "NonPagedPoolQuota"      = 0
    "PagedPoolQuota"         = 0
    "SessionPoolSize"        = 4
    "SessionViewSize"        = 48
}
foreach ($k in $mmSettings.Keys) {
    Set-ItemProperty -Path $mm -Name $k -Value $mmSettings[$k] -Type DWord -ErrorAction SilentlyContinue
}
if (Test-Path $pref) {
    Set-ItemProperty -Path $pref -Name "EnablePrefetcher"  -Value 0 -Type DWord -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $pref -Name "EnableSuperfetch"  -Value 0 -Type DWord -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $pref -Name "EnableBoottrace"   -Value 0 -Type DWord -ErrorAction SilentlyContinue
}
Write-Log "  [OK] Memory Management registry optimized" "Green"

# --- Telemetry ---
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
# Block CompatTelRunner via IFEO
$ctrKey = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\CompatTelRunner.exe"
if (-not (Test-Path $ctrKey)) { New-Item -Path $ctrKey -Force -ErrorAction SilentlyContinue | Out-Null }
Set-ItemProperty -Path $ctrKey -Name "Debugger" -Value "%windir%\System32\taskkill.exe" -Type String -ErrorAction SilentlyContinue
Write-Log "  [OK] Telemetry + CEIP + CompatTelRunner disabled" "Green"

# --- Visual FX: Best Performance ---
$visPref = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects"
if (-not (Test-Path $visPref)) { New-Item -Path $visPref -Force -ErrorAction SilentlyContinue | Out-Null }
Set-ItemProperty -Path $visPref -Name "VisualFXSetting" -Value 2 -Type DWord -ErrorAction SilentlyContinue
Write-Log "  [OK] Visual Effects set to Best Performance" "Green"

# --- TCP tweaks ---
$tcpPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
Set-ItemProperty -Path $tcpPath -Name "TcpAckFrequency" -Value 1  -Type DWord -ErrorAction SilentlyContinue
Set-ItemProperty -Path $tcpPath -Name "TCPNoDelay"      -Value 1  -Type DWord -ErrorAction SilentlyContinue
Set-ItemProperty -Path $tcpPath -Name "DefaultTTL"      -Value 64 -Type DWord -ErrorAction SilentlyContinue
Write-Log "  [OK] TCP parameters optimized" "Green"

# --- Power Plan: High Performance ---
try {
    powercfg /setactive SCHEME_MIN 2>&1 | Out-Null
    Write-Log "  [OK] Power Plan set to High Performance" "Green"
} catch {}

# --- Disable GameDVR / GameBar ---
$gdvrPath = "HKCU:\System\GameConfigStore"
if (-not (Test-Path $gdvrPath)) { New-Item -Path $gdvrPath -Force -ErrorAction SilentlyContinue | Out-Null }
Set-ItemProperty -Path $gdvrPath -Name "GameDVR_Enabled" -Value 0 -Type DWord -ErrorAction SilentlyContinue
$gbarPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR"
if (-not (Test-Path $gbarPath)) { New-Item -Path $gbarPath -Force -ErrorAction SilentlyContinue | Out-Null }
Set-ItemProperty -Path $gbarPath -Name "AppCaptureEnabled" -Value 0 -Type DWord -ErrorAction SilentlyContinue
Write-Log "  [OK] GameDVR / GameBar disabled" "Green"

# --- Disable Cortana ---
$cortanaPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"
if (-not (Test-Path $cortanaPath)) { New-Item -Path $cortanaPath -Force -ErrorAction SilentlyContinue | Out-Null }
Set-ItemProperty -Path $cortanaPath -Name "AllowCortana" -Value 0 -Type DWord -ErrorAction SilentlyContinue
Write-Log "  [OK] Cortana disabled via policy" "Green"

# Win11: Widgets panel
if ($isWin11) {
    $widgetPath = "HKLM:\SOFTWARE\Policies\Microsoft\Dsh"
    if (-not (Test-Path $widgetPath)) { New-Item -Path $widgetPath -Force -ErrorAction SilentlyContinue | Out-Null }
    Set-ItemProperty -Path $widgetPath -Name "AllowNewsAndInterests" -Value 0 -Type DWord -ErrorAction SilentlyContinue
    Write-Log "  [OK] Win11 Widgets panel disabled" "Green"
}

# Win10: News & Interests taskbar
if ($isWin10) {
    $niPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds"
    if (-not (Test-Path $niPath)) { New-Item -Path $niPath -Force -ErrorAction SilentlyContinue | Out-Null }
    Set-ItemProperty -Path $niPath -Name "EnableFeeds" -Value 0 -Type DWord -ErrorAction SilentlyContinue
    Write-Log "  [OK] Win10 News & Interests taskbar disabled" "Green"
}

# ==========================================================================
# STEP 9 -- DEEP JUNK CLEANUP
# ==========================================================================
Show-Section "STEP 9: Deep junk file cleanup (5 layers)"

$cleanDirs = @(
    $env:TEMP,
    "$env:LOCALAPPDATA\Temp",
    "C:\Windows\Temp",
    "C:\Windows\Prefetch",
    "$env:LOCALAPPDATA\Microsoft\Windows\INetCache",
    "$env:LOCALAPPDATA\Microsoft\Windows\INetCookies",
    "$env:LOCALAPPDATA\Microsoft\Windows\WebCache",
    "$env:APPDATA\Microsoft\Windows\Recent\AutomaticDestinations",
    "$env:APPDATA\Microsoft\Windows\Recent\CustomDestinations"
)

foreach ($d in $cleanDirs) {
    if (Test-Path $d) {
        $cnt = (Get-ChildItem -Path $d -Recurse -ErrorAction SilentlyContinue | Measure-Object).Count
        Get-ChildItem -Path $d -ErrorAction SilentlyContinue |
            Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
        Write-Log ("  [OK] Cleaned: {0,-55} ({1} items)" -f $d, $cnt) "Green"
    }
}

# Windows Update download cache
$wu = "C:\Windows\SoftwareDistribution\Download"
if (Test-Path $wu) {
    $wus = Get-Service "wuauserv" -ErrorAction SilentlyContinue
    if ($wus -and $wus.Status -eq "Running") {
        Stop-Service "wuauserv" -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
    }
    $wuCnt = (Get-ChildItem $wu -Recurse -ErrorAction SilentlyContinue | Measure-Object).Count
    Get-ChildItem $wu -ErrorAction SilentlyContinue |
        Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
    Start-Service "wuauserv" -ErrorAction SilentlyContinue
    Write-Log ("  [OK] Windows Update download cache: {0} items removed" -f $wuCnt) "Green"
}

# Thumbnail cache
$thumbDir = "$env:LOCALAPPDATA\Microsoft\Windows\Explorer"
if (Test-Path $thumbDir) {
    Get-ChildItem -Path $thumbDir -Filter "thumbcache_*.db" -ErrorAction SilentlyContinue |
        Remove-Item -Force -ErrorAction SilentlyContinue
    Write-Log "  [OK] Thumbnail cache (thumbcache_*.db) removed" "Green"
}

# DNS cache
ipconfig /flushdns 2>&1 | Out-Null
Write-Log "  [OK] DNS cache flushed" "Green"

# Event Logs
foreach ($log in @("Application","System","Setup")) {
    try {
        $ec = (Get-EventLog -LogName $log -ErrorAction SilentlyContinue | Measure-Object).Count
        Clear-EventLog -LogName $log -ErrorAction SilentlyContinue
        Write-Log ("  [OK] Event Log [{0}] cleared ({1} entries)" -f $log, $ec) "DarkGray"
    } catch {}
}

# ==========================================================================
# STEP 10 -- VERSION-SPECIFIC TWEAKS
# ==========================================================================
Show-Section ("STEP 10: Version-specific tweaks [{0}]" -f $winTag)

if ($isWin11) {
    # Taskbar Chat button (Teams consumer)
    $chatKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    Set-ItemProperty -Path $chatKey -Name "TaskbarMn" -Value 0 -Type DWord -ErrorAction SilentlyContinue
    Write-Log "  [OK] Taskbar Chat icon hidden" "Green"

    # Snap Assist Flyout
    Set-ItemProperty -Path $chatKey -Name "EnableSnapAssistFlyout" -Value 0 -Type DWord -ErrorAction SilentlyContinue
    Write-Log "  [OK] Snap Assist Flyout disabled" "Green"

    # Online Speech / Voice Access
    $vaSpeech = "HKCU:\Software\Microsoft\Speech_OneCore\Settings\OnlineServices"
    if (Test-Path $vaSpeech) {
        Set-ItemProperty -Path $vaSpeech -Name "OnlineSpeechPrivacy" -Value 0 -Type DWord -ErrorAction SilentlyContinue
    }
    Write-Log "  [OK] Online Speech Privacy disabled" "Green"

    # Windows Subsystem for Android
    $wsaSvc = Get-Service -Name "WsaService" -ErrorAction SilentlyContinue
    if ($wsaSvc) {
        Stop-Service "WsaService" -Force -ErrorAction SilentlyContinue
        Set-Service  "WsaService" -StartupType Disabled -ErrorAction SilentlyContinue
        Write-Log "  [OK] Windows Subsystem for Android (WSA) disabled" "Green"
    } else {
        Write-Log "  [--] WSA not installed -- skipping" "DarkGray"
    }

    # Copilot button on taskbar
    $cpPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    Set-ItemProperty -Path $cpPath -Name "ShowCopilotButton" -Value 0 -Type DWord -ErrorAction SilentlyContinue
    Write-Log "  [OK] Copilot button hidden from taskbar" "Green"
}

if ($isWin10) {
    # Timeline / Activity Feed
    $tlPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"
    if (-not (Test-Path $tlPath)) { New-Item -Path $tlPath -Force -ErrorAction SilentlyContinue | Out-Null }
    Set-ItemProperty -Path $tlPath -Name "EnableActivityFeed"    -Value 0 -Type DWord -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $tlPath -Name "PublishUserActivities" -Value 0 -Type DWord -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $tlPath -Name "UploadUserActivities"  -Value 0 -Type DWord -ErrorAction SilentlyContinue
    Write-Log "  [OK] Windows Timeline / Activity Feed disabled" "Green"

    # Fast Startup / Hiberboot (can cause RAM issues on HDD)
    $hiberPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power"
    Set-ItemProperty -Path $hiberPath -Name "HiberbootEnabled" -Value 0 -Type DWord -ErrorAction SilentlyContinue
    Write-Log "  [OK] Fast Startup (Hiberboot) disabled -- more stable on HDD" "Green"
}

# ==========================================================================
# SUMMARY
# ==========================================================================
Write-Log ""
Write-Log "  +========================================================+" "Cyan"
Write-Log "  |                      SUMMARY                          |" "Cyan"
Write-Log "  +========================================================+" "Cyan"

$os1   = Get-CimInstance Win32_OperatingSystem
$free1 = [math]::Round($os1.FreePhysicalMemory / 1MB, 2)
$used1 = [math]::Round($total - $free1, 2)
$pct1  = [math]::Round(($used1 / $total) * 100, 1)
$gain  = [math]::Round($free1 - $free0, 2)

Write-Log ""
Write-Log ("  OS          :  {0}  [Build {1}  |  {2}]" -f $winName, $winBuild, $winTag) "White"
Write-Log ("  Brand       :  {0}" -f $brand) $brandColor
Write-Log ("  Total RAM   :  {0} GB" -f $total) "White"
Write-Log ("  Before      :  {0} GB free" -f $free0) "DarkGray"
Write-Log ("  After       :  {0} GB free" -f $free1) "White"

if ($gain -gt 0) {
    Write-Log ("  Freed       :  +{0} GB" -f $gain) "Green"
} else {
    Write-Log "  Change      :  Minor (kernel will release more over the next few seconds)" "Yellow"
}

$ramCol = if ($pct1 -gt 80) {"Red"} elseif ($pct1 -gt 60) {"Yellow"} else {"Green"}
Write-Log ("  In use      :  {0} GB  ({1}%)" -f $used1, $pct1) $ramCol

Write-Log ""
Write-Log "  --------------------------------------------------------" "DarkGray"
Write-Log "  [!] RESTART your PC for all changes to take full effect." "Yellow"
Write-Log "  [!] Vendor services are DISABLED -- they will not auto-start on boot." "Yellow"
Write-Log "  [!] If you lose hardware functionality (Fn keys, sensors, hotkeys)" "Yellow"
Write-Log "      open Services.msc and re-enable the relevant service." "Yellow"
Write-Log "  --------------------------------------------------------" "DarkGray"

# Write log file
try {
    Add-Content -Path $Script:LogFile -Value ("Log created: " + (Get-Date)) -Encoding UTF8
    $Script:LogLines | Out-File -FilePath $Script:LogFile -Encoding UTF8 -ErrorAction Stop
    Write-Log ""
    Write-Log "  [LOG] Report saved to:" "Cyan"
    Write-Log ("        {0}" -f $Script:LogFile) "Cyan"
} catch {
    Write-Log "  [LOG] Could not write log file (Desktop may be restricted)." "DarkGray"
}

Write-Log ""
pause
