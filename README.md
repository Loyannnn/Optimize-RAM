# 🧠 Optimize-RAM V3

> Advanced Windows 10/11 memory optimization toolkit with OEM-aware tuning, deep cleanup routines, and session-based system optimization.

---

## 📖 About

Optimize-RAM V3 is the latest generation of the Optimize-RAM project.

The goal of V3 is to maximize available memory, reduce unnecessary background overhead, and improve system responsiveness while maintaining system safety.

Unlike many aggressive optimization tools, V3 focuses on **temporary and controlled optimizations** rather than permanent system modifications.

---

# ✨ Key Features

## 🧹 Advanced Memory Optimization

* Standby List cleanup
* Modified Page List cleanup
* Working Set trimming
* File System Cache cleanup
* Process memory optimization
* Memory pressure reduction

---

## 🖥 OEM-Aware Optimization

V3 automatically detects the system manufacturer and applies vendor-specific optimization rules.

Supported manufacturers include:

* Dell
* HP
* Lenovo
* ASUS
* MSI
* Acer
* Samsung
* Huawei
* Gigabyte
* Microsoft Surface
* Toshiba
* Fujitsu
* Panasonic
* Razer

This allows V3 to optimize OEM-related background services more intelligently than generic RAM optimization scripts.

---

## ⚙ Windows Optimization

### Service Optimization

Temporarily optimizes non-essential services during the current session.

### Startup Optimization

* Startup entry cleanup
* Background process reduction
* Resource prioritization

### Scheduled Task Optimization

* OEM maintenance tasks
* Diagnostic tasks
* Telemetry-related tasks

### Performance Tweaks

* GameDVR optimization
* Background activity reduction
* Performance-oriented adjustments

---

## 🧽 Cleanup Engine

V3 includes an expanded cleanup system capable of removing:

* Temporary files
* Update cache
* Prefetch cache
* Thumbnail cache
* Browser cache
* Event logs
* Various Windows-generated temporary data

---

# 🛡 Safety Design

Optimize-RAM V3 follows a safety-first approach.

### What V3 Does NOT Do

❌ Permanently disable services

❌ Delete system files

❌ Modify BIOS settings

❌ Install drivers

❌ Replace Windows components

❌ Perform irreversible system modifications

---

## Session-Based Optimization

Most optimizations are applied only to the current Windows session.

After reboot:

* Services return to normal behavior
* Windows restores default operating conditions
* No manual rollback is required

---

# 📊 Performance Results

Results depend on:

* Running applications
* OEM software
* Hardware configuration
* System workload
* Current memory state

Observed improvements during testing:

* Lower RAM usage
* Reduced background overhead
* Improved responsiveness
* Better multitasking performance

### Best Observed Case

Before:

11.8 GB RAM Used

After:

6.2 GB RAM Used

Freed:

5.6 GB RAM

> This is a best-case result observed during testing and is not guaranteed on every system.

---

# 💻 Requirements

### Supported Operating Systems

* Windows 11
* Windows 10 (1809+)

### Requirements

* Administrator privileges
* PowerShell 5.1+

---

# 🚀 Usage

Run:

```bat
Optimize-RAM-v3-GodMode.bat
```

as Administrator.

Or directly:

```powershell
powershell -ExecutionPolicy Bypass -File Optimize-RAM-v3.ps1
```

---

# 📄 Logging

V3 automatically generates optimization reports containing:

* System information
* Memory statistics
* OEM detection results
* Optimization summary
* Cleanup results

---

# 🔮 Future Plans

* GUI Interface
* Audit Mode
* Real-Time Monitoring
* HTML Reports
* Optimization Profiles
* Extended Windows Compatibility

---

# ⚠ Disclaimer

Optimize-RAM V3 is provided as-is.

Always review source code before execution and use at your own discretion.

---

# ❤️ Philosophy

> Optimize temporarily. Recover automatically. Preserve system stability.
