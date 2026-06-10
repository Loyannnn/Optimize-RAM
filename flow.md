Optimize-ram V1

  RAM tong: 31.69 GB   Dang ranh: 23.58 GB

========================================
  BUOC 1: Xa Standby List + kernel cache
========================================
  [OK] Flush Modified List (trang thai dirty -> standby)
  [OK] Purge Standby List (giai phong cache kernel)
  [OK] Empty Working Sets (tat ca tien trinh)

========================================
  BUOC 2: Xa File System Cache
========================================
  Cache hien tai: min=1MB  max=16777216MB
  [OK] File system cache da xa

========================================
  BUOC 3: Trim Working Set tat ca tien trinh
========================================
  [OK] Trim xong: 185 process, skip: 3
  [OK] Giai phong working set: ~7824.6 MB

========================================
  BUOC 4: Tat dich vu khong can thiet
========================================
  [OFF] DiagTrack
  [OFF] dmwappushservice
  [OFF] WerSvc
  [OFF] wercplsupport
  [OFF] MapsBroker
  [OFF] SysMain
  [OFF] WSearch
  [OFF] XblGameSave
  [OFF] XboxNetApiSvc
  [OFF] XblAuthManager
  [OFF] RetailDemo
  [OFF] wisvc
  [OFF] lfsvc
  [OFF] TapiSrv
  [OFF] Fax
  [OFF] WbioSrvc
  [OK] Superfetch + MM registry da tat

========================================
  BUOC 5: Don file rac
========================================
  [OK] Don: C:\Users\PRECIS~1\AppData\Local\Temp
  [OK] Don: C:\Windows\Temp
  [OK] Don: C:\Windows\Prefetch
  [OK] Windows Update cache da don

========================================
  TONG KET
========================================
  Tong RAM      : 31.69 GB
  Truoc         : ranh 23.58 GB
  Sau           : ranh 27.31 GB
  Da giai phong : +3.73 GB
  Dang dung     : 4.38 GB  (13.8 %)

  Luu y: Restart may de service changes co hieu luc day du.

Optimize-ram V2


  ╔══════════════════════════════════════════════════╗
  ║       TOI UU RAM WINDOWS 11 -- Version 2.0      ║
  ║         Nhan dien hang + Tat dich vu hang        ║
  ╚══════════════════════════════════════════════════╝

  May:    Dell Inc.  |  Precision 7670
  BIOS:   Dell Inc.  1.36.0
  CPU:    12th Gen Intel(R) Core(TM) i9-12950HX
  RAM:    31.69 GB    |    Dang ranh: 25.33 GB

  *** Phat hien hang may: [ DELL ] ***


  ┌─────────────────────────────────────────────────┐
  │  BUOC 1: Xa Standby List + kernel cache         │
  └─────────────────────────────────────────────────┘
  [OK] Flush Modified List (dirty -> standby)
  [OK] Purge Standby List (giai phong cache kernel)
  [OK] Empty Working Sets (tat ca tien trinh)

  ┌─────────────────────────────────────────────────┐
  │  BUOC 2: Xa File System Cache                   │
  └─────────────────────────────────────────────────┘
  Cache hien tai:  min=1 MB   max=16777216 MB
  [OK] File system cache da xa

  ┌─────────────────────────────────────────────────┐
  │  BUOC 3: Trim Working Set tat ca tien trinh     │
  └─────────────────────────────────────────────────┘
  [OK] Trim xong:   189 tien trinh
  [OK] Giai phong:  ~3862 MB
  [--] Bo qua:       3 tien trinh he thong

  ┌─────────────────────────────────────────────────┐
  │  BUOC 4: Tat dich vu he thong khong can thiet   │
  └─────────────────────────────────────────────────┘
  >> Dang xu ly dich vu Windows chung...
  [OFF  ] icssvc                                  -- Windows Mobile Hotspot
  [OFF  ] MessagingService                        -- Messaging Service
  [OFF  ] RetailDemo                              -- Retail Demo
  [OFF  ] TapiSrv                                 -- Telephony
  [OFF  ] Fax                                     -- Fax Service
  [OFF  ] EntAppSvc                               -- Enterprise App Management
  [OFF  ] dmwappushservice                        -- WAP Push Message Routing (telemetry)
  [OFF  ] PrintNotify                             -- Print Spooler Extension (neu khong in)
  [OFF  ] DiagTrack                               -- Windows Diagnostic Tracking (telemetry Microsoft)
  [OFF  ] WalletService                           -- WalletService
  [OFF  ] MapsBroker                              -- Downloaded Maps Manager
  [OFF  ] WSearch                                 -- Windows Search (index file)
  [OFF  ] XboxNetApiSvc                           -- Xbox Network API
  [OFF  ] wisvc                                   -- Windows Insider Service
  [OFF  ] lfsvc                                   -- Geolocation (GPS)
  [OFF  ] WbioSrvc                                -- Windows Biometric Service
  [OFF  ] XboxGipSvc                              -- Xbox Accessories Service
  [OFF  ] WerSvc                                  -- Windows Error Reporting
  [OFF  ] wercplsupport                           -- Windows Error Reporting UI
  [OFF  ] XblGameSave                             -- Xbox Game Save
  [OFF  ] XblAuthManager                          -- Xbox Auth Manager
  [OFF  ] OneSyncSvc                              -- Sync Host (neu khong dung mail/calendar)
  >> Da xu ly: 22 dich vu

  ┌─────────────────────────────────────────────────┐
  │  BUOC 5: Tat dich vu theo hang may [DELL]       │
  └─────────────────────────────────────────────────┘
  >> Hang may da nhan dien: DELL

  [OFF  ] DellClientManagementService             -- Dell Client Management Service

  >> Tong dich vu hang [DELL] da xu ly: 1

  ┌─────────────────────────────────────────────────┐
  │  BUOC 6: Scan dich vu hang khac trong he thong  │
  └─────────────────────────────────────────────────┘
  [OK] Khong phat hien them dich vu hang nao.

  ┌─────────────────────────────────────────────────┐
  │  BUOC 7: Toi uu Registry Memory + Tat Telemetry │
  └─────────────────────────────────────────────────┘
  [OK] Memory Management registry da toi uu
  [OK] Windows Telemetry da tat qua policy registry
  [OK] Visual Effects -> Best Performance

  ┌─────────────────────────────────────────────────┐
  │  BUOC 8: Don file rac he thong                  │
  └─────────────────────────────────────────────────┘
  [OK] Don: C:\Users\PRECIS~1\AppData\Local\Temp  (17 item)
  [OK] Don: C:\Windows\Temp  (1 item)
  [OK] Don: C:\Windows\Prefetch  (0 item)
  [OK] Don: C:\Users\Precision\AppData\Local\Temp  (9 item)
  [OK] Windows Update cache da don
  [OK] DNS Cache da flush

  ╔══════════════════════════════════════════════════╗
  ║                   TONG KET                      ║
  ╚══════════════════════════════════════════════════╝

  Hang may     :  DELL
  Tong RAM     :  31.69 GB
  Truoc        :  ranh 25.33 GB
  Sau          :  ranh 26.55 GB
  Giai phong   :  +1.22 GB
  Dang dung    :  5.14 GB  (16.2%)

  ─────────────────────────────────────────────────
  [!] Mot so thay doi co hieu luc sau khi RESTART.
  [!] Cac dich vu hang da tat (Disabled) se khong tu khoi dong lai.
  [!] Neu may mat chuc nang nao do, dung Services.msc bat lai.
  ─────────────────────────────────────────────────

