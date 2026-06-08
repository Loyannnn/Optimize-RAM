# 🧠 RAM Optimizer — GOD MODE v4.0

> **Persistent, kernel-level RAM optimization for Windows 11 (8 GB) & Windows 10**  
> Fixes the root cause of RAM bouncing back after 2-3 minutes — not just a one-shot flush.

---

## ⚡ The Problem with Other RAM Optimizers

Most RAM optimizers (including v1/v2/v3 of this tool) do a one-shot flush and call it done.  
RAM drops from 96% → 80%, then **climbs right back in 2-3 minutes**.

**Why?** Because they don't fix the actual cause:

- Windows **Memory Compression** process refills the Standby List automatically
- **SwapFile.sys** (Win11 compressed swap) continuously re-pressures RAM on 8 GB machines
- **SessionViewSize = 48 MB** (common default) causes kernel pool pressure on 8 GB → forces RAM up
- **SearchIndexer** wakes back up and grabs memory after being stopped
- No persistent mechanism — Windows just reloads everything

**v4 solves all of this.**

---

## ✅ What v4 Does Differently

| Fix | Problem | Solution |
|-----|---------|----------|
| `FIX-1` | RAM bounces back every 2-3 min | **Persistent watchdog task** — runs every 5 min as SYSTEM |
| `FIX-2` | Memory Compression refills Standby | Process priority → **IDLE** (throttled) |
| `FIX-3` | SessionViewSize too small for 8 GB | Corrected to **256 MB** (was 48 MB) |
| `FIX-4` | SwapFile.sys continuous RAM pressure | **Disabled via policy** on SSD |
| `FIX-6` | MsMpEng (Defender) RAM/CPU spikes | CPU capped **25%**, priority → BelowNormal |
| `FIX-7` | SearchIndexer wakes up after flush | **Killed + Disabled** permanently |
| `FIX-8` | WSL2 vmmem holds RAM indefinitely | `.wslconfig` → `autoMemoryReclaim=gradual` |
| `FIX-9` | ReadyBoost re-caches pages | ReadyBoot logger **disabled** |
| `FIX-10` | Stale pagefile RAM pressure | `ClearPageFileAtShutdown = 1` |
| `FIX-12` | Top RAM hogs not targeted | Runtime top-10 trim with `SetProcessWorkingSetSizeEx` |

---

## 🚀 How to Use

### Requirements
- Windows 10 (Build 1809+) or Windows 11
- PowerShell 5.1+
- **Administrator privileges** (mandatory)

### Steps

1. Download both files into the **same folder**:
   - `Optimize-RAM-v4-GodMode.bat`
   - `Optimize-RAM-v4.ps1`

2. **Right-click** `Optimize-RAM-v4-GodMode.bat`

3. Select **"Run as administrator"**

4. Wait for all 12 steps to complete

5. **Restart recommended** — registry changes take full effect after reboot

---

## 📋 What Gets Optimized (12 Steps)

```
[Step 1]  Kernel memory flush — Standby / Modified / Working Sets
[Step 2]  File system cache flush
[Step 3]  Working Set trim — all user processes (+ second pass after trim)
[Step 4]  Disable unnecessary Windows services (common + Win10/11 specific)
[Step 5]  Disable brand-specific services (Dell / HP / Lenovo / ASUS / MSI / Acer / ...)
[Step 6]  Keyword scan — catch any leftover brand services
[Step 7]  Remove vendor startup items + disable Scheduled Tasks
[Step 8]  Registry tuning — Memory / Telemetry / Visual FX / TCP / GameDVR
[Step 9]  8 GB Win11 targeted fixes (Memory Compression, SwapFile, WSL2, Defender, SearchIndexer)
[Step 10] System junk cleanup — Temp / Cache / Logs / DNS / Minidumps
[Step 11] Platform-specific tweaks (Win11: Widgets, Copilot, Snap / Win10: Timeline)
[Step 12] Install persistent RAM Watchdog as Scheduled Task (SYSTEM account, every 5 min)
```

---

## 🔁 The Watchdog Task

The most important feature in v4. After setup:

- Runs **silently every 5 minutes** as SYSTEM
- **No window, no tray icon, zero UI**
- Only triggers a flush when RAM usage exceeds **75%** (low overhead when RAM is fine)
- Logs each trigger to `Desktop\RAM-Watchdog-Log.txt`
- Survives restarts — registered as a permanent Scheduled Task

**To remove the watchdog:**  
Open Task Scheduler → find `RAMWatchdog-GodMode-V4` → Delete

---

## 🖥️ Auto-Detected Machine Brands

The tool automatically identifies your machine and disables brand-specific bloatware:

`Dell` · `HP` · `Lenovo` · `ASUS` · `MSI` · `Acer` · `Samsung` · `Microsoft Surface`  
`Razer` · `Gigabyte` · `Toshiba` · `Huawei` · `LG` · `Panasonic` · `Fujitsu` · `VAIO`

