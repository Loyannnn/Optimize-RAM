# ==========================================================================
#  Optimize-RAM-v3.ps1  |  GOD MODE
#  Ho tro: Windows 10 (1809+) & Windows 11
#  Phien ban: 3.0
#  --------------------------------------------------------------------------
#  TINH NANG:
#   [0]  Nhan dien Win10 / Win11, build number, kich hoat tinh nang phu hop
#   [1]  Xa Standby List, Modified List, Working Sets (kernel-level)
#   [2]  Xa File System Cache
#   [3]  Trim Working Set toan bo tien trinh
#   [4]  Nhan dien hang may (Dell/HP/Lenovo/ASUS/MSI/Acer/Samsung/...)
#   [5]  Tat dich vu Windows chung + rieng theo Win10/Win11
#   [6]  Tat dich vu hang may (danh sach rieng tung hang)
#   [7]  Scan keyword tat dich vu hang con sot
#   [8]  Tat Startup Registry + Task Scheduler cua hang
#   [9]  Registry: Memory Mgmt, Telemetry, Visual FX, TCP, GameDVR
#   [10] Don file rac: Temp, Prefetch, WU, INet, Thumbnail, EventLog
#   [11] Toi uu dac biet Win11 (Widgets, WSA, Chat) / Win10 (Timeline)
#   [12] Xuat LOG bao cao chi tiet ra Desktop
#  --------------------------------------------------------------------------
#  Yeu cau: PowerShell 5.1+  |  Administrator
# ==========================================================================

#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = "SilentlyContinue"

# ---- Admin guard ----
$_ap = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $_ap.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "[!] Can quyen Administrator!" -ForegroundColor Red
    Write-Host "    Nhan chuot PHAI vao file .bat -> Run as administrator" -ForegroundColor Yellow
    Start-Sleep 3; exit 1
}

# ==========================================================================
# BIEN TOAN CUC
# ==========================================================================
$Script:LogLines   = [System.Collections.Generic.List[string]]::new()
$Script:LogFile    = "$env:USERPROFILE\Desktop\RAM-Optimize-Log-$(Get-Date -f 'yyyyMMdd-HHmmss').txt"
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
# PHAN 0 -- NHAN DIEN HE THONG
# ==========================================================================
Clear-Host
Write-Log ""
Write-Log "  +========================================================+" "Cyan"
Write-Log "  |    TOI UU RAM  --  GOD MODE  v3.0                     |" "Cyan"
Write-Log "  |    Ho tro: Windows 10 (1809+) & Windows 11            |" "Cyan"
Write-Log "  |    Nhan dien hang + Tat dich vu + Don sach he thong   |" "Cyan"
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

Write-Log ("  OS    :  {0}" -f $winName) "White"
Write-Log ("  Build :  {0}  [{1}]" -f $winBuild, $winTag) "White"
Write-Log ("  May   :  {0}  |  {1}" -f $cs.Manufacturer, $cs.Model) "White"
Write-Log ("  BIOS  :  {0}  {1}"   -f $bios.Manufacturer, ($bios.SMBIOSBIOSVersion -join " ")) "White"
Write-Log ("  CPU   :  {0}" -f $cpu.Name) "White"
Write-Log ("  RAM   :  {0} GB (Physical)  |  Dang ranh: {1} GB" -f $ramGB, $free0) "White"
Write-Log ""

if ($winTag -eq "WIN_OLD") {
    Write-Log "  [!] Windows build qua cu (<1809). Mot so tinh nang co the khong hoat dong." "Yellow"
}

# --- Nhan dien hang may ---
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

Write-Log ("  [*] Hang may nhan dien: [ {0} ]  (nguon: {1})" -f $brand, $brandSrc) $brandColor
Write-Log ""