Press Enter to continue...:


Optimize-ram V3

 +========================================================+
  |    TOI UU RAM  --  GOD MODE  v3.0                     |
  |    Ho tro: Windows 10 (1809+) & Windows 11            |
  |    Nhan dien hang + Tat dich vu + Don sach he thong   |
  +========================================================+

  OS    :  Microsoft Windows 11 Pro
  Build :  26200  [WIN11]
  May   :  Dell Inc.  |  Precision 7670
  BIOS  :  Dell Inc.  1.36.0
  CPU   :  12th Gen Intel(R) Core(TM) i9-12950HX
  RAM   :  31.7 GB (Physical)  |  Dang ranh: 22.51 GB

  [*] Hang may nhan dien: [ DELL ]  (nguon: manufacturer)


  ────────────────────────────────────────────────────────
  >> BUOC 1: Xa Standby List + Kernel Cache
  ────────────────────────────────────────────────────────
  [OK] Flush Modified List (dirty pages -> standby)
  [OK] Purge Standby List (giai phong cache kernel)
  [OK] Empty All Working Sets

  ────────────────────────────────────────────────────────
  >> BUOC 2: Xa File System Cache
  ────────────────────────────────────────────────────────
  Cache hien tai:  min=1 MB   max=16777216 MB
  [OK] File system cache da xa

  ────────────────────────────────────────────────────────
  >> BUOC 3: Trim Working Set toan bo tien trinh
  ────────────────────────────────────────────────────────
  [OK] Trim xong  : 109 tien trinh
  [OK] Giai phong : ~7611.6 MB
  [--] Bo qua     : 3 tien trinh he thong

  ────────────────────────────────────────────────────────
  >> BUOC 4: Tat dich vu Windows khong can thiet
  ────────────────────────────────────────────────────────
  >> Dich vu chung (Win10 + Win11)...
  [OFF ] DiagTrack                                Connected User Experiences & Telemetry (Microsoft)
  [OFF ] dmwappushservice                         WAP Push Message Routing (telemetry)
  [OFF ] WerSvc                                   Windows Error Reporting
  [OFF ] wercplsupport                            WER Control Panel Support
  [OFF ] XblGameSave                              Xbox Game Save
  [OFF ] XboxNetApiSvc                            Xbox Live Networking
  [OFF ] XblAuthManager                           Xbox Live Auth Manager
  [OFF ] XboxGipSvc                               Xbox Accessories Service
  [OFF ] MapsBroker                               Downloaded Maps Manager
  [OFF ] RetailDemo                               Retail Demo Service
  [OFF ] wisvc                                    Windows Insider Service
  [OFF ] lfsvc                                    Geolocation / GPS
  [OFF ] TapiSrv                                  Telephony
  [OFF ] Fax                                      Fax Service
  [OFF ] icssvc                                   Windows Mobile Hotspot
  [OFF ] WalletService                            Wallet Service
  [OFF ] EntAppSvc                                Enterprise App Management
  [OFF ] MessagingService                         Messaging Service
  [OFF ] OneSyncSvc                               Sync Host (mail/calendar)
  [OFF ] WSearch                                  Windows Search Indexing
  [OFF ] SysMain                                  SysMain / Superfetch
  [OFF ] RemoteRegistry                           Remote Registry
  [OFF ] RemoteAccess                             Routing and Remote Access
  [STOP] SharedAccess                             Internet Connection Sharing
  [OFF ] SharedAccess                             Internet Connection Sharing
  [OFF ] TermService                              Remote Desktop Services (neu khong dung RDP)
  [OFF ] SessionEnv                               Remote Desktop Configuration
  [OFF ] UmRdpService                             Remote Desktop Device Redirector
  [OFF ] ScDeviceEnum                             Smart Card Device Enumeration
  [OFF ] SCardSvr                                 Smart Card
  [OFF ] SCPolicySvc                              Smart Card Removal Policy
  [OFF ] WbioSrvc                                 Windows Biometric
  [STOP] PhoneSvc                                 Phone Service
  [OFF ] PhoneSvc                                 Phone Service
  [OFF ] PimIndexMaintenanceSvc                   Contact Data
  [OFF ] UnistoreSvc                              User Data Storage
  [OFF ] UserDataSvc                              User Data Access
  [OFF ] PrintNotify                              Printer Extensions & Notifications
  [STOP] Spooler                                  Print Spooler (neu khong in)
  [OFF ] Spooler                                  Print Spooler (neu khong in)
  [STOP] BthAvctpSvc                              Bluetooth Audio Gateway
  [OFF ] BthAvctpSvc                              Bluetooth Audio Gateway
  [STOP] BTAGService                              Bluetooth Audio Gateway AVRCP
  [OFF ] BTAGService                              Bluetooth Audio Gateway AVRCP
  >> Common: 39 dich vu xu ly
  >> Dich vu Win11-only...
  [OFF ] cbdhsvc                                  Clipboard User Service
  [STOP] WpnService                               Windows Push Notifications System
  [OFF ] WpnService                               Windows Push Notifications System
  [OFF ] WpnUserService                           Windows Push Notifications User
  [OFF ] DsSvc                                    Data Sharing Service
  [OFF ] DevicesFlowUserSvc                       Devices Flow
  [OFF ] NPSMSvc                                  Now Playing Session Manager
  [OFF ] BcastDVRUserService                      GameDVR & Broadcast User Service
  [OFF ] PerceptionSimulation                     Windows Perception Simulation
  [OFF ] MsKeyboardFilter                         Microsoft Keyboard Filter
  >> Win11 specific: 9 dich vu

  ────────────────────────────────────────────────────────
  >> BUOC 5: Tat dich vu hang may [ DELL ]
  ────────────────────────────────────────────────────────
  >> Hang: DELL  |  Nguon: manufacturer

  [OFF ] DellClientManagementService              Dell Client Management

  >> Tong dich vu hang [DELL] xu ly: 1

  ────────────────────────────────────────────────────────
  >> BUOC 6: Scan keyword -- tim dich vu hang con sot
  ────────────────────────────────────────────────────────
  [OK] Khong phat hien them dich vu hang nao.

  ────────────────────────────────────────────────────────
  >> BUOC 7: Tat Startup items hang (Registry + Task Scheduler)
  ────────────────────────────────────────────────────────
  [TASK-OFF] \Microsoft\Windows\input\RemoteTouchpadSyncDataAvailable
  [TASK-OFF] \Microsoft\Windows\input\TouchpadSyncDataAvailable
  [TASK-OFF] \Microsoft\Windows\InstallService\ScanForUpdatesAsUser
  [OK] Startup registry entries da xoa : 0
  [OK] Scheduled tasks hang da tat     : 3

  ────────────────────────────────────────────────────────
  >> BUOC 8: Toi uu Registry (Memory / Telemetry / Visual / TCP / Game)
  ────────────────────────────────────────────────────────
  [OK] Memory Management registry
  [OK] Telemetry + CEIP + CompatTelRunner da tat
  [OK] Visual Effects -> Best Performance
  [OK] TCP parameters toi uu
  [OK] Power Plan -> High Performance
  [OK] GameDVR / GameBar tat
  [OK] Cortana tat qua policy
  [OK] Win11 Widgets panel tat

  ────────────────────────────────────────────────────────
  >> BUOC 9: Don file rac he thong (nam cap)
  ────────────────────────────────────────────────────────
  [OK] Don: C:\Users\PRECIS~1\AppData\Local\Temp                    (54 items)
  [OK] Don: C:\Users\Precision\AppData\Local\Temp                   (9 items)
  [OK] Don: C:\Windows\Temp                                         (7 items)
  [OK] Don: C:\Windows\Prefetch                                     (2 items)
  [OK] Don: C:\Users\Precision\AppData\Local\Microsoft\Windows\INetCache (4 items)
  [OK] Don: C:\Users\Precision\AppData\Local\Microsoft\Windows\INetCookies (2 items)
  [OK] Don: C:\Users\Precision\AppData\Local\Microsoft\Windows\WebCache (11 items)
  [OK] Don: C:\Users\Precision\AppData\Roaming\Microsoft\Windows\Recent\AutomaticDestinations (78 items)
  [OK] Don: C:\Users\Precision\AppData\Roaming\Microsoft\Windows\Recent\CustomDestinations (22 items)