Detection uses both `Win32_ComputerSystem` (manufacturer string) and `Win32_BIOS` as fallback.

---

## 📊 Expected Results

| Scenario | Before | After v4 |
|----------|--------|----------|
| Windows 11 idle (8 GB) | 85-96% | ~55-65% |
| 2 Chrome tabs open | 88-96% | ~65-72% |
| Gaming (light titles) | 90-96% | ~55-65% |
| RAM after 10 minutes | Climbs back to 90%+ | Stays flat (watchdog holds it) |

> Results vary by installed apps and background processes.  
> The key improvement is **stability over time**, not just the initial drop.

---

## ⚠️ Important Notes

**Services that get disabled** are non-essential Windows features (Xbox, telemetry, remote desktop, fax, etc.) and brand bloatware. Core system services are never touched.

**If something breaks** after running (Fn keys, fingerprint reader, special buttons):
```
Win + R → services.msc → find the service → set Startup Type to Automatic
```

**Defender is throttled, not disabled.** Real-time protection stays active — only CPU usage is capped at 25% to prevent scan spikes from consuming RAM.

**Pagefile is NOT deleted.** On 8 GB systems, pagefile is set to fixed size (1 GB min / 4 GB max) to eliminate the overhead of Windows dynamically resizing it.

---

## 🔧 Advanced: Manual Watchdog Trigger

To manually flush RAM at any time (e.g. right before launching a heavy game):

```powershell
# Run as Administrator
& "C:\ProgramData\RAMWatchdog\RAMWatchdog.ps1"
```

---

## 📁 File Structure

```
RAM-Optimizer-V4/
├── Optimize-RAM-v4-GodMode.bat   ← Launch this (Run as Administrator)
├── Optimize-RAM-v4.ps1           ← Main optimization script
└── README.md                     ← This file

After running, auto-created:
C:\ProgramData\RAMWatchdog\
└── RAMWatchdog.ps1               ← Watchdog script (runs every 5 min)

Desktop\
├── RAM-Optimize-V4-Log-[date].txt  ← Full optimization report
└── RAM-Watchdog-Log.txt            ← Watchdog trigger history
```

---

## 🔬 Technical Details

**Kernel-level calls used:**
- `NtSetSystemInformation(80, ...)` — cmd 1/3/4/5 for Standby/Modified/WorkingSet flush
- `SetSystemFileCacheSize(-1, -1, 0)` — file system cache reset
- `EmptyWorkingSet()` + `SetProcessWorkingSetSizeEx()` — per-process RAM trim
- `AdjustTokenPrivileges` — `SeIncreaseQuotaPrivilege` + `SeProfileSingleProcessPrivilege` + `SeDebugPrivilege`

**Registry keys modified:**
- `HKLM:\SYSTEM\...\Memory Management` — kernel pool sizing
- `HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Scan` — Defender throttle
- `HKLM:\SOFTWARE\Policies\Microsoft\Windows\System` — SwapFile, telemetry, Timeline
- `HKCU:\...\VisualEffects` — Best Performance mode
- `HKCU:\System\GameConfigStore` — GameDVR off

---

## 📜 Changelog

### v4.0 — Current
- Complete English rewrite
- Persistent watchdog Scheduled Task (SYSTEM, every 5 min) — **the key fix**
- Memory Compression process throttled to IDLE priority
- SwapFile.sys disabled on SSD via policy
- SessionViewSize corrected: 48 MB → 256 MB for 8 GB
- WSL2 autoMemoryReclaim configured via `.wslconfig`
- SearchIndexer killed + disabled permanently
- Defender CPU capped 25% + process priority lowered
- `SetProcessWorkingSetSizeEx` added (deeper trim than V3)
- Top-10 RAM consumer targeted trim
- `ClearPageFileAtShutdown` enabled
- ReadyBoot logger disabled
- Post-trim second Standby flush pass added
- NtSetSystemInformation cmd=5 (combined flush) for Win10 1809+
- SSD auto-detection via `Get-PhysicalDisk`
- Fixed pagefile sizing for 8 GB (1 GB min / 4 GB max, no auto-resize)

### v3.0
- Added brand service detection (16 brands)
- Added keyword scan for leftover vendor services
- Added Scheduled Task vendor disable
- Vietnamese UI

### v2.0
- Added Win10/Win11 version-specific service lists
- Registry telemetry block
- File system cache flush

### v1.0
- Basic working set trim + standby flush

---

## 📄 License

MIT — use freely, modify freely, no warranty.

---

> **Tested on:** Windows 11 23H2 / 8 GB RAM / SSD  
> **PowerShell:** 5.1+  
> **Does NOT require:** .NET install, third-party tools, internet connection
