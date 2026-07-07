# Atomic Scripts (`as`)

Welcome to the **Atomic Scripts** library. 

This repository is a modular extraction of the core `wa.ps1` (WinAuto) configuration engine. Rather than using one massive, monolithic script to control your Windows 11 system, this repository breaks down every single action into an independent, hyper-fast, "atomic" PowerShell script.

## Compatibility
*Note: All scripts in this repository have been tested and verified on:*
- **Processor:** Intel(R) Core(TM) Ultra 7 268V
- **OS Version:** Microsoft Windows 11 Pro 10.0.26200

## Core Features
- **True Modularity:** Every configuration, security tweak, and maintenance task is isolated in its own `.ps1` file.
- **Zero Bloat:** Scripts contain only the absolute minimum native PowerShell and Registry commands required to execute the task.
- **Built-in Undo Logic:** All `SET_` configuration scripts natively support a `-Undo` switch to instantly revert the setting back to the Windows 11 default.

## Usage

### 1. Applying a Configuration (`SET_`)
To harden a setting or apply a custom UI configuration, simply run the script natively in an Administrator PowerShell window:
```powershell
.\SET_RealTimeProt.ps1
```

### 2. Reversing a Configuration (`-Undo`)
If you decide you don't like a change, or need to temporarily disable a security feature, just append the `-Undo` parameter:
```powershell
.\SET_RealTimeProt.ps1 -Undo
```

### 3. Maintenance Tasks (`RUN_`)
Maintenance scripts (like Windows Updates or Disk Cleanup) perform one-time actions and cannot be undone:
```powershell
.\RUN_SystemCleanup.ps1
```

## Available Scripts

### Automation
- `SET_MicrosoftUpd.ps1`
- `SET_RestartIsReq.ps1`
- `SET_RestartApps.ps1`
- `SET_MeteredUpd.ps1`
- `UNLOCK_MeteredUpdGUI.ps1`

### Security
- `SET_PSTranscription.ps1`
- `SET_Telemetry.ps1`
- `SET_LLMNR.ps1`
- `SET_PSScriptBlock.ps1`
- `SET_PSModuleLogging.ps1`
- `SET_NetBIOS.ps1`
- `SET_RealTimeProt.ps1`
- `SET_PUABlockApps.ps1`
- `SET_PUABlockDLs.ps1`
- `SET_MemoryInteg.ps1`
- `SET_KernelMode.ps1`
- `SET_LocalSecurity.ps1`
- `SET_FirewallON.ps1`

### User Interface
- `SET_TaskbarSearch.ps1`
- `SET_TaskViewOFF.ps1`
- `SET_ShowExtensions.ps1`
- `SET_ShowHidden.ps1`

### System Information
- `GET_DeviceInfo.ps1`

### Maintenance
- `RUN_UpdateSuite.ps1`
- `RUN_OptimizeDisks.ps1`
- `RUN_SystemCleanup.ps1`
- `RUN_WindowsRepair.ps1`

## Future Roadmap
- **Expand `GET_` Scripts:** Build out additional informational scripts (similar to `GET_DeviceInfo.ps1`) to query system statuses, security health, and network configurations without modifying them.
- **Expand `UNLOCK_` Scripts:** Develop more standalone unlock scripts (similar to `UNLOCK_MeteredUpdGUI.ps1`) designed specifically to wipe strict Group Policies and restore control to the native Windows Settings GUI.
- **Process Monitoring Idea:** Create a `GET_` script to query and review all currently running processes on the computer (similar to Task Manager) to quickly identify background tasks and resource usage.