# ==========================================================================
# DANH SACH DICH VU
# ==========================================================================

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
    "OneSyncSvc"             = "Sync Host (mail/calendar)"
    "WSearch"                = "Windows Search Indexing"
    "SysMain"                = "SysMain / Superfetch"
    "RemoteRegistry"         = "Remote Registry"
    "RemoteAccess"           = "Routing and Remote Access"
    "SharedAccess"           = "Internet Connection Sharing"
    "TermService"            = "Remote Desktop Services (neu khong dung RDP)"
    "SessionEnv"             = "Remote Desktop Configuration"
    "UmRdpService"           = "Remote Desktop Device Redirector"
    "ScDeviceEnum"           = "Smart Card Device Enumeration"
    "SCardSvr"               = "Smart Card"
    "SCPolicySvc"            = "Smart Card Removal Policy"
    "MixedRealityOpenXRSvc"  = "Mixed Reality OpenXR"
    "WbioSrvc"               = "Windows Biometric"
    "PhoneSvc"               = "Phone Service"
    "PimIndexMaintenanceSvc" = "Contact Data"
    "UnistoreSvc"            = "User Data Storage"
    "UserDataSvc"            = "User Data Access"
    "PrintNotify"            = "Printer Extensions & Notifications"
    "Spooler"                = "Print Spooler (neu khong in)"
    "BthAvctpSvc"            = "Bluetooth Audio Gateway"
    "BTAGService"            = "Bluetooth Audio Gateway AVRCP"
}

$svcsWin10Only = [ordered]@{
    "AJRouter"               = "AllJoyn Router (IoT protocol)"
    "CscService"             = "Offline Files"
    "DusmSvc"                = "Data Usage"
    "wlidsvc"                = "Microsoft Account Sign-in Assistant"
    "SEMgrSvc"               = "Payments and NFC/SE Manager"
    "NcbService"             = "Network Connection Broker"
    "CDPSvc"                 = "Connected Devices Platform (Win10)"
}

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
    "DellInc.SupportAssistBusinessPCAgent"   = "Dell SupportAssist Business Agent"
}

# ---------- HP ----------
$svcsHP = [ordered]@{
    "HPAppHelperCap"             = "HP App Helper Capture"
    "HPDiagsMsgSvc"              = "HP Diagnostics Messages"
    "HPNetworkCap"               = "HP Network Capture (telemetry)"
    "HPSysInfoCap"               = "HP SysInfo Capture (telemetry)"
    "hpsvc"                      = "HP Service"
    "HpTouchpointAnalyticsService" = "HP Touchpoint Analytics (telemetry)"
    "HP Comm Recover"            = "HP Comm Recover"
    "HPPrintScanDoctorService"   = "HP Print Scan Doctor"
    "HPAudioSwitch"              = "HP Audio Switch"
    "hp3ddrivelock"              = "HP 3D DriveGuard"
    "HotKeyServiceDLL"           = "HP HotKey Service"
    "HPWMISVC"                   = "HP WMI Service"
    "HPJumpStartBridge"          = "HP JumpStart Bridge"
    "HPJumpStartSvc"             = "HP JumpStart Service"
    "hpCMSgt"                    = "HP Connection Manager"
    "HPSmartAdapter"             = "HP Smart Adapter"
    "HPUpdateService"            = "HP Update Service"
    "HPDrvSvc"                   = "HP Driver Service"
    "HPAM"                       = "HP Account Manager"
}

# ---------- LENOVO ----------
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
    "bcom"                       = "Lenovo BCOM module"
    "LenovoSmartStandbyService"  = "Lenovo Smart Standby"
    "LenovoUtilityService"       = "Lenovo Utility Service"
    "LenovoMigrationService"     = "Lenovo Migration Service"
    "LenovoWiFiHotspotSvc"       = "Lenovo WiFi Hotspot"
}

# ---------- ASUS ----------
$svcsASUS = [ordered]@{
    "asHmComSvc"                 = "ASUS HM Com Service"
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
    "ArmouryCrateService"        = "Armoury Crate"
    "GamingCenterService"        = "ASUS Gaming Center"
    "ASUSGiftBoxService"         = "ASUS Gift Box"
    "ASUSGiftBoxDesktopService"  = "ASUS Gift Box Desktop"
    "ASUSSystemControlInterface" = "ASUS System Control Interface"
    "ASUSSmartLogon"             = "ASUS Smart Logon"
}

# ---------- MSI ----------
$svcsMSI = [ordered]@{
    "MSI_SuperCharger"       = "MSI SuperCharger"
    "MSIAfterburnerCore"     = "MSI Afterburner (neu khong ep xung GPU)"
    "SCM"                    = "MSI System Control Manager"
    "msidrvsvc"              = "MSI Driver Service"
    "MSICenterService"       = "MSI Center"
    "MSIKeyboard"            = "MSI Keyboard Service"
    "MSIGamingCenterService" = "MSI Gaming Center"
    "DragonCenterService"    = "MSI Dragon Center"
    "NahimicService"         = "Nahimic Audio (MSI)"
    "MSIRGBService"          = "MSI RGB Service"
}

