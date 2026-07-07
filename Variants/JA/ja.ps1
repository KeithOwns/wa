<#
.SYNOPSIS
    WinAuto (Core Edition)
.DESCRIPTION
    A lightweight, single-file version of the WinAuto suite for Windows 11.
    Focuses purely on Configuration (Security/UI) and Maintenance (Updates/Repair).
    
    Usage: Copy and paste this script into an Administrator PowerShell window.
#>


# --- CLI PARAMETERS ---
param(
    [Parameter(Mandatory = $false)]
    [string]$Module,

    [Parameter(Mandatory = $false)]
    [switch]$Silent,

    [Parameter(Mandatory = $false)]
    [string]$LogPath,

    [Parameter(Mandatory = $false)]
    [string]$Config
    
    # Verbose is automatic due to [Parameter()] attributes
)

# --- INITIALIZATION ---
function Set-WA_WorkingDirectory {
    $targetDir = Join-Path -Path ([Environment]::GetFolderPath("MyDocuments")) -ChildPath "KeithOwns"
    if (-not (Test-Path -Path $targetDir)) {
        New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
    }
    Set-Location -Path $targetDir
}
Set-WA_WorkingDirectory

# Admin check (manual, for iex compatibility â€” #Requires does not work with Invoke-Expression)
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "This script requires Administrator privileges. Please run in an elevated PowerShell window."
    return
}

# Validate -Module (manual check for iex compatibility)
if ($Module -and $Module -notin @("SmartRun", "Config", "Maintenance", "Help")) {
    Write-Error "Invalid Module: '$Module'. Valid values: SmartRun, Config, Maintenance, Help"
    return
}

$Global:Silent = $Silent
$Global:Module = $Module
$Global:Config = $Config
$Global:LogPath = $LogPath

# --- EXECUTION POLICY CONFIGURATION ---
# Ensures local scripts can run by setting policy to 'RemoteSigned'
try {
    $currentPolicy = Get-ExecutionPolicy -Scope LocalMachine
    if ($currentPolicy -ne "RemoteSigned") {
        Set-ExecutionPolicy -ExecutionPolicy "RemoteSigned" -Scope "LocalMachine" -Force -ErrorAction Stop
        Write-Host "Execution Policy set to 'RemoteSigned' for LocalMachine."
    }
}
catch {
    Write-Warning "Failed to set Execution Policy: $_"
}

# --- AUTO-UNBLOCK ROUTINE ---
# Removes 'Mark of the Web' from the script and its components to prevent "not digitally signed" errors.
try {
    if ($PSCommandPath) { Unblock-File -Path $PSCommandPath -ErrorAction SilentlyContinue }
    if ($PSScriptRoot) {
        Get-ChildItem -Path $PSScriptRoot -Filter "*.ps*" -Recurse -ErrorAction SilentlyContinue | Unblock-File -ErrorAction SilentlyContinue
    }
}
catch {}

# --- INITIAL SETUP ---
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$Global:ShowDetails = $false
$Global:WinAutoFirstLoad = $true

# --- SYSTEM PATHS ---
$Global:WinAutoLogDir = $null
$Global:WinAutoLogPath = $null

if ($LogPath) {
    if (Test-Path $LogPath -PathType Container) {
        $Global:WinAutoLogDir = $LogPath
    }
    else {
        # Assume full file path or new directory
        $Global:WinAutoLogDir = Split-Path $LogPath -Parent
        if (-not $Global:WinAutoLogDir) { $Global:WinAutoLogDir = $PWD.Path }
    }
}

if ($null -eq $Global:WinAutoLogDir) {
    # Use local 'logs' folder relative to script
    $root = if ($PSScriptRoot) { $PSScriptRoot } else { $PWD.Path }
    $Global:WinAutoLogDir = Join-Path $root "logs"
}

if (-not (Test-Path $Global:WinAutoLogDir)) { New-Item -ItemType Directory -Force -Path $Global:WinAutoLogDir | Out-Null }
$env:WinAutoLogDir = $Global:WinAutoLogDir

if ($LogPath -and (Test-Path $LogPath -PathType Leaf)) {
    # User provided an existing file
    $Global:WinAutoLogPath = $LogPath
}
elseif ($LogPath -and -not (Test-Path $LogPath)) {
    # User provided a new file path (folder logic handled earlier) or just a folder
    if ($LogPath -match "\.\w+$") {
        # Likely a file path
        $Global:WinAutoLogPath = $LogPath
    }
    else {
        # Likely a folder
        $Global:WinAutoLogPath = Join-Path $Global:WinAutoLogDir "wa.log"
    }
}
else {
    # Default behavior
    $Global:WinAutoLogPath = Join-Path $Global:WinAutoLogDir "wa.log"
}

# --- GLOBAL ERROR TRAP ---


# --- GLOBAL RESOURCES ---
# Centralized definition of ANSI colors and Unicode characters.

# --- ANSI Escape Sequences ---
$Esc = [char]0x1B
$Global:Reset = "$Esc[0m"
$Global:Bold = "$Esc[1m"

# Script Palette (Foreground)
$Global:FGCyan = "$Esc[96m"
$Global:FGBlue = "$Esc[94m"
$Global:FGDarkBlue = "$Esc[34m"
$Global:FGGreen = "$Esc[92m"
$Global:FGRed = "$Esc[91m"
$Global:FGYellow = "$Esc[93m"
$Global:FGDarkGray = "$Esc[90m"
$Global:FGDarkRed = "$Esc[31m"
$Global:FGDarkGreen = "$Esc[32m"
$Global:FGDarkCyan = "$Esc[36m"
$Global:FGMagenta = "$Esc[95m"


$Global:FGWhite = "$Esc[97m"
$Global:FGGray = "$Esc[37m"
$Global:FGDarkYellow = "$Esc[33m"

# --- LOGGING & REGISTRY ---
function Write-Log {
    param([string]$Message, [string]$Level = 'INFO', [string]$Path = $Global:WinAutoLogPath)
    if (-not $Path) { $Path = "C:\Windows\Temp\WinAuto.log" }
    
    # Verbose Output (CLI Support)
    if ($Global:VerbosePreference -eq 'Continue') {
        Write-Host "[$Level] $Message" -ForegroundColor Gray
    }

    $logDir = Split-Path -Path $Path -Parent
    if (-not (Test-Path $logDir)) { New-Item -Path $logDir -ItemType Directory -Force | Out-Null }
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    Add-Content -Path $Path -Value "[$timestamp] [$Level] $Message" -ErrorAction SilentlyContinue
}

# --- GLOBAL ERROR TRAP ---
trap {
    $msg = "CRITICAL UNHANDLED ERROR: $($_.Exception.Message)`n$($_.ScriptStackTrace)"
    try { Write-Log $msg -Level ERROR } catch { Write-Host "LOG FAIL: $msg" -ForegroundColor Red }
    Write-Error $msg
    return
}

# --- MANIFEST CONTENT ---
$Global:WinAutoManifestContent = @'
- ja.ps1: Functional Outline -
________________________________________________________
Pre-Run Setup
- Execution Policy check    | (Inline)
- Administrator check       | (Inline)
- Environment Setup         | (Inline: Variables, Logging, UI Types)
________________________________________________________
[S]martRUN
Method: Orchestration Loop
Actions:
- Configuration Check       | Invoke-WinAutoConfiguration -SmartRun
- Maintenance Check         | Invoke-WinAutoMaintenance -SmartRun
________________________________________________________
[C]onfiguration
Security Actions:
- Real-Time Protection      | Invoke-WA_SetRealTimeProtection (Set-MpPreference)
- PUA Protection            | Invoke-WA_SetPUA (Set-MpPreference)
- Memory Integrity          | Invoke-WA_SetMemoryIntegrity (Registry)
- Kernel Stack Protection   | Invoke-WA_SetKernelStack (Registry)
- LSA Protection            | Invoke-WA_SetLSA (Reg: Control\Lsa)
- Windows Firewall          | Invoke-WA_SetFirewall (Set-NetFirewallProfile)
- SmartScreen (UIA)         | Invoke-WA_SetSmartScreen (UI Automation)
- Defender Remediation (UIA)| Invoke-WA_SetVirusThreatProtect (UI Automation)
UI & UX Actions:
- Taskbar/Search/Widgets    | Invoke-WA_SetTaskbarDefaults (Reg: HKCU/HKLM)
- Windows Update Config     | Invoke-WA_SetWindowsUpdateConfig (Reg: UX/Settings)
________________________________________________________

[M]aintenance
Orchestrated Maintenance:
- System Pre-Flight Check   | Invoke-WA_SystemPreCheck
- Windows Update (API/UI)   | Invoke-WA_WindowsUpdate
- SFC System Scan           | Invoke-WA_SFCRepair (Conditional: 30 days)
- DISM Repair               | Invoke-WA_SFCRepair (Triggered on corruption)
- WinGet/Store Updates      | Invoke-WA_WindowsUpdate
- Drive Opt (Trim/Defrag)   | Invoke-WA_OptimizeDisks (Conditional: 7 days)
- System Cleanup            | Invoke-WA_SystemCleanup (Conditional: 7 days)
'@
$Global:FGBlack = "$Esc[30m"

# Script Palette (Background)
$Global:BGDarkGreen = "$Esc[42m"
$Global:BGDarkGray = "$Esc[100m"
$Global:BGYellow = "$Esc[103m"
$Global:BGRed = "$Esc[41m"
$Global:BGDarkRed = "$Esc[41m"
$Global:BGDarkCyan = "$Esc[46m"
$Global:BGWhite = "$Esc[107m"

# --- Unicode Icons & Characters ---
$Global:Char_HeavyCheck = "[v]" 

$Global:Char_Warn = "!" 
$Global:Char_BallotCheck = "[v]" 

$Global:Char_Copyright = "(c)" 
$Global:Char_Finger = "->" 
$Global:Char_CheckMark = "v" 
$Global:Char_FailureX = "x" 
$Global:Char_RedCross = "x"
$Global:Char_HeavyMinus = "-" 
$Global:Char_EnDash = "-"