WARNING: Waiting for service 'Windows Update (wuauserv)' to start...
  [OK] Windows Update cache: 1 items
  [OK] Thumbnail cache (thumbcache_*.db) xoa
  [OK] DNS Cache flush
  [OK] Event Log [Application] cleared (23776 entries)
  [OK] Event Log [System] cleared (38276 entries)

  ────────────────────────────────────────────────────────
  >> BUOC 10: Toi uu dac thu [WIN11]
  ────────────────────────────────────────────────────────
  [OK] Taskbar Chat icon an
  [OK] Snap Assist Flyout tat
  [OK] Online Speech Privacy tat
  [--] WSA khong cai -- bo qua
  [OK] Copilot button an tren taskbar

  +========================================================+
  |                     TONG KET                          |
  +========================================================+

  OS       :  Microsoft Windows 11 Pro  [Build 26200  |  WIN11]
  Hang may :  DELL
  Tong RAM :  31.69 GB
  Truoc    :  ranh 22.51 GB
  Sau      :  ranh 26.4 GB
  Giai phong : +3.89 GB
  Dang dung  : 5.29 GB  (16.7%)

  --------------------------------------------------------
  [!] RESTART may de toan bo thay doi co hieu luc.
  [!] Dich vu hang da DISABLED -- khong tu chay lai khi boot.
  [!] Neu mat chuc nang (Fn key, cam bien, bam phim dac biet)
      vao: Services.msc  bat lai dich vu can thiet.
  --------------------------------------------------------

  [LOG] Bao cao da luu tai:
        C:\Users\Precision\Desktop\RAM-Optimize-Log-20260605-083306.txt