# ---------- ACER ----------
$svcsACER = [ordered]@{
    "AcerService"                = "Acer Service"
    "AcerCloudService"           = "Acer Cloud"
    "AcerPortalService"          = "Acer Portal"
    "eDataSecurityManagement"    = "Acer eDataSecurity"
    "AcerLaunchManager"          = "Acer Launch Manager"
    "AcerOptimizer"              = "Acer Optimizer"
    "PredatorSenseService"       = "Acer PredatorSense"
    "NitroSenseService"          = "Acer NitroSense"
    "QuickAccessService"         = "Acer Quick Access"
    "AcerUpdateService"          = "Acer Update Service"
    "AcerCare"                   = "Acer Care Center"
    "ConceptDSenseService"       = "Acer ConceptD Sense"
}

# ---------- SAMSUNG ----------
$svcsSAMSUNG = [ordered]@{
    "SamsungMagicianService"  = "Samsung Magician"
    "SamsungDeXSvc"           = "Samsung DeX"
    "SamsungUpdateService"    = "Samsung Update"
    "SamsungSystemManager"    = "Samsung System Manager"
    "SamsungPC_Share_Manager" = "Samsung PC Share Manager"
    "SAService"               = "Samsung Activation Service"
    "SamsungSSDManager"       = "Samsung SSD Manager"
}

# ---------- SURFACE ----------
$svcsSURFACE = [ordered]@{
    "SurfaceService"                     = "Surface Service"
    "SurfaceTelemetryService"            = "Surface Telemetry"
    "SurfaceDiagnostics"                 = "Surface Diagnostics"
    "SurfaceButton"                      = "Surface Button Service"
    "SurfacePen"                         = "Surface Pen Service"
    "SurfaceFirmwareProvisioningService" = "Surface Firmware Provisioning"
}

# ---------- RAZER ----------
$svcsRAZER = [ordered]@{
    "Razer Chroma SDK Server"  = "Razer Chroma SDK Server"
    "Razer Chroma SDK Service" = "Razer Chroma SDK Service"
    "RazerCentralService"      = "Razer Central"
    "RazerIngameEngine"        = "Razer InGame Engine"
    "Razer Synapse Service"    = "Razer Synapse"
    "RzActionSvc"              = "Razer Action Service"
    "RazerNamingService"       = "Razer Naming Service"
}

# ---------- GIGABYTE ----------
$svcsGIGABYTE = [ordered]@{
    "GiGEAudServ"           = "Gigabyte Audio Service"
    "GbActuatorService"     = "Gigabyte Actuator"
    "AppCenter"             = "Gigabyte App Center"
    "EasyTuneEngineService" = "Gigabyte Easy Tune"
    "RGBFusionSvc"          = "Gigabyte RGB Fusion"
    "AGSService"            = "Gigabyte AGS Service"
    "GbFirmwareUpdateSvc"   = "Gigabyte Firmware Update"
}

# ---------- TOSHIBA ----------
$svcsTOSHIBA = [ordered]@{
    "TODDSrv"                     = "Toshiba ODD Device"
    "TMachInfo"                   = "Toshiba Machine Info"
    "TOSHIBA eco Utility Service" = "Toshiba Eco Utility"
    "TVALZ"                       = "Toshiba ACPI Driver"
    "TPCH"                        = "Toshiba PCH Service"
    "Toshiba TEMPRO"              = "Toshiba TEMPRO"
}

# ---------- HUAWEI ----------
$svcsHUAWEI = [ordered]@{
    "HuaweiPCManagerSvc"       = "Huawei PCManager"
    "HuaweiService"            = "Huawei Service"
    "HiService"                = "Huawei HiSuite"
    "HuaweiEasyProjectionSvc"  = "Huawei EasyProjection"
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
    "FjSessServiceAgent" = "Fujitsu Session Agent"
    "FjDspService"       = "Fujitsu DSP Service"
    "FUJBtnSvc"          = "Fujitsu Button Service"
}