$Global:RegPath_WU_UX = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings"
$Global:RegPath_WU_POL = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
$Global:RegPath_Winlogon_User = "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" 
$Global:RegPath_Winlogon_Machine = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"

# --- MANIFEST CONTENT ---

$Global:WinAutoManifestContent = @"
  ${FGDarkCyan}__________________________________________________________${Reset}
  ${FGDarkCyan}ACTION${Reset}                   ${FGDarkGray}|${Reset} ${FGDarkCyan}STAGE${Reset}    ${FGDarkGray}|${Reset} ${FGDarkCyan}SOURCE SCRIPT${Reset}
  ${FGDarkGray}----------------------------------------------------------${Reset}
  Real-Time Protection     ${FGDarkGray}|${Reset} ${FGGray}Configure${Reset}${FGDarkGray}|${Reset} ${FGGray}SET_RealTimeProt${Reset}
  PUA Protection           ${FGDarkGray}|${Reset} ${FGGray}Configure${Reset}${FGDarkGray}|${Reset} ${FGGray}SET_PUABlockApps${Reset}
  PUA Protection (Edge)    ${FGDarkGray}|${Reset} ${FGGray}Configure${Reset}${FGDarkGray}|${Reset} ${FGGray}SET_PUABlockDLs${Reset}
  Memory Integrity         ${FGDarkGray}|${Reset} ${FGGray}Configure${Reset}${FGDarkGray}|${Reset} ${FGGray}SET_MemoryInteg${Reset}
  Kernel Stack Protection  ${FGDarkGray}|${Reset} ${FGGray}Configure${Reset}${FGDarkGray}|${Reset} ${FGGray}SET_KernelMode${Reset}
  LSA Protection           ${FGDarkGray}|${Reset} ${FGGray}Configure${Reset}${FGDarkGray}|${Reset} ${FGGray}SET_LocalSecurity${Reset}
  Windows Firewall         ${FGDarkGray}|${Reset} ${FGGray}Configure${Reset}${FGDarkGray}|${Reset} ${FGGray}SET_FirewallON${Reset}
  Classic Context Menu     ${FGDarkGray}|${Reset} ${FGGray}Configure${Reset}${FGDarkGray}|${Reset} ${FGGray}SET_ClassicMenu${Reset}
  Taskbar Search Box       ${FGDarkGray}|${Reset} ${FGGray}Configure${Reset}${FGDarkGray}|${Reset} ${FGGray}SET_TaskbarSearch${Reset}
  Task View Toggle         ${FGDarkGray}|${Reset} ${FGGray}Configure${Reset}${FGDarkGray}|${Reset} ${FGGray}SET_TaskViewOFF${Reset}
  Microsoft Update Service ${FGDarkGray}|${Reset} ${FGGray}Configure${Reset}${FGDarkGray}|${Reset} ${FGGray}SET_MicrosoftUpd${Reset}
  Restart Notifications    ${FGDarkGray}|${Reset} ${FGGray}Configure${Reset}${FGDarkGray}|${Reset} ${FGGray}SET_RestartIsReq${Reset}
  App Restart Persistence  ${FGDarkGray}|${Reset} ${FGGray}Configure${Reset}${FGDarkGray}|${Reset} ${FGGray}SET_RestartApps${Reset}
  Get Updates              ${FGDarkGray}|${Reset} ${FGGray}Maintain${Reset} ${FGDarkGray}|${Reset} ${FGGray}RUN_UpdateSuite${Reset}
  Drive Optimization       ${FGDarkGray}|${Reset} ${FGGray}Maintain${Reset} ${FGDarkGray}|${Reset} ${FGGray}RUN_OptimizeDisks${Reset}
  Temp File Cleanup        ${FGDarkGray}|${Reset} ${FGGray}Maintain${Reset} ${FGDarkGray}|${Reset} ${FGGray}RUN_SystemCleanup${Reset}
  SFC / DISM Repair        ${FGDarkGray}|${Reset} ${FGGray}Maintain${Reset} ${FGDarkGray}|${Reset} ${FGGray}RUN_WindowsRepair${Reset}
  ${FGDarkCyan}__________________________________________________________${Reset}
"@

$Global:WinAutoCSVContent = @'
ACTION,STAGE,SOURCE SCRIPT,METHOD,TECHNICAL DETAILS,REVERTIBLE,RESTART REQUIRED,IMPACT,FUNCTION
Execution Policy / Admin Check,Pre-Run Setup,wa,Inline,Set-ExecutionPolicy RemoteSigned -Scope Process,N/A,No,System,(Script Header)
Auto-Unblock,Pre-Run Setup,wa,Inline,Unblock-File (Self),N/A,No,System,(Script Header)
System Hardening Check,SmartRUN,wa (Embedded),Mixed,Checks system state vs desired configuration,N/A,No,Automation,Invoke-WinAutoConfiguration -SmartRun
Maintenance Cycle,SmartRUN,wa (Embedded),Mixed,Checks Last Run dates (Repair=30d; Disk=7d; Clean=7d) to trigger tasks,N/A,No,Automation,Invoke-WinAutoMaintenance -SmartRun
Real-Time Protection,Configure,wa (Embedded),PS WMI,Set-MpPreference -DisableRealtimeMonitoring 0,Yes,No,Security,Invoke-WA_SetRealTimeProt
PUA Protection,Configure,wa (Embedded),PS WMI,Set-MpPreference -PUAProtection 1,Yes,No,Security,Invoke-WA_SetPUABlockApps
PUA Protection (Edge),Configure,wa (Embedded),Registry (HKCU),HKCU:\Software\Microsoft\Edge\SmartScreenPuaEnabled (1),Yes,No,Security,Invoke-WA_SetPUABlockDLs
Memory Integrity,Configure,wa (Embedded),Registry (HKLM),HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity (1),Yes,Yes,Security,Invoke-WA_SetMemoryInteg
Kernel Stack Protection,Configure,wa (Embedded),Registry (HKLM),HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\KernelShadowStacks (1),Yes,Yes,Security,Invoke-WA_SetKernelMode
LSA Protection,Configure,wa (Embedded),Registry (HKLM),HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\RunAsPPL (1),Yes,Yes,Security,Invoke-WA_SetLocalSecurity
Windows Firewall,Configure,wa (Embedded),PowerShell Cmdlt,Set-NetFirewallProfile -Enabled True,Yes,No,Security,Invoke-WA_SetFirewallON
Classic Context Menu,Configure,wa (Embedded),Registry (HKCU),HKCU:\Software\Classes\CLSID\{86ca1aa0...}\InprocServer32,Yes,No,UI,Invoke-WA_SetClassicMenu
Taskbar Search Box,Configure,wa (Embedded),Registry (HKCU),HKCU:\Software\Microsoft\Windows\CurrentVersion\Search\SearchboxTaskbarMode (3),Yes,No,UI,Invoke-WA_SetTaskbarSearch
Task View Toggle,Configure,wa (Embedded),Registry (HKCU),HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\ShowTaskViewButton (0),Yes,No,UI,Invoke-WA_SetTaskViewOFF
SmartScreen (UIA),Configure,wa (Embedded),UI Automation,Automates Windows Security App & Browser control,No,No,Security,Invoke-WA_SetSmartScreen
Defender Remediation (UIA),Configure,wa (Embedded),UI Automation,Automates Windows Security Virus & Threat protection,No,No,Security,Invoke-WA_SetVirusThreatProtect
Microsoft Update Service,Configure,wa (Embedded),Registry (HKLM),HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings\AllowMUUpdateService (1),Yes,No,Config,Invoke-WA_SetMicrosoftUpd
Restart Notifications,Configure,wa (Embedded),Registry (HKLM),HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings\RestartNotificationsAllowed2 (1),Yes,No,Config,Invoke-WA_SetRestartIsReq
App Restart Persistence,Configure,wa (Embedded),Registry (HKCU),HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\RestartApps (1),Yes,No,Config,Invoke-WA_SetRestartApps
Get Updates,Maintain,wa (Embedded),UI Automation,Automates Windows Update Settings and MS Store updates,No,No,Maintenance,Invoke-WA_WindowsUpdate
Drive Optimization,Maintain,wa (Embedded),PowerShell Cmdlt,Optimize-Volume for all fixed disks (SSD=Trim; HDD=Defrag),No,No,Maintenance,Invoke-WA_OptimizeDisks
Temp File Cleanup,Maintain,wa (Embedded),File System,Clears Windows Temp and User Temp,No,No,Maintenance,Invoke-WA_SystemCleanup
SFC / DISM Repair,Maintain,wa (Embedded),Command Line,Runs SFC scan; if corruption found runs DISM image repair,No,No,Maintenance,Invoke-WA_WindowsRepair
'@


# UI Automation Preparation
if (-not ([System.Management.Automation.PSTypeName]"System.Windows.Automation.AutomationElement").Type) {
    try {
        Add-Type -AssemblyName UIAutomationClient
        Add-Type -AssemblyName UIAutomationTypes
    }
    catch {}
}

function Get-UIAElement {
    param(
        [System.Windows.Automation.AutomationElement]$Parent,
        [string]$Name,
        [string]$AutomationId,
        [System.Windows.Automation.ControlType]$ControlType,
        [System.Windows.Automation.TreeScope]$Scope = [System.Windows.Automation.TreeScope]::Descendants,
        [int]$TimeoutSeconds = 5
    )
    
    $Conditions = @()
    if ($Name) { $Conditions += New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty, $Name) }
    if ($AutomationId) { $Conditions += New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::AutomationIdProperty, $AutomationId) }
    if ($ControlType) { $Conditions += New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, $ControlType) }

    $Condition = if ($Conditions.Count -eq 1) { $Conditions[0] }
    elseif ($Conditions.Count -gt 1) { New-Object System.Windows.Automation.AndCondition($Conditions) }
    else { return $null }

    $StopWatch = [System.Diagnostics.Stopwatch]::StartNew()
    while ($StopWatch.Elapsed.TotalSeconds -lt $TimeoutSeconds) {
        $Result = $Parent.FindFirst($Scope, $Condition)
        if ($Result) { return $Result }
        Start-Sleep -Milliseconds 500
    }
    return $null
}

