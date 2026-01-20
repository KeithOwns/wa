#Requires -RunAsAdministrator
<#
.SYNOPSIS
    WinAuto Standalone Edition
.DESCRIPTION
    A self-contained, single-file version of the WinAuto suite for Windows 11.
    Includes Configuration (Security/UI) and Maintenance (Updates/Repair) modules.
    
    Usage: Copy and paste this entire script into an Administrator PowerShell window, or run the file.
#>

# --- INITIAL SETUP ---
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$Global:ShowDetails = $false
$Global:WinAutoFirstLoad = $true
$Global:InstallApps = $false
$Global:EnhancedSecurity = $false
$Global:RegPath_WU_UX = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings"
$Global:RegPath_WU_POL = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
$Global:RegPath_Winlogon_User = "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" 
$Global:RegPath_Winlogon_Machine = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"

# --- MANIFEST CONTENT ---
$Global:WinAutoManifestContent = @'
# WinAuto System Impact Manifest

This document details the specific technical changes that the **WinAuto** suite makes to your Windows 11 system.

## 1. Security Configuration

**Goal:** Harden system security according to Microsoft recommended baselines.

| Feature | Change | Technical Action |
| :--- | :--- | :--- |
| **Real-Time Protection** | **Enabled** | `Set-MpPreference -DisableRealtimeMonitoring $false` |
| **PUA Protection** | **Enabled** | `Set-MpPreference -PUAProtection Enabled` & Edge 'Block downloads' |
| **Memory Integrity** | **Enabled** | Registry: `HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity` -> `Enabled = 1` |
| **LSA Protection** | **Enabled** | Registry: `HKLM\SYSTEM\CurrentControlSet\Control\Lsa` -> `RunAsPPL = 1` |
| **Stack Protection** | **Enabled** | Registry: `HKLM\...\Session Manager\Kernel` -> `KernelSEHOPEnabled = 1` |
| **Phishing Protection** | **Enabled** | Registry: `HKCU\...\PhishingProtection` -> `WarnMaliciousAppsAndSites = 1` |
| **Firewall** | **Enabled** | `Set-NetFirewallProfile -Enabled True` (Domain, Private, Public) |

---

## 2. Windows Update

**Goal:** Ensure updates are delivered reliably and automatically.

| Feature | Change | Technical Action |
| :--- | :--- | :--- |
| **Microsoft Updates** | **Enabled** | Registry: `HKLM\...\WindowsUpdate\UX\Settings` -> `AllowMUUpdateService = 1` |
| **Metered Connections** | **Allowed** | Registry: `HKLM\...\WindowsUpdate\UX\Settings` -> `AllowAutoWindowsUpdateDownloadOverMeteredNetwork = 1` |
| **Restart Notifications**| **Enabled** | Registry: `HKLM\...\WindowsUpdate\UX\Settings` -> `RestartNotificationsAllowed2 = 1` |
| **App Restart** | **Enabled** | Registry: `HKCU\...\Winlogon` -> `RestartApps = 1` |

---

## 3. System Maintenance

**Goal:** Repair system files and optimize performance.

| Action | Description | Technical Command |
| :--- | :--- | :--- |
| **System Repair** | Scan & Repair OS | `sfc /scannow` (and `DISM /RestoreHealth` if needed) |
| **Disk Optimization** | TRIM/Defrag | `Optimize-Volume -DriveLetter C -NormalPriority` |
| **Cleanup** | Clear Temp Files | Delete files in `%TEMP%` and `%WINDIR%\Temp` |
| **Updates** | App Updates | `winget upgrade --all` |
| **Updates** | Store Updates | Automates Microsoft Store UI to click "Get updates" |
| **Updates** | OS Updates | Automates Settings UI to click "Check for updates" |

---

## 4. UI Optimization

**Goal:** Improve responsiveness by setting standard defaults.

| Feature | Change | Technical Action |
| :--- | :--- | :--- |
| **Taskbar Search** | **Icon+Label**| Registry: `HKCU\...\Search` -> `SearchboxTaskbarMode = 2` |
| **Taskbar Items** | **Clean** | Taskview & Widgets set to **OFF** |

---
(c) 2026 www.AIIT.support
'@

# --- GLOBAL RESOURCES ---
# Centralized definition of ANSI colors and Unicode characters.

# --- ANSI Escape Sequences ---
$Esc = [char]0x1B
$Reset = "$Esc[0m"
$Bold = "$Esc[1m"

# Script Palette (Foreground)
$FGCyan = "$Esc[96m"
$FGDarkBlue = "$Esc[34m"
$FGGreen = "$Esc[92m"
$FGRed = "$Esc[91m"
$FGYellow = "$Esc[93m"
$FGDarkCyan = "$Esc[36m"
$FGWhite = "$Esc[97m"
$FGGray = "$Esc[37m"
$FGDarkGray = "$Esc[90m"
$FGDarkGreen = "$Esc[32m"
$FGDarkRed = "$Esc[31m"
$FGDarkYellow = "$Esc[33m"
$FGBlack = "$Esc[30m"

# Script Palette (Background)
$BGDarkGreen = "$Esc[42m"
$BGDarkGray = "$Esc[100m"
$BGYellow = "$Esc[103m"

# --- Unicode Icons & Characters ---
$Char_HeavyCheck = "[v]" 
$Char_Warn = [char]0x26A0 
$Char_BallotCheck = "[v]" 
$Char_Keyboard = "[:::]" 
$Char_Copyright = "(c)" 
$Char_Finger = "->" 
$Char_CheckMark = "v" 
$Char_FailureX = "x" 
$Char_RedCross = "x"
$Char_HeavyMinus = "-" 