# ---------- VAIO ----------
$svcsVAIO = [ordered]@{
    "VAIOCareService"    = "VAIO Care Service"
    "VAIOAudioControl"   = "VAIO Audio Control"
    "VAIOEventService"   = "VAIO Event Service"
    "VaioSettingsService"= "VAIO Settings Service"
}

# ==========================================================================
# HAM TIEN ICH -- Stop & Disable
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
# BUOC 1 -- XA STANDBY LIST + KERNEL CACHE
# ==========================================================================
Show-Section "BUOC 1: Xa Standby List + Kernel Cache"

[TokenPriv3]::Enable("SeIncreaseQuotaPrivilege")        | Out-Null
[TokenPriv3]::Enable("SeProfileSingleProcessPrivilege") | Out-Null

Invoke-MemoryCommand -cmd 4 -label "Flush Modified List (dirty pages -> standby)"
Start-Sleep -Milliseconds 300
Invoke-MemoryCommand -cmd 3 -label "Purge Standby List (giai phong cache kernel)"
Start-Sleep -Milliseconds 300
Invoke-MemoryCommand -cmd 1 -label "Empty All Working Sets"

# ==========================================================================
# BUOC 2 -- XA FILE SYSTEM CACHE
# ==========================================================================
Show-Section "BUOC 2: Xa File System Cache"

$minB = [IntPtr]::Zero; $maxB = [IntPtr]::Zero; $flg = 0
[SysCache3]::GetSystemFileCacheSize([ref]$minB, [ref]$maxB, [ref]$flg) | Out-Null
Write-Log ("  Cache hien tai:  min={0} MB   max={1} MB" -f ([long]$minB/1MB), ([long]$maxB/1MB)) "White"

$r2 = [SysCache3]::SetSystemFileCacheSize([IntPtr](-1), [IntPtr](-1), 0)
if ($r2) { Write-Log "  [OK] File system cache da xa" "Green" }
else     { Write-Log "  [WARN] Khong xa duoc (co the can them quyen SE_INCREASE_QUOTA)" "Yellow" }

# ==========================================================================
# BUOC 3 -- TRIM WORKING SET TOAN BO TIEN TRINH
# ==========================================================================
Show-Section "BUOC 3: Trim Working Set toan bo tien trinh"

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
Write-Log ("  [OK] Trim xong  : {0} tien trinh" -f $trimOK)  "Green"
Write-Log ("  [OK] Giai phong : ~{0} MB" -f [math]::Round($freedBytes/1MB,1)) "Green"
Write-Log ("  [--] Bo qua     : {0} tien trinh he thong" -f $trimFail) "DarkGray"

# ==========================================================================
# BUOC 4 -- TAT DICH VU HE THONG CHUNG
# ==========================================================================
Show-Section "BUOC 4: Tat dich vu Windows khong can thiet"

Write-Log "  >> Dich vu chung (Win10 + Win11)..." "White"
$n4 = Stop-And-Disable -ServiceMap $svcsCommon -Category "Common"
Write-Log ("  >> Common: {0} dich vu xu ly" -f $n4) "Green"

if ($isWin10) {
    Write-Log "  >> Dich vu Win10-only..." "DarkGray"
    $n4b = Stop-And-Disable -ServiceMap $svcsWin10Only -Category "Win10Only"
    Write-Log ("  >> Win10 specific: {0} dich vu" -f $n4b) "Green"
}
if ($isWin11) {
    Write-Log "  >> Dich vu Win11-only..." "DarkGray"
    $n4c = Stop-And-Disable -ServiceMap $svcsWin11Only -Category "Win11Only"
    Write-Log ("  >> Win11 specific: {0} dich vu" -f $n4c) "Green"
}

# ==========================================================================
# BUOC 5 -- TAT DICH VU THEO HANG MAY
# ==========================================================================
Show-Section ("BUOC 5: Tat dich vu hang may [ {0} ]" -f $brand)
Write-Log ("  >> Hang: {0}  |  Nguon: {1}" -f $brand, $brandSrc) $brandColor
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
        Write-Log "  [i] BIOS AMI -- thu Gigabyte + ASUS..." "Yellow"
        $n5a = Stop-And-Disable -ServiceMap $svcsGIGABYTE -Category "GIGABYTE/AMI"
        $n5b = Stop-And-Disable -ServiceMap $svcsASUS     -Category "ASUS/AMI"
        $n5  = $n5a + $n5b
    }
    default {
        Write-Log "  [i] Hang chua nhan dien -- bo qua dich vu hang." "Yellow"
    }
}
Write-Log ""
Write-Log ("  >> Tong dich vu hang [{0}] xu ly: {1}" -f $brand, $n5) $brandColor