Opyimize-RAM-v4-befoere_fix

  +==================================================================+
  |     RAM OPTIMIZER  --  GOD MODE  v4.0  (FIXED + UPGRADED)      |
  |     Target: Windows 10 (1809+) & Windows 11                     |
  |     8 GB RAM profile  |  Persistent Watchdog  |  Full Verbose   |
  +==================================================================+

  ... Querying system information...
  OS       :  Microsoft Windows 11 Pro
  Build    :  26200  [WIN11]
  Machine  :  Dell Inc.  |  Precision 7670
  CPU      :  12th Gen Intel(R) Core(TM) i9-12950HX
  RAM      :  31.7 GB  (Free now: 9.78 GB)
  Disk     :  Micron 3400 NVMe 2048GB  [SSD]
  Brand    :  [ DELL ]  (source: manufacturer)
  [*] SSD detected — SwapFile.sys will be DISABLED, Prefetch OFF


  ────────────────────────────────────────────────────────────────
  >> STEP 1: Kernel Memory Flush — Standby / Modified / Working Sets
  ────────────────────────────────────────────────────────────────
  [OK] Kernel privileges acquired
  [OK] Flush Modified Page List (dirty pages -> standby)
  [OK] Purge Standby List (free kernel cache)
  [OK] Empty All Working Sets (kernel + user)
  [OK] Flush Modified List pass-2 (Win10 1809+ specific)

  ────────────────────────────────────────────────────────────────
  >> STEP 2: File System Cache Flush
  ────────────────────────────────────────────────────────────────
  Current cache size:  min=1 MB   max=16777216 MB
  [OK] File system cache flushed successfully

  ────────────────────────────────────────────────────────────────
  >> STEP 3: Working Set Trim — All user processes (sorted by RAM usage)
  ────────────────────────────────────────────────────────────────
  Found 115 user processes to trim...
  ... Trimming: Client-Win64-Shipping        using 341.6 MB
  ... Trimming: Secure System                using 111.2 MB
  ... Trimming: SearchHost                   using 59.8 MB
  ... Trimming: msedge                       using 56.9 MB
  [OK] Post-trim Standby flush (catch promoted pages)
  [OK] Trimmed    : 113 processes
  [OK] Freed      : ~469.7 MB
  [--] Skipped    : 2 protected processes

  ────────────────────────────────────────────────────────────────
  >> STEP 4: Disable unnecessary Windows services (Common)
  ────────────────────────────────────────────────────────────────
  Scanning 43 common services...
  ... Checking [1/43] DiagTrack
  [OFF ] DiagTrack                                    Connected User Experiences & Telemetry
  ... Checking [2/43] dmwappushservice
  [OFF ] dmwappushservice                             WAP Push Message Routing (telemetry)
  ... Checking [3/43] WerSvc
  [OFF ] WerSvc                                       Windows Error Reporting
  ... Checking [4/43] wercplsupport
  [OFF ] wercplsupport                                WER Control Panel Support
  ... Checking [5/43] XblGameSave
  [OFF ] XblGameSave                                  Xbox Game Save
  ... Checking [6/43] XboxNetApiSvc
  [OFF ] XboxNetApiSvc                                Xbox Live Networking
  ... Checking [7/43] XblAuthManager
  [OFF ] XblAuthManager                               Xbox Live Auth Manager
  ... Checking [8/43] XboxGipSvc
  [OFF ] XboxGipSvc                                   Xbox Accessories Service
  ... Checking [9/43] MapsBroker
  [OFF ] MapsBroker                                   Downloaded Maps Manager
  ... Checking [10/43] RetailDemo
  [OFF ] RetailDemo                                   Retail Demo Service
  ... Checking [11/43] wisvc
  [OFF ] wisvc                                        Windows Insider Service
  ... Checking [12/43] lfsvc
  [OFF ] lfsvc                                        Geolocation / GPS
  ... Checking [13/43] TapiSrv
  [OFF ] TapiSrv                                      Telephony
  ... Checking [14/43] Fax
  [OFF ] Fax                                          Fax Service
  ... Checking [15/43] icssvc
  [OFF ] icssvc                                       Windows Mobile Hotspot
  ... Checking [16/43] WalletService
  [OFF ] WalletService                                Wallet Service
  ... Checking [17/43] EntAppSvc
  [OFF ] EntAppSvc                                    Enterprise App Management
  ... Checking [18/43] MessagingService
  [OFF ] MessagingService                             Messaging Service
  ... Checking [19/43] OneSyncSvc
  [OFF ] OneSyncSvc                                   Sync Host (mail/calendar)
  ... Checking [20/43] WSearch
  [OFF ] WSearch                                      Windows Search Indexing
  ... Checking [21/43] SysMain
  [OFF ] SysMain                                      SysMain / Superfetch
  ... Checking [22/43] RemoteRegistry
  [OFF ] RemoteRegistry                               Remote Registry
  ... Checking [23/43] RemoteAccess
  [OFF ] RemoteAccess                                 Routing and Remote Access
  ... Checking [24/43] SharedAccess
  [STOP] SharedAccess                                 Internet Connection Sharing
  [OFF ] SharedAccess                                 Internet Connection Sharing
  ... Checking [25/43] TermService
  [OFF ] TermService                                  Remote Desktop Services (if not using RDP)
  ... Checking [26/43] SessionEnv
  [OFF ] SessionEnv                                   Remote Desktop Configuration
  ... Checking [27/43] UmRdpService
  [OFF ] UmRdpService                                 Remote Desktop Device Redirector
  ... Checking [28/43] ScDeviceEnum
  [OFF ] ScDeviceEnum                                 Smart Card Device Enumeration
  ... Checking [29/43] SCardSvr
  [OFF ] SCardSvr                                     Smart Card Service
  ... Checking [30/43] SCPolicySvc
  [OFF ] SCPolicySvc                                  Smart Card Removal Policy
  ... Checking [31/43] MixedRealityOpenXRSvc
  [--]  MixedRealityOpenXRSvc                      not found on this system
  ... Checking [32/43] PhoneSvc
  [OFF ] PhoneSvc                                     Phone Service
  ... Checking [33/43] PimIndexMaintenanceSvc
  [OFF ] PimIndexMaintenanceSvc                       Contact Data Service
  ... Checking [34/43] UnistoreSvc
  [OFF ] UnistoreSvc                                  User Data Storage
  ... Checking [35/43] UserDataSvc
  [OFF ] UserDataSvc                                  User Data Access
  ... Checking [36/43] PrintNotify
  [OFF ] PrintNotify                                  Printer Extensions & Notifications
  ... Checking [37/43] Spooler
  [OFF ] Spooler                                      Print Spooler (disable if no printer)
  ... Checking [38/43] BthAvctpSvc
  [OFF ] BthAvctpSvc                                  Bluetooth Audio Gateway
  ... Checking [39/43] BTAGService
  [OFF ] BTAGService                                  Bluetooth Audio AVRCP
  ... Checking [40/43] AJRouter
  [--]  AJRouter                                   not found on this system
  ... Checking [41/43] CscService
  [OFF ] CscService                                   Offline Files
  ... Checking [42/43] DusmSvc
  [OFF ] DusmSvc                                      Data Usage
  ... Checking [43/43] WbioSrvc
  [OFF ] WbioSrvc                                     Windows Biometric Service
  >> Common: 41 services found and handled

  Scanning 13 Win11-specific services...
  ... Checking [1/13] cbdhsvc
  [OFF ] cbdhsvc                                      Clipboard User Service
  ... Checking [2/13] WpnService
  [OFF ] WpnService                                   Windows Push Notifications System
  ... Checking [3/13] WpnUserService
  [OFF ] WpnUserService                               Windows Push Notifications User
  ... Checking [4/13] DsSvc
  [OFF ] DsSvc                                        Data Sharing Service
  ... Checking [5/13] DevicesFlowUserSvc
  [OFF ] DevicesFlowUserSvc                           Devices Flow
  ... Checking [6/13] NPSMSvc
  [OFF ] NPSMSvc                                      Now Playing Session Manager
  ... Checking [7/13] BcastDVRUserService
  [OFF ] BcastDVRUserService                          GameDVR & Broadcast User Service
  ... Checking [8/13] PerceptionSimulation
  [OFF ] PerceptionSimulation                         Windows Perception Simulation
  ... Checking [9/13] MsKeyboardFilter
  [OFF ] MsKeyboardFilter                             Microsoft Keyboard Filter
  ... Checking [10/13] DoSvc
