#Requires -RunAsAdministrator
<#
.SYNOPSIS
    WinAuto (Core Edition)
.DESCRIPTION
    A lightweight, single-file version of the WinAuto suite for Windows 11.
    Focuses purely on Configuration (Security/UI) and Maintenance (Updates/Repair).
    
    Usage: Copy and paste this script into an Administrator PowerShell window.
#>

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
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$Global:ShowDetails = $false
$Global:WinAutoFirstLoad = $true

$Global:RegPath_WU_UX = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings"
$Global:RegPath_WU_POL = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
$Global:RegPath_Winlogon_User = "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" 
$Global:RegPath_Winlogon_Machine = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"

# --- MANIFEST CONTENT ---

$Global:WinAutoManifestContent = @'
- wa.ps1: Functional Outline -
________________________________________________________
Pre-Run Setup                 | SOURCE SCRIPT
- Execution Policy            | (Inline Logic)
- Auto-Unblock                | (Inline Logic)
________________________________________________________
Smart Run                     | SOURCE SCRIPT
Method: Orchestration Loop
Actions:
- System Hardening Check      | CHECK_SystemHardening
  - Runs checks for Secure Boot, TPM, BitLocker
- Maintenance Cycle           | SET_ScheduleMaintenance
  - Schedules maintenance task in Task Scheduler
________________________________________________________
Install                       | SOURCE SCRIPT
- Install Applications        | Install_Apps-wa.json
  - Iterates through apps list in JSON config
________________________________________________________
Configuration                 | SOURCE SCRIPT
Security Actions:
- Real-Time Protection        | SET_RealTimeProtection
- PUA Protection              | SET_DefenderPUA
- PUA Protection (Edge)       | SET_EdgePUA
- Memory Integrity            | SET_MemoryIntegrity_Reg
- Kernel Stack Protection     | SET_KernelMode_Reg
- LSA Protection              | SET_LocalSecurityAuth
- Windows Firewall            | SET_FirewallON
UI & User Experience Actions:
- Taskbar Search Box          | SET_TaskbarSearchIcon
- Task View Toggle            | SET_DisableTaskView
- Widgets Toggle              | SET_WidgetsUIA
- Microsoft Update Service    | SET_MicrosoftUpdate
- Restart Notifications       | SET_RestartIsRequired
- App Restart Persistence     | SET_ToggleRestartApps
________________________________________________________
Maintenance                   | SOURCE SCRIPT
Application Maintenance:
- WinGet App Updates          | RUN_WingetUpgrade
  - Checks for and updates all apps via WinGet
Disk Maintenance:
- Drive Optimization (TRIM)   | RUN_OptimizeDisks
- Temp File Cleanup           | RUN_SystemCleanup
  - Clears Windows Temp, User Temp, Prefetch
OS Repair & Updates:
- SFC / DISM Repair           | RUN_WindowsSFCRepair
  - Runs DISM scan/repair first, then SFC scan
________________________________________________________
'@

$Global:WinAutoCSVContent = @'
Stage,Step,Method,Technical Details,SOURCE SCRIPT,Function
Pre-Run Setup,Execution Policy / Admin Check,Inline,Set-ExecutionPolicy RemoteSigned -Scope Process,wa.ps1,(Script Header)
Pre-Run Setup,Auto-Unblock,Inline,Unblock-File (Self),wa.ps1,(Script Header)
Smart Run,System Hardening Check,Mixed,Runs checks for Secure Boot; TPM; BitLocker,CHECK_SystemHardening.ps1,Invoke-WinAutoConfiguration -SmartRun
Smart Run,Maintenance Cycle,Mixed,Schedules maintenance task in Task Scheduler,SET_ScheduleMaintenance.ps1,Invoke-WinAutoMaintenance -SmartRun
Install,Install Applications,Mixed,Iterates through apps list in JSON config,Install_Apps-wa.json,Invoke-WA_InstallApps
Configuration,Real-Time Protection,PS WMI,Set-MpPreference -DisableRealtimeMonitoring 0,SET_RealTimeProtection.ps1,Invoke-WA_SetRealTimeProtection
Configuration,PUA Protection,PS WMI,Set-MpPreference -PUAProtection 1,SET_DefenderPUA.ps1,Invoke-WA_SetPUA
Configuration,PUA Protection (Edge),Registry (HKCU),HKCU:\Software\Microsoft\Edge\SmartScreenPuaEnabled,SET_EdgePUA.ps1,Invoke-WA_SetPUA
Configuration,Memory Integrity,Registry (HKLM),HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity (Enabled=1),SET_MemoryIntegrity_Reg.ps1,Invoke-WA_SetMemoryIntegrity
Configuration,Kernel Stack Protection,Registry (HKLM),HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\KernelShadowStacks (Enabled=1),SET_KernelMode_Reg.ps1,Invoke-WA_SetKernelStack
Configuration,LSA Protection,Registry (HKLM),HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\RunAsPPL,SET_LocalSecurityAuth.ps1,Invoke-WA_SetLSA
Configuration,Windows Firewall,PS Cmdlet,Set-NetFirewallProfile -Enabled True,SET_FirewallON.ps1,Invoke-WA_SetFirewall
Configuration,Taskbar Search Box,Registry (HKCU),HKCU:\Software\Microsoft\Windows\CurrentVersion\Search\SearchboxTaskbarMode (3),SET_TaskbarSearchIcon.ps1,Invoke-WA_SetTaskbarDefaults
Configuration,Task View Toggle,Registry (HKCU),HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\ShowTaskViewButton (0),SET_DisableTaskView.ps1,Invoke-WA_SetTaskbarDefaults
Configuration,Widgets Toggle,UI Automation,Settings -> Taskbar -> Widgets Toggle,SET_WidgetsUIA.ps1,Invoke-WA_SetTaskbarDefaults
Configuration,Microsoft Update Service,Registry (HKLM),HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings\AllowMUUpdateService,SET_MicrosoftUpdate.ps1,Invoke-WA_SetWindowsUpdateConfig
Configuration,Restart Notifications,Registry (HKLM),HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings\RestartNotificationsAllowed2,SET_RestartIsRequired.ps1,Invoke-WA_SetWindowsUpdateConfig
Configuration,App Restart Persistence,Registry (HKCU),HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\RestartApps,SET_ToggleRestartApps.ps1,Invoke-WA_SetWindowsUpdateConfig
Maintenance,WinGet App Updates,CMD Line,Checks for and updates all apps via WinGet,RUN_WingetUpgrade.ps1,Invoke-WA_WindowsUpdate
Maintenance,Drive Optimization (TRIM),PS Cmdlet,Optimize-Volume -DriveLetter C -NormalPriority,RUN_OptimizeDisks.ps1,Invoke-WA_OptimizeDisks
Maintenance,Temp File Cleanup,File System,Clears Windows Temp; User Temp; Prefetch,RUN_SystemCleanup.ps1,Invoke-WA_SystemCleanup
Maintenance,SFC / DISM Repair,CMD Line,Runs DISM scan/repair first; then SFC scan,RUN_WindowsSFCRepair.ps1,Invoke-WA_SFCRepair
'@

# --- GLOBAL RESOURCES ---
# Centralized definition of ANSI colors and Unicode characters.

# --- ANSI Escape Sequences ---
$Esc = [char]0x1B
$Global:Reset = "$Esc[0m"
$Global:Bold = "$Esc[1m"

