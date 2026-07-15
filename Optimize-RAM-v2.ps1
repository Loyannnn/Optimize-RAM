# ==========================================================================
#  Optimize-RAM-v2.ps1
#  RAM Optimization Windows 11 -- Phien ban 2.0
#  Tinh nang moi:
#    - Tu dong nhan dien hang may (Dell, HP, Lenovo, ASUS, MSI, Acer, ...)
#    - Disable services theo hang + dich vu he thong khong can thiet
#    - Phan tich startup items, telemetry hang
#    - Bao cao chi tiet theo tung buoc
#  Requirement: PowerShell 5.1+ | Administrator
# ==========================================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "SilentlyContinue"

# ---- Admin check ----
$ap = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $ap.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "[!] Administrator privileges required! Nhan chuot phai -> Run as administrator" -ForegroundColor Red
    pause; exit
}

# =====================================================================
# PHAN 0 -- Lay thong tin he thong & nhan dien hang may
# =====================================================================
Clear-Host
Write-Host ""
Write-Host "  ╔══════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "  ║       RAM OPTIMIZATION WINDOWS 11 -- Version 2.0      ║" -ForegroundColor Cyan
Write-Host "  ║         Nhan dien hang + Disable services hang        ║" -ForegroundColor Cyan
Write-Host "  ╚══════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

$cs      = Get-CimInstance Win32_ComputerSystem
$bios    = Get-CimInstance Win32_BIOS
$os0     = Get-CimInstance Win32_OperatingSystem
$cpu     = Get-CimInstance Win32_Processor | Select-Object -First 1

$mfrRaw  = ($cs.Manufacturer  + " " + $cs.Model).ToLower()
$biosRaw = ($bios.Manufacturer + " " + ($bios.SMBIOSBIOSVersion -join " ")).ToLower()
$free0   = [math]::Round($os0.FreePhysicalMemory   / 1MB, 2)
$total   = [math]::Round($os0.TotalVisibleMemorySize / 1MB, 2)

Write-Host "  May:    $($cs.Manufacturer)  |  $($cs.Model)" -ForegroundColor White
Write-Host "  BIOS:   $($bios.Manufacturer)  $($bios.SMBIOSBIOSVersion)" -ForegroundColor White
Write-Host "  CPU:    $($cpu.Name)" -ForegroundColor White
Write-Host "  RAM:    ${total} GB    |    Available: ${free0} GB" -ForegroundColor White
Write-Host ""

# ---- Nhan dien hang ----
$brand = "UNKNOWN"
switch -Wildcard ($mfrRaw) {
    "*dell*"    { $brand = "DELL"    }
    "*hp*"      { $brand = "HP"      }
    "*hewlett*" { $brand = "HP"      }
    "*lenovo*"  { $brand = "LENOVO"  }
    "*asus*"    { $brand = "ASUS"    }
    "*acer*"    { $brand = "ACER"    }
    "*msi*"     { $brand = "MSI"     }
    "*samsung*" { $brand = "SAMSUNG" }
    "*microsoft*" { $brand = "MICROSOFT_SURFACE" }
    "*toshiba*" { $brand = "TOSHIBA" }
    "*huawei*"  { $brand = "HUAWEI"  }
    "*razer*"   { $brand = "RAZER"   }
    "*gigabyte*"{ $brand = "GIGABYTE" }
    "*intel*"   { $brand = "INTEL_NUC" }
}

# Kiem tra them qua BIOS neu chua xac dinh
if ($brand -eq "UNKNOWN") {
    switch -Wildcard ($biosRaw) {
        "*dell*"    { $brand = "DELL"    }
        "*hp*"      { $brand = "HP"      }
        "*lenovo*"  { $brand = "LENOVO"  }
        "*asus*"    { $brand = "ASUS"    }
        "*acer*"    { $brand = "ACER"    }
        "*msi*"     { $brand = "MSI"     }
        "*american megatrends*" {
            # AMI BIOS thuong la ASUS, MSI, Gigabyte -- giu UNKNOWN nhung ghi chu
            $brand = "GENERIC_AMI"
        }
    }
}