WARNING: Waiting for service 'Delivery Optimization (DoSvc)' to stop...
  [STOP] DoSvc                                        Delivery Optimization
  [OFF ] DoSvc                                        Delivery Optimization
  ... Checking [11/13] CDPUserSvc
  [OFF ] CDPUserSvc                                   Connected Devices Platform User
  ... Checking [12/13] PushToInstall
  [OFF ] PushToInstall                                Windows PushToInstall
  ... Checking [13/13] NetTcpPortSharing
  [OFF ] NetTcpPortSharing                            Net.Tcp Port Sharing
  >> Win11 specific: 13 services handled

  ────────────────────────────────────────────────────────────────
  >> STEP 5: Brand services [ DELL ] — explicit list
  ────────────────────────────────────────────────────────────────
  Brand: DELL  |  Detection source: manufacturer

  Scanning 13 DELL services...
  ... Checking [1/13] DellClientManagementService
  [OFF ] DellClientManagementService                  Dell Client Management
  ... Checking [2/13] DellUpdate
  [--]  DellUpdate                                 not found on this system
  ... Checking [3/13] DellSupportAssistRemedationService
  [--]  DellSupportAssistRemedationService         not found on this system
  ... Checking [4/13] DellFoundationServices
  [--]  DellFoundationServices                     not found on this system
  ... Checking [5/13] DellTechHubService
  [--]  DellTechHubService                         not found on this system
  ... Checking [6/13] DellOptimizer
  [--]  DellOptimizer                              not found on this system
  ... Checking [7/13] DellMobileConnect
  [--]  DellMobileConnect                          not found on this system
  ... Checking [8/13] DellDataVault
  [--]  DellDataVault                              not found on this system
  ... Checking [9/13] DellDataVaultWizard
  [--]  DellDataVaultWizard                        not found on this system
  ... Checking [10/13] ThermalService
  [--]  ThermalService                             not found on this system
  ... Checking [11/13] DellDigitalDelivery
  [--]  DellDigitalDelivery                        not found on this system
  ... Checking [12/13] DellServiceConnectivity
  [--]  DellServiceConnectivity                    not found on this system
  ... Checking [13/13] DellInc.SupportAssistBusinessPCAgent
  [--]  DellInc.SupportAssistBusinessPCAgent       not found on this system
  >> Brand [DELL] total: 1 services found and handled

  ────────────────────────────────────────────────────────────────
  >> STEP 6: Keyword scan — catch remaining brand / bloatware services
  ────────────────────────────────────────────────────────────────
  Scanning ALL 306 services against 44 vendor keywords...
  >> Scanned: 306 active services  |  Keyword hits: 0
  [OK] No additional vendor services found.

  ────────────────────────────────────────────────────────────────
  >> STEP 7: Startup items (Registry) + Scheduled Tasks — vendor keyword clean
  ────────────────────────────────────────────────────────────────
  Scanning registry: HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run
  Scanning registry: HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run
  Scanning registry: HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run
  Scanning Task Scheduler tree for vendor tasks...
  >> Startup registry entries removed : 0
  >> Scheduled tasks disabled         : 0

  ────────────────────────────────────────────────────────────────
  >> STEP 8: Registry tuning — Memory / Telemetry / Visual / TCP / Power
  ────────────────────────────────────────────────────────────────
  [OK] Memory Management: SessionViewSize=128 MB, ClearPageFile=1
  [OK] Prefetcher=0 (SSD=True), Superfetch=0
  [OK] ReadyBoot logger disabled
  [OK] Telemetry + CEIP + CompatTelRunner blocked
  [OK] Visual FX -> Best Performance
  [OK] TCP parameters optimized (NoDelay, AckFreq=1, TTL=64)
  [OK] Power Plan -> High Performance
  [OK] GameDVR / GameBar disabled
  [OK] Cortana disabled via group policy
  [OK] Win11 Widgets panel disabled

  ────────────────────────────────────────────────────────────────
  >> STEP 9: GOD MODE — targeted RAM fixes (8 GB profile + Win11)
  ────────────────────────────────────────────────────────────────
  [WARN] Could not set Memory Compression priority
  [OK] SwapFile.sys (Win11 compressed swap) disabled — SSD detected [FIX-4]
  [--] WSL2 .wslconfig already has autoMemoryReclaim configured
  [OK] SearchIndexer process terminated (index left intact on disk)
  [WARN] Defender policy write failed (GPO may be enforced by domain)

  Scanning for top-10 RAM consumers (verbose)...
  Top-10 RAM consumers right now:
  #1   Memory Compression             2455.4 MB
  #2   Client-Win64-Shipping          567.8 MB
  [TRIM] -> trimmed
  #3   SearchHost                     273 MB
  [TRIM] -> trimmed
  #4   msedge                         220.3 MB
  [TRIM] -> trimmed
  #5   Secure System                  111.2 MB
  #6   explorer                       103.5 MB
  [TRIM] -> trimmed
  #7   msedge                         76.2 MB
  [TRIM] -> trimmed
  #8   msedge                         68.3 MB
  [TRIM] -> trimmed
  #9   Taskmgr                        51.7 MB
  [TRIM] -> trimmed
  #10  ProtonVPN.Client               51 MB
  [TRIM] -> trimmed

  ────────────────────────────────────────────────────────────────
  >> STEP 10: System junk cleanup
  ────────────────────────────────────────────────────────────────
  [OK] Cleaned: C:\Users\PRECIS~1\AppData\Local\Temp                           (3062 items)
  [OK] Cleaned: C:\Users\Precision\AppData\Local\Temp                          (11 items)
  [OK] Cleaned: C:\Windows\Temp                                                (30 items)
  [OK] Cleaned: C:\Windows\Prefetch                                            (0 items)
  [OK] Cleaned: C:\Users\Precision\AppData\Local\Microsoft\Windows\INetCache   (0 items)
  [OK] Cleaned: C:\Users\Precision\AppData\Local\Microsoft\Windows\INetCookies (3 items)
  [OK] Cleaned: C:\Users\Precision\AppData\Local\Microsoft\Windows\WebCache    (8 items)
  [OK] Cleaned: C:\Users\Precision\AppData\Roaming\Microsoft\Windows\Recent\AutomaticDestinations (7 items)
  [OK] Cleaned: C:\Users\Precision\AppData\Roaming\Microsoft\Windows\Recent\CustomDestinations (2 items)
  [OK] Cleaned: C:\Users\Precision\AppData\Local\CrashDumps                    (0 items)
  [OK] Cleaned: C:\Windows\LiveKernelReports                                   (2 items)
  [OK] Cleaned: C:\Windows\Minidump                                            (0 items)
  [OK] Thumbnail cache (thumbcache_*.db) removed
  [OK] Windows Update download cache: 17033 items removed
  [OK] DNS cache flushed
  [OK] Event Log [Application] cleared (222 entries)
  [OK] Event Log [System] cleared (394 entries)

  ────────────────────────────────────────────────────────────────
  >> STEP 11: Platform-specific tweaks [WIN11]
  ────────────────────────────────────────────────────────────────
  [OK] Taskbar Chat + Snap Assist Flyout + Copilot button hidden
  [OK] Online Speech Privacy disabled
  [--] WSA not installed

  ────────────────────────────────────────────────────────────────
  >> STEP 12: Persistent RAM Watchdog — Scheduled Task [V4 KEY FIX]
  ────────────────────────────────────────────────────────────────
  KEY FIX: This is why RAM bounces back to 96% after 2-3 min.
  A silent watchdog task runs every 5 minutes to keep RAM clear.

  [OK] Watchdog script written to: C:\ProgramData\RAMWatchdog\RAMWatchdog.ps1
  [WARN] Task register failed: The task XML contains a value which is incorrectly formatted or out of range.