# ==========================================================================
# BUOC 6 -- SCAN KEYWORD: Tim dich vu hang con sot
# ==========================================================================
Show-Section "BUOC 6: Scan keyword -- tim dich vu hang con sot"

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
    Write-Log ("  [!] Phat hien them {0} dich vu hang:" -f $extraFound.Count) "Yellow"
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
    Write-Log "  [OK] Khong phat hien them dich vu hang nao." "Green"
}

# ==========================================================================
# BUOC 7 -- TAT STARTUP ITEMS HANG (Registry + Task Scheduler)
# ==========================================================================
Show-Section "BUOC 7: Tat Startup items hang (Registry + Task Scheduler)"

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

# Task Scheduler: vo hieu hoa task cua hang
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

Write-Log ("  [OK] Startup registry entries da xoa : {0}" -f $startupRemoved) "Green"
Write-Log ("  [OK] Scheduled tasks hang da tat     : {0}" -f $Script:taskDisabled) "Green"

# ==========================================================================
# BUOC 8 -- REGISTRY TUNG HOP
# ==========================================================================
Show-Section "BUOC 8: Toi uu Registry (Memory / Telemetry / Visual / TCP / Game)"

# Memory Management
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
Write-Log "  [OK] Memory Management registry" "Green"

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
# Block CompatTelRunner
$ctrKey = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\CompatTelRunner.exe"
if (-not (Test-Path $ctrKey)) { New-Item -Path $ctrKey -Force -ErrorAction SilentlyContinue | Out-Null }
Set-ItemProperty -Path $ctrKey -Name "Debugger" -Value "%windir%\System32\taskkill.exe" -Type String -ErrorAction SilentlyContinue
Write-Log "  [OK] Telemetry + CEIP + CompatTelRunner da tat" "Green"

# Visual FX -- Best Performance
$visPref = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects"
if (-not (Test-Path $visPref)) { New-Item -Path $visPref -Force -ErrorAction SilentlyContinue | Out-Null }
Set-ItemProperty -Path $visPref -Name "VisualFXSetting" -Value 2 -Type DWord -ErrorAction SilentlyContinue
Write-Log "  [OK] Visual Effects -> Best Performance" "Green"

# TCP toi uu
$tcpPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
Set-ItemProperty -Path $tcpPath -Name "TcpAckFrequency" -Value 1  -Type DWord -ErrorAction SilentlyContinue
Set-ItemProperty -Path $tcpPath -Name "TCPNoDelay"      -Value 1  -Type DWord -ErrorAction SilentlyContinue
Set-ItemProperty -Path $tcpPath -Name "DefaultTTL"      -Value 64 -Type DWord -ErrorAction SilentlyContinue
Write-Log "  [OK] TCP parameters toi uu" "Green"

# Power: High Performance
try {
    powercfg /setactive SCHEME_MIN 2>&1 | Out-Null
    Write-Log "  [OK] Power Plan -> High Performance" "Green"
} catch {}

# GameDVR / GameBar tat
$gdvrPath = "HKCU:\System\GameConfigStore"
if (-not (Test-Path $gdvrPath)) { New-Item -Path $gdvrPath -Force -ErrorAction SilentlyContinue | Out-Null }
Set-ItemProperty -Path $gdvrPath -Name "GameDVR_Enabled" -Value 0 -Type DWord -ErrorAction SilentlyContinue
$gbarPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR"
if (-not (Test-Path $gbarPath)) { New-Item -Path $gbarPath -Force -ErrorAction SilentlyContinue | Out-Null }
Set-ItemProperty -Path $gbarPath -Name "AppCaptureEnabled" -Value 0 -Type DWord -ErrorAction SilentlyContinue
Write-Log "  [OK] GameDVR / GameBar tat" "Green"