# --- SYSTEM PATHS ---
if ($null -eq (Get-Variable -Name 'WinAutoLogDir' -Scope Global -ErrorAction SilentlyContinue)) {
    $Global:WinAutoLogDir = "C:\Users\admin\GitHub\WinAuto\logs"
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

$Global:GetUIA = {
    param($Parent, $Name, $Type, $Timeout = 10)
    $Cond = & { 
        if ($Name -and $Type) {
            New-Object System.Windows.Automation.AndCondition(
                (New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty, $Name)),
                (New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, $Type))
            )
        }
        elseif ($Name) {
            New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty, $Name)
        }
        else {
            New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, $Type)
        }
    }
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt $Timeout) {
        $res = $Parent.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $Cond)
        if ($res) { return $res }
        Start-Sleep -Milliseconds 500
    }
    return $null
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
    $Global:WinAutoLogPath = "$Global:WinAutoLogDir\WinAuto_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
}

# --- SHARED UI FUNCTIONS ---

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
    param([int]$Columns = 56)
    try {
        $code = 'using System; using System.Runtime.InteropServices; namespace WinAutoNative { [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left; public int Top; public int Right; public int Bottom; } public class ConsoleUtils { [DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow(); [DllImport("user32.dll")] public static extern bool MoveWindow(IntPtr hWnd, int X, int Y, int nWidth, int nHeight, bool bRepaint); [DllImport("user32.dll")] public static extern int GetSystemMetrics(int nIndex); [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect); } }'
        if (-not ([System.Management.Automation.PSTypeName]"WinAutoNative.ConsoleUtils").Type) {
            Add-Type -TypeDefinition $code -ErrorAction SilentlyContinue
        }
        $buffer = $Host.UI.RawUI.BufferSize
        $window = $Host.UI.RawUI.WindowSize
        $targetHeight = [Math]::Max($window.Height, 50)
        
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
    param([string]$Text, [int]$Width = 56, [string]$Color)
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
    param([string]$LeftIcon, [string]$LeftText, [string]$RightText, [bool]$IsActive, [int]$Width = 56, [string]$ActiveColor = "$BGDarkGreen")
    $Circle = [char]0x25CF
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
    param($ElapsedTimespan, $ActionText = "CONTINUE", $Timeout = 10, $PromptCursorTop)
    if ($null -eq $PromptCursorTop) { $PromptCursorTop = [Console]::CursorTop }
    $WiggleFrame = [Math]::Floor($ElapsedTimespan.TotalMilliseconds / 500)
    $IsRight = ($WiggleFrame % 2) -eq 1
    if ($IsRight) { $CurrentChars = @(" ", $Char_Finger, "[", "E", "n", "t", "e", "r", "]", " ") } 
    else { $CurrentChars = @($Char_Finger, " ", "[", "E", "n", "t", "e", "r", "]", " ") }
    $FilledCount = [Math]::Floor($ElapsedTimespan.TotalSeconds)
    if ($FilledCount -gt $Timeout) { $FilledCount = $Timeout }
    $DynamicPart = ""
    for ($i = 0; $i -lt 10; $i++) {
        $Char = $CurrentChars[$i]
        if ($i -lt $FilledCount) { $DynamicPart += "${BGYellow}${FGBlack}$Char${Reset}" } 
        else { if ($Char -eq " ") { $DynamicPart += " " } else { $DynamicPart += "${FGYellow}$Char${Reset}" } }
    }
    $PromptStr = "${FGWhite}$Char_Keyboard Press ${FGDarkGray}$DynamicPart${FGDarkGray}${FGWhite}to${FGDarkGray} ${FGYellow}$ActionText${FGDarkGray} ${FGWhite}or${FGDarkGray} ${FGRed}[Esc]${FGWhite} to ${FGRed}EXIT${Reset}"
    try { [Console]::SetCursorPosition(0, $PromptCursorTop); Write-Centered $PromptStr -Width 56 } catch {}
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
            # Non-interactive fallback: check if input is piped
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
    $StopWatch.Stop(); return [PSCustomObject]@{ VirtualKeyCode = 13 }
}

function Invoke-AnimatedPause {
    param([string]$ActionText = "CONTINUE", [int]$Timeout = 10)
    Write-Host ""; $PromptCursorTop = [Console]::CursorTop
    if ($Timeout -le 0) {
        $PromptStr = "$FGWhite$Char_Keyboard Press ${FGBlack}${BGYellow}[S]${Reset}$FGWhite to $FGYellow$ActionText$FGWhite or ${FGRed}[Esc]${Reset}$FGWhite to ${FGRed}EXIT$Reset"
        Write-Centered $PromptStr
        return $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
    $LocalTick = { param($Elapsed) & $Global:TickAction -ElapsedTimespan $Elapsed -ActionText $ActionText -Timeout $Timeout -PromptCursorTop $PromptCursorTop }
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
            Write-LeftAligned "$FGDarkYellow$Char_Warn 3rd Party AV detected ($($thirdParty.displayName)). Skipping Defender config.$Reset"
            return
        }
    }

    try {
        $target = & { if ($Undo) { $true } else { $false } }
        $status = & { if ($Undo) { "DISABLED" } else { "ENABLED" } }
        $tp = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows Defender\Features" -Name "TamperProtection" -ErrorAction SilentlyContinue).TamperProtection
        if ($tp -eq 5) { Write-LeftAligned "$FGDarkYellow$Char_Warn Tamper Protection is ENABLED and blocking changes.$Reset"; return }
        Set-MpPreference -DisableRealtimeMonitoring $target -ErrorAction Stop
        Write-LeftAligned "$FGGreen$Char_HeavyCheck  Real-time Protection is $status.$Reset"
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
            Write-LeftAligned "$FGGreen$Char_HeavyCheck  Defender PUA Blocking is $statusText.$Reset"
        }

        # 2. Edge PUA
        Set-RegistryDword -Path "HKCU:\Software\Microsoft\Edge\SmartScreenPuaEnabled" -Name "(default)" -Value $target
        Write-LeftAligned "$FGGreen$Char_HeavyCheck  Edge 'Block downloads' is $statusText.$Reset"
    }
    catch { Write-LeftAligned "$FGRed$Char_RedCross  Failed: $($_.Exception.Message)$Reset" }
}

