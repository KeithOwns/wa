# WinAuto Script Library

This folder contains a collection of standalone PowerShell scripts for checking and configuring Windows 11 system and security settings.

## Standard Features
All scripts in this library follow the **WinAuto Visual Standards**:
- **Shared UI:** Uses centralized colors and icons from `Shared_UI_Functions.ps1`.
- **Interactive Timeouts:** 10-second animated "Fuse" timer for all prompts, enabling unattended automation.
- **Undo Support:** All configuration (`SET_`) scripts include an `-Undo` switch to revert changes.

## Script Categories

### Security Configuration (SET)
Standardized security hardening modules.
- **SET_EnableRealTimeProtection-WinAuto.ps1**: Toggles Defender Real-time monitoring.
- **SET_EnablePUA-WinAuto.ps1**: Configures Potentially Unwanted App blocking (System & Edge).
- **SET_EnableMemoryIntegrity-WinAuto.ps1**: Manages Core Isolation (HVCI).
- **SET_EnableLSA-WinAuto.ps1**: Manages Local Security Authority protection.
- **SET_EnableKernelStackProtection-WinAuto.ps1**: Manages Hardware-enforced Stack Protection.
- **SET_EnableSmartScreen-WinAuto.ps1**: Configures 'Check apps and files'.
- **SET_EnableMSstoreSmartScreen-WinAuto.ps1**: Configures SmartScreen for Store apps.
- **SET_EnablePhishingProtection-WinAuto.ps1**: Manages Enhanced Phishing Protection.
- **SET_EnablePhishingProtectionMalicious-WinAuto.ps1**: Toggles malicious app/site warnings.
- **SET_FirewallON-WinAuto.ps1**: Ensures Firewall is active on all profiles.
- **UIA_AppBrowserCtrl.ps1**: Automates Windows Security App & browser control.

### System Maintenance & UI (RUN/SET)
Extracted standalone actions from the maintenance suite.
- **RUN_OptimizeDisks-WinAuto.ps1**: Performs TRIM (SSD) or Defrag (HDD) on all fixed drives.
- **RUN_SystemCleanup-WinAuto.ps1**: Cleans User and System Temp directories.
- **RUN_RemoveBloatware-WinAuto.ps1**: Removes common junk apps or restores default Windows apps (`-Undo`).
- **SET_PowerPlanHigh-WinAuto.ps1**: Toggles "High Performance" and "Balanced" power plans.
- **SET_VisualEffectsPerformance-WinAuto.ps1**: Optimizes UI for best performance or resets to defaults (`-Undo`).
- **SET_AlignTaskbarLeft-WinAuto.ps1**: Toggles Taskbar between Left and Center.
- **SET_ClassicContextMenu-WinAuto.ps1**: Restores/Removes the Windows 10 style context menu.
- **SET_DynamicLockON-WinAuto.ps1**: Configures the Dynamic Lock Bluetooth feature.
- **SET_EnableStorageSense-WinAuto.ps1**: Standardizes Storage Sense cleanup intervals.

### Network Utilities (RUN/SET)
- **RUN_ResetNetworkStack-WinAuto.ps1**: Performs a full Winsock, IP, and DNS reset.
- **SET_HardenNetworkProtocols-WinAuto.ps1**: Disables/Enables legacy NetBIOS and LLMNR.
- **SET_SecureDNS-WinAuto.ps1**: Configures Cloudflare (1.1.1.1) DNS or restores DHCP.

### System Checks (CHECK)
Read-only status reports.
- **CHECK_SecurityComprehensive-WinAuto.ps1**: Full audit with remediation suggestions.
- **CHECK_SecurityOnly-WinAuto.ps1**: Core security posture audit.
- **CHECK_SmartAppControl-WinAuto.ps1**: Reports SAC state (On/Off/Eval).
- **CHECK_SmartScreen-WinAuto.ps1**: Reports Edge SmartScreen status.
- **CHECK_SmartScreenApps-WinAuto.ps1**: Reports 'Check apps and files' status.
- **CHECK_WiFiOPEN-WinAuto.ps1**: Warns if connected to an unsecured Wi-Fi network.
- **CHECK_CurrentWinSecVer-WinAuto.ps1**: Displays Defender signature versions.
- **CHECK_WindowsUpdateStatus-WinAuto.ps1**: Lists pending OS updates.
- **CHECK_WinUpdates-WinAuto.ps1**: Triggers a GUI-based update check.
- **CHECK_MSstoreUpdates-WinAuto.ps1**: Triggers a GUI-based Store update check.
- **CHECK_DevDrive-WinAuto.ps1**: Detects ReFS Dev Drive volumes.
- **CHECK_ScriptQuality-WinAuto.ps1**: Validates encoding, syntax, and standards for the suite.

---
© 2026, www.AIIT.support. All Rights Reserved.