# Cortana tat
$cortanaPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"
if (-not (Test-Path $cortanaPath)) { New-Item -Path $cortanaPath -Force -ErrorAction SilentlyContinue | Out-Null }
Set-ItemProperty -Path $cortanaPath -Name "AllowCortana" -Value 0 -Type DWord -ErrorAction SilentlyContinue
Write-Log "  [OK] Cortana tat qua policy" "Green"

# Win11: Widgets
if ($isWin11) {
    $widgetPath = "HKLM:\SOFTWARE\Policies\Microsoft\Dsh"
    if (-not (Test-Path $widgetPath)) { New-Item -Path $widgetPath -Force -ErrorAction SilentlyContinue | Out-Null }
    Set-ItemProperty -Path $widgetPath -Name "AllowNewsAndInterests" -Value 0 -Type DWord -ErrorAction SilentlyContinue
    Write-Log "  [OK] Win11 Widgets panel tat" "Green"
}

# Win10: News & Interests
if ($isWin10) {
    $niPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds"
    if (-not (Test-Path $niPath)) { New-Item -Path $niPath -Force -ErrorAction SilentlyContinue | Out-Null }
    Set-ItemProperty -Path $niPath -Name "EnableFeeds" -Value 0 -Type DWord -ErrorAction SilentlyContinue
    Write-Log "  [OK] Win10 News & Interests taskbar tat" "Green"
}

# ==========================================================================
# BUOC 9 -- DON FILE RAC NAM CAP
# ==========================================================================
Show-Section "BUOC 9: Don file rac he thong (nam cap)"

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
        Write-Log ("  [OK] Don: {0,-55} ({1} items)" -f $d, $cnt) "Green"
    }
}

# Windows Update cache
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
    Write-Log ("  [OK] Windows Update cache: {0} items" -f $wuCnt) "Green"
}

# Thumbnail cache
$thumbDir = "$env:LOCALAPPDATA\Microsoft\Windows\Explorer"
if (Test-Path $thumbDir) {
    Get-ChildItem -Path $thumbDir -Filter "thumbcache_*.db" -ErrorAction SilentlyContinue |
        Remove-Item -Force -ErrorAction SilentlyContinue
    Write-Log "  [OK] Thumbnail cache (thumbcache_*.db) xoa" "Green"
}

# DNS
ipconfig /flushdns 2>&1 | Out-Null
Write-Log "  [OK] DNS Cache flush" "Green"

# Event Logs
foreach ($log in @("Application","System","Setup")) {
    try {
        $ec = (Get-EventLog -LogName $log -ErrorAction SilentlyContinue | Measure-Object).Count
        Clear-EventLog -LogName $log -ErrorAction SilentlyContinue
        Write-Log ("  [OK] Event Log [{0}] cleared ({1} entries)" -f $log, $ec) "DarkGray"
    } catch {}
}

# ==========================================================================
# BUOC 10 -- TOI UU DANG THEO PHIEN BAN WINDOWS
# ==========================================================================
Show-Section ("BUOC 10: Toi uu dac thu [{0}]" -f $winTag)

if ($isWin11) {
    # Taskbar Chat (Teams consumer)
    $chatKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    Set-ItemProperty -Path $chatKey -Name "TaskbarMn" -Value 0 -Type DWord -ErrorAction SilentlyContinue
    Write-Log "  [OK] Taskbar Chat icon an" "Green"

    # Snap Assist Flyout
    Set-ItemProperty -Path $chatKey -Name "EnableSnapAssistFlyout" -Value 0 -Type DWord -ErrorAction SilentlyContinue
    Write-Log "  [OK] Snap Assist Flyout tat" "Green"

    # Voice / Online Speech
    $vaSpeech = "HKCU:\Software\Microsoft\Speech_OneCore\Settings\OnlineServices"
    if (Test-Path $vaSpeech) {
        Set-ItemProperty -Path $vaSpeech -Name "OnlineSpeechPrivacy" -Value 0 -Type DWord -ErrorAction SilentlyContinue
    }
    Write-Log "  [OK] Online Speech Privacy tat" "Green"

    # WSA (Windows Subsystem for Android)
    $wsaSvc = Get-Service -Name "WsaService" -ErrorAction SilentlyContinue
    if ($wsaSvc) {
        Stop-Service "WsaService" -Force -ErrorAction SilentlyContinue
        Set-Service  "WsaService" -StartupType Disabled -ErrorAction SilentlyContinue
        Write-Log "  [OK] Windows Subsystem for Android (WSA) tat" "Green"
    } else {
        Write-Log "  [--] WSA khong cai -- bo qua" "DarkGray"
    }

    # Copilot
    $cpPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    Set-ItemProperty -Path $cpPath -Name "ShowCopilotButton" -Value 0 -Type DWord -ErrorAction SilentlyContinue
    Write-Log "  [OK] Copilot button an tren taskbar" "Green"
}