function Invoke-UIAElement {
    param([System.Windows.Automation.AutomationElement]$Element)
    
    if (-not $Element) { return $false }
    
    try {
        if ($Element.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern)) {
            $Element.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern).Invoke()
            return $true
        }
    }
    catch {}

    try {
        if ($Element.GetCurrentPattern([System.Windows.Automation.TogglePattern]::Pattern)) {
            $Element.GetCurrentPattern([System.Windows.Automation.TogglePattern]::Pattern).Toggle()
            return $true
        }
    }
    catch {}

    try {
        $Element.GetCurrentPattern([System.Windows.Automation.SelectionItemPattern]::Pattern).Select()
        return $true
    }
    catch {}

    return $false
}

function Get-UIAToggleState {
    param([System.Windows.Automation.AutomationElement]$Element)
    try {
        $p = $Element.GetCurrentPattern([System.Windows.Automation.TogglePattern]::Pattern)
        return $p.Current.ToggleState # 0=Off, 1=On, 2=Indeterminate
    }
    catch { return $null }
}




# --- SHARED UI FUNCTIONS ---

function Start-SecHealthUI {
    # Robust launch of Windows Security
    Stop-Process -Name "SecHealthUI" -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
    
    try {
        Start-Process "windowsdefender:" -ErrorAction Stop
    }
    catch {
        try {
            # Fallback: Use Explorer to launch protocol
            Start-Process "explorer.exe" -ArgumentList "windowsdefender:"
        }
        catch {
            Write-LeftAligned "$FGRed$Char_Warn Failed to launch Windows Security.$Reset"
        }
    }
    Start-Sleep -Seconds 3

}

