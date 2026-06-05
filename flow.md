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