if ($isWin10) {
    # Timeline
    $tlPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"
    if (-not (Test-Path $tlPath)) { New-Item -Path $tlPath -Force -ErrorAction SilentlyContinue | Out-Null }
    Set-ItemProperty -Path $tlPath -Name "EnableActivityFeed"    -Value 0 -Type DWord -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $tlPath -Name "PublishUserActivities" -Value 0 -Type DWord -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $tlPath -Name "UploadUserActivities"  -Value 0 -Type DWord -ErrorAction SilentlyContinue
    Write-Log "  [OK] Windows Timeline tat" "Green"

    # Fast Startup (neu o SSD thi co the giu, o HDD tat de tranh loi RAM)
    $hiberPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power"
    Set-ItemProperty -Path $hiberPath -Name "HiberbootEnabled" -Value 0 -Type DWord -ErrorAction SilentlyContinue
    Write-Log "  [OK] Fast Startup (Hiberboot) tat -- on dinh hon tren HDD" "Green"
}

# ==========================================================================
# TONG KET & XAC NHAN
# ==========================================================================
Write-Log ""
Write-Log "  +========================================================+" "Cyan"
Write-Log "  |                     TONG KET                          |" "Cyan"
Write-Log "  +========================================================+" "Cyan"

$os1   = Get-CimInstance Win32_OperatingSystem
$free1 = [math]::Round($os1.FreePhysicalMemory / 1MB, 2)
$used1 = [math]::Round($total - $free1, 2)
$pct1  = [math]::Round(($used1 / $total) * 100, 1)
$gain  = [math]::Round($free1 - $free0, 2)

Write-Log ""
Write-Log ("  OS       :  {0}  [Build {1}  |  {2}]" -f $winName, $winBuild, $winTag) "White"
Write-Log ("  Hang may :  {0}" -f $brand) $brandColor
Write-Log ("  Tong RAM :  {0} GB" -f $total) "White"
Write-Log ("  Truoc    :  ranh {0} GB" -f $free0) "DarkGray"
Write-Log ("  Sau      :  ranh {0} GB" -f $free1) "White"

if ($gain -gt 0) {
    Write-Log ("  Giai phong : +{0} GB" -f $gain) "Green"
} else {
    Write-Log "  Thay doi   : Nho (kernel tu xa them sau vai giay)" "Yellow"
}

$ramCol = if ($pct1 -gt 80) {"Red"} elseif ($pct1 -gt 60) {"Yellow"} else {"Green"}
Write-Log ("  Dang dung  : {0} GB  ({1}%)" -f $used1, $pct1) $ramCol

Write-Log ""
Write-Log "  --------------------------------------------------------" "DarkGray"
Write-Log "  [!] RESTART may de toan bo thay doi co hieu luc." "Yellow"
Write-Log "  [!] Dich vu hang da DISABLED -- khong tu chay lai khi boot." "Yellow"
Write-Log "  [!] Neu mat chuc nang (Fn key, cam bien, bam phim dac biet)" "Yellow"
Write-Log "      vao: Services.msc  bat lai dich vu can thiet." "Yellow"
Write-Log "  --------------------------------------------------------" "DarkGray"

# Ghi log
try {
    Add-Content -Path $Script:LogFile -Value ("Log tao luc: " + (Get-Date)) -Encoding UTF8
    $Script:LogLines | Out-File -FilePath $Script:LogFile -Encoding UTF8 -ErrorAction Stop
    Write-Log ""
    Write-Log ("  [LOG] Bao cao da luu tai:") "Cyan"
    Write-Log ("        {0}" -f $Script:LogFile) "Cyan"
} catch {
    Write-Log "  [LOG] Khong ghi duoc log (co the Desktop bi chan)." "DarkGray"
}

Write-Log ""
pause