# --- OS VALIDATION ---
function Test-IsWindows11 {
    $os = Get-CimInstance -ClassName Win32_OperatingSystem
    $build = [int]$os.BuildNumber
    if ($build -lt 22000) {
        Write-Warning "WinAuto is designed for Windows 11 (Build 22000+). Detected Build: $build."
        Write-Warning "Some features may fail."
        $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
}
Test-IsWindows11

# --- CONSOLE SETTINGS ---
function Set-ConsoleSnapRight {
    param([int]$Columns = 60)
    
    # 1. Terminal Check
    if ($env:WT_SESSION) { return }

    try {
        $code = @"
        using System;
        using System.Runtime.InteropServices;
        namespace WinAutoNative {
            [StructLayout(LayoutKind.Sequential)]
            public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
            public class ConsoleUtils {
                [DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
                [DllImport("user32.dll")] public static extern bool MoveWindow(IntPtr hWnd, int X, int Y, int nWidth, int nHeight, bool bRepaint);
                [DllImport("user32.dll")] public static extern int GetSystemMetrics(int nIndex);
                [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
                [DllImport("user32.dll")] public static extern bool SystemParametersInfo(int uiAction, int uiParam, out RECT pvParam, int fWinIni);
            }
        }
"@
        if (-not ([System.Management.Automation.PSTypeName]"WinAutoNative.ConsoleUtils").Type) {
            Add-Type -TypeDefinition $code -ErrorAction SilentlyContinue
        }
        
        $hWnd = [WinAutoNative.ConsoleUtils]::GetConsoleWindow()
        if ($hWnd -eq [IntPtr]::Zero) { return }

        $buffer = $Host.UI.RawUI.BufferSize
        $window = $Host.UI.RawUI.WindowSize
        $targetHeight = $Host.UI.RawUI.MaxWindowSize.Height
        
        # 2. Resize Logic (Safe Order)
        if ($Columns -ne $window.Width) {
            if ($Columns -lt $window.Width) {
                # Shrinking: Set Window first
                $window.Width = $Columns; $Host.UI.RawUI.WindowSize = $window
                $buffer.Width = $Columns; $Host.UI.RawUI.BufferSize = $buffer
            }
            else {
                # Growing: Set Buffer first
                $buffer.Width = $Columns; $Host.UI.RawUI.BufferSize = $buffer
                $window.Width = $Columns; $Host.UI.RawUI.WindowSize = $window
            }
        }

        if ($buffer.Height -lt $targetHeight) {
            $buffer.Height = $targetHeight
            $Host.UI.RawUI.BufferSize = $buffer
        }
        $window.Height = $targetHeight
        $Host.UI.RawUI.WindowSize = $window

        # 3. SNAP-RIGHT LOGIC
        Start-Sleep -Milliseconds 150 # Brief pause for rendering

        # Get the WorkArea (Usable screen excluding Taskbar)
        $workArea = New-Object WinAutoNative.RECT
        $SPI_GETWORKAREA = 0x0030
        if ([WinAutoNative.ConsoleUtils]::SystemParametersInfo($SPI_GETWORKAREA, 0, [ref]$workArea, 0)) {
            $waHeight = $workArea.Bottom - $workArea.Top
            
            # Get actual pixel dimensions of the current window
            $winRect = New-Object WinAutoNative.RECT
            if ([WinAutoNative.ConsoleUtils]::GetWindowRect($hWnd, [ref]$winRect)) {
                $pixelW = $winRect.Right - $winRect.Left
                
                # Target: Flush to the right edge of the work area
                $targetX = $workArea.Right - $pixelW
                $targetY = $workArea.Top
                
                # Force movement
                [WinAutoNative.ConsoleUtils]::MoveWindow($hWnd, $targetX, $targetY, $pixelW, $waHeight, $true) | Out-Null
            }
        }
    }
    catch { }
}





# --- FORMATTING HELPERS ---
function Get-VisualWidth {
    param([string]$String)
    $Width = 0
    $Chars = $String.ToCharArray()
    for ($i = 0; $i -lt $Chars.Count; $i++) {
        if ([char]::IsHighSurrogate($Chars[$i])) { $Width += 2; $i++ } else { $Width += 1 }
    }
    return $Width
}

function Add-DashLine {
    param([string]$Text = "")
    if ($Global:DashboardBufferMode) {
        $Global:DashboardBuffer += ($Text + "$Esc[K")
    } else {
        Write-Host $Text
    }
}

function Write-Centered {
    param([string]$Text, [int]$Width = 60, [string]$Color)
    $cleanText = $Text -replace "$Esc\[[0-9;]*m", ""
    $padLeft = [Math]::Floor(($Width - $cleanText.Length) / 2)
    if ($padLeft -lt 0) { $padLeft = 0 }
    if ($Color) { Add-DashLine (" " * $padLeft + "$Color$Text$Reset") }
    else { Add-DashLine (" " * $padLeft + $Text) }
}

function Write-LeftAligned {
    param([string]$Text, [int]$Indent = 2)
    Add-DashLine (" " * $Indent + $Text)
}

function Write-Boundary {
    param([string]$Color = $FGDarkBlue)
    Write-Host "  $Color$([string]'_' * 56)$Reset"
}

function Export-WinAutoCSV {
    $path = $PSScriptRoot
    if (-not $path) { $path = $PWD.Path }
    $file = Join-Path $path "scriptOUTLINE-ja.csv"
    $Global:WinAutoCSVContent | Set-Content -Path $file -Encoding UTF8 -Force
    # Invoke-Item $path # Optional: Open folder
}

# --- REGISTRY HELPERS ---
function Get-WinAutoLastRun {
    param([string]$Module)
    $path = "HKLM:\SOFTWARE\WinAuto"
    if (-not (Test-Path $path)) { return "Never" }
    $val = Get-ItemProperty -Path $path -Name "LastRun_$Module" -ErrorAction SilentlyContinue
    if ($val) { return $val."LastRun_$Module" }
    return "Never"
}

function Set-WinAutoLastRun {
    param([string]$Module)
    $path = "HKLM:\SOFTWARE\WinAuto"
    try {
        if (-not (Test-Path $path)) { New-Item -Path $path -Force | Out-Null }
        Set-ItemProperty -Path $path -Name "LastRun_$Module" -Value (Get-Date).ToString() -Force | Out-Null
    }
    catch {
        Write-Log "Failed to update LastRun for $Module : $_" -Level WARN
    }
}

function Write-Header {
    param(
        [string]$Title,
        [switch]$NoBottom
    )
    Clear-Host
    Write-Host ""
    $WinAutoTitle = "WinAuto"
    Write-Centered "$Bold$FGCyan$WinAutoTitle$Reset"
    Write-Centered "$Bold$FGCyan$($Title.ToUpper())$Reset"
    if (-not $NoBottom) {
        Write-Boundary
    }
}

function Write-Footer {
    Write-Host "  ${FGCyan}$('_' * 56)${Reset}"
    $FooterText = "$Char_Copyright 2026 www.AIIT.support"
    Write-Centered "$FGCyan$FooterText$Reset"
}

function Write-FlexLine {
    param([string]$LeftIcon, [string]$LeftText, [string]$RightText, [bool]$IsActive, [int]$Width = 60, [string]$ActiveColor = "$BGDarkGreen")
    $Circle = "*"
    if ($IsActive) {
        $LeftDisplay = "$FGGray$LeftIcon $FGGray$LeftText$Reset"
        $RightDisplay = "$ActiveColor  $Circle$Reset$FGGray$RightText$Reset  "
        $LeftRaw = "$LeftIcon $LeftText"; $RightRaw = "  $Circle$RightText  " 
    }
    else {
        $LeftDisplay = "$FGDarkGray$LeftIcon $FGDarkGray$LeftText$Reset"
        $RightDisplay = "$BGDarkGray$FGBlack$Circle  $Reset${FGDarkGray}Off$Reset "
        $LeftRaw = "$LeftIcon $LeftText"; $RightRaw = "$Circle  Off "
    }
    $SpaceCount = $Width - ($LeftRaw.Length + $RightRaw.Length + 3) - 1
    if ($SpaceCount -lt 1) { $SpaceCount = 1 }
    Write-Host ("   " + $LeftDisplay + (" " * $SpaceCount) + $RightDisplay)
}

function Write-BodyTitle {
    param([string]$Title)
    Write-LeftAligned "$FGWhite$Char_HeavyMinus $Bold$Title$Reset"
}

# --- LOGGING & REGISTRY ---
# --- LOGGING & REGISTRY ---




function Get-LogReport {
    param([string]$Path = $Global:WinAutoLogPath)
    if (-not $Path -or -not (Test-Path $Path)) { return }
    $Content = @(Get-Content -Path $Path)
    # Count visual indicators and text tags
    $Errors = @($Content | Select-String -Pattern "\[ERROR\]").Count
    $Warnings = @($Content | Select-String -Pattern "\[WARNING\]").Count
    $Successes = @($Content | Select-String -Pattern "\[SUCCESS\]").Count
    Write-Host ""
    Write-Boundary
    Write-Centered "SESSION REPORT"
    Write-Boundary
    Write-LeftAligned "Log File: $Path"
    Write-Host ""
    Write-LeftAligned "Successes     : $Successes"
    Write-LeftAligned "Warnings      : $Warnings"
    Write-LeftAligned "Errors        : $Errors"
    Write-Boundary
}



function Get-RegistryValue {
    param([string]$Path, [string]$Name)
    try {
        if (Test-Path $Path) {
            $prop = Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue
            return $prop.$Name
        }
        return $null
    }
    catch { return $null }
}

function Set-RegistryDword {
    param([string]$Path, [string]$Name, [int]$Value)
    try {
        if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
        if (Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue) {
            Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type DWord -Force | Out-Null
        }
        else {
            New-ItemProperty -Path $Path -Name $Name -PropertyType DWord -Value $Value -Force | Out-Null
        }
    }
    catch { throw $_ }
}

function Invoke-AtomicScript {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ScriptName,
        [switch]$Reverse
    )
    
    $AtomicDir = Join-Path $PSScriptRoot "AtomicScripts"
    $ScriptPath = Get-ChildItem -Path $AtomicDir -Recurse -Filter "$ScriptName.ps1" | Select-Object -First 1 -ExpandProperty FullName
    
    if ($ScriptPath) {
        Write-Log "Invoking AtomicScript: $ScriptName (Reverse: $Reverse)" "INFO"
        $params = @{}
        if ($Reverse) { $params["Reverse"] = $true }
        & $ScriptPath @params
    }
    else {
        Write-Log "AtomicScript NOT FOUND: $ScriptName" "ERROR"
        Write-Warning "AtomicScript NOT FOUND: $ScriptName"
    }
}

# --- TIMEOUT LOGIC ---
$Global:TickAction = {
    param($ElapsedTimespan, $ActionText = "CONTINUE", $Timeout = 10, $PromptCursorTop, $SelectionChar = $null, $PreActionWord = "to")
    if ($null -eq $PromptCursorTop) { $PromptCursorTop = [Console]::CursorTop }
    
    $Line = ""
    
    if ($ActionText -eq "DASHBOARD") {
        # KEYS ^ v keys | info | Esc
        $Line = "  ${Global:FGBlack}${Global:BGYellow} KEYS ${Global:Reset}  ${Global:FGBlack}${Global:BGYellow} ^ ${Global:Reset}   ${Global:FGBlack}${Global:BGYellow} v ${Global:Reset}  ${Global:FGDarkGray}|${Global:Reset}  ${Global:FGBlack}${Global:BGYellow} i ${Global:Reset}${Global:FGGray}nfo${Global:Reset}  ${Global:FGDarkGray}|${Global:Reset}  ${Global:FGBlack}${Global:BGDarkCyan} Esc ${Global:Reset}"
    }

    try { [Console]::SetCursorPosition(0, $PromptCursorTop); Write-Host $Line } catch {}
}

function Wait-KeyPressWithTimeout {
    param([int]$Seconds = 10, [scriptblock]$OnTick)
    if ($Global:Silent) { return [PSCustomObject]@{ VirtualKeyCode = 13; Character = [char]13 } }
    $StopWatch = [System.Diagnostics.Stopwatch]::StartNew()
    while ($StopWatch.Elapsed.TotalSeconds -lt $Seconds) {
        if ($OnTick) { & $OnTick $StopWatch.Elapsed }
        try {
            if ([Console]::KeyAvailable) { $StopWatch.Stop(); return $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") }
        }
        catch {
            if ([Console]::IsInputRedirected) {
                try {
                    $code = [Console]::Read()
                    if ($code -ne -1) { return [PSCustomObject]@{ Character = [char]$code; VirtualKeyCode = $code } }
                }
                catch {}
            }
            break 
        }
        Start-Sleep -Milliseconds 100
    }
    $StopWatch.Stop(); return [PSCustomObject]@{ VirtualKeyCode = 13; Character = [char]13 }
}

function Invoke-AnimatedPause {
    param([string]$ActionText = "CONTINUE", [int]$Timeout = 10, [string]$SelectionChar = $null, [string]$PreActionWord = "to", [int]$OverrideCursorTop)
    if ($Global:Silent) { return [PSCustomObject]@{ VirtualKeyCode = 13; Character = [char]13 } }
    $PromptCursorTop = if ($OverrideCursorTop) { $OverrideCursorTop } else { [Console]::CursorTop }
    if ($Timeout -le 0) {
        & $Global:TickAction -ElapsedTimespan ([timespan]::Zero) -ActionText $ActionText -Timeout 0 -PromptCursorTop $PromptCursorTop -SelectionChar $SelectionChar -PreActionWord $PreActionWord
        return $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
    $LocalTick = { param($Elapsed) & $Global:TickAction -ElapsedTimespan $Elapsed -ActionText $ActionText -Timeout $Timeout -PromptCursorTop $PromptCursorTop -SelectionChar $SelectionChar -PreActionWord $PreActionWord }
    $res = Wait-KeyPressWithTimeout -Seconds $Timeout -OnTick $LocalTick; Write-Host ""; return $res
}

# --- CONFIGURATION FUNCTIONS ---

function Get-ThirdPartyAV {
    if ($Host.Name -match "ConsoleHost" -and [Environment]::OSVersion.Platform -eq "Win32NT") {
        try {
            $av = Get-CimInstance -Namespace root/SecurityCenter2 -ClassName AntivirusProduct -ErrorAction SilentlyContinue | Where-Object { $_.displayName -notlike "*Windows Defender*" -and $_.displayName -notlike "*Microsoft Defender*" }
            return $av
        }
        catch {}
    }
    return $null
}


function Invoke-WA_SetSmartScreen {
    Write-Header "SMARTSCREEN FILTER (UIA)"
    
    # UIA Preparation
    if (-not ([System.Management.Automation.PSTypeName]"System.Windows.Automation.AutomationElement").Type) {
        try {
            Add-Type -AssemblyName UIAutomationClient
            Add-Type -AssemblyName UIAutomationTypes
        }
        catch {
            Write-LeftAligned "$FGRed$Char_RedCross Failed to load UI Automation assemblies.$Reset"
            return
        }
    }

    # 1. Launch Windows Security at App & Browser Control
    Write-LeftAligned "Opening Windows Security..."
    try { Start-Process "windowsdefender://appbrowser" -ErrorAction Stop }
    catch { try { Start-Process "explorer.exe" -ArgumentList "windowsdefender://appbrowser" } catch { Write-LeftAligned "$FGRed$Char_RedCross Failed to launch Windows Security.$Reset"; return } }
    Start-Sleep -Seconds 2

    # 2. Find Window
    $timeout = 10
    $startTime = Get-Date
    $window = $null
    
    Write-LeftAligned "Searching for 'Windows Security' window..."
    
    do {
        $desktop = [System.Windows.Automation.AutomationElement]::RootElement
        $condition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty, "Windows Security")
        $window = $desktop.FindFirst([System.Windows.Automation.TreeScope]::Children, $condition)
        if ($null -ne $window) { break }
        Start-Sleep -Milliseconds 500
    } while ((Get-Date) -lt $startTime.AddSeconds($timeout))

    if ($window) {
        Write-LeftAligned "$FGGreen$Char_HeavyCheck Window found.$Reset"
        
        # 3. Search for 'Turn on' button
        $buttonCondition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty, "Turn on")
        
        # Search Descendants (deep search)
        $button = $window.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $buttonCondition)
        
        if ($button) {
            try {
                $invokePattern = $button.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern)
                if ($invokePattern) {
                    $invokePattern.Invoke()
                    Write-LeftAligned "$FGGreen$Char_HeavyCheck Clicked 'Turn on'.$Reset"
                    Start-Sleep -Seconds 1
                }
                else {
                    Write-LeftAligned "$FGDarkYellow$Char_Warn 'Turn on' button found but not clickable.$Reset"
                }
            }
            catch {
                Write-LeftAligned "$FGRed$Char_RedCross Failed to click button: $($_.Exception.Message)$Reset"
            }
        }
        else {
            Write-LeftAligned "$FGGray No 'Turn on' button found (Already enabled?).$Reset"
        }
        
        # Close Window
        try {
            $windowPattern = $window.GetCurrentPattern([System.Windows.Automation.WindowPattern]::Pattern)
            if ($windowPattern) { $windowPattern.Close() }
        }
        catch {}
    }
    else {
        Write-LeftAligned "$FGRed$Char_RedCross Timeout waiting for Windows Security window.$Reset"
    }
}



