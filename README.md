# WinAuto (Core Edition)

> **A lightweight, single-file automation suite for Windows 11 Configuration & Maintenance.**

WinAuto Core (`wa.ps1`) is a streamlined PowerShell utility designed to automate the essential tasks of setting up and maintaining a Windows 11 environment. It combines intelligent application installation, security hardening, and system maintenance into a responsive, dashboard-driven interface.

It is designed as a standalone tool - its code is fully self-contained, meaning the script can execute all of its processes without relying on external module dependencies.

## * Key Features

*   **SmartRUN Orchestration**: Automatically determines the necessary actions based on your system's state and recent history.
*   **App Installation**: Installs applications defined in a JSON configuration file (`Install_RequiredApps-Config.json`). If this file is not found, the script can automatically download a default configuration from the repository.
*   **Security Configuration**: Applies best-practice security settings (Real-Time Protection, Memory Integrity, Firewall, etc.) via Registry and WMI.
*   **System Maintenance**: Performs essential maintenance duties including Windows Updates (via Winget), Disk Optimization (TRIM), and Temporary File Cleanup.
*   **Dashboard UI**: A clean, keyboard-navigable interface with real-time status indicators.

## * Prerequisites

*   **OS**: Windows 11 (Recommended)
*   **Permissions**: Administrator privileges are required.
*   **Files**:
    *   `wa.ps1` (The main script)
    *   `Install_RequiredApps-Config.json` (Optional - The script checks `Documents\wa\` or `Downloads` for this file)

## * Quick Start

1.  **Download** the `wa.ps1` script.
2.  **(Optional) Configuration**: If you have a custom `Install_RequiredApps-Config.json`, place it in your `Documents\wa\` or `Downloads` folder.
3.  **Open PowerShell** as Administrator.
4.  **Navigate** to the folder containing the script:
    ```powershell
    cd C:\Path\To\Script
    ```
5.  **execute** the script:
    ```powershell
    .\wa.ps1
    ```

## * Navigation

The dashboard uses a simple keyboard-driven interface:

*   **Arrow Keys (`^` `v`)**: Navigate between menu items.
*   **Spacebar**: Execute the selected action (`RUN`).
*   **Esc**: Exit the script.
*   **Hotkeys**:
    *   `S`: Execute **SmartRUN**
    *   `I`: Execute **Install Applications**
    *   `C`: Execute **Configure OS**
    *   `M`: Execute **Maintain OS**
    *   `H`: View **Help / Info** (Manifest)

## * Configuration

Application installation is controlled by the `Install_RequiredApps-Config.json` file. You can customize the list of apps to install by editing this JSON file.

**Example Structure:**
```json
{
  "BaseApps": [
    {
      "AppName": "Box Drive",
      "MatchName": "Box",
      "Type": "MSI",
      "Url": "https://example.com/installer.msi"
    },
    {
      "AppName": "Adobe Creative Cloud",
      "Type": "WINGET",
      "WingetId": "Adobe.CreativeCloud"
    }
  ]
}
```

## * Documentation & Export

*   **Help / Info**: Press `H` on the dashboard to view the **System Impact Manifest**, which details every action the script performs.
*   **CSV Export**: From the Help page, press `Enter` to export a detailed CSV report of all script functions and methods to the script's directory.

## ! Disclaimer

This script modifies system settings and registry keys. While designed to be safe and reversible where possible, **always ensure you have a backup** before applying major configuration changes. Use at your own risk.

---
*Generated for WinAuto Core Project*