function Invoke-WA_SetMemoryIntegrity {
    param([switch]$Undo)
    Write-Header "MEMORY INTEGRITY"
    $target = & { if ($Undo) { 0 } else { 1 } }
    $path = "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity"
    try {
        Set-RegistryDword -Path $path -Name "Enabled" -Value $target
        if ($target -eq 1) { Set-RegistryDword -Path $path -Name "WasEnabledBy" -Value 2 }
        Write-LeftAligned "$FGGreen$Char_BallotCheck Memory Integrity configured.$Reset"
    }
    catch { Write-LeftAligned "$FGRed$Char_RedCross Failed: $($_.Exception.Message)$Reset" }
}

function Invoke-WA_SetLSA {
    param([switch]$Undo)
    Write-Header "LSA PROTECTION"
    $target = & { if ($Undo) { 0 } else { 1 } }
    try {
        Set-RegistryDword -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "RunAsPPL" -Value $target
        Write-LeftAligned "$FGGreen$Char_HeavyCheck LSA Protection configured.$Reset"
    }
    catch { Write-LeftAligned "$FGRed$Char_RedCross Failed: $($_.Exception.Message)$Reset" }
}

function Invoke-WA_SetKernelStack {
    param([switch]$Undo)
    Write-Header "KERNEL STACK PROTECTION"
    $target = & { if ($Undo) { 0 } else { 1 } }
    
    # 1. Registry Baseline
    try {
        Set-RegistryDword -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Kernel" -Name "KernelSEHOPEnabled" -Value $target
        Write-LeftAligned "$FGGreen$Char_BallotCheck Registry baseline set.$Reset"
    }
    catch {
        Write-LeftAligned "$FGRed$Char_Warn Registry baseline failed.$Reset"
    }

    # 2. Try External Script (Repository Mode)
    $ExternalScriptPath = Get-WA_LibraryScript "SET_Enable-KernelModeHardwareStackProtection.ps1"
    
    if ($ExternalScriptPath) {
        Write-LeftAligned "$FGGray Launching security module in isolated process...$Reset"
        try {
            $ProcArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $ExternalScriptPath)
            if ($Undo) { $ProcArgs += "-Undo" } else { $ProcArgs += "-Force" }
            $p = Start-Process -FilePath "powershell.exe" -ArgumentList $ProcArgs -Wait -PassThru -NoNewWindow
            if ($p.ExitCode -eq 0) {
                Write-LeftAligned "$FGGreen$Char_CheckMark Kernel Stack Protection automation finished.$Reset"
                Start-Sleep -Seconds 2
                return
            }
            else {
                Write-LeftAligned "$FGRed$Char_Warn Module exited with code $($p.ExitCode).$Reset"
                Write-LeftAligned "$FGGray Falling back to standalone automation...$Reset"
            }
        }
        catch {
            Write-LeftAligned "$FGRed$Char_Warn External launch failed: $_$Reset"
            Write-LeftAligned "$FGRed$Char_Warn Falling back to standalone logic.$Reset"
            Start-Sleep -Seconds 2
        }
    }
    
    # 3. Standalone Fallback (UI Automation)
    Write-LeftAligned "Launching Windows Security..."
    Stop-Process -Name "SecHealthUI" -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
    Start-Process "windowsdefender:"
    Start-Sleep -Seconds 3

    $Desktop = [System.Windows.Automation.AutomationElement]::RootElement
    $Window = $Desktop.FindFirst([System.Windows.Automation.TreeScope]::Children, (New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty, "Windows Security")))

    if ($Window) {
        try { $Window.SetFocus() } catch {}
        
        # Navigate to Device Security
        $DevSec = &$Global:GetUIA $Window "Device security" ([System.Windows.Automation.ControlType]::ListItem)
        if ($DevSec) { 
            try { ($DevSec.GetCurrentPattern([System.Windows.Automation.SelectionItemPattern]::Pattern)).Select() } catch {}
            Start-Sleep -Seconds 1
        }

        # Navigate to Core Isolation
        $CoreIso = &$Global:GetUIA $Window "Core isolation details" ([System.Windows.Automation.ControlType]::Hyperlink)
        if ($CoreIso) {
            try { ($CoreIso.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern)).Invoke() } catch {}
            Start-Sleep -Seconds 1
        }

        # Find Toggle
        $TargetName = "Kernel-mode Hardware-enforced Stack Protection"
        $Toggle = &$Global:GetUIA $Window $TargetName ([System.Windows.Automation.ControlType]::CheckBox)
        
        if ($Toggle) {
            try {
                $Pattern = $Toggle.GetCurrentPattern([System.Windows.Automation.TogglePattern]::Pattern)
                $CurrentState = $Pattern.Current.ToggleState # 0=Off, 1=On
                $DesiredState = & { if ($Undo) { 0 } else { 1 } }

                if ($CurrentState -ne $DesiredState) {
                    $Pattern.Toggle()
                    Write-LeftAligned "$FGGreen$Char_HeavyCheck Toggled Stack Protection.$Reset"
                }
                else {
                    Write-LeftAligned "$FGGreen$Char_BallotCheck Stack Protection already in desired state.$Reset"
                }
            }
            catch {
                Write-LeftAligned "$FGRed$Char_Warn Failed to toggle: $_$Reset"
            }
        }
        else {
            Write-LeftAligned "$FGRed$Char_Warn Could not find Stack Protection toggle (Hardware might not support it).$Reset"
        }
    }
    else {
        Write-LeftAligned "$FGRed$Char_Warn Could not find Windows Security window.$Reset"
    }
}


function Invoke-WA_SetPhishingMalicious {
    param([switch]$Undo)
    Write-Header "MALICIOUS APP WARNING"
    
    if (-not $Undo) {
        $thirdParty = Get-ThirdPartyAV
        if ($thirdParty) {
            Write-LeftAligned "$FGDarkYellow$Char_Warn 3rd Party AV detected ($($thirdParty.displayName)). Skipping Phishing config.$Reset"
            return
        }
    }

    try {
        $target = & { if ($Undo) { 0 } else { 1 } }
        Set-RegistryDword -Path "HKCU:\Software\Microsoft\Windows Security Health\PhishingProtection" -Name "WarnMaliciousAppsAndSites" -Value $target
        Write-LeftAligned "$FGGreen$Char_HeavyCheck Malicious App Warning configured.$Reset"
    }
    catch { Write-LeftAligned "$FGRed$Char_RedCross Failed: $($_.Exception.Message)$Reset" }
}