$brandColor = switch ($brand) {
    "DELL"    { "Blue"    }
    "HP"      { "SuccessfullyrkCyan" }
    "LENOVO"  { "Red"     }
    "ASUS"    { "Blue"    }
    "MSI"     { "Red"     }
    "ACER"    { "Green"   }
    "SAMSUNG" { "Cyan"    }
    "RAZER"   { "Green"   }
    default   { "Yellow"  }
}
Write-Host "  *** Phat hien hang may: [ $brand ] ***" -ForegroundColor $brandColor
Write-Host ""

# =====================================================================
# DANH SACH DICH VU THEO HANG
# Key: ten dich vu, Value: mo ta
# =====================================================================

# --- Dich vu chung (tat ca may) ---
$svcsCommon = [ordered]@{
    # Telemetry & diagnostics
    "DiagTrack"             = "Windows Diagnostic Tracking (telemetry Microsoft)"
    "dmwappushservice"      = "WAP Push Message Routing (telemetry)"
    "WerSvc"                = "Windows Error Reporting"
    "wercplsupport"         = "Windows Error Reporting UI"
    # Xbox
    "XblGameSave"           = "Xbox Game Save"
    "XboxNetApiSvc"         = "Xbox Network API"
    "XblAuthManager"        = "Xbox Auth Manager"
    "XboxGipSvc"            = "Xbox Accessories Service"
    # Linh tinh
    "MapsBroker"            = "Downloaded Maps Manager"
    "RetailDemo"            = "Retail Demo"
    "wisvc"                 = "Windows Insider Service"
    "lfsvc"                 = "Geolocation (GPS)"
    "TapiSrv"               = "Telephony"
    "Fax"                   = "Fax Service"
    "WbioSrvc"              = "Windows Biometric Service"
    "icssvc"                = "Windows Mobile Hotspot"
    "MixedRealityOpenXRSvc" = "Mixed Reality OpenXR"
    "WalletService"         = "WalletService"
    "EntAppSvc"             = "Enterprise App Management"
    "MessagingService"      = "Messaging Service"
    "OneSyncSvc"            = "Sync Host (neu khong dung mail/calendar)"
    "PrintNotify"           = "Print Spooler Extension (neu khong in)"
    "WSearch"               = "Windows Search (index file)"
}

# --- Dell ---
$svcsDELL = [ordered]@{
    "DellClientManagementService"       = "Dell Client Management Service"
    "DellUpdate"                        = "Dell Update"
    "DellSupportAssistRemedationService"= "Dell SupportAssist Remediation"
    "Dell SupportAssist Remediation"    = "Dell SupportAssist Remediation (alt)"
    "DellFoundationServices"            = "Dell Foundation Services"
    "DellTechHubService"                = "Dell TechHub Service"
    "DellOptimizer"                     = "Dell Optimizer"
    "DellMobileConnect"                 = "Dell Mobile Connect"
    "DellSuccessfullytaVault"                     = "Dell Successfullyta Vault"
    "DellSuccessfullytaVaultWizard"               = "Dell Successfullyta Vault Wizard"
    "DellInc.PartnerPromo"              = "Dell Partner Promo bloatware"
    "ThermalService"                    = "Dell Thermal Service"
}

# --- HP ---
$svcsHP = [ordered]@{
    "HPAppHelperCap"            = "HP App Helper"
    "HPDiagsMsgSvc"             = "HP Diagnostics Messages"
    "HPNetworkCap"              = "HP Network Capture"
    "HPSysInfoCap"              = "HP System Info Capture"
    "hpsvc"                     = "HP Service"
    "HpTouchpointAnalyticsService" = "HP Touchpoint Analytics (telemetry)"
    "HP Comm Recover"           = "HP Communication Recover"
    "HPPrintScanDoctorService"  = "HP Print Scan Doctor"
    "HPAudioSwitch"             = "HP Audio Switch"
    "hp3ddrivelock"             = "HP 3D DriveGuard"
    "HotKeyServiceDLL"          = "HP HotKey Service"
    "HPWMISVC"                  = "HP WMI Service"
}