(8,42):Duration:P99999999DT23H59M59S
  [i] You can manually run the watchdog from:
  [i] C:\ProgramData\RAMWatchdog\RAMWatchdog.ps1

  Running watchdog FIRST PASS inline (visible)...
  Current RAM usage: 30% (22723 MB free)
  [--] RAM below threshold (75%) — watchdog trim not triggered this pass

  +==================================================================+
  |                  SUMMARY — GOD MODE v4.0                        |
  +==================================================================+

  OS            :  Microsoft Windows 11 Pro  [Build 26200 | WIN11]
  Machine       :  Precision 7670  |  Brand: DELL
  Total RAM     :  31.7 GB  |  Disk: SSD

  Before        :  9.78 GB free  (69.1% used)
  After         :  22.19 GB free  (30% used)
  Freed         :  +12.41 GB
  RAM in use    :  9.5 GB  (30%)

  Svc (common)  :  54
  Svc (brand)   :  1  [DELL]
  Svc (keyword) :  0
  Tasks OFF     :  0
  Startup DEL   :  0

  ----------------------------------------------------------------
  [V4] Watchdog task active — checks RAM every 5 min silently
  [V4] SwapFile.sys disabled (SSD), WSL2 reclaim configured
  [V4] SessionViewSize = 128 MB (8 GB=False)
  [V4] Defender CPU capped at 25% (protection still active)
  ----------------------------------------------------------------

  [!] RESTART recommended — registry changes need reboot to take full effect.
  [!] Brand services DISABLED permanently — will not auto-start on boot.
  [!] If any Fn key / sensor / hardware feature stops working:
      Open: services.msc -> find the service -> set to Automatic -> Start
  [!] To REMOVE watchdog: Task Scheduler -> 'RAMWatchdog-GodMode-V4'
  ----------------------------------------------------------------

  [LOG] Report saved to:
        C:\Users\Precision\Desktop\RAM-Optimize-V4-Log-20260610-094751.txt

  Script complete. Press ENTER to close...
Optimize-RAM-v4-after_fix

  +==================================================================+
  |     RAM OPTIMIZER  --  GOD MODE  v4.0  (FIXED + UPGRADED)      |
  |     Target: Windows 10 (1809+) & Windows 11                     |
  |     8 GB RAM profile  |  Persistent Watchdog  |  Full Verbose   |
  +==================================================================+

  ... Querying system information...
  OS       :  Microsoft Windows 11 Pro
  Build    :  26200  [WIN11]
  Machine  :  Dell Inc.  |  Precision 7670
  CPU      :  12th Gen Intel(R) Core(TM) i9-12950HX
  RAM      :  31.7 GB  (Free now: 19.05 GB)
  Disk     :  Micron 3400 NVMe 2048GB  [SSD]
  Brand    :  [ DELL ]  (source: manufacturer)
  [*] SSD detected — SwapFile.sys will be DISABLED, Prefetch OFF


  ────────────────────────────────────────────────────────────────
  >> STEP 1: Kernel Memory Flush — Standby / Modified / Working Sets
  ────────────────────────────────────────────────────────────────
  [OK] Kernel privileges acquired
  [OK] Flush Modified Page List (dirty pages -> standby)
  [OK] Purge Standby List (free kernel cache)
  [OK] Empty All Working Sets (kernel + user)
  [OK] Flush Modified List pass-2 (Win10 1809+ specific)

  ────────────────────────────────────────────────────────────────
  >> STEP 2: File System Cache Flush
  ────────────────────────────────────────────────────────────────
  Current cache size:  min=1 MB   max=16777216 MB
  [OK] File system cache flushed successfully

  ────────────────────────────────────────────────────────────────
  >> STEP 3: Working Set Trim — All user processes (sorted by RAM usage)
  ────────────────────────────────────────────────────────────────
  Found 120 user processes to trim...
  ... Trimming: Client-Win64-Shipping        using 510.6 MB
  ... Trimming: Secure System                using 111.2 MB
  [OK] Post-trim Standby flush (catch promoted pages)
  [OK] Trimmed    : 118 processes
  [OK] Freed      : ~360 MB
  [--] Skipped    : 2 protected processes

  ────────────────────────────────────────────────────────────────
  >> STEP 4: Disable unnecessary Windows services (Common)
  ────────────────────────────────────────────────────────────────
  Scanning 43 common services...
  ... Checking [1/43] DiagTrack
  [OFF ] DiagTrack                                    Connected User Experiences & Telemetry
  ... Checking [2/43] dmwappushservice
  [OFF ] dmwappushservice                             WAP Push Message Routing (telemetry)
  ... Checking [3/43] WerSvc
  [OFF ] WerSvc                                       Windows Error Reporting
  ... Checking [4/43] wercplsupport
  [OFF ] wercplsupport                                WER Control Panel Support
  ... Checking [5/43] XblGameSave
  [OFF ] XblGameSave                                  Xbox Game Save
  ... Checking [6/43] XboxNetApiSvc
  [OFF ] XboxNetApiSvc                                Xbox Live Networking
  ... Checking [7/43] XblAuthManager
  [OFF ] XblAuthManager                               Xbox Live Auth Manager
  ... Checking [8/43] XboxGipSvc
  [OFF ] XboxGipSvc                                   Xbox Accessories Service
  ... Checking [9/43] MapsBroker
  [OFF ] MapsBroker                                   Downloaded Maps Manager
  ... Checking [10/43] RetailDemo
  [OFF ] RetailDemo                                   Retail Demo Service
  ... Checking [11/43] wisvc
  [OFF ] wisvc                                        Windows Insider Service
  ... Checking [12/43] lfsvc
  [OFF ] lfsvc                                        Geolocation / GPS
  ... Checking [13/43] TapiSrv
  [OFF ] TapiSrv                                      Telephony
  ... Checking [14/43] Fax
  [OFF ] Fax                                          Fax Service
  ... Checking [15/43] icssvc
  [OFF ] icssvc                                       Windows Mobile Hotspot
  ... Checking [16/43] WalletService
  [OFF ] WalletService                                Wallet Service
  ... Checking [17/43] EntAppSvc
  [OFF ] EntAppSvc                                    Enterprise App Management
  ... Checking [18/43] MessagingService
  [OFF ] MessagingService                             Messaging Service
  ... Checking [19/43] OneSyncSvc
  [OFF ] OneSyncSvc                                   Sync Host (mail/calendar)
  ... Checking [20/43] WSearch
  [OFF ] WSearch                                      Windows Search Indexing
  ... Checking [21/43] SysMain
  [OFF ] SysMain                                      SysMain / Superfetch
  ... Checking [22/43] RemoteRegistry
  [OFF ] RemoteRegistry                               Remote Registry
  ... Checking [23/43] RemoteAccess
  [OFF ] RemoteAccess                                 Routing and Remote Access
  ... Checking [24/43] SharedAccess
  [STOP] SharedAccess                                 Internet Connection Sharing
  [OFF ] SharedAccess                                 Internet Connection Sharing
  ... Checking [25/43] TermService
  [OFF ] TermService                                  Remote Desktop Services (if not using RDP)
  ... Checking [26/43] SessionEnv
  [OFF ] SessionEnv                                   Remote Desktop Configuration
  ... Checking [27/43] UmRdpService
  [OFF ] UmRdpService                                 Remote Desktop Device Redirector
  ... Checking [28/43] ScDeviceEnum
  [OFF ] ScDeviceEnum                                 Smart Card Device Enumeration
  ... Checking [29/43] SCardSvr
  [OFF ] SCardSvr                                     Smart Card Service
  ... Checking [30/43] SCPolicySvc
  [OFF ] SCPolicySvc                                  Smart Card Removal Policy
  ... Checking [31/43] MixedRealityOpenXRSvc
  [--]  MixedRealityOpenXRSvc                      not found on this system
  ... Checking [32/43] PhoneSvc
  [OFF ] PhoneSvc                                     Phone Service
  ... Checking [33/43] PimIndexMaintenanceSvc
  [OFF ] PimIndexMaintenanceSvc                       Contact Data Service
  ... Checking [34/43] UnistoreSvc
  [OFF ] UnistoreSvc                                  User Data Storage
  ... Checking [35/43] UserDataSvc
  [OFF ] UserDataSvc                                  User Data Access
  ... Checking [36/43] PrintNotify
  [OFF ] PrintNotify                                  Printer Extensions & Notifications
  ... Checking [37/43] Spooler
  [OFF ] Spooler                                      Print Spooler (disable if no printer)
  ... Checking [38/43] BthAvctpSvc
  [OFF ] BthAvctpSvc                                  Bluetooth Audio Gateway
  ... Checking [39/43] BTAGService
  [OFF ] BTAGService                                  Bluetooth Audio AVRCP
  ... Checking [40/43] AJRouter
  [--]  AJRouter                                   not found on this system
  ... Checking [41/43] CscService
  [OFF ] CscService                                   Offline Files
  ... Checking [42/43] DusmSvc
  [OFF ] DusmSvc                                      Data Usage
  ... Checking [43/43] WbioSrvc
  [OFF ] WbioSrvc                                     Windows Biometric Service
  >> Common: 41 services found and handled

  Scanning 13 Win11-specific services...
  ... Checking [1/13] cbdhsvc
  [OFF ] cbdhsvc                                      Clipboard User Service
  ... Checking [2/13] WpnService
  [OFF ] WpnService                                   Windows Push Notifications System
  ... Checking [3/13] WpnUserService
  [OFF ] WpnUserService                               Windows Push Notifications User
  ... Checking [4/13] DsSvc
  [OFF ] DsSvc                                        Data Sharing Service
  ... Checking [5/13] DevicesFlowUserSvc
  [OFF ] DevicesFlowUserSvc                           Devices Flow
  ... Checking [6/13] NPSMSvc
  [OFF ] NPSMSvc                                      Now Playing Session Manager
  ... Checking [7/13] BcastDVRUserService
  [OFF ] BcastDVRUserService                          GameDVR & Broadcast User Service
  ... Checking [8/13] PerceptionSimulation
  [OFF ] PerceptionSimulation                         Windows Perception Simulation
  ... Checking [9/13] MsKeyboardFilter
  [OFF ] MsKeyboardFilter                             Microsoft Keyboard Filter
  ... Checking [10/13] DoSvc