function Invoke-WA_SetFirewall {

    param([switch]$Undo)

    Write-Header "WINDOWS FIREWALL"
    
    if (-not $Undo) {
        $thirdParty = Get-ThirdPartyAV
        if ($thirdParty) {
            Write-LeftAligned "$FGDarkYellow$Char_Warn 3rd Party AV detected ($($thirdParty.displayName)). Skipping Firewall config.$Reset"
            return
        }
    }

    try {

        $target = & { if ($Undo) { $false } else { $true } }
        Get-NetFirewallProfile | ForEach-Object {
            Set-NetFirewallProfile -Name $_.Name -Enabled $target -ErrorAction Stop

            Write-LeftAligned "$FGGreen$Char_HeavyCheck $($_.Name) Firewall configured.$Reset"

        }

    }
    catch { Write-LeftAligned "$FGRed$Char_RedCross Error: $($_.Exception.Message)$Reset" }

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



        Set-KeySafe $search "SearchboxTaskbarMode" 1



        Set-KeySafe $adv "ShowTaskViewButton" 1



        # Widgets: ON (UI Automation Bypass)
        Write-LeftAligned "Toggling Widgets ON (UI)..."
        Start-Process "ms-settings:taskbar"
        Start-Sleep -Seconds 5
        $Desktop = [System.Windows.Automation.AutomationElement]::RootElement
        $SWindow = $null
        foreach ($title in @("Settings", "Paramètres", "Einstellungen")) {
            $SWindow = $Desktop.FindFirst([System.Windows.Automation.TreeScope]::Children, (New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty, $title)))
            if ($SWindow) { break }
        }
        if ($SWindow) {
            try { $SWindow.SetFocus() } catch {}
            $WElement = &$Global:GetUIA $SWindow "Widgets" $null
            if ($WElement) {
                $WToggle = $null
                if ($WElement.Current.ControlType -eq [System.Windows.Automation.ControlType]::Button -or $WElement.Current.ControlType -eq [System.Windows.Automation.ControlType]::CheckBox) { $WToggle = $WElement }
                else { $WToggle = $WElement.FindFirst([System.Windows.Automation.TreeScope]::Children, (New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Button))) }
                
                if ($WToggle) {
                    try {
                        $WPattern = $WToggle.GetCurrentPattern([System.Windows.Automation.TogglePattern]::Pattern)
                        if ($WPattern.Current.ToggleState -eq 0) { $WPattern.Toggle(); Write-LeftAligned "$FGGreen$Char_HeavyCheck Widgets enabled.$Reset" }
                        else { Write-LeftAligned "  Widgets already ON." }
                    }
                    catch {
                        try { ($WToggle.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern)).Invoke(); Write-LeftAligned "$FGGreen$Char_HeavyCheck Widgets clicked.$Reset" } catch {}
                    }
                }
            }
            Stop-Process -Name "SystemSettings" -Force -ErrorAction SilentlyContinue
        }
        else {
            Write-LeftAligned "$FGRed$Char_Warn Could not automate Widgets. Falling back to Registry.$Reset"
            Set-KeySafe $adv "TaskbarDa" 1
        }

        Write-LeftAligned "$FGGreen$Char_HeavyCheck Taskbar defaults reverted.$Reset"



    }
    else {



        # Search: Search icon and label (Value 2)



        Set-KeySafe $search "SearchboxTaskbarMode" 2



        # Taskview: OFF



        Set-KeySafe $adv "ShowTaskViewButton" 0



        # Widgets: OFF (UI Automation Bypass)
        Write-LeftAligned "Toggling Widgets OFF (UI)..."
        Start-Process "ms-settings:taskbar"
        Start-Sleep -Seconds 5
        $Desktop = [System.Windows.Automation.AutomationElement]::RootElement
        $SWindow = $null
        foreach ($title in @("Settings", "Paramètres", "Einstellungen")) {
            $SWindow = $Desktop.FindFirst([System.Windows.Automation.TreeScope]::Children, (New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty, $title)))
            if ($SWindow) { break }
        }
        if ($SWindow) {
            try { $SWindow.SetFocus() } catch {}
            $WElement = &$Global:GetUIA $SWindow "Widgets" $null
            if ($WElement) {
                $WToggle = $null
                if ($WElement.Current.ControlType -eq [System.Windows.Automation.ControlType]::Button -or $WElement.Current.ControlType -eq [System.Windows.Automation.ControlType]::CheckBox) { $WToggle = $WElement }
                else { $WToggle = $WElement.FindFirst([System.Windows.Automation.TreeScope]::Children, (New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Button))) }
                
                if ($WToggle) {
                    try {
                        $WPattern = $WToggle.GetCurrentPattern([System.Windows.Automation.TogglePattern]::Pattern)
                        if ($WPattern.Current.ToggleState -eq 1) { $WPattern.Toggle(); Write-LeftAligned "$FGGreen$Char_HeavyCheck Widgets disabled.$Reset" }
                        else { Write-LeftAligned "  Widgets already OFF." }
                    }
                    catch {
                        try { ($WToggle.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern)).Invoke(); Write-LeftAligned "$FGGreen$Char_HeavyCheck Widgets clicked.$Reset" } catch {}
                    }
                }
            }
            Stop-Process -Name "SystemSettings" -Force -ErrorAction SilentlyContinue
        }
        else {
            Write-LeftAligned "$FGRed$Char_Warn Could not automate Widgets. Falling back to Registry.$Reset"
            Set-KeySafe $adv "TaskbarDa" 0
        }

        Write-LeftAligned "$FGGreen$Char_HeavyCheck Taskbar configuration applied.$Reset"



    }



}