# --- Lenovo ---
$svcsLENOVO = [ordered]@{
    "ImControllerService"       = "Lenovo IdeaPad Controller"
    "LenovoFnAndFunctionKeys"   = "Lenovo Fn Function Keys"
    "Lenovo.Modern.ImController"= "Lenovo Modern ImController"
    "LenovoVantageService"      = "Lenovo Vantage Service"
    "LenovoSystemUpdateAddin"   = "Lenovo System Update"
    "SUService"                 = "Lenovo System Update Svc"
    "ThinkPad HDD APS"          = "Lenovo HDD Active Protection"
    "LENOVO.CAMMUTE"            = "Lenovo Camera Mute"
    "LENOVO.MICMUTE"            = "Lenovo Mic Mute"
    "PMSvc"                     = "Lenovo Power Manager"
    "bcom"                      = "Lenovo BCOM (comm module)"
}

# --- ASUS ---
$svcsASUS = [ordered]@{
    "asHmComSvc"        = "ASUS HM Com Service"
    "asus"              = "ASUS Generic Service"
    "AsSysCtrlService"  = "ASUS Sys Control"
    "AsusCertService"   = "ASUS Certificate Service"
    "AsusUpdateCheck"   = "ASUS Update Check"
    "ASUSUpdate"        = "ASUS Update"
    "ASUSLinkNear"      = "ASUS Link Near (Armoury Crate)"
    "ASUSLinkRemote"    = "ASUS Link Remote (Armoury Crate)"
    "ASUSOptimization"  = "ASUS Optimization Service"
    "ASUSSystemAnalysis"= "ASUS System Analysis"
    "ASUSSystemDiagnosis"="ASUS System Diagnosis"
    "ROGLiveService"    = "ASUS ROG Live Service"
    "GamingCenterService" = "ASUS Gaming Center"
    "ArmouryCrateService" = "Armoury Crate Service"
}

# --- MSI ---
$svcsMSI = [ordered]@{
    "MSI_SuperCharger"          = "MSI SuperCharger"
    "MSIAfterburnerCore"        = "MSI Afterburner Core (neu khong ep xung)"
    "SCM"                       = "MSI System Control Manager"
    "msidrvsvc"                 = "MSI Driver Service"
    "MSICenterService"          = "MSI Center Service"
    "MSIKeyboard"               = "MSI Keyboard Service"
    "MSIGamingCenterService"    = "MSI Gaming Center"
    "DragonCenterService"       = "MSI Dragon Center"
}

# --- Acer ---
$svcsACER = [ordered]@{
    "AcerService"               = "Acer Service"
    "AcerCloudService"          = "Acer Cloud Service"
    "AcerPortalService"         = "Acer Portal Service"
    "eSuccessfullytaSecurityManagement"   = "Acer eSuccessfullytaSecurity"
    "AcerLaunchManager"         = "Acer Launch Manager"
    "AcerOptimizer"             = "Acer Optimizer"
    "PredatorSenseService"      = "Acer PredatorSense"
    "NitroSenseService"         = "Acer NitreSense"
}

# --- Samsung ---
$svcsSAMSUNG = [ordered]@{
    "SamsungMagicianService"    = "Samsung Magician"
    "SamsungDeXSvc"             = "Samsung DeX Service"
    "SamsungUpdateService"      = "Samsung Update Service"
    "SamsungSystemManager"      = "Samsung System Manager"
    "SamsungPC_Share_Manager"   = "Samsung PC Share Manager"
}

# --- Microsoft Surface ---
$svcsMICROSOFT_SURFACE = [ordered]@{
    "SurfaceService"            = "Microsoft Surface Service"
    "SurfaceTelemetryService"   = "Surface Telemetry"
    "SurfaceDiagnostics"        = "Surface Diagnostics"
    "SurfaceButton"             = "Surface Button Service"
    "SurfacePen"                = "Surface Pen Service"
}