function Invoke-WA_SetVirusThreatProtect {
    Write-Header "VIRUS & THREAT PROTECTION (UIA)"
    
    # UIA Preparation
    if (-not ([System.Management.Automation.PSTypeName]"System.Windows.Automation.AutomationElement").Type) {
        try {
            Add-Type -AssemblyName UIAutomationClient
            Add-Type -AssemblyName UIAutomationTypes
        }
        catch {
            Write-LeftAligned "$FGRed$Global:Char_RedCross Failed to load UI Automation assemblies.$Reset"
            return
        }
    }

    # 1. Launch Windows Security
    Write-LeftAligned "Opening Windows Security..."
    try { Start-Process "windowsdefender://threat" -ErrorAction Stop }
    catch { try { Start-Process "explorer.exe" -ArgumentList "windowsdefender://threat" } catch { Write-LeftAligned "$FGRed$Char_RedCross Failed to launch Windows Security.$Reset"; return } }
    Start-Sleep -Seconds 2

    # 2. Find Window
    $timeout = 10
    $startTime = Get-Date
    $window = $null

    Write-LeftAligned "Searching for 'Windows Security' window..."

    do {
        $desktop = [System.Windows.Automation.AutomationElement]::RootElement
        $condition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty, "Windows Security")
        $window = $desktop.FindFirst([System.Windows.Automation.TreeScope]::Children, $condition)
        if ($null -ne $window) { break }
        Start-Sleep -Milliseconds 500
    } while ((Get-Date) -lt $startTime.AddSeconds($timeout))

    if ($window) {
        Write-LeftAligned "$FGGreen$Global:Char_HeavyCheck Window found.$Reset"
        
        # 3. Search for 'Turn on' (or 'Restart now') button
        $targets = @("Turn on", "Restart now")
        $button = $null
        
        foreach ($t in $targets) {
            $cond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty, $t)
            $button = $window.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $cond)
            if ($button) { 
                Write-LeftAligned "$FGGreen$Global:Char_HeavyCheck Found '$t' button.$Reset"
                break 
            }
        }
        
        if ($button) {
            try {
                $invokePattern = $button.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern)
                if ($invokePattern) {
                    $invokePattern.Invoke()
                    Write-LeftAligned "$FGGreen$Global:Char_HeavyCheck Clicked button.$Reset"
                    Start-Sleep -Seconds 1
                }
                else {
                    Write-LeftAligned "$FGDarkYellow$Global:Char_Warn Button found but not clickable.$Reset"
                }
            }
            catch {
                Write-LeftAligned "$FGRed$Global:Char_RedCross Failed to click button: $($_.Exception.Message)$Reset"
            }
        }
        else {
            Write-LeftAligned "$FGGray No 'Turn on' button found (Already enabled?).$Reset"
        }
        
        # Close Window
        # Commented out to match standalone behavior - closing might interrupt the click action
        # try {
        #    $windowPattern = $window.GetCurrentPattern([System.Windows.Automation.WindowPattern]::Pattern)
        #    if ($windowPattern) { $windowPattern.Close() }
        # }
        # catch {}
    }
    else {
        Write-LeftAligned "$FGRed$Global:Char_RedCross Timeout waiting for Windows Security window.$Reset"
    }
}



# --- ATTESTATION HELPERS (Global Access) ---
function Test-Reg { param($P, $N, $V) try { (Get-ItemProperty $P $N -EA 0).$N -eq $V } catch { $false } }

function Test-WinAutoAttestation {
    # Returns $true if ALL critical configuration items are currently compliant.
    # Used by SmartRUN to force specific repairs even if "Last Run" was recent.
    
    # 1. Registry Checks (Fast)
    $s_Edge = Test-Reg "HKCU:\Software\Microsoft\Edge\SmartScreenPuaEnabled" "(default)" 1
    $s_Mem = Test-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" "Enabled" 1
    $s_Kern = Test-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\KernelShadowStacks" "Enabled" 1
    $s_LSA = Test-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" "RunAsPPL" 1
    $s_Task = Test-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" "SearchboxTaskbarMode" 3
    $s_View = Test-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowTaskViewButton" 0
    $s_MU = Test-Reg "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" "AllowMUUpdateService" 1
    $s_Rest = Test-Reg "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" "RestartNotificationsAllowed2" 1
    $s_Pers = Test-Reg "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" "RestartApps" 1
    
    # 2. Context Menu
    $ctxPath = "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32"
    $s_Ctx = $false
    if (Test-Path $ctxPath) {
        $val = (Get-ItemProperty $ctxPath)."(default)"
        if ($val -eq "") { $s_Ctx = $true }
    }
    
    # 3. Widgets Check (TaskbarDa: 0=Hidden/Compliant, 1=Visible)
    $s_Wid = Test-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarDa" 0

    # 4. WMI Checks (Real-Time & Firewall) - Critical Security
    $s_RT = $false; $s_PUA = $false; $s_FW = $false
    try { 
        $mp = Get-MpPreference -ErrorAction SilentlyContinue
        $s_RT = $mp.DisableRealtimeMonitoring -eq $false
        $s_PUA = $mp.PUAProtection -eq 1
    }
    catch { $s_RT = $true; $s_PUA = $true } 
    
    try {
        $profiles = Get-NetFirewallProfile
        $allEnabled = $true

        foreach ($fwProfile in $profiles) {
            $isEnabled = $fwProfile.Enabled -eq $true
            if (-not $isEnabled) { $allEnabled = $false }

            if ($isEnabled) {
                Write-LeftAligned "$FGGreen$Char_BallotCheck  $($fwProfile.Name) Firewall: ENABLED$Reset"
            }
            else {
                Write-LeftAligned "$FGRed$Char_RedCross  $($fwProfile.Name) Firewall: DISABLED$Reset"
            }
        }

        Write-Host ""

        # Summary status
        if ($allEnabled) {
            Write-LeftAligned "$FGGreen$Char_HeavyCheck All firewall profiles are ENABLED.$Reset"
        }
        else {
            Write-LeftAligned "$FGDarkYellow$Char_Warn One or more firewall profiles are DISABLED.$Reset"
        }
        $s_FW = $allEnabled

    }
    catch {
        Write-LeftAligned "$FGRed$Char_RedCross  Error detecting firewall state: $($_.Exception.Message)$Reset"
        $s_FW = $false
    }
    
    # Check Aggregate
    if (-not ($s_Edge -and $s_Mem -and $s_Kern -and $s_LSA -and $s_Task -and $s_View -and $s_MU -and $s_Rest -and $s_Pers -and $s_Ctx -and $s_Wid -and $s_RT -and $s_PUA -and $s_FW)) {
        return $false
    }
    return $true
}

# --- MAINTENANCE FUNCTIONS ---

