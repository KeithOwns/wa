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
$Global:EnhancedSecurity = $false
$Global:RegPath_WU_UX = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings"
$Global:RegPath_WU_POL = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
$Global:RegPath_Winlogon_User = "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" 
$Global:RegPath_Winlogon_Machine = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"

# --- MANIFEST CONTENT ---

$Global:WinAutoManifestContent = @'
- wa.ps1: Functional Outline -
________________________________________________________
Pre-Run Setup		    | METHOD
- Execution Policy          | PS (RemoteSigned)
- Auto-Unblock              | PS (Unblock-File)
________________________________________________________
[S]mart Run
Method: Orchestration Loop
Actions:
- System Hardening Check (Registry & Logic)
- Maintenance Cycle (Component Check/Days)
- Auto-Cleanup (File System)
________________________________________________________
[C]onfiguration		    | METHOD
Security Actions:
- Real-Time Protection      | PS WMI (MpPreference)
- PUA Protection (Defender) | PS WMI (MpPreference)
- PUA Protection (Edge)     | RegEdit (HKCU)
- Memory Integrity          | RegEdit (HKLM)
- LSA Protection            | RegEdit (HKLM)
- Kernel Stack Protection   | UI Automation
- Phishing Protection       | RegEdit (HKCU)
- Windows Firewall          | Set-NetFirewallProfile
UI & User Experience Actions:
- Taskbar Search Box        | RegEdit (HKCU)
- Task View Toggle          | RegEdit (HKCU)
- Widgets Toggle            | UI Automation (Settings)
- Microsoft Update Service  | RegEdit (HKLM)
- Restart Notifications     | RegEdit (HKLM)
- App Restart Persistence   | RegEdit (HKCU)
________________________________________________________
[E]nhanced Security (Toggle)| METHOD
- Expedited Updates         | UI Automation
- Restart ASAP              | UI Automation
- Metered Connection        | RegEdit (HKLM)
________________________________________________________
[M]aintenance		    | METHOD
OS Repair & Updates:
- Windows Update Check      | COM Object & UI Automation
- SFC System Scan           | Command Line (sfc.exe)
- DISM Repair               | Command Line (dism.exe)
Application Maintenance:
- WinGet App Updates        | Command Line (winget.exe)
- MS Store App Updates      | UI Automation (Store UI)
Disk Maintenance:
- Drive Optimization (TRIM) | PS (Optimize-Volume)
- Temp File Cleanup         | FSR (Recursive)
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
$FGDarkGray = "$Esc[90m"
$FGDarkGreen = "$Esc[32m"
$FGDarkRed = "$Esc[31m"
$FGDarkCyan = "$Esc[36m"

$FGWhite = "$Esc[97m"
$FGGray = "$Esc[37m"
$FGDarkYellow = "$Esc[33m"
$FGBlack = "$Esc[30m"

# Script Palette (Background)
$BGDarkGreen = "$Esc[42m"
$BGDarkGray = "$Esc[100m"
$BGYellow = "$Esc[103m"

# --- Unicode Icons & Characters ---
$Global:Char_HeavyCheck = "[v]" 
$Global:Char_Warn = [char]0x26A0 
$Global:Char_BallotCheck = "[v]" 

$Global:Char_Copyright = "(c)" 
$Global:Char_Finger = "->" 
$Global:Char_CheckMark = "v" 
$Global:Char_FailureX = "x" 
$Global:Char_RedCross = "x"
$Global:Char_HeavyMinus = "-" 
$Global:Char_EnDash = [char]0x2013

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
    param([int]$Columns = 64)
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

