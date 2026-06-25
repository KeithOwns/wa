# WA (Core Version of WinAuto)

> **Enterprise-grade Windows 11 configuration management in a single, self-contained PowerShell file.**

![Version](https://img.shields.io/badge/version-2.1.0-blue) ![Platform](https://img.shields.io/badge/platform-Windows%2011-lightgray) ![License](https://img.shields.io/badge/license-MIT-green)

WA is the core, standalone delivery of the full [WinAuto](https://github.com/KeithOwns/winauto) suite. It is a powerful, lightweight automation script designed to streamline configuration, security hardening, and maintenance of Windows 11 systems—consolidated entirely into one interactive file.

## ⚡ Quick Start

Run this command in an **Administrator** PowerShell window to download and execute WA instantly:
```powershell
iex (irm https://raw.githubusercontent.com/KeithOwns/wa/main/wa.ps1)
```

## 🚀 Key Features

-   **Interactive Dashboard:** A modern, arrow-key driven CLI interface for manual and automated operations.
-   **SmartRUN Automation:** Intelligent orchestration that audits system state and only applies changes where configuration drift is detected.
-   **Security Hardening:** Automates Microsoft Defender, Memory Integrity, Kernel Stack Protection, LSA Protection, App & browser control, and Windows Firewall.
-   **Application Management:** Built-in application setups utilizing WinGet and direct downloads with silent deployment.
-   **Automated Maintenance:** One-touch system repair (SFC/DISM), drive optimization, and temp file cleanup.
-   **UI Automation:** Robust handling of Windows Settings that cannot be managed via the registry alone.

## 🧠 Execution Modes

### 1. State-Aware Remediation (Configuration)

-   **SmartRun**: Performs a "drift audit" first. It only executes configuration changes for settings that are currently detected as non-compliant or out of the desired state. If all enabled settings are already perfectly configured, it completely skips the Configuration phase.
-   **ManualMode**: Operates blindly. It forces the execution and re-application of all enabled Configuration settings, regardless of whether the system is already in compliance.

### 2. Time-Based Thresholds (Maintenance)

-   **SmartRun**: Respects the built-in cool-down thresholds for maintenance tasks. For example, it checks the local registry history and skips Windows Updates if they were run within the last 1 day, or skips Disk Optimization/Temp Cleanup if they were run within the last 7 days. If all tasks are within their thresholds, it skips the Maintenance phase entirely.
-   **ManualMode**: Completely ignores all time-based thresholds and forces every selected Maintenance task to execute immediately.

**In summary:** `SmartRun` acts as a surgical, idempotent desired-state engine (only fixing what is broken and running what is due), whereas `ManualMode` acts as a heavy-handed override that forcefully re-applies everything you have toggled on.

## 🛠️ Usage

1.  **Elevate:** Open a PowerShell window as **Administrator**.
2.  **Run:** Execute the core script:
    ```powershell
    .\wa.ps1
    ```
3.  **Navigate:** Use the `^` and `v` arrow keys to select items.
4.  **Toggle:** Press `Space` to toggle selected options.
5.  **Execute:** Press `Enter` to run the selected section or `SmartRUN`.

## 📁 Repository Structure

Unlike the full WinAuto suite, the WA repository relies on a strictly single-file architecture:

-   `wa.ps1`: The complete standalone core script comprising the interactive dashboard and all automation logic. No external dependencies or separate folders required.

## 🛡️ Requirements

-   **Operating System:** Windows 11 (Build 22000+)
-   **Privileges:** Administrator
-   **Execution Policy:** Set to `RemoteSigned` (handled automatically by the script).

## ⚖️ Disclaimer

1.  **Test First:** Always run in a non-production environment first.
2.  **Back up:** Critical data should be backed up before running maintenance tasks.
3.  **Responsibility:** The authors are not responsible for any system instability or data loss.

---
*Maintained by KeithOwns | Open Source MIT License*