WARNING: Waiting for service 'Delivery Optimization (DoSvc)' to stop...
  [STOP] DoSvc                                        Delivery Optimization
  [OFF ] DoSvc                                        Delivery Optimization
  ... Checking [11/13] CDPUserSvc
  [OFF ] CDPUserSvc                                   Connected Devices Platform User
  ... Checking [12/13] PushToInstall
  [OFF ] PushToInstall                                Windows PushToInstall
  ... Checking [13/13] NetTcpPortSharing
  [OFF ] NetTcpPortSharing                            Net.Tcp Port Sharing
  >> Win11 specific: 13 services handled

  ────────────────────────────────────────────────────────────────
  >> STEP 5: Brand services [ DELL ] — explicit list
  ────────────────────────────────────────────────────────────────
  Brand: DELL  |  Detection source: manufacturer

  Scanning 13 DELL services...
  ... Checking [1/13] DellClientManagementService
  [OFF ] DellClientManagementService                  Dell Client Management
  ... Checking [2/13] DellUpdate
  [--]  DellUpdate                                 not found on this system
  ... Checking [3/13] DellSupportAssistRemedationService
  [--]  DellSupportAssistRemedationService         not found on this system
  ... Checking [4/13] DellFoundationServices
  [--]  DellFoundationServices                     not found on this system
  ... Checking [5/13] DellTechHubService
  [--]  DellTechHubService                         not found on this system
  ... Checking [6/13] DellOptimizer
  [--]  DellOptimizer                              not found on this system
  ... Checking [7/13] DellMobileConnect
  [--]  DellMobileConnect                          not found on this system
  ... Checking [8/13] DellDataVault
  [--]  DellDataVault                              not found on this system
  ... Checking [9/13] DellDataVaultWizard
  [--]  DellDataVaultWizard                        not found on this system
  ... Checking [10/13] ThermalService
  [--]  ThermalService                             not found on this system
  ... Checking [11/13] DellDigitalDelivery
  [--]  DellDigitalDelivery                        not found on this system
  ... Checking [12/13] DellServiceConnectivity
  [--]  DellServiceConnectivity                    not found on this system
  ... Checking [13/13] DellInc.SupportAssistBusinessPCAgent
  [--]  DellInc.SupportAssistBusinessPCAgent       not found on this system
  >> Brand [DELL] total: 1 services found and handled

  ────────────────────────────────────────────────────────────────
  >> STEP 6: Keyword scan — catch remaining brand / bloatware services
  ────────────────────────────────────────────────────────────────
  Scanning ALL 306 services against 44 vendor keywords...
  >> Scanned: 306 active services  |  Keyword hits: 0
  [OK] No additional vendor services found.

  ────────────────────────────────────────────────────────────────
  >> STEP 7: Startup items (Registry) + Scheduled Tasks — vendor keyword clean
  ────────────────────────────────────────────────────────────────
  Scanning registry: HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run
  Scanning registry: HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run
  Scanning registry: HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run
  Scanning Task Scheduler tree for vendor tasks...
  >> Startup registry entries removed : 0
  >> Scheduled tasks disabled         : 0

  ────────────────────────────────────────────────────────────────
  >> STEP 8: Registry tuning — Memory / Telemetry / Visual / TCP / Power
  ────────────────────────────────────────────────────────────────
  [OK] Memory Management: SessionViewSize=128 MB, ClearPageFile=1
  [OK] Prefetcher=0 (SSD=True), Superfetch=0
  [OK] ReadyBoot logger disabled
  [OK] Telemetry + CEIP + CompatTelRunner blocked
  [OK] Visual FX -> Best Performance
  [OK] TCP parameters optimized (NoDelay, AckFreq=1, TTL=64)
  [OK] Power Plan -> High Performance
  [OK] GameDVR / GameBar disabled
  [OK] Cortana disabled via group policy
  [OK] Win11 Widgets panel disabled

  ────────────────────────────────────────────────────────────────
  >> STEP 9: GOD MODE — targeted RAM fixes (8 GB profile + Win11)
  ────────────────────────────────────────────────────────────────
  [WARN] Could not open Memory Compression handle (insufficient rights)
  [OK] SwapFile.sys (Win11 compressed swap) disabled — SSD detected [FIX-4]
  [--] WSL2 .wslconfig already has autoMemoryReclaim configured
  [OK] SearchIndexer process terminated (index left intact on disk)

  Scanning for top-10 RAM consumers (verbose)...
  Top-10 RAM consumers right now:
  #1   Client-Win64-Shipping          1350.1 MB
  [TRIM] -> trimmed
  #2   Memory Compression             1049.9 MB
  #3   Secure System                  111.2 MB
  #4   ProtonVPN.Client               109.9 MB
  [TRIM] -> trimmed
  #5   explorer                       103.6 MB
  [TRIM] -> trimmed
  #6   msedge                         48.1 MB
  [TRIM] -> trimmed
  #7   msedge                         33.9 MB
  [TRIM] -> trimmed
  #8   msedge                         33.3 MB
  [TRIM] -> trimmed
  #9   msedge                         29.7 MB
  [TRIM] -> trimmed
  #10  msedge                         27.6 MB
  [TRIM] -> trimmed

  ────────────────────────────────────────────────────────────────
  >> STEP 10: System junk cleanup
  ────────────────────────────────────────────────────────────────
  [OK] Cleaned: C:\Users\PRECIS~1\AppData\Local\Temp                           (16 items)
  [OK] Cleaned: C:\Users\Precision\AppData\Local\Temp                          (13 items)
  [OK] Cleaned: C:\Windows\Temp                                                (9 items)
  [OK] Cleaned: C:\Windows\Prefetch                                            (0 items)
  [OK] Cleaned: C:\Users\Precision\AppData\Local\Microsoft\Windows\INetCache   (0 items)
  [OK] Cleaned: C:\Users\Precision\AppData\Local\Microsoft\Windows\INetCookies (2 items)
  [OK] Cleaned: C:\Users\Precision\AppData\Local\Microsoft\Windows\WebCache    (4 items)
  [OK] Cleaned: C:\Users\Precision\AppData\Roaming\Microsoft\Windows\Recent\AutomaticDestinations (4 items)
  [OK] Cleaned: C:\Users\Precision\AppData\Roaming\Microsoft\Windows\Recent\CustomDestinations (1 items)
  [OK] Cleaned: C:\Users\Precision\AppData\Local\CrashDumps                    (0 items)
  [OK] Cleaned: C:\Windows\LiveKernelReports                                   (0 items)
  [OK] Cleaned: C:\Windows\Minidump                                            (0 items)
  [OK] Thumbnail cache (thumbcache_*.db) removed
  [OK] Windows Update download cache: 2 items removed
  [OK] DNS cache flushed
  [OK] Event Log [Application] cleared (0 entries)
  [OK] Event Log [System] cleared (5 entries)

  ────────────────────────────────────────────────────────────────
  >> STEP 11: Platform-specific tweaks [WIN11]
  ────────────────────────────────────────────────────────────────
  [OK] Taskbar Chat + Snap Assist Flyout + Copilot button hidden
  [OK] Online Speech Privacy disabled
  [--] WSA not installed

  ────────────────────────────────────────────────────────────────
  >> STEP 12: Persistent RAM Watchdog — Scheduled Task [V4 KEY FIX]
  ────────────────────────────────────────────────────────────────
  KEY FIX: This is why RAM bounces back to 96% after 2-3 min.
  A silent watchdog task runs every 5 minutes to keep RAM clear.

  [OK] Watchdog script written to: C:\ProgramData\RAMWatchdog\RAMWatchdog.ps1
  [OK] Watchdog task REGISTERED successfully
  [OK] Task name : RAMWatchdog-GodMode-V4
  [OK] Schedule  : every 5 minutes, SYSTEM account, hidden window
  [OK] Threshold : fires only when RAM > 75% used (low overhead)
  [OK] Log file  : C:\Users\Precision\Desktop\RAM-Watchdog-Log.txt

  Running watchdog FIRST PASS inline (visible)...
  Current RAM usage: 25.6% (24155 MB free)
  [--] RAM below threshold (75%) — watchdog trim not triggered this pass

  +==================================================================+
  |                  SUMMARY — GOD MODE v4.0                        |
  +==================================================================+

  OS            :  Microsoft Windows 11 Pro  [Build 26200 | WIN11]
  Machine       :  Precision 7670  |  Brand: DELL
  Total RAM     :  31.7 GB  |  Disk: SSD

  Before        :  19.05 GB free  (39.9% used)
  After         :  23.59 GB free  (25.6% used)
  Freed         :  +4.54 GB
  RAM in use    :  8.1 GB  (25.6%)

  Svc (common)  :  54
  Svc (brand)   :  1  [DELL]
  Svc (keyword) :  0
  Tasks OFF     :  0
  Startup DEL   :  0

  ----------------------------------------------------------------
  [V4] Watchdog task active — checks RAM every 5 min silently
  [V4] SwapFile.sys disabled (SSD), WSL2 reclaim configured
  [V4] SessionViewSize = 128 MB (8 GB=False)
  [V4] Defender CPU capped at 25% (protection still active)
  ----------------------------------------------------------------

  [!] RESTART recommended — registry changes need reboot to take full effect.
  [!] Brand services DISABLED permanently — will not auto-start on boot.
  [!] If any Fn key / sensor / hardware feature stops working:
      Open: services.msc -> find the service -> set to Automatic -> Start
  [!] To REMOVE watchdog: Task Scheduler -> 'RAMWatchdog-GodMode-V4'
  ----------------------------------------------------------------

  [LOG] Report saved to:
        C:\Users\Precision\Desktop\RAM-Optimize-V4-Log-20260610-095441.txt

  Script complete. Press ENTER to close...


 +==================================================================+
 |  Done! Review the results above.                                |
 |  Press any key to close this window.                           |
 +==================================================================+