# Script Palette (Foreground)
$Global:FGCyan = "$Esc[96m"
$Global:FGDarkBlue = "$Esc[34m"
$Global:FGGreen = "$Esc[92m"
$Global:FGRed = "$Esc[91m"
$Global:FGYellow = "$Esc[93m"
$Global:FGDarkGray = "$Esc[90m"
$Global:FGDarkRed = "$Esc[31m"
$Global:FGDarkGreen = "$Esc[32m"


$Global:FGWhite = "$Esc[97m"
$Global:FGGray = "$Esc[37m"
$Global:FGDarkYellow = "$Esc[33m"
$Global:FGBlack = "$Esc[30m"

# Script Palette (Background)
$Global:BGDarkGreen = "$Esc[42m"
$Global:BGDarkGray = "$Esc[100m"
$Global:BGYellow = "$Esc[103m"
$Global:BGRed = "$Esc[41m"
$Global:BGWhite = "$Esc[107m"

# --- Unicode Icons & Characters ---
$Global:Char_HeavyCheck = "[v]" 
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

# --- SYSTEM PATHS ---
if ($null -eq (Get-Variable -Name 'WinAutoLogDir' -Scope Global -ErrorAction SilentlyContinue)) {
    $Global:WinAutoLogDir = "$env:ProgramData\WinAuto\Logs"
    if (-not (Test-Path $Global:WinAutoLogDir)) { New-Item -ItemType Directory -Force -Path $Global:WinAutoLogDir | Out-Null }
}
$env:WinAutoLogDir = $Global:WinAutoLogDir

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
        [System.Windows.Automation.ControlType]$ControlType,
        [System.Windows.Automation.TreeScope]$Scope = [System.Windows.Automation.TreeScope]::Descendants,
        [int]$TimeoutSeconds = 5
    )
    
    $Condition = if ($Name -and $ControlType) {
        $c1 = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty, $Name)
        $c2 = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, $ControlType)
        New-Object System.Windows.Automation.AndCondition($c1, $c2)
    }
    elseif ($Name) {
        New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty, $Name)
    }
    elseif ($ControlType) {
        New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, $ControlType)
    }
    else {
        return $null
    }

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

function Get-WA_LibraryScript {
    param([string]$ScriptName)
    $Locs = @()
    if ($PSScriptRoot) { $Locs += $PSScriptRoot }
    $Locs += (Get-Location).Path
    $Locs += "C:\Users\admin\GitHub\WinAuto" # User Environment Root

    foreach ($l in $Locs) {
        if (-not $l) { continue }
        $candidates = @(
            (Join-Path $l "scripts\Library\$ScriptName"),
            (Join-Path $l "..\scripts\Library\$ScriptName"),
            (Join-Path $l "dev\scripts\Library\$ScriptName"),
            (Join-Path $l $ScriptName)
        )
        foreach ($p in $candidates) {
            if (Test-Path $p) { return (Resolve-Path $p).Path }
        }
    }
    return $null
}
$env:WinAutoLogDir = $Global:WinAutoLogDir

