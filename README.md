# WinAuto (Core Edition)

> **Enterprise-grade Windows 11 configuration management in a single, self-contained PowerShell file.**

![Version](https://img.shields.io/badge/version-2.0.0-blue) ![Platform](https://img.shields.io/badge/platform-Windows%2011-blue) ![License](https://img.shields.io/badge/license-MIT-green)

## Overview

**WinAuto** is more than just a setup script; it is a **portable IT Asset Management (ITAM) artifact** designed for professional environments. Unlike traditional RMM agents or complex SCCM task sequences, WinAuto offers a **zero-dependency** architecture that can run in air-gapped environments, on standalone workstations, or as part of a Golden Image sealing process.

It combines intelligent application orchestration, security hardening (CIS/NIST alignment), and system maintenance into a responsive, keyboard-driven dashboard.

### Why WinAuto?

| Feature | WinAuto | Traditional Scripts | RMM Agents |
| :--- | :--- | :--- | :--- |
| **Dependencies** | **None (Zero)** | Modules / Internet | Cloud Connectivity |
| **Execution** | **Portable File** | Complex Folder Structures | Installed Agent |
| **Security** | **HVCI / VBS Aware** | Basic Registry Tweaks | Varies by Vendor |
| **Auditability** | **CSV Export / Logs** | Transient Output | Cloud Dashboard |

---

## 🏗️ Self-Contained Architecture

WinAuto follows a **single-file delivery model**. 
- **`wa.ps1`**: The Core Logic engine. It contains all necessary functions, UI rendering code, and logic internally. It **embeds the application configuration**, requiring no external files.

**Key Benefits:**
1.  **Air-Gap Ready**: Copy the script to a USB drive and run it on a machine with no internet access.
2.  **Golden Image Sealing**: Perfect for "Sysprep" phases where you want to apply a consistent baseline before capturing an image.
3.  **Field Engineering**: A single tool for technicians to carry on their toolkit USBs.

---

## 🛡️ Security & Compliance

WinAuto is built with an "Audit First" philosophy, aligning configuring settings with major security frameworks.

| Feature | CIS Control (v8) | NIST SP 800-53 | Implementation |
| :--- | :--- | :--- | :--- |
| **Real-Time Protection** | 10.1 | SI-3 | Enforces `DisableRealtimeMonitoring = 0` via WMI |
| **Memory Integrity (HVCI)** | 4.8 | SI-16 | Safe Registry injection for `HypervisorEnforcedCodeIntegrity` |
| **PUA Protection** | 10.1 | SI-3 | Enables Potentially Unwanted App blocking in Defender & Edge |
| **Firewall Enforcement** | 4.4 | SC-7 | Validates and enables all 3 Firewall Profiles (Domain/Private/Public) |
| **LSA Protection** | 4.8 | SC-3 | Configures `RunAsPPL` for Local Security Authority |
| **Windows Updates** | 7.4 | SI-2 | Enforces Auto-Update service and restart notifications |

> **Note**: WinAuto respects the "True Compliance State". If a setting is already correct, it skips the action (Idempotency).

---

## ⚡ Deployment Scenarios

### 1. New Device Provisioning (OOBE)
Run WinAuto immediately after the first login to:
- Install baseline applications (via `Install_RequiredApps-Config.json`).
- Harden security settings (HVCI, Firewall).
- Debloat UI (Taskbar, Widget cleanup).

### 2. Golden Image Preparation
Run WinAuto in "Audit Mode" or before Sysprep to ensure the base image complies with security standards. Use the **Maintenance** module to clean up temp files and optimize disks before capture.

### 3. Field Maintenance (Break/Fix)
Technicians can use the **Maintenance** dashboard to:
- Run standard SFC/DISM repairs.
- Force Windows Updates via USOClient.
- Reset Firewall states.

---

## 🚀 Quick Start

### Prerequisites
- **OS**: Windows 11 (Build 22000+) recommended.
- **Privileges**: **Administrator** rights are required.
- **Execution Policy**: Script will attempt to set `Process` scope to `RemoteSigned`.

### Execution

**Option A: Web Wrapper (Easiest)**
```powershell
iex (irm "https://raw.githubusercontent.com/KeithOwns/wa/main/dev/wa.ps1")
```

**Option B: Manual Download (Air-Gap / Secure)**
1.  Download `wa.ps1`.
2.  Run from Administrator PowerShell:
    ```powershell
    .\wa.ps1
    ```

---

## 🎮 Dashboard Navigation

WinAuto features a unified, keyboard-driven text UI (TUI).

```text
    [ SmartRUN ]      [ Install ]      [ Configure ]      [ Maintain ]
```

*   **Arrow Keys (`^` `v`)**: Navigate between phases.
*   **Spacebar**: Execute the selected phase.
*   **Hotkeys**:
    *   `S`: **SmartRUN** (Orchestrated run based on logic).
    *   `I`: **Install** Apps.
    *   `C`: **Configure** Security & UI.
    *   `M`: **Maintain** System.
    *   `H`: **Help** / System Impact Manifest.
*   **Esc**: Exit.

---

## ⚙️ Configuration (JSON)

Application installation is driven by an **embedded JSON configuration** within `wa.ps1`. You can edit the `Get-WA_InstallAppList` function directly to modify the list of applications.

**Internal Schema:**
```json
{
  "BaseApps": [
    {
      "AppName": "Google Chrome",
      "Type": "WINGET",
      "WingetId": "Google.Chrome"
    },
    {
      "AppName": "Corporate VPN",
      "Type": "MSI",
      "Url": "https://intranet.corp/vpn.msi",
      "Arguments": "/quiet /norestart"
    }
  ]
}
```

---

## 📊 Logging & Audit

*   **Logs**: Stored in `.\logs\wa.log` (Rotated).
*   **CSV Export**: Press `Enter` on the Help screen to generate `scriptOUTLINE-wa.csv`. This file contains a detailed audit trail of every function, registry key, and command the script is capable of modifying.

---

## ⚠️ Disclaimer

This software modifies system configurations, registry keys, and security policies. While designed to be safe and idempotent:
1.  **Always test** in a non-production environment first.
2.  **Back up** critical data before running maintenance tasks.
3.  The authors are not responsible for any system instability or data loss.

---
*Maintained by the WinAuto Team | Open Source MIT License*