# --- Razer ---
$svcsRAZER = [ordered]@{
    "Razer Chroma SDK Server"   = "Razer Chroma SDK Server"
    "Razer Chroma SDK Service"  = "Razer Chroma SDK Service"
    "RazerCentralService"       = "Razer Central Service"
    "RazerIngameEngine"         = "Razer InGame Engine"
    "Razer Synapse Service"     = "Razer Synapse"
}

# --- Generic AMI / Gigabyte / bo mach chu roi ---
$svcsGIGABYTE = [ordered]@{
    "GiGEAudServ"               = "Gigabyte Audio Service"
    "GbActuatorService"         = "Gigabyte Actuator"
    "AppCenter"                 = "Gigabyte App Center"
    "EasyTuneEngineService"     = "Gigabyte Easy Tune"
    "RGBFusionSvc"              = "Gigabyte RGB Fusion"
}

# --- Toshiba ---
$svcsTOSHIBA = [ordered]@{
    "TODDSrv"                   = "Toshiba ODD Device"
    "TMachInfo"                 = "Toshiba Machine Info"
    "TOSHIBA eco Utility Service" = "Toshiba Eco Utility"
    "TVALZ"                     = "Toshiba ACPI Driver"
    "TPCH"                      = "Toshiba PCH Service"
}

# --- Huawei ---
$svcsHUAWEI = [ordered]@{
    "HuaweiPCManagerSvc"        = "Huawei PCManager Service"
    "HuaweiService"             = "Huawei Service"
    "HiService"                 = "Huawei HiSuite"
}

# =====================================================================
# Ham tien ich
# =====================================================================
function Show-Section {
    param([string]$title)
    Write-Host ""
    Write-Host "  ┌─────────────────────────────────────────────────┐" -ForegroundColor Cyan
    Write-Host "  │  $($title.PadRight(47))│" -ForegroundColor Cyan
    Write-Host "  └─────────────────────────────────────────────────┘" -ForegroundColor Cyan
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
    param([hashtable]$ServiceMap, [string]$Category)
    $stopped = 0
    $notfound = 0
    foreach ($s in $ServiceMap.Keys) {
        $desc = $ServiceMap[$s]
        if (Test-ProtectedService -Name $s -DisplayName $desc) {
            Write-Host "  [SKIP ] $s (protected core network/bluetooth service)" -ForegroundColor DarkGray
            continue
        }
        $svc = Get-Service -Name $s -ErrorAction SilentlyContinue
        if ($null -eq $svc) {
            # Thu tim theo DisplayName
            $svc2 = Get-Service -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like "*$s*" } | Select-Object -First 1
            if ($null -eq $svc2) { $notfound++; continue }
            $svc = $svc2
        }
        if (Test-ProtectedService -Name $svc.Name -DisplayName $svc.DisplayName) {
            Write-Host "  [SKIP ] $($svc.Name.PadRight(38))  -- protected core service" -ForegroundColor DarkGray
            continue
        }
        try {
            if ($svc.Status -eq "Running") {
                Invoke-SafeStopService -Name $svc.Name -DisplayName $svc.DisplayName
                Write-Host "  [STOP ] $($svc.Name.PadRight(38))  -- $desc" -ForegroundColor SuccessfullyrkYellow
            }
            Invoke-SafeSetDisabledService -Name $svc.Name -DisplayName $svc.DisplayName
            Write-Host "  [OFF  ] $($svc.Name.PadRight(38))  -- $desc" -ForegroundColor SuccessfullyrkGray
            $stopped++
        } catch {}
    }
    if ($stopped -eq 0) {
        Write-Host "  (Unable tim thay dich vu nao cua [$Category] dang chay)" -ForegroundColor SuccessfullyrkGray
    }
    return $stopped
}

# =====================================================================
# PHAN 1 -- XA STANDBY LIST + KERNEL CACHE
# =====================================================================
Show-Section "STEP 1: Xa Standby List + kernel cache"