function Invoke-WA_SetWindowsUpdateConfig {
    param([switch]$EnhancedSecurity)
    Write-Header "WINDOWS UPDATE CONFIGURATION"
    
    $WU_UX = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings"
    try {
        Set-RegistryDword -Path $WU_UX -Name "AllowMUUpdateService" -Value 1
        Set-RegistryDword -Path $WU_UX -Name "RestartNotificationsAllowed2" -Value 1

        # Enable Restartable Apps
        $WinlogonPath = "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
        Set-ItemProperty -Path $WinlogonPath -Name "RestartApps" -Value 1 -Type DWord -Force
        
        # External Scripts for Update Settings (Integrated)
        $ScriptExpedited = Get-WA_LibraryScript "SET_Enable-Getmeuptodate.ps1"
        $ScriptMetered = Get-WA_LibraryScript "SET_Enable-Downloadupdatesovermeteredconnections.ps1"

        $TargetState = & { if ($EnhancedSecurity) { "On" } else { "Off" } }
        
        if ($ScriptExpedited) {
            Start-Process "powershell" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptExpedited`" -State $TargetState -NoWait" -Wait -NoNewWindow
        }
        if ($ScriptMetered) {
            Start-Process "powershell" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptMetered`" -State $TargetState -NoWait" -Wait -NoNewWindow
        }
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
    
    Invoke-AnimatedPause -Timeout 5
}

function Invoke-WA_InstallRequiredApps {
    Write-Header "REQUIRED APPLICATIONS"
    
    # Check for Winget
    $winget = Get-Command winget.exe -ErrorAction SilentlyContinue
    if (-not $winget) {
        Write-LeftAligned "$FGRed$Char_FailureX Winget is not installed.$Reset"
        return
    }

    # Temporary Disable Controlled Folder Access for installation
    $cfaChanged = $false
    try {
        $cfa = (Get-MpPreference).EnableControlledFolderAccess
        if ($cfa -eq 1) {
            Write-LeftAligned "$FGDarkYellow$Char_Warn Temporarily disabling Controlled Folder Access...$Reset"
            Set-MpPreference -EnableControlledFolderAccess Disabled -ErrorAction SilentlyContinue
            $cfaChanged = $true
        }
    }
    catch {}

    # Hardcoded App List (Standalone Requirement)
    $Apps = @(
        @{ AppName = "Adobe Creative Cloud"; Type = "WINGET"; WingetId = "Adobe.CreativeCloud"; MatchName = "*Adobe Creative Cloud*" },
        @{ AppName = "Box"; Type = "MSI"; Url = "https://e3.boxcdn.net/box-installers/desktop/releases/win/Box-x64.msi"; MatchName = "Box" },
        @{ AppName = "Box for Office"; Type = "EXE"; Url = "https://e3.boxcdn.net/box-installers/boxforoffice/currentrelease/BoxForOffice.exe"; MatchName = "*Box for Office*"; SilentArgs = "/quiet /norestart"; PreDelay = 10 },
        @{ AppName = "Box Tools"; Type = "EXE"; Url = "https://e3.boxcdn.net/box-installers/boxedit/win/currentrelease/BoxToolsInstaller.exe"; MatchName = "*Box Tools*"; SilentArgs = "/quiet /norestart ALLUSERS=1" }
    )

    # Add Laptop specific apps if applicable
    $chassis = (Get-CimInstance -ClassName Win32_SystemEnclosure -ErrorAction SilentlyContinue).ChassisTypes
    $IsLaptop = ($chassis -and ($chassis -contains 8 -or $chassis -contains 9 -or $chassis -contains 10 -or $chassis -contains 11 -or $chassis -contains 12 -or $chassis -contains 14 -or $chassis -contains 18 -or $chassis -contains 21 -or $chassis -contains 30 -or $chassis -contains 32))
    
    if ($IsLaptop) {
        $Apps += @{ AppName = "Crestron AirMedia"; Type = "WINGET"; WingetId = "Crestron.AirMedia"; MatchName = "*AirMedia*" }
    }

    Write-LeftAligned "Checking application status..."
    $AppsToInstall = @()
    foreach ($app in $Apps) {
        # Simple check for installed app
        $installed = Get-ItemProperty HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*, HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*, HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like $app.MatchName }
        if ($installed) {
            Write-LeftAligned "$FGDarkGreen$Char_BallotCheck Found: $($app.AppName)$Reset"
        }
        else {
            Write-LeftAligned "$FGDarkRed$Char_FailureX Missing: $($app.AppName)$Reset"
            $AppsToInstall += $app
        }
    }

    if ($AppsToInstall.Count -gt 0) {
        Write-Host ""
        Write-BodyTitle "INSTALLATION QUEUE"
        foreach ($app in $AppsToInstall) {
            Write-LeftAligned "$FGWhite $Char_Finger $($app.AppName)$Reset"
        }

        $res = Invoke-AnimatedPause "INSTALL"
        if ($res.VirtualKeyCode -eq 13) {
            foreach ($app in $AppsToInstall) {
                Write-LeftAligned "$FGDarkCyan Installing $($app.AppName)...$Reset"
                if ($app.PreDelay) { Start-Sleep -Seconds $app.PreDelay }

                try {
                    if ($app.Type -eq "WINGET") {
                        Start-Process "winget.exe" -ArgumentList "install --id $($app.WingetId) -e --silent --accept-package-agreements --accept-source-agreements" -Wait -NoNewWindow
                    }
                    elseif ($app.Type -eq "MSI") {
                        $tmp = Join-Path $env:TEMP "wa_installer.msi"
                        Invoke-WebRequest -Uri $app.Url -OutFile $tmp -UseBasicParsing
                        Start-Process "msiexec.exe" -ArgumentList "/i `"$tmp`" /qn /norestart" -Wait -NoNewWindow
                        Remove-Item $tmp -Force
                    }
                    elseif ($app.Type -eq "EXE") {
                        $tmp = Join-Path $env:TEMP "wa_installer.exe"
                        Invoke-WebRequest -Uri $app.Url -OutFile $tmp -UseBasicParsing
                        Start-Process $tmp -ArgumentList $app.SilentArgs -Wait -NoNewWindow
                        Remove-Item $tmp -Force
                    }
                    Write-LeftAligned "$FGGreen$Char_HeavyCheck Completed $($app.AppName).$Reset"
                }
                catch {
                    Write-LeftAligned "$FGRed$Char_FailureX Failed: $($_.Exception.Message)$Reset"
                }
            }
        }
    }
    else {
        Write-LeftAligned "$FGGreen$Char_HeavyCheck All applications are present.$Reset"
    }

    # Re-enable Controlled Folder Access if changed
    if ($cfaChanged) {
        try {
            Write-LeftAligned "$FGDarkYellow$Char_Warn Re-enabling Controlled Folder Access...$Reset"
            Set-MpPreference -EnableControlledFolderAccess Enabled -ErrorAction SilentlyContinue
        }
        catch {}
    }
}

function Invoke-WA_InstallCppRedist {
    Write-Header "INSTALL C++ REDIST"

    # Temporary Disable Controlled Folder Access
    $cfaChanged = $false
    try {
        $cfa = (Get-MpPreference).EnableControlledFolderAccess
        if ($cfa -eq 1) {
            Write-LeftAligned "$FGDarkYellow$Char_Warn Temporarily disabling Controlled Folder Access...$Reset"
            Set-MpPreference -EnableControlledFolderAccess Disabled -ErrorAction SilentlyContinue
            $cfaChanged = $true
        }
    }
    catch {}

    $TempDir = "$env:TEMP\WinAuto_CppRedist"
    if (-not (Test-Path $TempDir)) { New-Item -Path $TempDir -ItemType Directory -Force | Out-Null }

    $Installers = @(
        @{ Name = "Visual C++ 2015-2022 (x64)"; Url = "https://aka.ms/vs/17/release/vc_redist.x64.exe"; File = "$TempDir\vc_redist.x64.exe"; Args = "/install /quiet /norestart" },
        @{ Name = "Visual C++ 2015-2022 (x86)"; Url = "https://aka.ms/vs/17/release/vc_redist.x86.exe"; File = "$TempDir\vc_redist.x86.exe"; Args = "/install /quiet /norestart" }
    )

    foreach ($app in $Installers) {
        Write-LeftAligned "$FGGray Downloading $($app.Name)...$Reset"
        try {
            Invoke-WebRequest -Uri $app.Url -OutFile $app.File -ErrorAction Stop
            Write-LeftAligned "$FGGray Installing $($app.Name)...$Reset"
            $proc = Start-Process -FilePath $app.File -ArgumentList $app.Args -Wait -PassThru -NoNewWindow
            
            if ($proc.ExitCode -eq 0 -or $proc.ExitCode -eq 3010) {
                Write-LeftAligned "$FGGreen$Char_HeavyCheck Installed $($app.Name).$Reset"
            }
            elseif ($proc.ExitCode -eq 1638) {
                Write-LeftAligned "$FGGreen$Char_CheckMark Newer version already installed.$Reset"
            }
            else {
                Write-LeftAligned "$FGRed$Char_RedCross Failed (Exit: $($proc.ExitCode)).$Reset"
            }
        }
        catch {
            Write-LeftAligned "$FGRed$Char_RedCross Error: $($_.Exception.Message)$Reset"
        }
    }
    try { Remove-Item -Path $TempDir -Recurse -Force -ErrorAction SilentlyContinue } catch {}

    # Re-enable Controlled Folder Access if changed
    if ($cfaChanged) {
        try {
            Write-LeftAligned "$FGDarkYellow$Char_Warn Re-enabling Controlled Folder Access...$Reset"
            Set-MpPreference -EnableControlledFolderAccess Enabled -ErrorAction SilentlyContinue
        }
        catch {}
    }

    Write-Host ""
    Write-LeftAligned "$FGCyan Done.$Reset"
}

function Invoke-WA_WindowsUpdate {
    Write-Header "WINDOWS UPDATE SCAN"

    # Status
    try {
        $Session = New-Object -ComObject Microsoft.Update.Session
        $Searcher = $Session.CreateUpdateSearcher()
        $Searcher.Online = $false
        $Result = $Searcher.Search("IsInstalled=0")
        if ($Result.Updates.Count -gt 0) {
            Write-LeftAligned "$FGDarkMagenta$Char_Warn $($Result.Updates.Count) updates pending (Offline Check).$Reset"
        }
        else {
            Write-LeftAligned "$FGGreen$Char_CheckMark System appears up to date (Offline Check).$Reset"
        }
    }
    catch { Write-LeftAligned "$FGGray Cannot perform offline check.$Reset" }

    # Automation
    Write-Host ""
    Write-Centered "$Char_EnDash WINGET UPDATE $Char_EnDash" -Color "$Bold$FGCyan"
    if (Get-Command winget.exe -ErrorAction SilentlyContinue) {
        Write-LeftAligned "Running winget upgrade..."
        Start-Process "winget.exe" -ArgumentList "upgrade --all --include-unknown --accept-package-agreements --silent" -Wait -NoNewWindow
    }

    Write-Host ""
    Write-Centered "$Char_EnDash STORE & SETTINGS $Char_EnDash" -Color "$Bold$FGCyan"

    # UI Automation Setup
    try {
        if (-not ([System.Management.Automation.PSTypeName]"System.Windows.Automation.AutomationElement").Type) {
            Add-Type -AssemblyName UIAutomationClient
            Add-Type -AssemblyName UIAutomationTypes
        }
    }
    catch {
        Write-LeftAligned "$FGRed$Char_RedCross Failed to load UI Automation assemblies.$Reset"
    }

    # 1. Windows Update Settings
    Write-LeftAligned "Opening Windows Update Settings..."
    Start-Process "ms-settings:windowsupdate"
    
    # Wait for Window
    $timeout = 10
    $startTime = Get-Date
    $settingsWindow = $null
    
    do {
        $desktop = [System.Windows.Automation.AutomationElement]::RootElement
        $condition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty, "Settings")
        $settingsWindow = $desktop.FindFirst([System.Windows.Automation.TreeScope]::Children, $condition)
        if ($null -ne $settingsWindow) { break }
        Start-Sleep -Milliseconds 500
    } while ((Get-Date) -lt $startTime.AddSeconds($timeout))
    
    if ($settingsWindow) {
        Start-Sleep -Seconds 2
        $targetButtons = @("Check for updates", "Download & install all", "Install all", "Restart now")
        $buttonFound = $false
        foreach ($text in $targetButtons) {
            $buttonCondition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty, $text)
            $button = $settingsWindow.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $buttonCondition)
            if ($button) {
                $invokePattern = $button.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern)
                if ($invokePattern) {
                    $invokePattern.Invoke()
                    Write-LeftAligned "$FGGreen$Char_HeavyCheck Clicked '$text'$Reset"
                    $buttonFound = $true
                    break
                }
            }
        }
        if (-not $buttonFound) { Write-LeftAligned "$FGGray No actionable buttons found in Settings.$Reset" }
    }
    else {
        Write-LeftAligned "$FGRed$Char_Warn Could not attach to Settings window.$Reset"
    }

    # 2. Microsoft Store
    Write-LeftAligned "Opening Microsoft Store Updates..."
    Start-Process "ms-windows-store://downloadsandupdates"
    
    $timeout = 10
    $startTime = Get-Date
    $storeWindow = $null
    
    do {
        $desktop = [System.Windows.Automation.AutomationElement]::RootElement
        $condition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty, "Microsoft Store")
        $storeWindow = $desktop.FindFirst([System.Windows.Automation.TreeScope]::Children, $condition)
        if ($null -ne $storeWindow) { break }
        Start-Sleep -Milliseconds 500
    } while ((Get-Date) -lt $startTime.AddSeconds($timeout))

    if ($storeWindow) {
        Start-Sleep -Seconds 2
        $buttonTexts = @("Get updates", "Check for updates", "Update all")
        $buttonFound = $false
        foreach ($buttonText in $buttonTexts) {
            $buttonCondition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty, $buttonText)
            $button = $storeWindow.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $buttonCondition)
            if ($button) {
                $invokePattern = $button.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern)
                if ($invokePattern) {
                    $invokePattern.Invoke()
                    Write-LeftAligned "$FGGreen$Char_HeavyCheck Clicked '$buttonText'$Reset"
                    $buttonFound = $true
                    break
                }
            }
        }
        if (-not $buttonFound) { Write-LeftAligned "$FGGray No update button found in Store.$Reset" }
    }
    else {
        Write-LeftAligned "$FGRed$Char_Warn Could not attach to Store window.$Reset"
    }
    
    Write-LeftAligned "$FGGray Checks initiated. Monitor windows for progress.$Reset"
    Start-Sleep -Seconds 3
}

function Invoke-WA_SFCRepair {
    Write-Header "SYSTEM REPAIR (SFC)"
    Write-LeftAligned "Running sfc /scannow..."
    $raw = & sfc /scannow 2>&1
    $out = ($raw -join " ")
    if ($out -match "did not find any integrity violations") {
        Write-LeftAligned "$FGGreen$Char_CheckMark System Healthy.$Reset"
    }
    elseif ($out -match "successfully repaired") {
        Write-LeftAligned "$FGGreen$Char_CheckMark corruption repaired.$Reset"
    }
    else {
        Write-LeftAligned "$FGRed$Char_Warn Corruption found. Running DISM...$Reset"
        & DISM /Online /Cleanup-Image /RestoreHealth | Out-Null
    }
}

function Invoke-WA_OptimizeDisks {
    Write-Header "DISK OPTIMIZATION"
    $vols = Get-Volume | Where-Object { $_.DriveLetter -and $_.DriveType -eq 'Fixed' }
    foreach ($v in $vols) {
        Write-LeftAligned "Optimizing Drive $($v.DriveLetter)..."
        Optimize-Volume -DriveLetter $v.DriveLetter -NormalPriority -ErrorAction SilentlyContinue
    }
    Write-LeftAligned "$FGGreen$Char_CheckMark Complete.$Reset"
}

function Invoke-WA_SystemCleanup {
    Write-Header "SYSTEM CLEANUP"
    $paths = @("$env:TEMP", "$env:WINDIR\Temp")
    foreach ($p in $paths) {
        Write-LeftAligned "Cleaning $p..."
        Get-ChildItem -Path $p -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    }
    Write-LeftAligned "$FGGreen$Char_CheckMark Cleanup Complete.$Reset"
}

# --- MODULE HANDLERS ---

function Invoke-WinAutoConfiguration {
    param([switch]$SmartRun, [switch]$EnhancedSecurity)
    Write-Header "WINDOWS CONFIGURATION PHASE"
    $lastRun = Get-WinAutoLastRun -Module "Configuration"
    Write-LeftAligned "$FGGray Last Run: $FGWhite$lastRun$Reset"

    if ($SmartRun -and $lastRun -ne "Never") {
        $lastDate = Get-Date $lastRun
        if ((Get-Date) -lt $lastDate.AddDays(30)) {
            Write-LeftAligned "$FGGreen$Char_CheckMark Configuration is up to date. Skipping...$Reset"
            return
        }
    }
    Write-Boundary

    Invoke-WA_SetRealTimeProtection
    Invoke-WA_SetPUA
    Invoke-WA_SetMemoryIntegrity
    Invoke-WA_SetLSA
    Invoke-WA_SetKernelStack
    Invoke-WA_SetPhishingMalicious
    Invoke-WA_SetFirewall
    
    # UI & Performance
    Invoke-WA_SetTaskbarDefaults
    Invoke-WA_SetWindowsUpdateConfig -EnhancedSecurity:$EnhancedSecurity
    
    # Restart Explorer to apply Standard UI changes
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
        Write-LeftAligned "$FGGreen$Char_CheckMark Skipping $Key (Run < $Days days ago).$Reset"
        return $false
    }

    Write-Boundary
    Invoke-WA_SystemPreCheck
    Invoke-WA_WindowsUpdate

    if (Test-RunNeeded -Key "Maintenance_Cpp" -Days 90) {
        Invoke-WA_InstallCppRedist
        Set-WinAutoLastRun -Module "Maintenance_Cpp"
    }

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

    Write-Host ""
    Write-Centered "$FGGreen MAINTENANCE COMPLETE $Reset"
    Set-WinAutoLastRun -Module "Maintenance"
    Start-Sleep -Seconds 2
}

# --- MAIN EXECUTION ---
# Ensure log directory exists
if (-not (Test-Path $Global:WinAutoLogDir)) { New-Item -Path $Global:WinAutoLogDir -ItemType Directory -Force | Out-Null }
Write-Log "WinAuto Standalone Session Started" -Level INFO
Set-ConsoleSnapRight -Columns 56
Disable-QuickEdit

while ($true) {
    Write-Header "WINAUTO: MASTER CONTROL"
    $lastConfig = Get-WinAutoLastRun -Module "Configuration"
    $lastMaint = Get-WinAutoLastRun -Module "Maintenance"
    $enStatus = & { if ($Global:EnhancedSecurity) { "${FGGreen}ON" } else { "${FGDarkGray}OFF" } }
    $iStatus = & { if ($Global:InstallApps) { "${FGGreen}ON" } else { "${FGDarkGray}OFF" } }

    Write-Host ""
    Write-LeftAligned "=>${FGBlack}${BGYellow}[S]${Reset}${FGYellow}mart Run${Reset}"
    Write-Host ""
    Write-LeftAligned "  ${FGYellow}[C]${Reset}${FGGray}onfiguration ${FGDarkGray}(Last: $lastConfig)${Reset}"
    Write-LeftAligned "      ${FGYellow}[E]${Reset}${FGGray}nhanced Security (Toggle: $enStatus${FGGray})${Reset}"
    if ($Global:ShowDetails) { 
        Write-LeftAligned "      ${FGDarkGray}Sec: RT, PUA, Memory, LSA, Stack, Phishing${Reset}"
        Write-LeftAligned "      ${FGDarkGray}Net: Windows Firewall (All Profiles)${Reset}"
        Write-LeftAligned "      ${FGDarkGray}UI : Taskbar Defaults & Windows Update${Reset}"
    }
    Write-Host ""
    Write-LeftAligned "  ${FGYellow}[M]${Reset}${FGGray}aintenance   ${FGDarkGray}(Last: $lastMaint)${Reset}"
    Write-LeftAligned "      ${FGYellow}[I]${Reset}${FGGray}nstall Applications${FGGray} (Toggle: $iStatus${FGGray})${Reset}"
    if ($Global:ShowDetails) { 
        Write-LeftAligned "      ${FGDarkGray}Apps: WinGet, Store, C++ Redistributables${Reset}"
        Write-LeftAligned "      ${FGDarkGray}OS  : Windows Update & SFC System Repair${Reset}"
        Write-LeftAligned "      ${FGDarkGray}Disk: Cleanup (Temp) & Drive Optimization${Reset}"
    }
    Write-Host ""
    $DetailText = & { if ($Global:ShowDetails) { "Details (Collapse)" } else { "Details (Expand)" } }
    Write-LeftAligned "  ${FGYellow}Space${Reset} ${FGGray}$DetailText${Reset}"
    Write-Host ""
    Write-LeftAligned "  ${FGYellow}[H]${Reset}${FGCyan}elp / System Impact${Reset}"
    Write-LeftAligned "  ${FGRed}[Esc] Exit Script${Reset}"
    Write-Boundary

    # Timeout logic: Only on first load (when no action has been taken yet)
    $ActionText = "RUN"
    $TimeoutSecs = & { if ($Global:WinAutoFirstLoad -ne $false) { 10 } else { 0 } }
    $Global:WinAutoFirstLoad = $false

    $res = Invoke-AnimatedPause -ActionText $ActionText -Timeout $TimeoutSecs

    if ($res.VirtualKeyCode -eq 27) {
        Write-LeftAligned "$FGGray Exiting WinAuto...$Reset"
        Start-Sleep -Seconds 1
        break
    }
    elseif ($res.VirtualKeyCode -eq 13 -or $res.Character -eq 'S' -or $res.Character -eq 's') {
        Invoke-WinAutoConfiguration -SmartRun -EnhancedSecurity:$Global:EnhancedSecurity
        Invoke-WinAutoMaintenance -SmartRun
        if ($Global:InstallApps) { Invoke-WA_InstallRequiredApps }
    }
    elseif ($res.Character -eq 'C' -or $res.Character -eq 'c') {
        Invoke-WinAutoConfiguration -EnhancedSecurity:$Global:EnhancedSecurity
    }
    elseif ($res.Character -eq 'M' -or $res.Character -eq 'm') {
        Invoke-WinAutoMaintenance
        if ($Global:InstallApps) { Invoke-WA_InstallRequiredApps }
    }
    elseif ($res.Character -eq 'E' -or $res.Character -eq 'e') {
        $Global:EnhancedSecurity = -not $Global:EnhancedSecurity
        continue
    }
    elseif ($res.Character -eq ' ' -or $res.VirtualKeyCode -eq 32) {
        $Global:ShowDetails = -not $Global:ShowDetails
        continue
    }
    elseif ($res.Character -eq 'I' -or $res.Character -eq 'i') {
        $Global:InstallApps = -not $Global:InstallApps
        continue
    }
    elseif ($res.Character -eq 'H' -or $res.Character -eq 'h') {
        Clear-Host
        Write-Header "SYSTEM IMPACT MANIFEST"
        $Global:WinAutoManifestContent | Out-Host
        Write-Boundary
        Write-Centered "Press any key to return..."
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
    else {
        Write-LeftAligned "$FGGray Exiting WinAuto...$Reset"
        Start-Sleep -Seconds 1
        break
    }
}

Get-LogReport
Write-Host ""
Write-Boundary
Write-Centered "$FGGreen ALL REQUESTED TASKS COMPLETE $Reset"
Write-Footer
Write-Host ""
Invoke-AnimatedPause -ActionText "EXIT" -Timeout 0
Write-Host ""
Write-Host ""
Write-Host ""
Write-Host ""
Write-Host ""