function Invoke-WA_SystemPreCheck {
    Write-Header "SYSTEM PRE-FLIGHT CHECK"
    $os = Get-CimInstance Win32_OperatingSystem
    Write-LeftAligned "$FGWhite OS: $($os.Caption) ($($os.Version))$Reset"
    $uptime = (Get-Date) - $os.LastBootUpTime
    $color = & { if ($uptime.Days -gt 7) { $FGRed } else { $FGGreen } }
    Write-LeftAligned "$FGWhite Uptime: $color$($uptime.Days) days$Reset"
    
    $drive = Get-Volume -DriveLetter C
    $freeGB = [math]::Round($drive.SizeRemaining / 1GB, 2)
    $dColor = & { if ($freeGB -lt 10) { $FGRed } else { $FGGreen } }
    Write-LeftAligned "$FGWhite Free Space (C:): $dColor$freeGB GB$Reset"
    
    $pending = $false
    if (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending") { $pending = $true }
    if ($pending) { Write-LeftAligned "$FGRed$Char_Warn REBOOT PENDING$Reset" } 
    else { Write-LeftAligned "$FGGreen$Char_BallotCheck System Ready$Reset" }
    
    $res = Invoke-AnimatedPause -Timeout 5
    if ($res.VirtualKeyCode -eq 27) { throw "UserCancelled" }
}

function Invoke-WA_WindowsUpdate {
    Write-Header "WINDOWS UPDATE SCAN"

    # 1. WinGet Update (Command Line)
    Write-Centered "$Global:Char_EnDash WINGET UPDATE $Global:Char_EnDash" -Color "$Bold$FGCyan"
    if (Get-Command winget.exe -ErrorAction SilentlyContinue) {
        Write-LeftAligned "Running winget upgrade..."
        Start-Process "winget.exe" -ArgumentList "upgrade --all --include-unknown --accept-package-agreements --accept-source-agreements --silent" -Wait -NoNewWindow
    }

    Write-Host ""
    Write-Centered "$Global:Char_EnDash STORE & SETTINGS $Global:Char_EnDash" -Color "$Bold$FGCyan"

    # 2. Windows Update Settings (UIA)
    Write-LeftAligned "Opening Windows Update Settings..."
    Start-Process "ms-settings:windowsupdate"

    $desktop = [System.Windows.Automation.AutomationElement]::RootElement
    $settingsWindow = $null

    $stopWatch = [System.Diagnostics.Stopwatch]::StartNew()
    while ($stopWatch.Elapsed.TotalSeconds -lt 15) {
        # Try by Name
        $settingsWindow = Get-UIAElement -Parent $desktop -Name "Settings" -Scope "Children" -TimeoutSeconds 1
        if (-not $settingsWindow) { $settingsWindow = Get-UIAElement -Parent $desktop -Name "Windows Update" -Scope "Children" -TimeoutSeconds 1 }

        # Try by Process
        if (-not $settingsWindow) {
            $ssProc = Get-Process "SystemSettings" -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($ssProc) {
                $settingsWindow = $desktop.FindFirst([System.Windows.Automation.TreeScope]::Children, (New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ProcessIdProperty, $ssProc.Id)))
            }
        }

        if ($settingsWindow) { break }
        Start-Sleep -Milliseconds 500
    }

    if ($settingsWindow) {
        try { $settingsWindow.SetFocus() } catch {}
        Start-Sleep -Seconds 3

        $targetButtons = @(
            @{ Name = "Check for updates"; Id = "SystemSettings_MusUpdate_CheckForUpdates_Button" },
            @{ Name = "Check for updates"; Id = "SystemSettings_MicrosoftUpdate_CheckForUpdates_Button" },
            @{ Name = "Check for updates"; Id = "Check for updates" },
            @{ Name = "Download & install all"; Id = "SystemSettings_MusUpdate_DownloadAndInstallAll_Button" },
            @{ Name = "Install all"; Id = "SystemSettings_MusUpdate_InstallAll_Button" },
            @{ Name = "Restart now"; Id = "SystemSettings_MusUpdate_RestartNow_Button" },
            @{ Name = "Resume updates"; Id = "SystemSettings_MusUpdate_ResumeUpdates_Button" },
            @{ Name = "Retry all"; Id = "" },
            @{ Name = "Retry"; Id = "" },
            @{ Name = "Check updates"; Id = "" }
        )

        $buttonFound = $false

        # Priority 1: Exact AutomationId (Most reliable)
        foreach ($btnInfo in $targetButtons) {
            if ($btnInfo.Id) {
                $button = Get-UIAElement -Parent $settingsWindow -AutomationId $btnInfo.Id -Scope "Descendants" -TimeoutSeconds 1
                if ($button -and (Invoke-UIAElement -Element $button)) {
                    Write-LeftAligned "$FGGreen$Char_HeavyCheck Clicked '$($btnInfo.Name)' (ID)$Reset"
                    $buttonFound = $true; break
                }
            }
        }

        # Priority 2: Exact Name
        if (-not $buttonFound) {
            foreach ($btnInfo in $targetButtons) {
                if ($btnInfo.Name) {
                    $button = Get-UIAElement -Parent $settingsWindow -Name $btnInfo.Name -Scope "Descendants" -TimeoutSeconds 1
                    if ($button -and (Invoke-UIAElement -Element $button)) {
                        Write-LeftAligned "$FGGreen$Char_HeavyCheck Clicked '$($btnInfo.Name)' (Name)$Reset"
                        $buttonFound = $true; break
                    }
                }
            }
        }

        # Priority 3: Fuzzy search (Search for ANY button containing "update", "check", "install", or "retry")
        if (-not $buttonFound) {
            Write-LeftAligned "$FGGray Primary buttons not found. Attempting fuzzy search...$Reset"
            $allButtons = $settingsWindow.FindAll([System.Windows.Automation.TreeScope]::Descendants, (New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Button)))
            foreach ($btn in $allButtons) {
                $n = $btn.Current.Name
                if ($n -match "update" -or $n -match "check" -or $n -match "install" -or $n -match "retry") {
                    if (Invoke-UIAElement -Element $btn) {
                        Write-LeftAligned "$FGGreen$Char_HeavyCheck Clicked '$n' (Fuzzy)$Reset"
                        $buttonFound = $true; break
                    }
                }
            }
        }

        if (-not $buttonFound) { Write-LeftAligned "$FGGray No actionable buttons found in Settings.$Reset" }
    }
    else { Write-LeftAligned "$FGRed$Char_Warn Could not attach to Settings window.$Reset" }

    # 3. Microsoft Store (UIA)
    Write-LeftAligned "Opening Microsoft Store Updates..."
    Start-Process "ms-windows-store://downloadsandupdates"

    $storeWindow = Get-UIAElement -Parent $desktop -Name "Microsoft Store" -Scope "Children" -TimeoutSeconds 10

    if ($storeWindow) {
        try { $storeWindow.SetFocus() } catch {}
        Start-Sleep -Seconds 2

        $buttonTexts = @("Get updates", "Check for updates", "Update all")
        $buttonFound = $false
        foreach ($buttonText in $buttonTexts) {
            $button = Get-UIAElement -Parent $storeWindow -Name $buttonText -Scope "Descendants" -TimeoutSeconds 2
            if ($button -and (Invoke-UIAElement -Element $button)) {
                Write-LeftAligned "$FGGreen$Char_HeavyCheck Clicked '$buttonText'$Reset"
                $buttonFound = $true; break
            }
        }
        if (-not $buttonFound) { Write-LeftAligned "$FGGray No update button found in Store.$Reset" }
    }
    else { Write-LeftAligned "$FGRed$Char_Warn Could not attach to Store window.$Reset" }

    Write-Host ""
    Start-Sleep -Seconds 3
}




# --- MODULE HANDLERS ---

function Invoke-WinAutoConfiguration {
    param([switch]$SmartRun)
    Write-Header "WINDOWS CONFIGURATION PHASE"
    $lastRun = Get-WinAutoLastRun -Module "Configuration"
    Write-LeftAligned "$FGGray Last Run: $FGWhite$lastRun$Reset"

    $SkipConfig = $false

    if ($SmartRun -and $lastRun -ne "Never") {
        # Check 30-day freshness
        $lastDate = Get-Date $lastRun
        if ((Get-Date) -lt $lastDate.AddDays(30)) {
            # TIME SAYS SKIP, BUT WE MUST AUDIT COMPLIANCE
            # If Attestation passes, we can safely skip REGISTRY items.
            Write-LeftAligned "$FGGray History valid. verifying system compliance..."
            if (Test-WinAutoAttestation) {
                Write-LeftAligned "$FGGreen$Global:Char_CheckMark System Compliant. Skipping Core Configuration...$Reset"
                $SkipConfig = $true
            }
            else {
                Write-LeftAligned "$FGRed$Global:Char_Warn DRIFT DETECTED. Forcing Re-Configuration.$Reset"
            }
        }
    }
    Write-Boundary

    if (-not $SkipConfig) {
        # Core Security (External AtomicScripts)
        Invoke-AtomicScript -ScriptName "SET_MemoryInteg"
        Invoke-AtomicScript -ScriptName "SET_RealTimeProt"
        Invoke-AtomicScript -ScriptName "SET_PUABlockApps"
        Invoke-AtomicScript -ScriptName "SET_PUABlockDLs"
        Invoke-AtomicScript -ScriptName "SET_LocalSecurity"
        Invoke-AtomicScript -ScriptName "SET_FirewallON"
        Invoke-AtomicScript -ScriptName "SET_KernelMode"
    }
    
    # UIA Remediation Steps (Only run if detected as disabled to minimize window popping, unless in Manual Mode)
    $runRT = -not $SmartRun
    $runSS = -not $SmartRun

    if ($SmartRun) {
        try {
            $mp = Get-MpPreference -ErrorAction SilentlyContinue
            if ($mp.DisableRealtimeMonitoring -eq $true) { $runRT = $true }
            if ($mp.EnableSmartScreen -eq $false) { $runSS = $true }
        }
        catch { $runRT = $true; $runSS = $true }
    }

    if ($runSS) { Invoke-AtomicScript -ScriptName "SET_SmartScreenFilter" }
    if ($runRT) { Invoke-AtomicScript -ScriptName "UIA_VirusThreatON" }
    
    if (-not $SkipConfig) {
        # UI & Performance (External AtomicScripts)
        Invoke-AtomicScript -ScriptName "SET_ClassicMenu"
        Invoke-AtomicScript -ScriptName "SET_TaskbarSearch"
        Invoke-AtomicScript -ScriptName "SET_TaskViewOFF"
        
        # Updates & Persistence
        Invoke-AtomicScript -ScriptName "SET_MicrosoftUpd"
        Invoke-AtomicScript -ScriptName "SET_RestartIsReq"
        Invoke-AtomicScript -ScriptName "SET_RestartApps"
    
        # Restart Explorer to force refresh of Taskbar/Start Menu registry settings (Standard UI changes)
        Write-LeftAligned "Restarting Explorer to apply UI settings..."
        Invoke-AtomicScript -ScriptName "RUN_RestartExplorer"
    }
    
    Write-Boundary
    Write-Centered "$FGGreen CONFIGURATION COMPLETE $Reset"
    Set-WinAutoLastRun -Module "Configuration"
    Start-Sleep -Seconds 2
}

function Invoke-WinAutoMaintenance {
    param([switch]$SmartRun)
    Write-Header "WINDOWS MAINTENANCE PHASE"
    $lastRun = Get-WinAutoLastRun -Module "Maintenance"
    Write-LeftAligned "$FGGray Last Run: $FGWhite$lastRun$Reset"
    
    function Test-RunNeeded {
        param($Key, $Days)
        if (-not $SmartRun) { return $true }
        $last = Get-WinAutoLastRun -Module $Key
        if ($last -eq "Never") { return $true }
        $date = Get-Date $last
        if ((Get-Date) -gt $date.AddDays($Days)) { return $true }
        Write-LeftAligned "$FGGreen$Global:Char_CheckMark Skipping $Key (Run < $Days days ago).$Reset"
        return $false
    }

    try {
        Write-Boundary
        Invoke-WA_SystemPreCheck
    
        if (Test-RunNeeded -Key "Maintenance_SFC" -Days 30) {
            Invoke-AtomicScript -ScriptName "RUN_WindowsRepair"
            Set-WinAutoLastRun -Module "Maintenance_SFC"
        }
    
        if (Test-RunNeeded -Key "Maintenance_Disk" -Days 7) {
            Invoke-AtomicScript -ScriptName "RUN_OptimizeDisks"
            Set-WinAutoLastRun -Module "Maintenance_Disk"
        }
    
        if (Test-RunNeeded -Key "Maintenance_Cleanup" -Days 7) {
            Invoke-AtomicScript -ScriptName "RUN_SystemCleanup"
            Set-WinAutoLastRun -Module "Maintenance_Cleanup"
        }
    
        # Run Windows Update Action (Skip if run in last 24 hours)
        if (Test-RunNeeded -Key "Maintenance_WinUpdate" -Days 1) {
            Invoke-AtomicScript -ScriptName "RUN_WindowsUpdateUIA"
            Set-WinAutoLastRun -Module "Maintenance_WinUpdate"
        }

        Write-Host ""
        Write-Centered "$FGGreen MAINTENANCE COMPLETE $Reset"
        Set-WinAutoLastRun -Module "Maintenance"
        Start-Sleep -Seconds 2
    }
    catch {
        if ($_.Exception.Message -eq "UserCancelled") {
            Write-LeftAligned "$FGGray Operation Cancelled by User.$Reset"
            Start-Sleep -Seconds 1
        }
        else { throw $_ }
    }
}