$ntdllCode = @"
using System;
using System.Runtime.InteropServices;
public class NtMem {
    [DllImport("ntdll.dll")]
    public static extern uint NtSetSystemInformation(int InfoClass, IntPtr Info, int Length);
}
"@
if (-not ([System.Management.Automation.PSTypeName]"NtMem").Type) {
    Add-Type -TypeDefinition $ntdllCode -ErrorAction SilentlyContinue
}

$privCode = @"
using System;
using System.Runtime.InteropServices;
public class TokenPriv {
    [StructLayout(LayoutKind.Sequential, Pack=1)]
    public struct TokPriv1Luid {
        public int Count; public long Luid; public int Attr;
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
        IntPtr hproc = GetCurrentProcess(); IntPtr htok = IntPtr.Zero;
        if (!OpenProcessToken(hproc, 0x28, ref htok)) return false;
        TokPriv1Luid tp; tp.Count = 1; tp.Luid = 0; tp.Attr = 2;
        if (!LookupPrivilegeValue(null, privilege, ref tp.Luid)) return false;
        return AdjustTokenPrivileges(htok, false, ref tp, 0, IntPtr.Zero, IntPtr.Zero);
    }
}
"@
if (-not ([System.Management.Automation.PSTypeName]"TokenPriv").Type) {
    Add-Type -TypeDefinition $privCode -ErrorAction SilentlyContinue
}

[TokenPriv]::EnablePrivilege("SeIncreaseQuotaPrivilege")        | Out-Null
[TokenPriv]::EnablePrivilege("SeProfileSingleProcessPrivilege") | Out-Null

function Invoke-MemoryCommand {
    param([int]$cmd, [string]$label)
    $ptr = [System.Runtime.InteropServices.Marshal]::AllocHGlobal(4)
    [System.Runtime.InteropServices.Marshal]::WriteInt32($ptr, $cmd)
    $r = [NtMem]::NtSetSystemInformation(80, $ptr, 4)
    [System.Runtime.InteropServices.Marshal]::FreeHGlobal($ptr)
    if ($r -eq 0) { Write-Host "  [OK] $label" -ForegroundColor Green }
    else { Write-Host ("  [WARN] $label - NTSTATUS: 0x{0:X}" -f $r) -ForegroundColor Yellow }
}

Invoke-MemoryCommand -cmd 4 -label "Flush Modified List (dirty -> standby)"
Start-Sleep -Milliseconds 300
Invoke-MemoryCommand -cmd 3 -label "Purge Standby List (giai phong cache kernel)"
Start-Sleep -Milliseconds 300
Invoke-MemoryCommand -cmd 1 -label "Empty Working Sets (tat ca tien trinh)"

# =====================================================================
# PHAN 2 -- XA FILE SYSTEM CACHE
# =====================================================================
Show-Section "STEP 2: Xa File System Cache"

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

$minB = [IntPtr]::Zero; $maxB = [IntPtr]::Zero; $flg = 0
[SysCache]::GetSystemFileCacheSize([ref]$minB, [ref]$maxB, [ref]$flg) | Out-Null
Write-Host ("  Cache hien tai:  min={0} MB   max={1} MB" -f ([long]$minB/1MB), ([long]$maxB/1MB)) -ForegroundColor White

$r2 = [SysCache]::SetSystemFileCacheSize([IntPtr](-1), [IntPtr](-1), 0)
if ($r2) { Write-Host "  [OK] File system cache da xa" -ForegroundColor Green }
else     { Write-Host "  [WARN] Unable xa duoc file cache (can quyen cao hon)" -ForegroundColor Yellow }

# =====================================================================
# PHAN 3 -- TRIM WORKING SET TAT CA TIEN TRINH
# =====================================================================
Show-Section "STEP 3: Trim Working Set tat ca tien trinh"

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
          "services","Registry","Memory Compression","MsMpEng","audiodg","dwm","fontdrvhost")
$trimOK = 0; $trimSkip = 0; $freedTotal = [long]0