function Set-ConsoleSnapLeft {
    param([int]$Columns = 56)
    try {
        if (-not ([System.Management.Automation.PSTypeName]"WinAutoNative.ConsoleUtils").Type) {
            # Reuse existing type, it should be loaded by SnapRight
            return
        }
        $buffer = $Host.UI.RawUI.BufferSize
        $window = $Host.UI.RawUI.WindowSize
        
        # 2. Position Adjustment
        $hWnd = [WinAutoNative.ConsoleUtils]::GetConsoleWindow()
        # Get actual pixel width 
        $rect = New-Object WinAutoNative.RECT
        if ([WinAutoNative.ConsoleUtils]::GetWindowRect($hWnd, [ref]$rect)) {
            $pixelW = $rect.Right - $rect.Left
            $screenH = [WinAutoNative.ConsoleUtils]::GetSystemMetrics(1) # SM_CYSCREEN
            
            # Snap to Left
            [WinAutoNative.ConsoleUtils]::MoveWindow($hWnd, 0, 0, $pixelW, $screenH, $true) | Out-Null
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
    Write-Host "$Color$([string]'_' * 64)$Reset"
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
    param($ElapsedTimespan, $ActionText = "CONTINUE", $Timeout = 10, $PromptCursorTop, $SelectionChar = $null, $PreActionWord = "to")
    if ($null -eq $PromptCursorTop) { $PromptCursorTop = [Console]::CursorTop }
    
    # Dynamic prompt based on selection char (Dashboard vs Standard)
    if ($SelectionChar) {
        if ($SelectionChar -eq "->") {
            # Initial Mockup Special Case: "Press -> [Enter] for SmartRun"
            # Note: The mockup uses "->". We'll color it Yellow.
            $PromptStr = "$FGWhite[Key] Press ${FGYellow}->${Reset}${FGWhite} ${FGBlack}${BGYellow}[Enter]${Reset}$FGWhite $PreActionWord ${FGYellow}$ActionText${Reset} $FGWhite| ${FGRed}[Esc]${Reset}$FGWhite to ${FGRed}EXIT$Reset"
        }
        else {
            # Standard Dynamic with Hotkey option
            $PromptStr = "$FGWhite[Key] Move ${FGYellow}->${Reset}$FGWhite and Press ${FGBlack}${BGYellow}[Enter]${Reset}$FGWhite or ${FGBlack}${BGYellow}[$SelectionChar]${Reset}$FGWhite $PreActionWord ${FGYellow}$ActionText${Reset} $FGWhite| ${FGRed}[Esc]${Reset}$FGWhite to ${FGRed}EXIT$Reset"
        }
    }
    else {
        # Standard fallback text: "Press [Enter] to RUN"
        $PromptStr = "$FGWhite[Key] Press ${FGBlack}${BGYellow}[Enter]${Reset}$FGWhite $PreActionWord ${FGYellow}$ActionText${Reset}   $FGWhite| Press ${FGRed}[Esc]${Reset}$FGWhite to ${FGRed}EXIT$Reset"
    }
    
    try { [Console]::SetCursorPosition(0, $PromptCursorTop); Write-Centered $PromptStr -Width 60 } catch {}
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
    param([switch]$Undo)
    Write-Header "MEMORY INTEGRITY"
    $target = & { if ($Undo) { 0 } else { 1 } }
    $path = "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity"
    try {
        Set-RegistryDword -Path $path -Name "Enabled" -Value $target
        if ($target -eq 1) { Set-RegistryDword -Path $path -Name "WasEnabledBy" -Value 2 }
        Write-LeftAligned "$FGGreen$Global:Char_BallotCheck Memory Integrity configured.$Reset"
    }
    catch { Write-LeftAligned "$FGRed$Char_RedCross Failed: $($_.Exception.Message)$Reset" }
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
    param([switch]$Undo)
    Write-Header "KERNEL STACK PROTECTION"
    $target = & { if ($Undo) { 0 } else { 1 } }
    
    # 1. Registry Baseline
    try {
        Set-RegistryDword -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Kernel" -Name "KernelSEHOPEnabled" -Value $target
        Write-LeftAligned "$FGGreen$Global:Char_BallotCheck Registry baseline set.$Reset"
    }
    catch {
        Write-LeftAligned "$FGRed$Char_Warn Registry baseline failed.$Reset"
    }

    # 2. Try External Script (Repository Mode)
    $ExternalScriptPath = Get-WA_LibraryScript "SET_EnableKernelModeHardwareStackProtection-wa.ps1"
    
    if ($ExternalScriptPath) {
        Write-LeftAligned "$FGGray Launching security module in isolated process...$Reset"
        try {
            $ProcArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $ExternalScriptPath)
            if ($Undo) { $ProcArgs += "-Undo" } else { $ProcArgs += "-Force" }
            $p = Start-Process -FilePath "powershell.exe" -ArgumentList $ProcArgs -Wait -PassThru -NoNewWindow
            if ($p.ExitCode -eq 0) {
                Write-LeftAligned "$FGGreen$Global:Char_CheckMark Kernel Stack Protection automation finished.$Reset"
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
    Set-ConsoleSnapLeft

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
        
        # Check for 'Scan again' (WinAuto Requirement)
        $ScanBtn = &$Global:GetUIA $Window "Scan again" ([System.Windows.Automation.ControlType]::Button) 2
        if ($ScanBtn) {
            try {
                ($ScanBtn.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern)).Invoke()
                Write-LeftAligned "   $FGGray(Scanning drivers...)$Reset"
                Start-Sleep -Seconds 6
            }
            catch {}
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
        Write-LeftAligned "$FGGreen$Global:Char_HeavyCheck Malicious App Warning configured.$Reset"
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



        Set-KeySafe $search "SearchboxTaskbarMode" 2



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



        # Search: Search box (Value 3)
        Set-KeySafe $search "SearchboxTaskbarMode" 3



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

    if (-not $EnhancedSecurity) {
        Write-LeftAligned "$FGGray Enhanced Security is OFF. Skipping strict enforcement.$Reset"
        return
    }

    $WU_UX = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings"

    # -----------------------------------------------------------------------------------------
    # 1. EXPEDITED UPDATES (UI AUTOMATION)
    # -----------------------------------------------------------------------------------------
    Write-LeftAligned "Step 1/5: Expedited Updates (UI Automation)..."

    # Load Assemblies
    if (-not ([System.Management.Automation.PSTypeName]"System.Windows.Automation.AutomationElement").Type) {
        Add-Type -AssemblyName UIAutomationClient
        Add-Type -AssemblyName UIAutomationTypes
    }

    # Launch Settings
    Start-Process "ms-settings:windowsupdate"
    Start-Sleep -Seconds 3

    $Desktop = [System.Windows.Automation.AutomationElement]::RootElement
    $Window = $null
    $Timeout = 10
    $Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    while ($null -eq $Window -and $Stopwatch.Elapsed.TotalSeconds -lt $Timeout) {
        foreach ($title in @("Settings", "Paramètres", "Einstellungen")) {
            $Window = $Desktop.FindFirst([System.Windows.Automation.TreeScope]::Children, 
                (New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty, $title)))
            if ($Window) { break }
        }
        Start-Sleep -Milliseconds 500
    }

    if ($Window) {
        try { $Window.SetFocus() } catch {}
        $TargetName = "Get the latest updates as soon as they're available"
        $ToggleElement = $Window.FindFirst([System.Windows.Automation.TreeScope]::Descendants, 
            (New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty, $TargetName)))
        
        if ($ToggleElement) {
            # Try finding the toggle in the same container (Parent)
            $Parent = [System.Windows.Automation.TreeWalker]::ControlViewWalker.GetParent($ToggleElement)
            $ActualToggle = $null

            if ($Parent) {
                $ActualToggle = $Parent.FindFirst([System.Windows.Automation.TreeScope]::Descendants, 
                    (New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Button)))
                
                if (-not $ActualToggle) {
                    $ActualToggle = $Parent.FindFirst([System.Windows.Automation.TreeScope]::Descendants, 
                        (New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::CheckBox)))
                }
            }

            if (-not $ActualToggle) {
                if ($ToggleElement.Current.ControlType -eq [System.Windows.Automation.ControlType]::Button -or $ToggleElement.Current.ControlType -eq [System.Windows.Automation.ControlType]::CheckBox -or $ToggleElement.Current.ControlType -eq [System.Windows.Automation.ControlType]::ListItem) {
                    $ActualToggle = $ToggleElement
                }
            }

            if ($ActualToggle) {
                try {
                    if ($ActualToggle.GetSupportedPatterns() -contains [System.Windows.Automation.TogglePattern]::Pattern) {
                        $Pattern = $ActualToggle.GetCurrentPattern([System.Windows.Automation.TogglePattern]::Pattern)
                        if ($Pattern.Current.ToggleState -eq 0) {
                            $Pattern.Toggle()
                            Write-LeftAligned "$FGGreen$Char_HeavyCheck 'Get latest updates' toggled ON.$Reset"
                        }
                        else {
                            Write-LeftAligned "$FGGreen$Char_CheckMark 'Get latest updates' already ON.$Reset"
                        }
                    }
                    else {
                        ($ActualToggle.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern)).Invoke()
                        Write-LeftAligned "$FGGreen$Char_HeavyCheck 'Get latest updates' clicked.$Reset"
                    }
                }
                catch { Write-LeftAligned "$FGRed$Char_Warn Failed to toggle 'Get latest updates'.$Reset" }
            }
            else { Write-LeftAligned "$FGRed$Char_Warn Could not identify toggle for 'Get latest updates'.$Reset" }
        }
        else { Write-LeftAligned "$FGRed$Char_Warn 'Get latest updates' label not found.$Reset" }
    }
    else { Write-LeftAligned "$FGRed$Char_Warn Settings window not found (Step 1).$Reset" }

    # -----------------------------------------------------------------------------------------
    # 2. RESTART ASAP (UI AUTOMATION)
    # -----------------------------------------------------------------------------------------
    Write-LeftAligned "Step 2/5: Restart ASAP (Adv. Options)..."
    Start-Process "ms-settings:windowsupdate-options"
    Start-Sleep -Seconds 3
    
    # Re-find Window for robustness
    $Window = $null
    $Stopwatch.Restart()
    while ($null -eq $Window -and $Stopwatch.Elapsed.TotalSeconds -lt $Timeout) {
        foreach ($title in @("Settings", "Paramètres", "Einstellungen")) {
            $Window = $Desktop.FindFirst([System.Windows.Automation.TreeScope]::Children, 
                (New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty, $title)))
            if ($Window) { break }
        }
        Start-Sleep -Milliseconds 500
    }

    if ($Window) {
        try { $Window.SetFocus() } catch {}
        $Toggles = $Window.FindAll([System.Windows.Automation.TreeScope]::Descendants, 
            (New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Button)))

        if (-not $Toggles) {
            $Toggles = $Window.FindAll([System.Windows.Automation.TreeScope]::Descendants, 
                (New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::CheckBox)))
        }

        $ActualToggle = $null
        if ($Toggles) {
            foreach ($t in $Toggles) {
                $n = $t.Current.Name
                if ($null -ne $n -and ($n -match "Get me up to date" -or $n -match "Restart as soon as possible")) {
                    $ActualToggle = $t; break
                }
            }
        }

        if ($ActualToggle) {
            try {
                if ($ActualToggle.GetSupportedPatterns() -contains [System.Windows.Automation.TogglePattern]::Pattern) {
                    $Pattern = $ActualToggle.GetCurrentPattern([System.Windows.Automation.TogglePattern]::Pattern)
                    if ($Pattern.Current.ToggleState -eq 0) {
                        $Pattern.Toggle()
                        Write-LeftAligned "$FGGreen$Char_HeavyCheck 'Get me up to date' toggled ON.$Reset"
                    }
                    else {
                        Write-LeftAligned "$FGGreen$Char_CheckMark 'Get me up to date' already ON.$Reset"
                    }
                }
                else {
                    ($ActualToggle.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern)).Invoke()
                    Write-LeftAligned "$FGGreen$Char_HeavyCheck 'Get me up to date' clicked.$Reset"
                }
            }
            catch { Write-LeftAligned "$FGRed$Char_Warn Failed to toggle 'Get me up to date'.$Reset" }
        }
        else { Write-LeftAligned "$FGRed$Char_Warn Toggle 'Get me up to date' not found.$Reset" }
        
        # Cleanup Settings Window
        Stop-Process -Name "SystemSettings" -Force -ErrorAction SilentlyContinue

    }
    else { Write-LeftAligned "$FGRed$Char_Warn Settings window not found (Step 2).$Reset" }


    # -----------------------------------------------------------------------------------------
    # 3. METERED CONNECTIONS (REGISTRY)
    # -----------------------------------------------------------------------------------------
    Write-LeftAligned "Step 3/5: Download over Metered Connections..."
    try {
        Set-RegistryDword -Path $WU_UX -Name "AllowAutoWindowsUpdateDownloadOverMeteredNetwork" -Value 1
        Write-LeftAligned "$FGGreen$Char_HeavyCheck Metered downloads enabled (Registry).$Reset"
    }
    catch {
        Write-LeftAligned "$FGRed$Char_Warn Failed to set Metered Connections registry key.$Reset"
    }

    # -----------------------------------------------------------------------------------------
    # 4. MICROSOFT UPDATES (REGISTRY)
    # -----------------------------------------------------------------------------------------
    Write-LeftAligned "Step 4/5: Receive updates for other Microsoft products..."
    try {
        Set-RegistryDword -Path $WU_UX -Name "AllowMUUpdateService" -Value 1
        Write-LeftAligned "$FGGreen$Char_HeavyCheck Microsoft Update Service enabled.$Reset"
    }
    catch {
        Write-LeftAligned "$FGRed$Char_Warn Failed to set MU Registry key.$Reset"
    }

    # -----------------------------------------------------------------------------------------
    # 5. RESTART NOTIFICATIONS (REGISTRY)
    # -----------------------------------------------------------------------------------------
    Write-LeftAligned "Step 5/5: Notify when restart required..."
    try {
        Set-RegistryDword -Path $WU_UX -Name "RestartNotificationsAllowed2" -Value 1
        Write-LeftAligned "$FGGreen$Char_HeavyCheck Restart Notifications enabled.$Reset"
    }
    catch {
        Write-LeftAligned "$FGRed$Char_Warn Failed to set Restart Notifications key.$Reset"
    }
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
    Write-Centered "$Global:Char_EnDash WINGET UPDATE $Global:Char_EnDash" -Color "$Bold$FGCyan"
    if (Get-Command winget.exe -ErrorAction SilentlyContinue) {
        Write-LeftAligned "Running winget upgrade..."
        Start-Process "winget.exe" -ArgumentList "upgrade --all --include-unknown --accept-package-agreements --silent" -Wait -NoNewWindow
    }

    Write-Host ""
    Write-Centered "$Global:Char_EnDash STORE & SETTINGS $Global:Char_EnDash" -Color "$Bold$FGCyan"

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
        Write-LeftAligned "$FGGreen$Global:Char_CheckMark System Healthy.$Reset"
    }
    elseif ($out -match "successfully repaired") {
        Write-LeftAligned "$FGGreen$Global:Char_CheckMark corruption repaired.$Reset"
    }
    else {
        Write-LeftAligned "$FGRed$Global:Char_Warn Corruption found. Running DISM...$Reset"
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

# --- MODULE HANDLERS ---

function Invoke-WinAutoConfiguration {
    param([switch]$SmartRun, [switch]$EnhancedSecurity)
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

    Write-Boundary
    Invoke-WA_SystemPreCheck
    Invoke-WA_WindowsUpdate

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

    Write-Host ""
    Write-Centered "$FGGreen MAINTENANCE COMPLETE $Reset"
    Set-WinAutoLastRun -Module "Maintenance"
    Start-Sleep -Seconds 2
}

# --- MAIN EXECUTION ---
# Ensure log directory exists
if (-not (Test-Path $Global:WinAutoLogDir)) { New-Item -Path $Global:WinAutoLogDir -ItemType Directory -Force | Out-Null }
Write-Log "WinAuto Standalone Session Started" -Level INFO
Set-ConsoleSnapRight -Columns 64
Disable-QuickEdit

$MenuSelection = 0  # 0=Smart, 1=Config, 2=Maintenance
# Per-section expansion flags
$ExpandS = $false; $ExpandC = $false; $ExpandM = $false
$Global:InstallApps = $false

while ($true) {
    Write-Header "WINAUTO: MASTER CONTROL"
    
    $lastConfig = Get-WinAutoLastRun -Module "Configuration"
    $lastMaint = Get-WinAutoLastRun -Module "Maintenance"
    
    # Toggle Display Strings
    $enStatus = if ($Global:EnhancedSecurity) { "ON" } else { "OFF" }

    # Enhanced Text Logic (User Request)
    if ($Global:EnhancedSecurity) {
        $EnhancedLabel = "${FGBlack}${BGYellow}[E]nhanced${Reset}"
    }
    else {
        $EnhancedLabel = "${FGYellow}[E]${Reset}${FGGray}nhanced${Reset}"
    }
    
    $iStatus = if ($Global:InstallApps) { "ON" } else { "OFF" }
    $installBracket = if ($Global:InstallApps) { "${FGGreen}[I]${Reset}" } else { "${FGGray}[I]${Reset}" }

    # Arrows
    $ArrS = if ($MenuSelection -eq 0) { "${FGYellow}->${Reset}" } else { "  " }
    $ArrC = if ($MenuSelection -eq 1) { "${FGYellow}->${Reset}" } else { "  " }
    $ArrM = if ($MenuSelection -eq 2) { "${FGYellow}->${Reset}" } else { "  " }
    
    # Check "Simplified Mode" condition: No expansion flags set
    $IsSimplified = (-not $ExpandS) -and (-not $ExpandC) -and (-not $ExpandM)

    if ($IsSimplified) {
        # --- SIMPLIFIED DASHBOARD (MATCHING MOCKUP) ---
        Write-Host ""
        
        # [SmartRun] (Note: No split [S] in simplified mockup)
        if ($MenuSelection -eq 0) {
            # Selected SmartRun (Reduced indentation)
            Write-LeftAligned "$ArrS ${FGBlack}${BGYellow}[SmartRun]${Reset}" -Indent 1
        }
        else {
            Write-LeftAligned "$ArrS ${FGYellow}[SmartRun]${Reset}" -Indent 1
        }
        
        Write-Host ""
        Write-Host "" # Spacer
        
        # [C]onfiguration (Reduced Spacing)
        if ($MenuSelection -eq 1) {
            Write-LeftAligned "$ArrC ${FGBlack}${BGYellow}[C]onfiguration${Reset}    ${FGDarkGray}(Last: $lastConfig)${Reset}" -Indent 1
        }
        else {
            Write-LeftAligned "$ArrC ${FGYellow}[C]onfiguration${Reset}    ${FGDarkGray}(Last: $lastConfig)${Reset}" -Indent 1
        }

        # Enhanced status line
        $eColor = if ($Global:EnhancedSecurity) { $FGGreen } else { $FGDarkGray }
        Write-LeftAligned "     ${FGGray}with $EnhancedLabel ${FGGray}Security ($eColor$enStatus${FGGray})${Reset}" -Indent 1
        Write-Host ""

        # [M]aintenance (Reduced Spacing)
        if ($MenuSelection -eq 2) {
            Write-LeftAligned "$ArrM ${FGBlack}${BGYellow}[M]aintenance${Reset}    ${FGDarkGray}(Last: $lastMaint)${Reset}" -Indent 1
        }
        else {
            Write-LeftAligned "$ArrM ${FGYellow}[M]aintenance${Reset}    ${FGDarkGray}(Last: $lastMaint)${Reset}" -Indent 1
        }

        # No Install Apps line in Simplified Mockup (per strict requirements)
        Write-Host ""
        Write-Host ""
        Write-Host ""
        
        # Helper Text Simplified
        Write-Boundary
        Write-Host ""
        Write-Centered "${FGGray}Use ${FGYellow}Arrow-Keys v / ^${Reset} ${FGGray}to Navigate | ${FGYellow}> / <${Reset} ${FGGray}to Toggle${Reset}"
        Write-Centered "${FGGray}or Press ${FGYellow}[Key]${Reset} ${FGGray}to ${FGYellow}SELECT${Reset} ${FGGray}Option${Reset}"
        Write-Centered "${FGGray}Press ${FGYellow}[Spacebar]${Reset} ${FGGray}to ${FGYellow}EXPAND${Reset} ${FGGray}Details${Reset}"
    }
    else {
        # --- DETAILED OUTLINE DASHBOARD (EXPANDED MOCKUP) ---
        Write-Host ""
        
        # [S]mart Run
        if ($MenuSelection -eq 0) {
            Write-LeftAligned "$ArrS ${FGBlack}${BGYellow}[S]${Reset}${FGYellow}mart Run${Reset}" -Indent 1
        }
        else {
            Write-LeftAligned "$ArrS ${FGYellow}[S]${Reset}${FGYellow}mart Run${Reset}" -Indent 1
        }

        if ($ExpandS) {
            Write-LeftAligned "   ${FGDarkGray}Method: Orchestration Loop${Reset}" -Indent 1
            Write-LeftAligned "   ${FGDarkGray}Actions:${Reset}" -Indent 1
            Write-LeftAligned "   - System Hardening Check (Registry & Logic)" -Indent 1
            Write-LeftAligned "   - Maintenance Cycle (Component Check/Days)" -Indent 1
            Write-LeftAligned "   - Auto-Cleanup (File System)" -Indent 1
        }
        
        Write-Boundary # Separator per Expanded Mockup

        # [C]onfiguration (Reduced Spacing)
        if ($MenuSelection -eq 1) {
            Write-LeftAligned "$ArrC ${FGBlack}${BGYellow}[C]${Reset}${FGGray}onfiguration${Reset}    ${FGDarkGray}(Last: $lastConfig)${Reset}" -Indent 1
        }
        else {
            Write-LeftAligned "$ArrC ${FGYellow}[C]${Reset}${FGGray}onfiguration${Reset}    ${FGDarkGray}(Last: $lastConfig)${Reset}" -Indent 1
        }
        
        if ($ExpandC) {
            Write-LeftAligned "   ${FGDarkGray}Security Actions:${Reset}" -Indent 1
            Write-LeftAligned "   - Real-Time Protection      | PS WMI (MpPreference)" -Indent 1
            Write-LeftAligned "   - PUA Protection (Defender) | PS WMI (MpPreference)" -Indent 1
            Write-LeftAligned "   - Memory Integrity          | RegEdit (HKLM)" -Indent 1
            Write-LeftAligned "   - Kernel Stack Protection   | UI Automation" -Indent 1
            Write-LeftAligned "   - Windows Firewall          | Set-NetFirewallProfile" -Indent 1
            Write-LeftAligned "   ${FGDarkGray}UI & UX Actions:${Reset}" -Indent 1
            Write-LeftAligned "   - Taskbar/Widgets/Search    | RegEdit (HKCU)" -Indent 1
        }
        
        # Enhanced Toggle Line
        $eColor = if ($Global:EnhancedSecurity) { $FGGreen } else { $FGDarkGray }
        Write-LeftAligned "   $EnhancedLabel ${FGGray}Security (Toggle) $eColor$enStatus${Reset}" -Indent 1
        
        if ($Global:EnhancedSecurity) {
            Write-LeftAligned "   - Expedited Updates         | UI Automation" -Indent 1
            Write-LeftAligned "   - Restart ASAP              | UI Automation" -Indent 1
            Write-LeftAligned "   - Metered Connection        | RegEdit (HKLM)" -Indent 1
        }

        Write-Boundary # Separator

        # [M]aintenance (Reduced Spacing)
        if ($MenuSelection -eq 2) {
            Write-LeftAligned "$ArrM ${FGBlack}${BGYellow}[M]${Reset}${FGGray}aintenance${Reset}    ${FGDarkGray}(Last: $lastMaint)${Reset}" -Indent 1
        }
        else {
            Write-LeftAligned "$ArrM ${FGYellow}[M]${Reset}${FGGray}aintenance${Reset}    ${FGDarkGray}(Last: $lastMaint)${Reset}" -Indent 1
        }
        
        if ($ExpandM) {
            Write-LeftAligned "   ${FGDarkGray}Orchestrated Maintenance:${Reset}" -Indent 1
            Write-LeftAligned "   - Windows Update Check      | COM Object & UI Automation" -Indent 1
            Write-LeftAligned "   - SFC System Scan           | Command Line (sfc.exe)" -Indent 1
            Write-LeftAligned "   - DISM Repair               | Command Line (dism.exe)" -Indent 1
            Write-LeftAligned "   - WinGet/Store App Updates  | Command Line / UI Automation" -Indent 1
            Write-LeftAligned "   - Drive Opt & Cleanup       | PS / FSR" -Indent 1
        }
        
        # Install Apps Toggle (Expanded Mockup Line 46: "[I]nstall Applications (Toggle) OFF")
        $iColor = if ($Global:InstallApps) { $FGGreen } else { $FGDarkGray }
        Write-LeftAligned "   $installBracket${FGGray}nstall Applications (Toggle) $iColor$iStatus${Reset}" -Indent 1

        Write-Boundary # Separator
        
        # Helper Text Detailed (Restored ARROWS TEXT)
        Write-Host ""
        Write-Centered "${FGGray}Use ${FGYellow}Arrow-Keys v / ^${Reset} ${FGGray}to Navigate | ${FGYellow}> / <${Reset} ${FGGray}to Toggle${Reset}"
        Write-Centered "${FGGray}or Press ${FGYellow}[Key]${Reset} ${FGGray}to ${FGYellow}SELECT${Reset} ${FGGray}Option${Reset}"
        Write-Centered "${FGGray}Press ${FGYellow}[Spacebar]${Reset} ${FGGray}to ${FGYellow}EXPAND${Reset} ${FGGray}Details${Reset}"
    }

    # Timeout logic: Only on first load
    $ActionText = "RUN"
    $TimeoutSecs = if ($Global:WinAutoFirstLoad -ne $false) { 10 } else { 0 }
    $Global:WinAutoFirstLoad = $false
    
    # Dynamic Footer Prompt Logic
    if ($IsSimplified -and $MenuSelection -eq 0) {
        # Initial View Special Case
        $Act = "SmartRun"
        $Sel = "->" # Special trigger
        $Pre = "for"
    }
    else {
        # Standard View (Option C or Detailed)
        $Act = "RUN"
        $Sel = $null
        $Pre = "to"
    }

    $res = Invoke-AnimatedPause -ActionText $Act -Timeout $TimeoutSecs -SelectionChar $Sel -PreActionWord $Pre

    # --- NAVIGATION LOGIC ---
    if ($res.VirtualKeyCode -eq 38) {
        # Up
        $MenuSelection--
        if ($MenuSelection -lt 0) { $MenuSelection = 2 }
        continue
    }
    elseif ($res.VirtualKeyCode -eq 40) {
        # Down
        $MenuSelection++
        if ($MenuSelection -gt 2) { $MenuSelection = 0 }
        continue
    }
    elseif ($res.VirtualKeyCode -eq 39) {
        # Right
        if ($MenuSelection -eq 1) { $Global:EnhancedSecurity = $true }
        if ($MenuSelection -eq 2) { $Global:InstallApps = $true }
        continue
    }
    elseif ($res.VirtualKeyCode -eq 37) {
        # Left
        if ($MenuSelection -eq 1) { $Global:EnhancedSecurity = $false }
        if ($MenuSelection -eq 2) { $Global:InstallApps = $false }
        continue
    }

    if ($res.VirtualKeyCode -eq 27) {
        # Esc
        Write-LeftAligned "$FGGray Exiting WinAuto...$Reset"
        Start-Sleep -Seconds 1
        break
    }
    elseif ($res.VirtualKeyCode -eq 13 -or $res.Character -match '[SCMscm]') {
        # Enter Handling
        $Target = $MenuSelection
        if ($res.Character -eq 'S' -or $res.Character -eq 's') { $Target = 0 }
        elseif ($res.Character -eq 'C' -or $res.Character -eq 'c') { $Target = 1 }
        elseif ($res.Character -eq 'M' -or $res.Character -eq 'm') { $Target = 2 }
        
        if ($Target -eq 0) {
            # Smart Run
            Invoke-WinAutoConfiguration -SmartRun -EnhancedSecurity:$Global:EnhancedSecurity
            Invoke-WinAutoMaintenance -SmartRun
        }
        elseif ($Target -eq 1) {
            Invoke-WinAutoConfiguration -EnhancedSecurity:$Global:EnhancedSecurity
        }
        elseif ($Target -eq 2) {
            Invoke-WinAutoMaintenance
            # Install Apps logic placeholder if needed
            if ($Global:InstallApps) { Write-Log "Install Apps requested but not implemented in Core." -Level WARN }
        }
        Start-Sleep -Seconds 2
    }
    elseif ($res.Character -eq 'E' -or $res.Character -eq 'e') {
        $Global:EnhancedSecurity = -not $Global:EnhancedSecurity
        continue
    }
    elseif ($res.Character -eq 'I' -or $res.Character -eq 'i') {
        $Global:InstallApps = -not $Global:InstallApps
        continue
    }
    elseif ($res.Character -eq ' ' -or $res.VirtualKeyCode -eq 32) {
        # Space now toggles expansion for the CURRENT selection
        if ($MenuSelection -eq 0) { $ExpandS = -not $ExpandS }
        elseif ($MenuSelection -eq 1) { $ExpandC = -not $ExpandC }
        elseif ($MenuSelection -eq 2) { $ExpandM = -not $ExpandM }
        continue
    }
    elseif ($res.Character -eq 'H' -or $res.Character -eq 'h') {
        Clear-Host
        Write-Header "SYSTEM IMPACT MANIFEST"
        Write-Host ""
        $Global:WinAutoManifestContent | Out-Host
        Write-Host ""
        Write-Boundary
        Write-Centered "Press any key to return..."
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
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
Invoke-AnimatedPause -ActionText "EXIT" -Timeout 10
Write-Host ""
Write-Host ""
Write-Host ""
Write-Host ""
Write-Host ""