# --- DELEGATED ATOMIC SCRIPTS ---
# State-changing logic has been moved to standalone scripts in the .\AtomicScripts directory.
# This orchestrator now calls those scripts via the Invoke-AtomicScript helper.

function Get-WinAutoLastRun {
    param([string]$Module)
    $path = "HKLM:\SOFTWARE\WinAuto"
    if (-not (Test-Path $path)) { return "Never" }
    $val = Get-ItemProperty -Path $path -Name "LastRun_$Module" -ErrorAction SilentlyContinue
    if ($val) { return $val."LastRun_$Module" }
    return "Never"
}

function Set-WinAutoLastRun {
    param([string]$Module)
    $path = "HKLM:\SOFTWARE\WinAuto"
    try {
        if (-not (Test-Path $path)) { New-Item -Path $path -Force | Out-Null }
        Set-ItemProperty -Path $path -Name "LastRun_$Module" -Value (Get-Date).ToString() -Force | Out-Null
    }
    catch {
        Write-Log "Failed to update LastRun for $Module : $_" -Level WARN
    }
}

function Write-Footer {
    Write-Host "${FGCyan}$('_' * 60)${Reset}"
    $FooterText = "$Char_Copyright 2026 www.AIIT.support"
    Write-Centered "$FGCyan$FooterText$Reset"
}

function Test-WA_MaintenanceRecentlyComplete {
    # Check if all maintenance tasks were run within their thresholds
    $tasks = @(
        @{ Key = "Maintenance_SFC"; Days = 30 },
        @{ Key = "Maintenance_Disk"; Days = 7 },
        @{ Key = "Maintenance_Cleanup"; Days = 7 },
        @{ Key = "Maintenance_WinUpdate"; Days = 1 }
    )
    foreach ($task in $tasks) {
        $last = Get-WinAutoLastRun -Module $task.Key
        if ($last -eq "Never") { return $false }
        try {
            $date = Get-Date $last
            if ((Get-Date) -gt $date.AddDays($task.Days)) { return $false }
        }
        catch { return $false }
    }
    return $true
}

# --- MAIN EXECUTION ---
# Ensure log directory exists
if (-not (Test-Path $Global:WinAutoLogDir)) { New-Item -Path $Global:WinAutoLogDir -ItemType Directory -Force | Out-Null }
Write-Log "WinAuto Standalone Session Started" -Level INFO

# --- CLI CONTROLLER ---
if ($Silent -or $Module) {
    if ($Module) { Write-Log "Starting CLI Mode (Module: $Module)" }
    else { Write-Log "Starting CLI Mode (Silent Default)" }

    if (-not $Module -and $Silent) { $Module = "SmartRun" }

    switch ($Module) {
        "SmartRun" { 
            Invoke-WinAutoConfiguration -SmartRun
            Invoke-WinAutoMaintenance -SmartRun
        }
        "Config" { Invoke-WinAutoConfiguration }
        "Maintenance" { Invoke-WinAutoMaintenance }
        "Help" { Write-Host $Global:WinAutoManifestContent; exit 0 }
    }
    
    Write-Log "CLI Execution Complete."
    return
}

Set-ConsoleSnapRight -Columns 60


$MenuSelection = 0  # 0=Smart, 1=Config, 2=Maintenance
# Per-section expansion flags



$Global:WinAutoFirstLoad = $true