Get-Process -ErrorAction SilentlyContinue |
  Where-Object { $skip -notcontains $_.ProcessName } |
  ForEach-Object {
    $pid2   = $_.Id
    $ws0    = $_.WorkingSet64
    $ACCESS = [uint32]0x1100
    try {
        $h = [MemUtil2]::OpenProcess($ACCESS, $false, $pid2)
        if ($h -ne [IntPtr]::Zero) {
            [MemUtil2]::EmptyWorkingSet($h)  | Out-Null
            [MemUtil2]::CloseHandle($h)      | Out-Null
            $pNow = Get-Process -Id $pid2 -ErrorAction SilentlyContinue
            if ($pNow) { $freedTotal += [math]::Max(0, $ws0 - $pNow.WorkingSet64) }
            $trimOK++
        } else { $trimSkip++ }
    } catch { $trimSkip++ }
}
Write-Host ("  [OK] Trim xong:   {0} tien trinh" -f $trimOK)  -ForegroundColor Green
Write-Host ("  [OK] Freed:  ~{0} MB"         -f [math]::Round($freedTotal/1MB,1)) -ForegroundColor Green
Write-Host ("  [--] Bo qua:       {0} tien trinh he thong" -f $trimSkip) -ForegroundColor SuccessfullyrkGray

# =====================================================================
# PHAN 4 -- TAT DICH VU HE THONG CHUNG (khong phu thuoc hang)
# =====================================================================
Show-Section "STEP 4: Disable services he thong khong can thiet"

Write-Host "  >> Successfullyng xu ly dich vu Windows chung..." -ForegroundColor White
$cStopped = Stop-And-Disable -ServiceMap $svcsCommon -Category "Windows System"
Write-Host ("  >> Successfully xu ly: {0} dich vu" -f $cStopped) -ForegroundColor Green

# =====================================================================
# PHAN 5 -- TAT DICH VU THEO HANG MAY
# =====================================================================
Show-Section "STEP 5: Disable services theo hang may [$brand]"

Write-Host "  >> Hang may da nhan dien: $brand" -ForegroundColor $brandColor
Write-Host ""

$brandStopped = 0
switch ($brand) {
    "DELL"               { $brandStopped = Stop-And-Disable -ServiceMap $svcsDELL    -Category "DELL" }
    "HP"                 { $brandStopped = Stop-And-Disable -ServiceMap $svcsHP      -Category "HP" }
    "LENOVO"             { $brandStopped = Stop-And-Disable -ServiceMap $svcsLENOVO  -Category "LENOVO" }
    "ASUS"               { $brandStopped = Stop-And-Disable -ServiceMap $svcsASUS    -Category "ASUS" }
    "MSI"                { $brandStopped = Stop-And-Disable -ServiceMap $svcsMSI     -Category "MSI" }
    "ACER"               { $brandStopped = Stop-And-Disable -ServiceMap $svcsACER    -Category "ACER" }
    "SAMSUNG"            { $brandStopped = Stop-And-Disable -ServiceMap $svcsSAMSUNG -Category "SAMSUNG" }
    "MICROSOFT_SURFACE"  { $brandStopped = Stop-And-Disable -ServiceMap $svcsMICROSOFT_SURFACE -Category "SURFACE" }
    "RAZER"              { $brandStopped = Stop-And-Disable -ServiceMap $svcsRAZER   -Category "RAZER" }
    "GIGABYTE"           { $brandStopped = Stop-And-Disable -ServiceMap $svcsGIGABYTE -Category "GIGABYTE" }
    "TOSHIBA"            { $brandStopped = Stop-And-Disable -ServiceMap $svcsTOSHIBA -Category "TOSHIBA" }
    "HUAWEI"             { $brandStopped = Stop-And-Disable -ServiceMap $svcsHUAWEI  -Category "HUAWEI" }
    "GENERIC_AMI"        {
        Write-Host "  [i] Bo mach chu dung BIOS AMI - thu tat dich vu Gigabyte..." -ForegroundColor Yellow
        $brandStopped = Stop-And-Disable -ServiceMap $svcsGIGABYTE -Category "GIGABYTE/AMI"
    }
    default {
        Write-Host "  [i] Unable nhan dien duoc hang cu the." -ForegroundColor Yellow
        Write-Host "  [i] Chi tat dich vu Windows chung." -ForegroundColor Yellow
    }
}
Write-Host ""
Write-Host ("  >> Tong dich vu hang [{0}] da xu ly: {1}" -f $brand, $brandStopped) -ForegroundColor $brandColor

