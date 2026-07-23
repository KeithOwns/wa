# JA Debloat Comparison & Audit Report

**Date**: July 22, 2026  
**Module**: `Automation_Scripts/wa/Variants/JA`  
**Target OS**: Windows 11 Build 22000+  

---

## 1. Executive Summary

This report documents the debloat strategy and parity comparison between the **JA standalone core script (`ja.ps1`)**, the **Dynamic Hub Launcher (`HUB_AtomicLauncher.ps1`)**, and third-party debloat configurations (O&O ShutUp10 / OOAPB).

The JA variant modularizes system tweaks into individual atomic script components located in `Variants/JA/AtomicScripts/`.

---

## 2. Comparison Matrix: JA vs. Local Admin vs. Domain User Profiles

| Audit Metric | Local Admin Profile | Domain User Profile | JA SmartRUN Behavior |
| :--- | :--- | :--- | :--- |
| **O&O ShutUp10 Hardening (`ooshutup10.cfg`)** | Applied globally via HKLM registry policies. | Inherited via HKLM policies upon first logon. | Clears conflicting managed policies first so user settings UI remains interactive. |
| **Telemetry & Data Collection** | Set to Required (Level 1). | Inherits Level 1 policy. | `ST_SetTelemetry.ps1` strips `AllowTelemetry` policy override to avoid "Managed by Organization" lockouts. |
| **Provisioned Bloatware Apps** | Uninstalled for current user context. | De-provisioned globally via `Remove-AppxProvisionedPackage`. | Prevents default UWP bloatware (Candy Crush, Xbox overlays) from auto-installing for new domain users. |
| **Visual Effects & UI Performance** | Modified in HKCU (`HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects`). | Default Windows 11 visual settings restored. | `CP_SetVisualEffects.ps1` must be triggered per-user on initial logon for non-admin domain accounts. |

---

## 3. Debloat Comparison Findings

1. **Global HKLM Policy Protection**:
   - `ja.ps1` and atomic scripts target HKLM keys (`HKLM:\SOFTWARE\Policies\...`) for Defender, Firewall, and PUA protection. These changes take immediate effect for all new domain logins.

2. **User-Scoped HKCU Parity**:
   - Settings in `HKCU` (Visual Effects, File Explorer extensions/hidden files, taskbar search bar layout) apply strictly to the currently logged-in user.
   - *Recommendation*: Call `HUB_AtomicLauncher.ps1` via a Logon Script / GPO for new domain users to enforce HKCU parity without needing local administrator rights.

3. **Atomic Modularization**:
   - `ja.ps1` has completed phase 1 & 2 of `masterPLAN.txt`.
   - All 38 atomic scripts in `Variants/JA/AtomicScripts/` mirror the main `wa` repository standards.

---

## 4. Action Items

- [x] Document Local Admin vs. Domain User debloat profile comparison.
- [x] Verify atomic script parity between `ja.ps1` and `HUB_AtomicLauncher.ps1`.
- [ ] Add GPO startup script example to `Variants/JA/README.md`.