if ($null -eq (Get-Variable -Name 'WinAutoLogPath' -Scope Global -ErrorAction SilentlyContinue)) {
    $Global:WinAutoLogPath = "$Global:WinAutoLogDir\wa.log"
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
    param([int]$Columns = 64)
    try {
        $code = 'using System; using System.Runtime.InteropServices; namespace WinAutoNative { [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left; public int Top; public int Right; public int Bottom; } public class ConsoleUtils { [DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow(); [DllImport("user32.dll")] public static extern bool MoveWindow(IntPtr hWnd, int X, int Y, int nWidth, int nHeight, bool bRepaint); [DllImport("user32.dll")] public static extern int GetSystemMetrics(int nIndex); [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect); } }'
        if (-not ([System.Management.Automation.PSTypeName]"WinAutoNative.ConsoleUtils").Type) {
            Add-Type -TypeDefinition $code -ErrorAction SilentlyContinue
        }
        $buffer = $Host.UI.RawUI.BufferSize
        $window = $Host.UI.RawUI.WindowSize
        $targetHeight = $Host.UI.RawUI.MaxWindowSize.Height
        
        # 1. Set Width/Buffer
        if ($Columns -ne $window.Width) {
            if ($Columns -lt $window.Width) {
                $window.Width = $Columns; $Host.UI.RawUI.WindowSize = $window
                $buffer.Width = $Columns; $Host.UI.RawUI.BufferSize = $buffer
            }
            else {
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

        # 2. Position Adjustment
        $hWnd = [WinAutoNative.ConsoleUtils]::GetConsoleWindow()
        $screenW = [WinAutoNative.ConsoleUtils]::GetSystemMetrics(0) # SM_CXSCREEN
        $screenH = [WinAutoNative.ConsoleUtils]::GetSystemMetrics(1) # SM_CYSCREEN
        
        # Get actual pixel width after column resize
        $rect = New-Object WinAutoNative.RECT
        if ([WinAutoNative.ConsoleUtils]::GetWindowRect($hWnd, [ref]$rect)) {
            $pixelW = $rect.Right - $rect.Left
            $targetX = $screenW - $pixelW
            
            # Snap to Right with fixed width
            [WinAutoNative.ConsoleUtils]::MoveWindow($hWnd, $targetX, 0, $pixelW, $screenH, $true) | Out-Null
        }
    }
    catch {}
}



function Disable-QuickEdit {
    try {
        $def = '[DllImport("kernel32.dll")] public static extern IntPtr GetStdHandle(int nStdHandle); [DllImport("kernel32.dll")] public static extern bool GetConsoleMode(IntPtr hConsoleHandle, out uint lpMode); [DllImport("kernel32.dll")] public static extern bool SetConsoleMode(IntPtr hConsoleHandle, uint dwMode);'
        $kernel32 = Add-Type -MemberDefinition $def -Name "Kernel32" -Namespace Win32 -PassThru
        $handle = $kernel32::GetStdHandle(-10)
        $mode = 0
        if ($kernel32::GetConsoleMode($handle, [ref]$mode)) {
            $mode = $mode -band (-bnot 0x0040)
            $null = $kernel32::SetConsoleMode($handle, $mode)
        }
    }
    catch {}
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

function Write-Centered {
    param([string]$Text, [int]$Width = 64, [string]$Color)
    $cleanText = $Text -replace "$Esc\[[0-9;]*m", ""
    $padLeft = [Math]::Floor(($Width - $cleanText.Length) / 2)
    if ($padLeft -lt 0) { $padLeft = 0 }
    if ($Color) { Write-Host (" " * $padLeft + "$Color$Text$Reset") }
    else { Write-Host (" " * $padLeft + $Text) }
}

function Write-LeftAligned {
    param([string]$Text, [int]$Indent = 2)
    Write-Host (" " * $Indent + $Text)
}

function Write-Boundary {
    param([string]$Color = $FGDarkBlue)
    Write-Host "$Color$([string]'_' * 56)$Reset"
}

function Export-WinAutoCSV {
    $path = $PSScriptRoot
    if (-not $path) { $path = $PWD.Path }
    $file = Join-Path $path "scriptOUTLINE-wa.csv"
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
    if (-not (Test-Path $path)) { New-Item -Path $path -Force | Out-Null }
    Set-ItemProperty -Path $path -Name "LastRun_$Module" -Value (Get-Date).ToString() -Force | Out-Null
}

function Write-Header {
    param([string]$Title)
    Clear-Host
    Write-Host ""
    $WinAutoTitle = "WinAuto"
    Write-Centered "$Bold$FGCyan$WinAutoTitle$Reset"
    Write-Centered "$Bold$FGCyan$($Title.ToUpper())$Reset"
    Write-Boundary
}

function Write-Footer {
    Write-Boundary
    $FooterText = "$Char_Copyright 2026 www.AIIT.support"
    Write-Centered "$FGCyan$FooterText$Reset"
}

function Write-FlexLine {
    param([string]$LeftIcon, [string]$LeftText, [string]$RightText, [bool]$IsActive, [int]$Width = 64, [string]$ActiveColor = "$BGDarkGreen")
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
function Write-Log {
    param([string]$Message, [string]$Level = 'INFO', [string]$Path = $Global:WinAutoLogPath)
    if (-not $Path) { $Path = "C:\Windows\Temp\WinAuto.log" }
    $logDir = Split-Path -Path $Path -Parent
    if (-not (Test-Path $logDir)) { New-Item -Path $logDir -ItemType Directory -Force | Out-Null }
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    Add-Content -Path $Path -Value "[$timestamp] [$Level] $Message" -ErrorAction SilentlyContinue
}

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

function Get-WinAutoLastRun {
    param([string]$Module = "Maintenance")
    $StateFile = "$Global:WinAutoLogDir\WinAuto_State.json"
    if (Test-Path $StateFile) {
        try {
            $State = Get-Content $StateFile -Raw | ConvertFrom-Json
            if ($State.$Module) { return $State.$Module }
        }
        catch {}
    }
    return "Never"
}

function Set-WinAutoLastRun {
    param([string]$Module = "Maintenance")
    $StateFile = "$Global:WinAutoLogDir\WinAuto_State.json"
    $State = & { if (Test-Path $StateFile) { Get-Content $StateFile -Raw | ConvertFrom-Json } else { New-Object PSCustomObject } }
    if (-not $State) { $State = New-Object PSCustomObject }
    Add-Member -InputObject $State -MemberType NoteProperty -Name $Module -Value (Get-Date -Format "yyyy-MM-dd HH:mm:ss") -Force
    $State | ConvertTo-Json | Set-Content $StateFile -Force
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

# --- TIMEOUT LOGIC ---
$Global:TickAction = {
    param($ElapsedTimespan, $ActionText = "CONTINUE", $Timeout = 10, $PromptCursorTop, $SelectionChar = $null, $PreActionWord = "to")
    if ($null -eq $PromptCursorTop) { $PromptCursorTop = [Console]::CursorTop }
    
    $Line = ""
    
    if ($ActionText -eq "DASHBOARD") {
        $Cycle = [math]::Floor($ElapsedTimespan.TotalSeconds * 2.0)
        $IsYellow = ($Cycle % 2) -eq 0
        $GapBg = if ($IsYellow) { $Global:BGYellow } else { $Global:Reset }
        
        # User defined footer with colors
        # Use ^ v keys then press Space to RUN | Esc to EXIT
        $Line = "  Press  ${Global:FGBlack}${Global:BGYellow} ^ ${Global:Reset}  &  ${Global:FGBlack}${Global:BGYellow} v ${Global:Reset}  keys to move the ${Global:FGYellow}->${Global:Reset}${Global:FGWhite}|${Global:Reset}${Global:FGBlack}${Global:BGYellow}Space${Global:Reset} to ${Global:FGYellow}RUN${Global:Reset}   "
    }

    try { [Console]::SetCursorPosition(0, $PromptCursorTop); Write-Host $Line } catch {}
}

function Wait-KeyPressWithTimeout {
    param([int]$Seconds = 10, [scriptblock]$OnTick)
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
    param([string]$ActionText = "CONTINUE", [int]$Timeout = 10, [string]$SelectionChar = $null, [string]$PreActionWord = "to")
    Write-Host ""; $PromptCursorTop = [Console]::CursorTop
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


function Invoke-WA_SetRealTimeProtection {
    param([switch]$Undo)
    Write-Header "REAL-TIME PROTECTION"

    if (-not $Undo) {
        $thirdParty = Get-ThirdPartyAV
        if ($thirdParty) {
            Write-LeftAligned "$FGDarkYellow$Global:Char_Warn 3rd Party AV detected ($($thirdParty.displayName)). Skipping Defender config.$Reset"
            return
        }
    }

    try {
        $target = & { if ($Undo) { $true } else { $false } }
        $status = & { if ($Undo) { "DISABLED" } else { "ENABLED" } }
        $tp = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows Defender\Features" -Name "TamperProtection" -ErrorAction SilentlyContinue).TamperProtection
        if ($tp -eq 5) { Write-LeftAligned "$FGDarkYellow$Char_Warn Tamper Protection is ENABLED and blocking changes.$Reset"; return }
        Set-MpPreference -DisableRealtimeMonitoring $target -ErrorAction Stop
        Write-LeftAligned "$FGGreen$Global:Char_HeavyCheck  Real-time Protection is $status.$Reset"
    }
    catch { Write-LeftAligned "$FGRed$Char_RedCross  Failed: $($_.Exception.Message)$Reset" }
}

function Invoke-WA_SetPUA {
    param([switch]$Undo)
    Write-Header "PUA PROTECTION"
    try {
        $target = & { if ($Undo) { 0 } else { 1 } }
        $statusText = & { if ($Undo) { "DISABLED" } else { "ENABLED" } }

        # 1. Defender PUA
        if (-not $Undo -and (Get-ThirdPartyAV)) {
            Write-LeftAligned "$FGGray Skipping Defender PUA (3rd Party AV Active).$Reset"
        }
        else {
            Set-MpPreference -PUAProtection $target -ErrorAction Stop
            Write-LeftAligned "$FGGreen$Global:Char_HeavyCheck  Defender PUA Blocking is $statusText.$Reset"
        }

        # 2. Edge PUA
        Set-RegistryDword -Path "HKCU:\Software\Microsoft\Edge\SmartScreenPuaEnabled" -Name "(default)" -Value $target
        Write-LeftAligned "$FGGreen$Global:Char_HeavyCheck  Edge 'Block downloads' is $statusText.$Reset"
    }
    catch { Write-LeftAligned "$FGRed$Char_RedCross  Failed: $($_.Exception.Message)$Reset" }
}

function Invoke-WA_SetMemoryIntegrity {
    # Ensure Admin
    if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
        Write-Warning "Run as Administrator required."
        break
    }

    $Path = "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity"
    $Name = "Enabled"
    $Value = 1

    try {
        # Create Path if missing
        if (-not (Test-Path $Path)) {
            New-Item -Path $Path -Force | Out-Null
        }

        # Set Value
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type DWord -Force -ErrorAction Stop
        
        # Add Tracking Keys
        Set-ItemProperty -Path $Path -Name "WasEnabledBy" -Value 2 -Type DWord -Force -ErrorAction SilentlyContinue
        


        Write-Host "[SUCCESS] Memory Integrity Registry Keys set." -ForegroundColor Green
        Write-Host "A system restart is required for this change to take effect." -ForegroundColor Cyan
    }
    catch {
        Write-Host "[ERROR] Failed to set registry key: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Possible causes: Tamper Protection is active, or insufficient permissions." -ForegroundColor Gray
    }
}

function Invoke-WA_SetLSA {
    param([switch]$Undo)
    Write-Header "LSA PROTECTION"
    $target = & { if ($Undo) { 0 } else { 1 } }
    try {
        Set-RegistryDword -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "RunAsPPL" -Value $target
        Write-LeftAligned "$FGGreen$Global:Char_HeavyCheck LSA Protection configured.$Reset"
    }
    catch { Write-LeftAligned "$FGRed$Char_RedCross Failed: $($_.Exception.Message)$Reset" }
}

function Invoke-WA_SetKernelStack {
    # Ensure Admin
    if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
        Write-Warning "Run as Administrator required."
        break
    }

    $Path = "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\KernelShadowStacks"
    $Name = "Enabled"
    $Value = 1

    try {
        # Create Path if missing
        if (-not (Test-Path $Path)) {
            New-Item -Path $Path -Force | Out-Null
        }

        # Set Value
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type DWord -Force -ErrorAction Stop
        
        # Add Tracking Keys
        Set-ItemProperty -Path $Path -Name "WasEnabledBy" -Value 2 -Type DWord -Force -ErrorAction SilentlyContinue
        


        Write-Host "[SUCCESS] Kernel-mode Stack Protection Registry Keys set." -ForegroundColor Green
        Write-Host "A system restart is required for this change to take effect." -ForegroundColor Cyan
    }
    catch {
        Write-Host "[ERROR] Failed to set registry key: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Possible causes: Tamper Protection is active, or insufficient permissions." -ForegroundColor Gray
    }
}




function Invoke-WA_SetFirewall {
    param([switch]$Undo)
    Write-Header "WINDOWS FIREWALL"

    try {
        $target = if ($Undo) { 'False' } else { 'True' }
        $status = if ($Undo) { "DISABLED" } else { "ENABLED" }

        $profiles = Get-NetFirewallProfile

        foreach ($fwProfile in $profiles) {
            if ($fwProfile.Enabled -eq $target) {
                Write-LeftAligned "$FGGreen$Char_BallotCheck  $($fwProfile.Name) Firewall is $status.$Reset"
            }
            else {
                try {
                    Set-NetFirewallProfile -Name $fwProfile.Name -Enabled $target -ErrorAction Stop
                    Write-LeftAligned "$FGGreen$Char_HeavyCheck  $($fwProfile.Name) Firewall is $status.$Reset"
                }
                catch {
                    Write-LeftAligned "$FGRed$Char_RedCross  Failed to modify $($profile.Name) firewall: $($_.Exception.Message)$Reset"
                }
            }
        }

    }
    catch {
        Write-LeftAligned "$FGRed$Char_RedCross  Critical Error: $($_.Exception.Message)$Reset"
    }
}



function Invoke-WA_SetTaskbarDefaults {



    param([switch]$Undo)



    Write-Header "TASKBAR CONFIGURATION"



    



    $adv = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"



    $search = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search"







    # Inner helper for robust setting



    function Set-KeySafe {



        param($P, $N, $V)



        try {



            if (-not (Test-Path $P)) { New-Item -Path $P -Force -ErrorAction SilentlyContinue | Out-Null }



            Set-ItemProperty -Path $P -Name $N -Value $V -Type DWord -Force -ErrorAction Stop



        }
        catch {



            Write-LeftAligned "$FGRed$Char_RedCross Failed to set $N : $($_.Exception.Message)$Reset"



        }



    }


    if ($Undo) {



        Set-KeySafe $search "SearchboxTaskbarMode" 2



        Set-KeySafe $adv "ShowTaskViewButton" 1



        # Widgets: ON (UI Automation Bypass)
        Write-LeftAligned "Toggling Widgets ON (UI)..."
        Start-Process "ms-settings:taskbar"
        Start-Sleep -Seconds 5
        $Desktop = [System.Windows.Automation.AutomationElement]::RootElement
        $SWindow = Get-UIAElement -Parent $Desktop -Name "Settings" -ControlType ([System.Windows.Automation.ControlType]::Window) -Scope "Children"

        if ($SWindow) {
            try { $SWindow.SetFocus() } catch {}
            $WElement = Get-UIAElement -Parent $SWindow -Name "Widgets" -Scope "Descendants"
            
            if ($WElement) {
                # Try finding a button inside if the element itself isn't one
                $WToggle = $WElement
                if ($WElement.Current.ControlType -ne [System.Windows.Automation.ControlType]::CheckBox -and $WElement.Current.ControlType -ne [System.Windows.Automation.ControlType]::Button) {
                    $WToggle = Get-UIAElement -Parent $WElement -ControlType ([System.Windows.Automation.ControlType]::Button) -Scope "Children"
                }

                if ($WToggle) {
                    $State = Get-UIAToggleState -Element $WToggle
                    if ($State -eq 0) { 
                        Invoke-UIAElement -Element $WToggle | Out-Null
                        Write-LeftAligned "$FGGreen$Char_HeavyCheck Widgets enabled.$Reset" 
                    }
                    else {
                        Write-LeftAligned "  Widgets already ON."
                    }
                }
            }
            Stop-Process -Name "SystemSettings" -Force -ErrorAction SilentlyContinue
        }
        else {
            # Fallback registry is already handled elsewhere or we can skip here
            Write-LeftAligned "$FGRed$Char_Warn Could not automate Widgets.$Reset"
        }

        Write-LeftAligned "$FGGreen$Char_HeavyCheck Taskbar defaults reverted.$Reset"



    }
    else {



        # Search: Search box (Value 3)
        Set-KeySafe $search "SearchboxTaskbarMode" 3



        # Taskview: OFF



        Set-KeySafe $adv "ShowTaskViewButton" 0



        # Widgets: OFF (UI Automation Bypass)
        Write-LeftAligned "Toggling Widgets OFF (UI)..."
        Start-Process "ms-settings:taskbar"
        Start-Sleep -Seconds 5
        $Desktop = [System.Windows.Automation.AutomationElement]::RootElement
        $SWindow = Get-UIAElement -Parent $Desktop -Name "Settings" -ControlType ([System.Windows.Automation.ControlType]::Window) -Scope "Children"

        if ($SWindow) {
            try { $SWindow.SetFocus() } catch {}
            $WElement = Get-UIAElement -Parent $SWindow -Name "Widgets" -Scope "Descendants"
            
            if ($WElement) {
                # Try finding a button inside if the element itself isn't one
                $WToggle = $WElement
                if ($WElement.Current.ControlType -ne [System.Windows.Automation.ControlType]::CheckBox -and $WElement.Current.ControlType -ne [System.Windows.Automation.ControlType]::Button) {
                    $WToggle = Get-UIAElement -Parent $WElement -ControlType ([System.Windows.Automation.ControlType]::Button) -Scope "Children"
                }

                if ($WToggle) {
                    $State = Get-UIAToggleState -Element $WToggle
                    if ($State -eq 1) { 
                        Invoke-UIAElement -Element $WToggle | Out-Null
                        Write-LeftAligned "$FGGreen$Char_HeavyCheck Widgets disabled.$Reset" 
                    }
                    else {
                        Write-LeftAligned "  Widgets already OFF."
                    }
                }
            }
            Stop-Process -Name "SystemSettings" -Force -ErrorAction SilentlyContinue
        }
        else {
            # Fallback
            Write-LeftAligned "$FGRed$Char_Warn Could not automate Widgets.$Reset"
        }

        Write-LeftAligned "$FGGreen$Char_HeavyCheck Taskbar configuration applied.$Reset"



    }



}








function Invoke-WA_SetWindowsUpdateConfig {
    param()
    Write-Header "WINDOWS UPDATE CONFIGURATION"
    
    $WU_UX = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings"
    try {
        Set-RegistryDword -Path $WU_UX -Name "AllowMUUpdateService" -Value 1
        Set-RegistryDword -Path $WU_UX -Name "RestartNotificationsAllowed2" -Value 1

        # Enable Restartable Apps
        $WinlogonPath = "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
        Set-ItemProperty -Path $WinlogonPath -Name "RestartApps" -Value 1 -Type DWord -Force
        
        # Logic adapted from STABLE (Inline Only)
        Write-LeftAligned "$FGGreen$Char_HeavyCheck Windows Update settings applied.$Reset"
        Write-Log -Message "Applied Windows Update settings (Config Phase)." -Level INFO
    }
    catch { Write-LeftAligned "$FGRed$Char_RedCross Error applying update settings: $($_.Exception.Message)$Reset" }
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

    # WinGet Update
    Write-Centered "$Global:Char_EnDash WINGET UPDATE $Global:Char_EnDash" -Color "$Bold$FGCyan"
    if (Get-Command winget.exe -ErrorAction SilentlyContinue) {
        Write-LeftAligned "Running winget upgrade..."
        Start-Process "winget.exe" -ArgumentList "upgrade --all --include-unknown --accept-package-agreements --accept-source-agreements --silent" -Wait -NoNewWindow
    }

    Write-Host ""
}

function Invoke-WA_SFCRepair {
    Write-Header "SYSTEM REPAIR (SFC)"
    Write-LeftAligned "Running sfc /scannow..."
    $raw = & sfc /scannow 2>&1
    $code = $LASTEXITCODE
    $out = ($raw -join " ")
    
    # 0 = No violations, 100 = Repaired
    if ($code -eq 0 -or $out -match "did not find any integrity violations") {
        Write-LeftAligned "$FGGreen$Global:Char_CheckMark System Healthy.$Reset"
    }
    elseif ($code -eq 100 -or $out -match "successfully repaired") {
        Write-LeftAligned "$FGGreen$Global:Char_CheckMark Corruption repaired.$Reset"
    }
    elseif ($out -match "found corrupt files" -or $out -match "could not perform the requested operation") {
        Write-LeftAligned "$FGRed$Global:Char_Warn Corruption found or Scan Failed. Running DISM...$Reset"
        & DISM /Online /Cleanup-Image /RestoreHealth | Out-Null
    }
    else {
        # Fallback for unexpected output rather than assuming corruption
        Write-LeftAligned "$FGGray Scan finished with code $code. (Log: $env:WINDIR\Logs\CBS\CBS.log)$Reset"
    }
}

function Invoke-WA_OptimizeDisks {
    Write-Header "DISK OPTIMIZATION"
    $vols = Get-Volume | Where-Object { $_.DriveLetter -and $_.DriveType -eq 'Fixed' }
    foreach ($v in $vols) {
        Write-LeftAligned "Optimizing Drive $($v.DriveLetter)..."
        Optimize-Volume -DriveLetter $v.DriveLetter -NormalPriority -ErrorAction SilentlyContinue
    }
    Write-LeftAligned "$FGGreen$Global:Char_CheckMark Complete.$Reset"
}

function Invoke-WA_SystemCleanup {
    Write-Header "SYSTEM CLEANUP"
    $paths = @("$env:TEMP", "$env:WINDIR\Temp")
    foreach ($p in $paths) {
        Write-LeftAligned "Cleaning $p..."
        Get-ChildItem -Path $p -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    }
    Write-LeftAligned "$FGGreen$Global:Char_CheckMark Cleanup Complete.$Reset"
}

function Get-WA_InstallAppList {
    $paths = @(
        "$env:USERPROFILE\Documents\wa\Install_RequiredApps-Config.json",
        "$env:USERPROFILE\Downloads\Install_RequiredApps-Config.json"
    )
    
    $jsonPath = $null
    foreach ($p in $paths) {
        if (Test-Path $p) { $jsonPath = $p; break }
    }

    if (-not $jsonPath) { return $null }

    try {
        $config = Get-Content $jsonPath -Raw | ConvertFrom-Json
    }
    catch { return $null }

    # Device Type Detection
    $IsDesktop = $false
    try {
        $chassis = (Get-CimInstance -ClassName Win32_SystemEnclosure -ErrorAction SilentlyContinue).ChassisTypes
        if ($chassis -and ($chassis -contains 3 -or $chassis -contains 4 -or $chassis -contains 6 -or $chassis -contains 7 -or $chassis -contains 15 -or $chassis -contains 23 -or $chassis -contains 31)) { 
            $IsDesktop = $true 
        }
    }
    catch {}

    $AppList = @()
    if ($config.BaseApps) { $AppList += $config.BaseApps }
    if (-not $IsDesktop -and $config.LaptopApps) { $AppList += $config.LaptopApps }
    
    if ($AppList) {
        return ($AppList | Sort-Object InstallOrder)
    }
    return @()
}


function Test-WA_AppInstalled {
    param($App)
    $scopes = @("HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall", "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall")
    $pattern = if ($App.MatchName) { $App.MatchName } else { $App.AppName }
    foreach ($s in $scopes) {
        if (Test-Path $s) {
            foreach ($k in (Get-ChildItem $s -ErrorAction SilentlyContinue)) {
                $dn = $k.GetValue('DisplayName', $null)
                if ($dn -and $dn -like $pattern) { return $true }
            }
        }
    }
    return $false
}

function Test-WA_AllAppsInstalled {
    $AppList = Get-WA_InstallAppList
    if (-not $AppList -or $AppList.Count -eq 0) { return $true }  # No apps to install = all done
    foreach ($app in $AppList) {
        if (-not (Test-WA_AppInstalled -App $app)) { return $false }
    }
    return $true
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

function Invoke-WA_InstallApps {
    Write-Header "APPLICATION INSTALLER"
    
    $AppList = Get-WA_InstallAppList
    
    if ($null -eq $AppList) {
        Write-LeftAligned "$FGRed$Global:Char_Warn Config file not found.$Reset"
        Write-Host ""
        Write-LeftAligned "Searched Locations:"
        Write-LeftAligned " - Documents\wa\Install_RequiredApps-Config.json"
        Write-LeftAligned " - Downloads\Install_RequiredApps-Config.json"
        
        Write-Host ""
        Write-LeftAligned "Would you like to download the default config from GitHub? [Y/N] (Defaults to Yes in 10s)"
        $key = Wait-KeyPressWithTimeout -Seconds 10
        
        if ($key.Character -eq 'y' -or $key.Character -eq 'Y' -or $key.VirtualKeyCode -eq 13) {
            Write-Host ""
            Write-LeftAligned "Downloading..."
            try {
                $waDir = "$env:USERPROFILE\Documents\wa"
                if (-not (Test-Path $waDir)) { New-Item -ItemType Directory -Path $waDir -Force | Out-Null }
                
                $target = "$waDir\Install_RequiredApps-Config.json"
                $url = "https://raw.githubusercontent.com/KeithOwns/wa/main/Install_Apps-wa.json"
                
                [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
                Invoke-WebRequest -Uri $url -OutFile $target -UseBasicParsing -ErrorAction Stop
                
                Write-LeftAligned "$FGGreen$Global:Char_CheckMark Download Complete.$Reset"
                Start-Sleep -Seconds 1
                $AppList = Get-WA_InstallAppList
            }
            catch {
                Write-LeftAligned "$FGRed$Global:Char_RedCross Download Failed: $($_.Exception.Message)$Reset"
                Start-Sleep -Seconds 2
                return
            }
        }
        else {
            return
        }
    }
    
    if ($null -eq $AppList) { return } # Failed to download or parse

    
    # Helper: Test-AppInstalled (Inline for standalone)

    # Helper: Test-AppInstalled (Inline for standalone)
    function Test-AppInstalled {
        param($App)
        # Registry Check
        $scopes = @("HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall", "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall")
        $pattern = if ($App.MatchName) { $App.MatchName } else { $App.AppName }
        
        foreach ($s in $scopes) {
            if (Test-Path $s) {
                foreach ($k in (Get-ChildItem $s -ErrorAction SilentlyContinue)) {
                    $dn = $k.GetValue('DisplayName', $null)
                    if ($dn -and $dn -like $pattern) { return $true }
                }
            }
        }
        return $false
    }
    
    Write-LeftAligned "Processing $($AppList.Count) applications..."
    
    foreach ($app in $AppList) {
        Write-Host ""
        if (Test-AppInstalled -App $app) {
            Write-LeftAligned "$FGGreen$Global:Char_BallotCheck $($app.AppName) is already installed.$Reset"
            continue
        }

        Write-LeftAligned "$FGWhite$Global:Char_Finger Installing $($app.AppName)...$Reset"
        
        try {
            if ($app.Type -eq "WINGET") {
                $procArgs = @("install", "--id", $app.WingetId, "-e", "--accept-package-agreements", "--accept-source-agreements", "--silent", "--disable-interactivity")
                if ($app.WingetScope) { $procArgs += "--scope"; $procArgs += $app.WingetScope }
                 
                $p = Start-Process -FilePath "winget.exe" -ArgumentList $procArgs -Wait -PassThru -ErrorAction SilentlyContinue
                if ($p.ExitCode -eq 0) { Write-LeftAligned "   $FGGreen$Global:Char_CheckMark Success.$Reset" }
                else { Write-LeftAligned "   $FGRed$Global:Char_RedCross Failed (Code: $($p.ExitCode)).$Reset" }
            }
            elseif ($app.Type -eq "MSI" -or $app.Type -eq "EXE") {
                if (-not $app.Url) { throw "Missing URL" }
                $ext = if ($app.Type -eq "MSI") { ".msi" } else { ".exe" }
                $out = "$env:TEMP\WinAuto_Install$ext"
                
                Write-LeftAligned "   Downloading..."
                [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
                Invoke-WebRequest -Uri $app.Url -OutFile $out -UseBasicParsing -ErrorAction Stop
                
                Write-LeftAligned "   Executing..."
                $procArgs = if ($app.SilentArgs) { $app.SilentArgs } else { "/quiet /norestart" }
                if ($app.Type -eq "MSI") {
                    $msiArgs = "/i `"$out`" $procArgs"
                    $p = Start-Process "msiexec.exe" -ArgumentList $msiArgs -Wait -PassThru
                }
                else {
                    $p = Start-Process $out -ArgumentList $procArgs -Wait -PassThru
                }
                
                if ($p.ExitCode -eq 0 -or $p.ExitCode -eq 3010) { Write-LeftAligned "   $FGGreen$Global:Char_CheckMark Success.$Reset" }
                else { Write-LeftAligned "   $FGRed$Global:Char_RedCross Failed (Code: $($p.ExitCode)).$Reset" }
                
                Remove-Item $out -Force -ErrorAction SilentlyContinue
            }
        }
        catch {
            Write-LeftAligned "   $FGRed$Global:Char_Warn Error: $($_.Exception.Message)$Reset"
        }
    }
    
    Invoke-AnimatedPause -Timeout 5 | Out-Null
}

# --- MODULE HANDLERS ---

function Invoke-WinAutoConfiguration {
    param([switch]$SmartRun)
    Write-Header "WINDOWS CONFIGURATION PHASE"
    $lastRun = Get-WinAutoLastRun -Module "Configuration"
    Write-LeftAligned "$FGGray Last Run: $FGWhite$lastRun$Reset"

    if ($SmartRun -and $lastRun -ne "Never") {
        $lastDate = Get-Date $lastRun
        if ((Get-Date) -lt $lastDate.AddDays(30)) {
            Write-LeftAligned "$FGGreen$Global:Char_CheckMark Configuration is up to date. Skipping...$Reset"
            return
        }
    }
    Write-Boundary

    Invoke-WA_SetMemoryIntegrity
    Invoke-WA_SetRealTimeProtection
    Invoke-WA_SetPUA
    Invoke-WA_SetLSA
    Invoke-WA_SetFirewall
    Invoke-WA_SetKernelStack
    
    # UI & Performance
    Invoke-WA_SetTaskbarDefaults
    Invoke-WA_SetWindowsUpdateConfig
    
    # Restart Explorer to force refresh of Taskbar/Start Menu registry settings (Standard UI changes)
    Write-LeftAligned "Restarting Explorer to apply UI settings..."
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
    Start-Process explorer

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
        # Invoke-WA_WindowsUpdate (Moved to End)
    
        # C++ Redist Removal for wa.ps1 (Requested)
    
        if (Test-RunNeeded -Key "Maintenance_SFC" -Days 30) {
            Invoke-WA_SFCRepair
            Set-WinAutoLastRun -Module "Maintenance_SFC"
        }
    
        if (Test-RunNeeded -Key "Maintenance_Disk" -Days 7) {
            Invoke-WA_OptimizeDisks
            Set-WinAutoLastRun -Module "Maintenance_Disk"
        }
    
        if (Test-RunNeeded -Key "Maintenance_Cleanup" -Days 7) {
            Invoke-WA_SystemCleanup
            Set-WinAutoLastRun -Module "Maintenance_Cleanup"
        }
    
        # Run Windows Update Action (Skip if run in last 24 hours)
        if (Test-RunNeeded -Key "Maintenance_WinUpdate" -Days 1) {
            Invoke-WA_WindowsUpdate
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

# --- MAIN EXECUTION ---
# Ensure log directory exists
if (-not (Test-Path $Global:WinAutoLogDir)) { New-Item -Path $Global:WinAutoLogDir -ItemType Directory -Force | Out-Null }
Write-Log "WinAuto Standalone Session Started" -Level INFO
Set-ConsoleSnapRight -Columns 56
Disable-QuickEdit

$MenuSelection = 0  # 0=Smart, 1=Config, 2=Maintenance
# Per-section expansion flags


while ($true) {
    Write-Header "WINAUTO: MASTER CONTROL"
    

    

    


    # Arrows (Updated Indices)
    # 0 = SmartRUN
    # 1 = Install
    # 2 = Config
    # 3 = Maintenance
    
    $ArrS = if ($MenuSelection -eq 0) { "${FGYellow}->${Reset}${FGWhite}|${Reset}" } else { "   " }
    $ArrI = if ($MenuSelection -eq 1) { "${FGYellow}->${Reset}${FGWhite}|${Reset}" } else { "   " }
    $ArrC = if ($MenuSelection -eq 2) { "${FGYellow}->${Reset}${FGWhite}|${Reset}" } else { "   " }
    $ArrM = if ($MenuSelection -eq 3) { "${FGYellow}->${Reset}${FGWhite}|${Reset}" } else { "   " }
    
    # --- ALWAYS EXPANDED DASHBOARD ---
    Write-Host ""
    Write-Host "$FGDarkBlue$([string]'_' * 56)$Reset"
    
    # [S]mart Run (Top)
    $srLabel = if ($MenuSelection -eq 0) {
        "${FGBlack}${BGYellow}Smart${Reset}${FGGray}RUN${Reset}"
    }
    else {
        "${FGYellow}S${FGGray}martRUN${Reset}"
    }
    
    # SmartRun Details lines with Hotkeys
    $sDetailColor = if ($MenuSelection -eq 0) { $FGGray } else { $FGDarkGray }
    
    # Header Line
    Write-LeftAligned "$ArrS$srLabel                    $FGDarkBlue| ${FGYellow}Hotkeys:${Reset}" -Indent 0

    # Logic to Determine Skip State for Config
    $ConfigNumColor = $FGYellow
    $ConfigTextColor = $sDetailColor
    $Global:AnySkipped = $false
    $lastConfigRun = Get-WinAutoLastRun -Module "Configuration"
    if ($lastConfigRun -ne "Never") {
        $lastConfigDate = Get-Date $lastConfigRun
        if ((Get-Date) -lt $lastConfigDate.AddDays(30)) {
            $ConfigNumColor = $FGDarkGray
            $ConfigTextColor = $FGDarkGray
            $Global:AnySkipped = $true
        }
    }

    # ... (Lines 1572-1698 preserved via context or skipped in this replacement block if I can target precisely) ...
    # Wait, replace_file_content replaces the block. I need to be careful not to delete the rows.
    # I will perform 2 separate edits to be safe.
    # Edit 1: Updates the Skip Logic to use Global.

    # ... (Render Lines 1526-1688 omitted for brevity, logic flows to footer) ...

    # Logic to Determine Skip State for Install (all apps already installed)
    $InstallNumColor = $FGYellow
    $InstallTextColor = $sDetailColor
    $Global:AllAppsInstalled = Test-WA_AllAppsInstalled
    if ($Global:AllAppsInstalled) {
        $InstallNumColor = $FGDarkGray
        $InstallTextColor = $FGDarkGray
        $Global:AnySkipped = $true
    }

    # Row 1 (Grayed out if all apps installed)
    Write-LeftAligned "${InstallNumColor}1.${InstallTextColor} Install Applications${Reset}       $FGDarkBlue| ${FGYellow}I${FGGray}nstall    ${FGYellow}S${FGGray}martRUN${Reset}" -Indent 1
    
    # Row 2 (Entire Line Grayed out if skipped)
    Write-LeftAligned "${ConfigNumColor}2.${ConfigTextColor} Configure Operating System${Reset} $FGDarkBlue| ${FGYellow}C${FGGray}onfigure  ${FGYellow}H${FGGray}elp / Info${Reset}" -Indent 1
    
    # Logic to Determine Skip State for Maintenance (all tasks recently complete)
    $MaintNumColor = $FGYellow
    $MaintTextColor = $sDetailColor
    $Global:MaintenanceComplete = Test-WA_MaintenanceRecentlyComplete
    if ($Global:MaintenanceComplete) {
        $MaintNumColor = $FGDarkGray
        $MaintTextColor = $FGDarkGray
        $Global:AnySkipped = $true
    }

    # Row 3 (Grayed out if all maintenance recently complete)
    Write-LeftAligned "${MaintNumColor}3.${MaintTextColor} Maintain Operating System${Reset}  $FGDarkBlue| ${FGYellow}M${FGGray}aintain   ${FGDarkRed}Esc${Reset} to ${FGDarkRed}${BGWhite}EXIT${Reset}" -Indent 1
    
    Write-Boundary # Separator

    # [I]nstall Applications (Pos 1)
    $iHeadLeft = "Install Applications:"
    $iHeadRight = "Install Source:"
    # Target Col 33.
    $padCount = 28 - $iHeadLeft.Length
    if ($padCount -lt 1) { $padCount = 1 }
    $iPad = " " * $padCount

    $iUnselColor = if ($MenuSelection -eq 1) { $FGGray } else { $FGDarkGray }
    
    if ($MenuSelection -eq 1) {
        Write-LeftAligned "$ArrI${FGBlack}${BGYellow}Install${Reset}${FGGray} Applications:${Reset}$iPad${FGDarkBlue}| ${iUnselColor}$iHeadRight${Reset}" -Indent 0
    }
    else {
        Write-LeftAligned "$ArrI${FGYellow}I${FGDarkGray}nstall Applications:${Reset}$iPad${FGDarkBlue}| ${FGDarkGray}$iHeadRight${Reset}" -Indent 0
    }

    $iDetailColor = if ($MenuSelection -eq 1) { $FGGray } else { $FGDarkGray }
    $appListDisplay = Get-WA_InstallAppList
    
    if ($appListDisplay) {
        foreach ($app in $appListDisplay) {
            $isInst = Test-WA_AppInstalled -App $app
            $icon = if ($isInst) { "${FGDarkGreen}[v]${Reset}" } else { "${FGRed}[ ]${Reset}" }
            $appColor = if ($isInst) { $FGDarkGray } else { $iDetailColor }
            $dName = "$icon ${appColor}$($app.AppName)${Reset}"
            $cleanName = "[v] $($app.AppName)"
            
            $dPadCount = 28 - $cleanName.Length
            if ($dPadCount -lt 1) { $dPadCount = 1 }
            $dPad = " " * $dPadCount
            
            # Right Column: Install Source (Filename, WinGet ID, or Type)
            $source = "Unknown"
            if ($app.PSObject.Properties['InstallerPath'] -and $app.InstallerPath) { 
                $source = Split-Path $app.InstallerPath -Leaf 
            }
            elseif ($app.PSObject.Properties['WinGetId'] -and $app.WinGetId) { 
                $source = $app.WinGetId 
            }
            elseif ($app.PSObject.Properties['Url'] -and $app.Url) { 
                # Extract filename from URL
                $source = Split-Path $app.Url -Leaf 
            }
            elseif ($app.PSObject.Properties['Source'] -and $app.Source) { 
                $source = $app.Source 
            }
            elseif ($app.PSObject.Properties['Type'] -and $app.Type) { 
                $source = $app.Type 
            }
            
            Write-LeftAligned "${dName}${Reset}$dPad${FGDarkBlue}| ${iDetailColor}$source${Reset}" -Indent 3
        }
    }
    else {
        Write-LeftAligned "${iDetailColor}- (Config not found in Downloads)${Reset}" -Indent 3
    }
    
    Write-Boundary # Separator
    Write-Host ""

    # [C]onfigure Operating System (Pos 2)
    $cHeadLeft = "Configure Operating System:"
    $cHeadRight = "Method:"
    # Target 30?
    $chPadCount = 28 - $cHeadLeft.Length
    if ($chPadCount -lt 1) { $chPadCount = 1 }
    $chPad = " " * $chPadCount

    if ($MenuSelection -eq 2) {
        Write-LeftAligned "$ArrC${FGBlack}${BGYellow}Configure${Reset}${FGGray} Operating System:${Reset}$chPad${FGDarkBlue}| ${FGGray}$cHeadRight${Reset}" -Indent 0
    }
    else {
        Write-LeftAligned "$ArrC${FGYellow}C${FGDarkGray}onfigure Operating System:${Reset}$chPad${FGDarkBlue}| ${FGDarkGray}$cHeadRight${Reset}" -Indent 0
    }
    
    # Config Details
    $cDetailColor = if ($MenuSelection -eq 2) { $FGGray } else { $FGDarkGray }
    
    # Helper to print item
    function Write-ColItem {
        param($Txt, $Met) 
        $pad = " " * (26 - $Txt.Length); 
        Write-LeftAligned "${cDetailColor}- $Txt${Reset}$pad${FGDarkBlue}| ${cDetailColor}$Met${Reset}" -Indent 3 
    }
    
    Write-ColItem "Real-Time Protection" "PowerShell WMI"
    Write-ColItem "PUA Protection" "PowerShell WMI"
    Write-ColItem "PUA Protection (Edge)" "Registry (HKCU)"
    Write-ColItem "Memory Integrity" "Registry (HKLM)"
    Write-ColItem "Kernel Stack Protection" "Registry (HKLM)"
    Write-ColItem "LSA Protection" "Registry (HKLM)"
    Write-ColItem "Windows Firewall" "PowerShell Cmdlet"
    Write-ColItem "Taskbar Search Box" "Registry (HKCU)"
    Write-ColItem "Task View Toggle" "Registry (HKCU)"
    Write-ColItem "Widgets Toggle" "UI Automation"
    Write-ColItem "Microsoft Update Service" "Registry (HKLM)"
    Write-ColItem "Restart Notifications" "Registry (HKLM)"
    Write-ColItem "App Restart Persistence" "Registry (HKCU)"
    

    
    Write-Boundary # Separator
    Write-Host ""

    # [M]aintain Operating System (Pos 4)
    $mHeadLeft = "Maintain Operating System"
    $mHeadRight = "Method:"
    $mhPadCount = 28 - $mHeadLeft.Length
    if ($mhPadCount -lt 1) { $mhPadCount = 1 }
    $mhPad = " " * $mhPadCount

    if ($MenuSelection -eq 3) {
        Write-LeftAligned "$ArrM${FGBlack}${BGYellow}Maintain${Reset}${FGGray} Operating System${Reset}$mhPad${FGDarkBlue}| ${FGGray}$mHeadRight${Reset}" -Indent 0
    }
    else {
        Write-LeftAligned "$ArrM${FGYellow}M${FGDarkGray}aintain Operating System${Reset}$mhPad${FGDarkBlue}| ${FGDarkGray}$mHeadRight${Reset}" -Indent 0
    }
    
    # Maintenance Details
    $mDetailColor = if ($MenuSelection -eq 3) { $FGGray } else { $FGDarkGray }
    
    function Write-MaintItem {
        param($Txt, $Met) 
        $pad = " " * (26 - $Txt.Length); 
        Write-LeftAligned "${mDetailColor}- $Txt${Reset}$pad${FGDarkBlue}| ${mDetailColor}$Met${Reset}" -Indent 3 
    }
    
    Write-MaintItem "WinGet App Updates" "CMD Line"
    Write-MaintItem "Drive Optimization (TRIM)" "PowerShell Cmdlet"
    Write-MaintItem "Temp File Cleanup" "File System"
    Write-MaintItem "SFC / DISM Repair" "CMD Line"

    Write-Boundary # Separator
    Write-Host ""
    
    Write-Boundary # Separator
    
    # Dynamic Footer Prompt Logic (Standard View Only now)
    $Act = "DASHBOARD"
    $Sel = $null
    $Pre = ""

    # Timeout logic: Only on first load
    $ActionText = "DASHBOARD" # Unused variable but kept for readability if referenced elsewhere
    $TimeoutSecs = if ($Global:WinAutoFirstLoad -ne $false) { 10 } else { 0 }
    $Global:WinAutoFirstLoad = $false

    $res = Invoke-AnimatedPause -ActionText $Act -Timeout $TimeoutSecs -SelectionChar $Sel -PreActionWord $Pre

    # --- NAVIGATION LOGIC ---
    if ($res.VirtualKeyCode -eq 38) {
        # Up
        $MenuSelection--
        if ($MenuSelection -lt 0) { $MenuSelection = 3 }
        continue
    }
    elseif ($res.VirtualKeyCode -eq 40) {
        # Down
        $MenuSelection++
        if ($MenuSelection -gt 3) { $MenuSelection = 0 }
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
    
    if ($res.VirtualKeyCode -eq 27 -or $res.Character -eq 'X' -or $res.Character -eq 'x') {
        # Esc or X -> Exit
        Write-LeftAligned "$FGGray Exiting WinAuto...$Reset"
        Start-Sleep -Seconds 1
        break
    }
    elseif ($res.VirtualKeyCode -eq 13) {
        # Enter Handling (Mapped to Spacebar logic logic effectively, or just loop if user insists on space)
        # We will ignore Enter or treat it as Space to be safe, but Space is the primary.
        $res.Character = ' '
        $res.VirtualKeyCode = 32
    }
    
    # Hotkey Logic (Numbers 1-3)
    if ($res.Character -eq '1') { $MenuSelection = 1; $res.Character = ' ' }
    elseif ($res.Character -eq '2') { 
        if (-not $AnySkipped) { $MenuSelection = 2; $res.Character = ' ' }
    }
    elseif ($res.Character -eq '3') { $MenuSelection = 3; $res.Character = ' ' }
    
    # Hotkey Logic (S, I, C, M) - Maps to Selection + Space
    elseif ($res.Character -eq 'S' -or $res.Character -eq 's') { $MenuSelection = 0; $res.Character = ' ' }
    elseif ($res.Character -eq 'I' -or $res.Character -eq 'i') { $MenuSelection = 1; $res.Character = ' ' }
    elseif ($res.Character -eq 'C' -or $res.Character -eq 'c') { $MenuSelection = 2; $res.Character = ' ' }
    elseif ($res.Character -eq 'M' -or $res.Character -eq 'm') { $MenuSelection = 3; $res.Character = ' ' }
    
    if ($res.Character -eq ' ' -or $res.VirtualKeyCode -eq 32) {
        # Space Action Logic (Context Sensitive)
        $Target = $MenuSelection
        
        # GLOBAL: Run Windows Update Check FIRST
        # Invoke-WA_WindowsUpdate (Moved to Maintenance Phase)
        
        if ($Target -eq 0) {
            # [S]mart Run -> EXECUTE
            if (-not $Global:AllAppsInstalled) { Invoke-WA_InstallApps }
            Invoke-WinAutoConfiguration -SmartRun
            Set-WinAutoLastRun -Module "Configuration"
            if (-not $Global:MaintenanceComplete) { Invoke-WinAutoMaintenance -SmartRun }
        }
        elseif ($Target -eq 1) {
            # [I]nstall -> EXECUTE (only if apps need installing)
            if (-not $Global:AllAppsInstalled) { Invoke-WA_InstallApps }
        }
        elseif ($Target -eq 2) {
            # [C]onfig -> EXECUTE
            Invoke-WinAutoConfiguration
            Set-WinAutoLastRun -Module "Configuration"
        }
        elseif ($Target -eq 3) {
            # [M]aintenance -> EXECUTE (only if tasks need running)
            if (-not $Global:MaintenanceComplete) { Invoke-WinAutoMaintenance }
        }
        
        # Pause slightly if we toggled, or if we ran (though ran usually has its own pauses)
        Start-Sleep -Milliseconds 200
        continue
    }
    elseif ($res.Character -eq 'H' -or $res.Character -eq 'h') {
        Clear-Host
        Write-Header "SYSTEM IMPACT MANIFEST"
        Write-Host ""
        # Display manifest with body lines in DarkGray
        $Global:WinAutoManifestContent -split "`n" | ForEach-Object {
            $line = $_.TrimEnd()
            if ($line -match "wa\.ps1: Functional Outline") {
                Write-Centered $line
            }
            elseif ($line.Trim() -match "^-") {
                Write-Host "${FGDarkGray}$line${Reset}"
            }
            else {
                Write-Host $line
            }
        }
        Write-Host ""
        Write-Host "   ${FGBlack}${BGYellow}Enter${Reset} to export CSV   ${FGBlack}${BGYellow}Space${Reset} to return   ${FGDarkRed}Esc${Reset} to ${FGDarkRed}${BGWhite}EXIT${Reset}"
        while ($true) {
            $mk = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            if ($mk.Character -eq ' ' -or $mk.VirtualKeyCode -eq 32 -or $mk.Character -eq 'H' -or $mk.Character -eq 'h') { break }
            if ($mk.VirtualKeyCode -eq 27) { 
                # Esc pressed - exit script
                Write-Host ""
                exit 0
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

Get-LogReport
Write-Host ""
Write-Boundary
Write-Centered "$FGGreen ALL REQUESTED TASKS COMPLETE $Reset"
Write-Footer
Write-Host ""
Invoke-AnimatedPause -ActionText "EXIT" -Timeout 0 | Out-Null
Write-Host ""
Write-Host ""
Write-Host ""
Write-Host ""
Write-Host ""