# =====================================================================
# PHAN 6 -- SCAN THEM: Tim dich vu hang con lai chua biet
# =====================================================================
Show-Section "STEP 6: Scan dich vu hang khac trong he thong"

# Successfullynh sach tu khoa bloatware pho bien them
$vendorKeywords = @(
    "dell","hp ","lenovo","asus","msi ","acer ","samsung","toshiba","huawei",
    "razer","gigabyte","nitro","legion","thinkpad","ideapad","zbook","elitebook",
    "omen","pavilion","inspiron","xps","vantage","supportassist","armoury","dragon center",
    "predator","swift","aspire","magicolor","magician","sysmanager"
)

$allSvcs = Get-Service -ErrorAction SilentlyContinue
$extraFound = @()
foreach ($svc in $allSvcs) {
    if ($svc.StartType -eq "Disabled") { continue }
    $displayLow = $svc.DisplayName.ToLower()
    $nameLow    = $svc.Name.ToLower()
    foreach ($kw in $vendorKeywords) {
        if ($displayLow -like "*$kw*" -or $nameLow -like "*$kw*") {
            $extraFound += $svc
            break
        }
    }
}

if ($extraFound.Count -gt 0) {
    Write-Host "  [!] Phat hien them $($extraFound.Count) dich vu hang co the tat:" -ForegroundColor Yellow
    foreach ($svc2 in $extraFound) {
        Write-Host "      $($svc2.Name.PadRight(38))  [$($svc2.Status)]  $($svc2.DisplayName)" -ForegroundColor Yellow
        try {
            if ($svc2.Status -eq "Running") {
                Invoke-SafeStopService -Name $svc2.Name -DisplayName $svc2.DisplayName
            }
            Invoke-SafeSetDisabledService -Name $svc2.Name -DisplayName $svc2.DisplayName
            Write-Host "      --> [OFF]" -ForegroundColor SuccessfullyrkGray
        } catch {}
    }
} else {
    Write-Host "  [OK] Unable phat hien them dich vu hang nao." -ForegroundColor Green
}

# =====================================================================
# PHAN 7 -- REGISTRY: Memory Management + Telemetry
# =====================================================================
Show-Section "STEP 7: Toi uu Registry Memory + Tat Telemetry"

# Memory Management
$mm = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
$pref = "$mm\PrefetchParameters"

Set-ItemProperty -Path $mm   -Name "LargeSystemCache"        -Value 0 -Type DWord -ErrorAction SilentlyContinue
Set-ItemProperty -Path $mm   -Name "DisablePagingExecutive"  -Value 1 -Type DWord -ErrorAction SilentlyContinue
Set-ItemProperty -Path $mm   -Name "SecondLevelSuccessfullytaCache"    -Value 0 -Type DWord -ErrorAction SilentlyContinue

if (Test-Path $pref) {
    Set-ItemProperty -Path $pref -Name "EnablePrefetcher"    -Value 0 -Type DWord -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $pref -Name "EnableSuperfetch"    -Value 0 -Type DWord -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $pref -Name "EnableBoottrace"     -Value 0 -Type DWord -ErrorAction SilentlyContinue
}
Write-Host "  [OK] Memory Management registry da toi uu" -ForegroundColor Green