while ($true) {
    # Config
    $lastConfigRun = Get-WinAutoLastRun -Module "Configuration"
    $configSkipped = $false
    if ($lastConfigRun -ne "Never") {
        $lastConfigDate = Get-Date $lastConfigRun
        if ((Get-Date) -lt $lastConfigDate.AddDays(30)) {
            $configSkipped = $true
            $Global:AnySkipped = $true 
        }
    }
    
    # Maintain
    $Global:MaintenanceComplete = Test-WA_MaintenanceRecentlyComplete
    if ($Global:MaintenanceComplete) { $Global:AnySkipped = $true }

    $manualHeaderColor = if ($MenuSelection -eq 0) { $FGDarkGray } else { $FGDarkCyan }

    $Global:DashboardBufferMode = $true
    $Global:DashboardBuffer = @()

    if ($Global:WinAutoFirstLoad) {
        Clear-Host
    } else {
        [Console]::SetCursorPosition(0,0)
    }
    
    Add-DashLine ""
    Write-Centered "$Bold${FGCyan} - WinAuto - $Reset"
    Write-Boundary -Color $FGCyan
    if ($MenuSelection -eq 0) {
        # Align with 56-char boundary lines (2 space indent + 56 char block)
        Add-DashLine "  ${FGBlack}${BGYellow}                        SmartRUN                        ${Reset}"
    }
    else {
        Write-Centered "${FGDarkGray}SmartRUN${Reset}"
    }
    
    # SmartRUN Indicators
    $cConf = if (-not $configSkipped) { $FGCyan } else { $FGDarkGray }
    $cMaint = if (-not $Global:MaintenanceComplete) { $FGCyan } else { $FGDarkGray }
    Write-Centered "${cConf}Configure${Reset} ${FGDarkGray}|${Reset} ${cMaint}Maintain${Reset}"



    Add-DashLine ""

    Add-DashLine ""
    Add-DashLine ""


    
    # SmartRun Details lines with Hotkeys
    
    # Header Line

    # Logic to Determine Skip State for Config
    # Logic to Determine Skip State for Config



    if ($MenuSelection -eq 1) {
        Write-Host "  ${Global:FGBlack}${Global:BGYellow}___________________MANUAL MODE_________________${Global:Reset}"
    }
    else {
        Write-Host "  ${Global:FGBlack}${Global:BGDarkGray}_________________MANUAL-MODE-OFF_______________${Global:Reset}"
    }
    Write-Boundary # Separator

    # Configure Operating System (Pos 1) - MANUAL-MODE
    if ($MenuSelection -eq 1) {
        Write-Host "  ${FGBlack}${BGYellow}               Configure Operating System               ${Reset}"
    }
    else {
        Write-Centered "${manualHeaderColor}|${Reset} ${manualHeaderColor}Configure Operating System${Reset} ${manualHeaderColor}|${Reset}"
    }
    Add-DashLine ""
    
    $cTopColor = if ($MenuSelection -eq 1) { $FGYellow } else { $FGWhite }
    Write-LeftAligned "${FGDarkGray}[${cTopColor}>${FGDarkGray}] ${cTopColor}ENABLE / ${FGDarkGray}[${FGDarkGreen}v${FGDarkGray}] ${cTopColor}ENABLED        ${FGDarkGray}|${cTopColor} ATOMIC_SCRIPT$Reset" -Indent 3
    Write-Centered "${FGDarkGray}--------------------------------------------------------$Reset"
    
    # Config Details
    $cDetailColor = if ($MenuSelection -eq 1) { $FGGray } else { $FGDarkGray }
    
    # Helper to print item with status
    function Write-ColItem {
        param($Txt, $Met, $Status) 
        # Status: $true (Green 1), $false (Red 0), $null (Gray ?), "GreyOut" (DarkGray [ ])
        
        if ("GreyOut" -eq $Status) {
            $icon = "${FGDarkGray}[ ]${Reset}"
            $pad = " " * (28 - $Txt.Length); 
            Write-LeftAligned "$icon ${FGDarkGray}$Txt${Reset}$pad${FGDarkGray}| ${FGDarkGray}$Met${Reset}" -Indent 3  
        }
        elseif ("ForceRun" -eq $Status) {
            $icon = "${FGDarkGray}[${FGWhite}>${FGDarkGray}]${Reset}"
            $pad = " " * (28 - $Txt.Length); 
            Write-LeftAligned "$icon ${FGGray}$Txt${Reset}$pad${FGDarkGray}| ${FGGray}$Met${Reset}" -Indent 3  
        }
        else {
            $icon = if ($null -eq $Status) { "${FGDarkGray}[?]${Reset}" } elseif ($Status) { "${FGDarkGray}[${FGDarkGreen}v${FGDarkGray}]${Reset}" } else { "${FGDarkGray}[${cTopColor}>${FGDarkGray}]${Reset}" }
            $pad = " " * (28 - $Txt.Length); 
            Write-LeftAligned "$icon ${cDetailColor}$Txt${Reset}$pad${FGDarkGray}| ${cDetailColor}$Met${Reset}" -Indent 3  
        }
    }
    
    # --- LIVE STATUS CHECKS (Lightweight) ---
    $s_RT = $null; $s_PUA = $null; $s_FW = $null
    # if ($MenuSelection -eq 2) {
    # Always run checks for accurate dashboard
    try { 
        $av = Get-ThirdPartyAV
        $mp = Get-MpPreference -ErrorAction SilentlyContinue

        if ($av) {
            $s_RT = "GreyOut"
        }
        else {
            $s_RT = $mp.DisableRealtimeMonitoring -eq $false
        }

        if ($mp.PUAProtection -eq 1) {
            $s_PUA = $true
        }
        else {
            $s_PUA = "GreyOut"
        }
    }
    catch { 
        $s_RT = $false; $s_PUA = $false 
        Write-Log "Failed to query Defender Preferences via WMI: $($_.Exception.Message)" -Level WARN
    }
    
    try {
        $profiles = Get-NetFirewallProfile
        $allEnabled = $true

        foreach ($fwProfile in $profiles) {
            $isEnabled = $fwProfile.Enabled -eq $true
            if (-not $isEnabled) { $allEnabled = $false }
        }

        $s_FW = $allEnabled
    }
    catch { 
        $s_FW = $false 
        Write-Log "Failed to query Firewall Profiles: $($_.Exception.Message)" -Level WARN
    }

    # }
    
    # Registry Checks (Fast)
    function Test-Reg { param($P, $N, $V) try { (Get-ItemProperty $P $N -EA 0).$N -eq $V } catch { $false } }
    
    $s_Edge = "ForceRun"
    $s_Mem = Test-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" "Enabled" 1
    $s_Kern = Test-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\KernelShadowStacks" "Enabled" 1
    $s_LSA = Test-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" "RunAsPPL" 1
    $s_Task = Test-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" "SearchboxTaskbarMode" 3
    $s_View = Test-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowTaskViewButton" 0
    $s_MU = Test-Reg "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" "AllowMUUpdateService" 1
    $s_Rest = Test-Reg "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" "RestartNotificationsAllowed2" 1
    $s_Pers = Test-Reg "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Winlogon" "RestartApps" 1
    

    # Classic Context Menu Check (InprocServer32 Default Value must be empty string)
    $ctxPath = "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32"
    $s_Ctx = $false
    if (Test-Path $ctxPath) {
        $val = (Get-ItemProperty $ctxPath)."(default)"
        if ($val -eq "") { $s_Ctx = $true }
    }
    
    # --- LIVE WMI CHECKS ---


    Write-ColItem "Real-Time Protection" "SET_RealTimeProt.ps1" $s_RT
    Write-ColItem "PUA Protection" "SET_DefenderPUA.ps1" $s_PUA
    Write-ColItem "PUA Protection (Edge)" "SET_EdgePUA.ps1" $s_Edge
    Write-ColItem "Memory Integrity" "SET_MemoryInteg.ps1" $s_Mem
    Write-ColItem "Kernel Stack Protection" "SET_KernelMode.ps1" $s_Kern
    Write-ColItem "LSA Protection" "SET_LocalSecurity.ps1" $s_LSA
    Write-ColItem "Windows Firewall" "SET_FirewallON.ps1" $s_FW
    Write-ColItem "Classic Context Menu" "SET_ClassicMenu.ps1" $s_Ctx
    Write-ColItem "Taskbar Search Box" "SET_TaskbarSearch.ps1" $s_Task
    Write-ColItem "Task View Toggle" "SET_TaskViewOFF.ps1" $s_View

    Write-ColItem "Microsoft Update Service" "SET_MicrosoftUpd.ps1" $s_MU
    Write-ColItem "Restart Notifications" "SET_RestartIsReq.ps1" $s_Rest
    Write-ColItem "App Restart Persistence" "SET_RestartApps.ps1" $s_Pers
    
    Add-DashLine ""
    
    

    
    Write-Boundary # Separator

    # Maintenance sub-section (inline under MANUAL-MODE)
    Write-Boundary # Separator between Config and Maintain items
    Write-Centered "${manualHeaderColor}Maintain Operating System${Reset}"
    Add-DashLine ""
    
    # Maintenance Details
    $mDetailColor = if ($MenuSelection -eq 1) { $FGGray } else { $FGDarkGray }
    
    function Write-MaintItem {
        param($Txt, $Met, $Key, [int]$Threshold = 7) 
        $prefix = "-"
        $statusColor = $mDetailColor
        if ($Key) {
            $last = Get-WinAutoLastRun -Module $Key
            if ($last -eq "Never") { $prefix = "!"; $statusColor = $FGDarkRed }
            else {
                try {
                    $days = ((Get-Date) - (Get-Date $last)).Days
                    $prefix = $days
                    if ($days -eq 0 -or $days -le $Threshold) { $statusColor = $FGDarkGreen } else { $statusColor = $FGDarkRed }
                }
                catch { $prefix = "!"; $statusColor = $FGDarkRed }
            }
        }
        $pad = " " * (28 - $Txt.Length); 
        Write-LeftAligned "${FGDarkGray}[${statusColor}$prefix${FGDarkGray}]${mDetailColor} $Txt${Reset}$pad${FGDarkGray}| ${mDetailColor}$Met${Reset}" -Indent 3  
    }

    $mTopColor = if ($MenuSelection -eq 1) { $FGYellow } else { $FGWhite }
    Write-LeftAligned "${FGDarkGray}[${mTopColor}#${FGDarkGray}]${mTopColor} OF DAYS SINCE LAST RUN      ${FGDarkGray}|${mTopColor} ATOMIC_SCRIPT$Reset" -Indent 3
    Write-Centered "${FGDarkGray}--------------------------------------------------------$Reset"
    Write-MaintItem "Get Updates" "RUN_UpdateSuite.ps1" "Maintenance_WinUpdate" -Threshold 1
    Write-MaintItem "Drive Optimization" "RUN_OptimizeDisks.ps1" "Maintenance_Disk" -Threshold 7
    Write-MaintItem "Temp File Cleanup" "RUN_SystemCleanup.ps1" "Maintenance_Cleanup" -Threshold 7
    Write-MaintItem "SFC / DISM Repair" "RUN_WindowsRepair.ps1" "Maintenance_SFC" -Threshold 30

    Add-DashLine ""
    Add-DashLine ""
    Write-Boundary -Color $FGYellow

    if ($Global:DashboardBufferMode) {
        Write-Host ($Global:DashboardBuffer -join "`n")
        $Global:DashboardBufferMode = $false
    }

    $PromptRow = [Console]::CursorTop
    
    # Dynamic Footer Prompt Logic (Standard View Only now)
    $Act = "DASHBOARD"
    $Sel = $null
    $Pre = ""

    # Timeout logic: Only on first load
    $ActionText = "DASHBOARD" # Unused variable but kept for readability if referenced elsewhere
    $TimeoutSecs = 0
    if ($Global:WinAutoFirstLoad) {
        $TimeoutSecs = 5
        $Global:WinAutoFirstLoad = $false
    }

    $res = Invoke-AnimatedPause -ActionText $Act -Timeout $TimeoutSecs -SelectionChar $Sel -PreActionWord $Pre -OverrideCursorTop $PromptRow

    # --- NAVIGATION LOGIC ---
    if ($res.VirtualKeyCode -eq 38) {
        # Up
        $MenuSelection--
        if ($MenuSelection -lt 0) { $MenuSelection = 1 }
        continue
    }
    elseif ($res.VirtualKeyCode -eq 40) {
        # Down
        $MenuSelection++
        if ($MenuSelection -gt 1) { $MenuSelection = 0 }
        continue
    }
    elseif ($res.VirtualKeyCode -eq 39) {
        # Right (Visual Feedback or expand logic if we had distinct expansions, keeping placeholder)
        continue
    }
    elseif ($res.VirtualKeyCode -eq 37) {
        # Left
        continue
    }
    
    if ($res.VirtualKeyCode -eq 27) {
        # Esc or X -> Exit
        Write-LeftAligned "$FGGray Exiting - WinAuto -...$Reset"
        Start-Sleep -Seconds 1
        break
    }
    elseif ($res.VirtualKeyCode -eq 13) {
        # Enter Handling (Mapped to Spacebar logic logic effectively, or just loop if user insists on space)
        # We will ignore Enter or treat it as Space to be safe, but Space is the primary.
        $res.Character = ' '
        $res.VirtualKeyCode = 32
    }
    

    
    if ($res.Character -eq ' ' -or $res.VirtualKeyCode -eq 32) {
        # Space Action Logic (Context Sensitive)
        $Target = $MenuSelection
        
        # GLOBAL: Run Windows Update Check FIRST
        # Invoke-WA_WindowsUpdate (Moved to Maintenance Phase)
        
        if ($Target -eq 0) {
            # [S]mart Run -> EXECUTE
            Invoke-WinAutoConfiguration -SmartRun
            Set-WinAutoLastRun -Module "Configuration"
            if (-not $Global:MaintenanceComplete) { Invoke-WinAutoMaintenance -SmartRun }
        }
        elseif ($Target -eq 1) {
            # MANUAL-MODE -> Run Configure + Maintain, all steps forced (no SmartRun)
            Invoke-WinAutoConfiguration
            Set-WinAutoLastRun -Module "Configuration"
            Invoke-WinAutoMaintenance
        }
        
        # Pause slightly if we toggled, or if we ran (though ran usually has its own pauses)
        Start-Sleep -Milliseconds 200
        continue
    }
    elseif ($res.Character -eq 'I' -or $res.Character -eq 'i') {
        Clear-Host
        Write-Host ""
        Write-Centered "$Bold$FGCyan - WinAuto - $Reset"
        Write-Boundary -Color $FGCyan
        Write-Centered "$Bold$FGCyan SmartRUN - Reference Map $Reset"
        Write-Host ""
        # Display manifest with body lines in DarkGray
        $Global:WinAutoManifestContent -split "`n" | ForEach-Object {
            $line = $_.TrimEnd()
            if ($line -match "wa\.ps1: Functional Outline") {
                Write-Centered $line
            }
            elseif ($line.Trim() -match "^-") {
                Write-Host $line
            }
            else {
                Write-Host $line
            }
        }
        Write-Host ""
        Write-Host "  ${Global:FGBlack}${Global:BGYellow} Enter ${Global:Reset} ${Global:FGGray}to export CSV${Global:Reset}  ${Global:FGDarkGray}|${Global:Reset}  ${Global:FGBlack}${Global:BGYellow} Esc ${Global:Reset} ${Global:FGGray}to return${Global:Reset}"
        while ($true) {
            $mk = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            if ($mk.Character -eq ' ' -or $mk.VirtualKeyCode -eq 32 -or $mk.Character -eq 'I' -or $mk.Character -eq 'i') { break }
            if ($mk.VirtualKeyCode -eq 27) { 
                # Esc pressed - return to dashboard
                break
            }
            if ($mk.VirtualKeyCode -eq 13) {
                # Enter pressed - export CSV
                Export-WinAutoCSV
                Write-Centered "$FGGreen Exported CSV to Script Directory! $Reset"
                Start-Sleep -Seconds 2
            }
        }
    }
    else {
        # Any other key loop back
        Start-Sleep -Milliseconds 100
        continue
    }
}

# Get-LogReport
Write-Host ""
Write-Footer
# Invoke-AnimatedPause -ActionText "EXIT" -Timeout 0 | Out-Null
Write-Host ""
Write-Centered "Copyright (c) 2026 WinAuto"
Write-Host ""