# Tat Windows telemetry qua registry
$telKeys = @(
    @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\SuccessfullytaCollection"; Name = "AllowTelemetry"; Value = 0 },
    @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\SuccessfullytaCollection"; Name = "AllowTelemetry"; Value = 0 },
    @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat"; Name = "DisableInventory"; Value = 1 },
    @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat"; Name = "DisablePCA"; Value = 1 }
)
foreach ($t in $telKeys) {
    if (-not (Test-Path $t.Path)) {
        New-Item -Path $t.Path -Force -ErrorAction SilentlyContinue | Out-Null
    }
    Set-ItemProperty -Path $t.Path -Name $t.Name -Value $t.Value -Type DWord -ErrorAction SilentlyContinue
}
Write-Host "  [OK] Windows Telemetry da tat qua policy registry" -ForegroundColor Green

# Visual performance: set to best performance mode
$visPref = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects"
if (-not (Test-Path $visPref)) { New-Item -Path $visPref -Force -ErrorAction SilentlyContinue | Out-Null }
Set-ItemProperty -Path $visPref -Name "VisualFXSetting" -Value 2 -Type DWord -ErrorAction SilentlyContinue
Write-Host "  [OK] Visual Effects -> Best Performance" -ForegroundColor Green

# =====================================================================
# PHAN 8 -- DON FILE RAC
# =====================================================================
Show-Section "STEP 8: Don file rac he thong"

$dirs = @($env:TEMP, "C:\Windows\Temp", "C:\Windows\Prefetch", "$env:LOCALAPPDATA\Temp")
foreach ($d in $dirs) {
    if (Test-Path $d) {
        $count = (Get-ChildItem -Path $d -ErrorAction SilentlyContinue | Measure-Object).Count
        Get-ChildItem -Path $d -ErrorAction SilentlyContinue |
            Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
        Write-Host ("  [OK] Don: {0}  ({1} item)" -f $d, $count) -ForegroundColor Green
    }
}

# Windows Update cache
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
    Write-Host "  [OK] Windows Update cache da don" -ForegroundColor Green
}

# DNS Cache flush
ipconfig /flushdns | Out-Null
Write-Host "  [OK] DNS Cache da flush" -ForegroundColor Green

# =====================================================================
# TONG KET
# =====================================================================
Write-Host ""
Write-Host "  ╔══════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "  ║                   TONG KET                      ║" -ForegroundColor Cyan
Write-Host "  ╚══════════════════════════════════════════════════╝" -ForegroundColor Cyan

$os1   = Get-CimInstance Win32_OperatingSystem
$free1 = [math]::Round($os1.FreePhysicalMemory / 1MB, 2)
$used1 = [math]::Round($total - $free1, 2)
$pct1  = [math]::Round(($used1 / $total) * 100, 1)
$gain  = [math]::Round($free1 - $free0, 2)

Write-Host ""
Write-Host "  Hang may     :  $brand" -ForegroundColor $brandColor
Write-Host "  Tong RAM     :  ${total} GB" -ForegroundColor White
Write-Host "  Truoc        :  ranh ${free0} GB" -ForegroundColor SuccessfullyrkGray
Write-Host "  Sau          :  ranh ${free1} GB" -ForegroundColor White

if ($gain -gt 0) {
    Write-Host "  Freed   :  +${gain} GB" -ForegroundColor Green
} else {
    Write-Host "  Thay doi     :  Nho (kernel tu xa them sau vai giay)" -ForegroundColor Yellow
}

$col = if ($pct1 -gt 80) { "Red" } elseif ($pct1 -gt 60) { "Yellow" } else { "Green" }
Write-Host "  Successfullyng dung    :  ${used1} GB  (${pct1}%)" -ForegroundColor $col

Write-Host ""
Write-Host "  ─────────────────────────────────────────────────" -ForegroundColor SuccessfullyrkGray
Write-Host "  [!] Mot so thay doi co hieu luc sau khi RESTART." -ForegroundColor Yellow
Write-Host "  [!] Cac dich vu hang da tat (Disabled) se khong tu khoi dong lai." -ForegroundColor Yellow
Write-Host "  [!] Neu may mat chuc nang nao do, dung Services.msc bat lai." -ForegroundColor Yellow
Write-Host "  ─────────────────────────────────────────────────" -ForegroundColor SuccessfullyrkGray
Write-Host ""
pause
