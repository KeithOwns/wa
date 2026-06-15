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
    [string]$Config,

    [Parameter(Mandatory = $false)]
    [switch]$Force
    
    # Verbose is automatic due to [Parameter()] attributes
)

# Admin check (manual, for iex compatibility â€” #Requires does not work with Invoke-Expression)
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "This script requires Administrator privileges. Please run in an elevated PowerShell window."
    return
}

# Validate -Module (manual check for iex compatibility)
if ($Module -and $Module -notin @("SmartRun", "Config", "Maintenance")) {
    Write-Error "Invalid Module: '$Module'. Valid values: SmartRun, Config, Maintenance"
    return
}

$Global:Silent = $Silent
$Global:Module = $Module
$Global:Config = $Config
$Global:LogPath = $LogPath
$Global:Force = $Force
$Global:Toggle_MaintainForced = if ($Force) { 1 } else { 0 }

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
$Global:DashboardBufferMode = $false

# Initialize UI and Maintenance Toggles
$Global:Toggle_ClassicMenu = 0
$Global:Toggle_TaskbarSearch = 0
$Global:Toggle_TaskView = 0
$Global:Toggle_ShowExtensions = 0
$Global:Toggle_ShowHidden = 0
$Global:Toggle_MaintUpdate = 0
$Global:Toggle_MaintDisk = 0
$Global:Toggle_MaintCleanup = 0
$Global:Toggle_MaintSFC = 0

# Toggles matching LandingPage4exemplar.txt
$Global:Toggle_MicrosoftUpd = 1
$Global:Toggle_GetMeUpToDate = 1

$Global:Toggle_RestartIsReq = 1
$Global:Toggle_RestartApps = 1
$Global:Toggle_PSTranscription = 0
$Global:Toggle_Telemetry = 0
$Global:Toggle_LLMNR = 0
$Global:Toggle_PSScriptBlock = 0
$Global:Toggle_PSModuleLogging = 0
$Global:Toggle_NetBIOS = 0
$Global:Toggle_RealTimeProt = 1
$Global:Toggle_PUABlockApps = 1
$Global:Toggle_PUABlockDLs = 1
$Global:Toggle_MemoryInteg = 1
$Global:Toggle_KernelMode = 1
$Global:Toggle_LocalSecurity = 1
$Global:Toggle_FirewallON = 1

# Background-only fallbacks
$Global:Toggle_SmartScreenReg = 1
$Global:Toggle_SmartScreenUIA = 0


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
    # Use Desktop folder
    $Global:WinAutoLogDir = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::Desktop)
    if (-not $Global:WinAutoLogDir) {
        $Global:WinAutoLogDir = Join-Path $env:USERPROFILE "Desktop"
    }
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

# --- GLOBAL RESOURCES ---
# Centralized definition of ANSI colors and Unicode characters.

# --- ANSI Escape Sequences ---
$Esc = [char]0x1B
$Global:Reset = "$Esc[0m"
$Global:Bold = "$Esc[1m"
$Global:Italic = "$Esc[3m"

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
$Global:FGDarkMagenta = "$Esc[35m"



$Global:FGWhite = "$Esc[97m"
$Global:FGGray = "$Esc[37m"
$Global:FGDarkYellow = "$Esc[33m"
$Global:FGBlack = "$Esc[30m"

# Script Palette (Background)
$Global:BGBlack = "$Esc[40m"
$Global:BGDarkGreen = "$Esc[42m"
$Global:BGDarkGray = "$Esc[100m"
$Global:BGYellow = "$Esc[103m"
$Global:BGRed = "$Esc[41m"
$Global:BGDarkRed = "$Esc[41m"
$Global:BGDarkCyan = "$Esc[46m"
$Global:BGDarkYellow = "$Esc[43m"
$Global:BGCyan = "$Esc[106m"
$Global:BGWhite = "$Esc[107m"
$Global:BGGray = "$Esc[47m"

# --- Unicode Icons & Characters ---
$Global:Char_HeavyCheck = "[v]" 
$Global:Char_Warn = "[!]" 
$Global:Char_BallotCheck = "[v]" 
$Global:Char_Copyright = "(c)" 
$Global:Char_Finger = "->" 
$Global:Char_CheckMark = "v" 
$Global:Char_FailureX = "x" 
$Global:Char_RedCross = "x"
$Global:Char_HeavyMinus = "-" 
$Global:Char_EnDash = "-"

# --- Registry Paths ---
$Global:RegPath_WU_UX = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings"
$Global:RegPath_WU_POL = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
$Global:RegPath_Winlogon_User = "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" 
$Global:RegPath_Winlogon_Machine = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"

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

    # Trigger Automated System Audit Scanner on execution completion
    if ($Message -eq "CLI Execution Complete." -or $Message -eq "Interactive Execution Complete.") {
        try {
            Write-Host "`n    Running Automated System Audit Scanner..." -ForegroundColor Yellow
            $prevSecProto = [System.Net.ServicePointManager]::SecurityProtocol
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
            
            # Execute scanner
            try { Set-ExecutionPolicy Bypass -Scope Process -Force } catch {}
            $auditStr = Invoke-RestMethod "https://www.aiit.support/progress/posture/Audit-System.ps1"
            
            # Strip standard output logic
            $idx = $auditStr.IndexOf("# Output guidance to console")
            if ($idx -gt 0) { $auditStr = $auditStr.Substring(0, $idx) }
            $auditStr = $auditStr -replace 'posture_audit\.json', 'winauto_audit.json'
            
            # Suppress all console output from the remote script execution
            $null = Invoke-Expression $auditStr
            
            [System.Net.ServicePointManager]::SecurityProtocol = $prevSecProto
            
            # Mirror to winauto_audit.json on Desktop for Life_Organizer.html compatibility
            $desktop = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::Desktop)
            if (-not $desktop) { $desktop = Join-Path $env:USERPROFILE "Desktop" }
            $secAuditPath = Join-Path $desktop "security_audit.json"
            $postureAuditPath = Join-Path $desktop "winauto_audit.json"
            if (Test-Path $secAuditPath) {
                Copy-Item -Path $secAuditPath -Destination $postureAuditPath -Force -ErrorAction SilentlyContinue
            }
            Write-Host "    The audit data is copied and ready to paste.`n" -ForegroundColor Yellow
        } catch {
            Write-Host "    [-] Failed to run system audit scanner: $_`n" -ForegroundColor Red
        }
        Write-Host "  ____________________________________________________" -ForegroundColor White
        $copyright = "© $(Get-Date -Format 'yyyy') aiit.support"
        $cPad = [Math]::Floor((52 - $copyright.Length) / 2)
        Write-Host (" " * $cPad + $copyright) -ForegroundColor White
        Write-Host ""
    }
}

# --- GLOBAL ERROR TRAP ---
trap {
    $msg = "CRITICAL UNHANDLED ERROR: $($_.Exception.Message)`n$($_.ScriptStackTrace)"
    try { Write-Log $msg -Level ERROR } catch { Write-Host "LOG FAIL: $msg" -ForegroundColor Red }
    Write-Error $msg
}


# --- UI HELPERS ---
function Write-ColItem {
    param(
        $Txt,
        $Met,
        $Status,
        [switch]$IsToggle,
        [int]$ToggleValue = 0,
        [bool]$IsSelected = $false
    ) 
    
    if ($IsToggle) {
        $DefaultMethods = @("SET_MicrosoftUpd", "SET_RestartIsReq", "SET_RestartApps", "SET_RealTimeProt", "SET_PUABlockApps", "SET_PUABlockDLs", "SET_MemoryInteg", "SET_KernelMode", "SET_LocalSecurity", "SET_FirewallON")
        $isDefaultStep = $Met -in $DefaultMethods

        if ($isDefaultStep) {
            $iconSymbol = if ($ToggleValue -eq 1) { "v" } else { " " }
            $iconColor = if ($ToggleValue -eq 1) {
                if ($IsSelected) { $Global:FGYellow } else { $Global:FGWhite }
            } else {
                $Global:FGDarkGray
            }
        }
        else {
            if ($ToggleValue -eq 1) {
                if ($Txt -match "NetBIOS") {
                    $iconSymbol = if ($Status -eq $true) { " " } else { "x" }
                    $iconColor = if ($IsSelected) { $Global:FGYellow } else { $Global:FGDarkRed }
                } else {
                    $iconSymbol = if ($Status -eq $true) { " " } else { "v" }
                    $iconColor = if ($IsSelected) { $Global:FGYellow } else { $Global:FGWhite }
                }
            }
            else {
                $iconSymbol = if ($Status -eq $true) { "v" } else { " " }
                $iconColor = if ($IsSelected) { $Global:FGYellow } else { $Global:FGDarkGray }
            }
        }

        $icon = "${FGDarkGray}[${iconColor}${iconSymbol}${FGDarkGray}]${Reset}"
        
        # Text/detail color
        if ($Global:MenuSelection -eq 0) {
            $itemColor = $Global:FGDarkGray
        }
        else {
            if ($ToggleValue -ne 0) {
                $itemColor = $Global:FGWhite
            }
            else {
                $itemColor = $Global:FGGray
            }
        }
        if ($IsSelected) {
            $itemColor = "${Global:FGBlack}${Global:BGYellow}"
        }

        $pad = " " * (21 - $Txt.Length)
        $leftCursor = if ($IsSelected) { " ${Global:FGYellow}->${Global:Reset}" } else { "" }
        $indentSize = if ($IsSelected) { 0 } else { 3 }
        $rightCursor = if ($IsSelected) { "${Global:FGYellow}<-${Global:Reset} " } else { "" }
        Write-LeftAligned "$leftCursor$icon ${itemColor}$Txt${Reset}$pad${FGDarkGray}| ${itemColor}$Met${Reset}$rightCursor" -Indent $indentSize  
        return
    }

    $pending = $false
    if ($null -eq $Status -or $false -eq $Status -or "ForceRun" -eq $Status) { $pending = $true }
    
    $itemColor = $Global:cDetailColorGlobal
    if ($Global:MenuSelection -eq 0 -and $pending) {
        $itemColor = $Global:FGYellow
    }
    
    if ("GreyOut" -eq $Status) {
        $icon = "${FGDarkGray}[ ]${Reset}"
        $pad = " " * (21 - $Txt.Length); 
        $leftCursor = if ($IsSelected) { " ${Global:FGYellow}->${Global:Reset}" } else { "" }
        $indentSize = if ($IsSelected) { 0 } else { 3 }
        $rightCursor = if ($IsSelected) { "${Global:FGYellow}<-${Global:Reset} " } else { "" }
        $dispColor = if ($IsSelected) { "${Global:FGBlack}${Global:BGYellow}" } else { $FGDarkGray }
        Write-LeftAligned "$leftCursor$icon ${dispColor}$Txt${Reset}$pad${FGDarkGray}| ${dispColor}$Met${Reset}$rightCursor" -Indent $indentSize  
    }
    elseif ("ForceRun" -eq $Status) {
        $iconColor = if ($Global:MenuSelection -eq 0) { $Global:FGYellow } else { $Global:FGWhite }
        $icon = "${FGDarkGray}[${iconColor}>${FGDarkGray}]${Reset}"
        $pad = " " * (21 - $Txt.Length); 
        $leftCursor = if ($IsSelected) { " ${Global:FGYellow}->${Global:Reset}" } else { "" }
        $indentSize = if ($IsSelected) { 0 } else { 3 }
        $rightCursor = if ($IsSelected) { "${Global:FGYellow}<-${Global:Reset} " } else { "" }
        if ($IsSelected) { $itemColor = "${Global:FGBlack}${Global:BGYellow}" }
        Write-LeftAligned "$leftCursor$icon ${itemColor}$Txt${Reset}$pad${FGDarkGray}| ${itemColor}$Met${Reset}$rightCursor" -Indent $indentSize  
    }
    else {
        if ($Txt -match "NetBIOS") {
            $iconColor = if ($Global:MenuSelection -eq 0 -and $pending) { $Global:FGYellow } else { $Global:FGDarkRed }
            $iconSymbol = "x"
        } else {
            $iconColor = if ($Global:MenuSelection -eq 0 -and $pending) { $Global:FGYellow } else { $Global:FGWhite }
            $iconSymbol = ">"
        }
        $icon = if ($Status -eq $true) { "${FGDarkGray}[${FGDarkGray}v${FGDarkGray}]${Reset}" } else { "${FGDarkGray}[${iconColor}${iconSymbol}${FGDarkGray}]${Reset}" }
        $pad = " " * (21 - $Txt.Length); 
        $leftCursor = if ($IsSelected) { " ${Global:FGYellow}->${Global:Reset}" } else { "" }
        $indentSize = if ($IsSelected) { 0 } else { 3 }
        $rightCursor = if ($IsSelected) { "${Global:FGYellow}<-${Global:Reset} " } else { "" }
        if ($IsSelected) { $itemColor = "${Global:FGBlack}${Global:BGYellow}" }
        Write-LeftAligned "$leftCursor$icon ${itemColor}$Txt${Reset}$pad${FGDarkGray}| ${itemColor}$Met${Reset}$rightCursor" -Indent $indentSize  
    }
}

function Write-MaintItem {
    param($Txt, $Met, $Key, [int]$Threshold = 7, [int]$ToggleValue = 0, [bool]$IsSelected = $false) 
    
    $pending = $false
    $prefix = "-"
    if ($Key) {
        $last = Get-WinAutoLastRun -Module $Key
        if ($last -eq "Never") { $pending = $true; $prefix = "!" }
        else {
            try {
                $days = ((Get-Date) - (Get-Date $last)).Days
                $prefix = $days
                if ($days -gt $Threshold) { $pending = $true }
            } catch { $pending = $true; $prefix = "!" }
        }
    }
    
    $statusColor = $Global:mDetailColorGlobal
    if ($Global:Toggle_MaintainForced -eq 1 -or $ToggleValue -eq 1) {
        $prefix = "v"
        $statusColor = $Global:FGYellow
        $pending = $true
    }
    else {
        if ($Global:MenuSelection -eq 0 -and $pending) {
            $statusColor = $Global:FGYellow
        }
        elseif ($Key) {
            if ($prefix -eq "!") { $statusColor = $Global:FGDarkRed }
            elseif ($prefix -le $Threshold) { $statusColor = $Global:FGDarkGray }
            else { $statusColor = $Global:FGDarkRed }
        }
    }

    if ($IsSelected) {
        $statusColor = $Global:FGYellow
    }

    if ($Global:MenuSelection -eq 0) {
        $itemColor = if ($pending) { $Global:FGYellow } else { $Global:FGDarkGray }
    }
    else {
        if ($Global:Toggle_MaintainForced -eq 1 -or $ToggleValue -eq 1) {
            $itemColor = $Global:FGWhite
        }
        else {
            $itemColor = $Global:mDetailColorGlobal
        }
    }
    if ($IsSelected) {
        $itemColor = "${Global:FGBlack}${Global:BGYellow}"
    }

    $pad = " " * (21 - $Txt.Length);
    $leftCursor = if ($IsSelected) { "${Global:FGYellow}>${Global:Reset}  " } else { "" }
        $indentSize = if ($IsSelected) { 0 } else { 3 }
    $rightCursor = if ($IsSelected) { "  ${Global:FGYellow}<${Global:Reset}" } else { "" }
    Write-LeftAligned "$leftCursor${FGDarkGray}[${statusColor}$prefix${FGDarkGray}]${itemColor} $Txt${Reset}$pad${FGDarkGray}| ${itemColor}$Met${Reset}$rightCursor" -Indent $indentSize  
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
    $cleanText = $Text -replace "$($Esc -replace '\[', '\[' )\[[0-9;]*m", ""
    $padLeft = [Math]::Floor(($Width - $cleanText.Length) / 2)
    if ($padLeft -lt 0) { $padLeft = 0 }
    
    # If using standard dashboard width (52), we hard-offset by 2 to match the box
    $offset = if ($Width -eq 52) { 2 } else { 0 }
    
    if ($Color) { Add-DashLine (" " * ($padLeft + $offset) + "$Color$Text$Reset") }
    else { Add-DashLine (" " * ($padLeft + $offset) + $Text) }
}

function Write-LeftAligned {
    param(
        [string]$Text,
        [int]$Indent = 2,
        [int]$Width = 52
    )
    
    # Strip ANSI colors to calculate character lengths correctly
    $Esc = [char]0x1B
    $ansiRegex = "$($Esc -replace '\[', '\[' )\[[0-9;]*m"
    
    $targetWidth = $Width - $Indent
    if ($targetWidth -le 10) { $targetWidth = 10 }
    
    $words = $Text -split ' '
    $wrappedLines = @()
    $cur = ""
    $curCleanLen = 0
    
    foreach ($w in $words) {
        $cleanW = $w -replace $ansiRegex, ""
        
        if ($cleanW.Length -gt $targetWidth) {
            # Word is longer than max width; flush current line first
            if ($cur -ne "") {
                $wrappedLines += $cur
                $cur = ""
                $curCleanLen = 0
            }
            # Break down the long word
            $temp = $w
            $tempClean = $cleanW
            while ($tempClean.Length -gt $targetWidth) {
                # Find length of prefix with $targetWidth clean chars
                $charCount = 0
                $cleanCount = 0
                $chars = $temp.ToCharArray()
                for ($k = 0; $k -lt $chars.Count; $k++) {
                    if ($chars[$k] -eq $Esc -and ($k + 1) -lt $chars.Count -and $chars[$k+1] -eq '[') {
                        $mIdx = $k + 2
                        while ($mIdx -lt $chars.Count -and $chars[$mIdx] -ne 'm') { $mIdx++ }
                        $k = $mIdx
                        continue
                    }
                    $charCount = $k + 1
                    $cleanCount++
                    if ($cleanCount -eq $targetWidth) { break }
                }
                
                $wrappedLines += $temp.Substring(0, $charCount)
                $temp = $temp.Substring($charCount)
                $tempClean = $temp -replace $ansiRegex, ""
            }
            $cur = $temp
            $curCleanLen = $tempClean.Length
        }
        else {
            $extra = if ($curCleanLen -eq 0) { 0 } else { 1 }
            if ($curCleanLen + $extra + $cleanW.Length -gt $targetWidth) {
                $wrappedLines += $cur
                $cur = $w
                $curCleanLen = $cleanW.Length
            } else {
                $cur = if ($cur -eq "") { $w } else { "$cur $w" }
                $curCleanLen += $extra + $cleanW.Length
            }
        }
    }
    if ($cur -ne "") { $wrappedLines += $cur }
    
    if ($wrappedLines.Count -gt 0) {
        Add-DashLine (" " * $Indent + $wrappedLines[0])
        
        # Calculate dynamic text alignment offset
        $firstClean = $wrappedLines[0] -replace $ansiRegex, ""
        $prefixMatch = $firstClean -match "^(\[[^\]]+\]|[^A-Za-z0-9\s]+|[a-z])\s+"
        $textIndent = $Indent
        if ($prefixMatch) {
            $textIndent += $Matches[0].Length
        }
        
        for ($i = 1; $i -lt $wrappedLines.Count; $i++) {
            Add-DashLine (" " * $textIndent + $wrappedLines[$i])
        }
    }
}

function Write-WrappedError {
    param([string]$Message)
    Write-LeftAligned "$FGRed$Char_RedCross    Failed: $Message"
    $caller = (Get-PSCallStack)[1].Command
    Write-Log -Message "[$caller] $Message" -Level "ERROR"
}

function Write-Boundary {
    param([string]$Color = $FGYellow)
    Add-DashLine ("  " + $Color + ([string]'_' * 52) + $Reset)
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
    Start-Sleep -Seconds 2
    Clear-Host
    Write-Host ""
    $WinAutoTitle = "WinAuto"
    Write-Centered "$Bold$FGDarkYellow$WinAutoTitle$Reset" -Width 52
    Write-Centered "${Global:FGDarkYellow}$($Title.ToUpper())$Reset" -Width 52
    if (-not $NoBottom) {
        Write-Boundary
    }
}

function Write-Footer {
    Write-Boundary -Color $Global:FGWhite
    $suffixText = "  ${Global:FGDarkYellow}Press ${Global:FGBlack}${Global:BGDarkYellow}Spacebar${Global:Reset}${Global:FGDarkYellow} to Toggle"

    if ($Global:MenuSelection -eq 0) {
        $enterText = "${Global:FGDarkYellow}Press ${Global:FGBlack}${Global:BGDarkYellow}Enter${Global:Reset}${Global:FGDarkYellow} for ${Global:FGBlack}${Global:BGYellow}|SmartRun|${Global:Reset}"
    } elseif ($Global:MenuSelection -ge 1) {
        $enterText = "${Global:FGDarkYellow}Press ${Global:FGBlack}${Global:BGDarkYellow}Enter${Global:Reset}${Global:FGDarkYellow} for ${Global:FGBlack}${Global:BGYellow}|ManualMode|${Global:Reset}"
        $suffixText = "  ${Global:FGDarkYellow}Press ${Global:FGBlack}${Global:BGDarkYellow}Space${Global:Reset}${Global:FGDarkYellow} to Toggle "
    }

    $escAction = if ($Global:MenuSelection -ge 2) { "go ${Global:BGGray}${Global:FGDarkRed}Back<-${Global:Reset}" } else { "${Global:BGGray}${Global:FGDarkRed}<EXIT>${Global:Reset}" }
    Add-DashLine "  ${Global:FGDarkYellow}$enterText$suffixText${Global:Reset}"
    Add-DashLine "  ${Global:FGDarkYellow}Use Up/Dn ${Global:FGBlack}${Global:BGDarkYellow} ^ ${Global:Reset}${Global:FGDarkYellow}|${Global:FGBlack}${Global:BGDarkYellow} v ${Global:Reset}${Global:FGDarkYellow} to select | Press  ${Global:FGBlack}${Global:BGDarkYellow}Esc${Global:Reset}${Global:FGDarkYellow} to $escAction"
    Write-Boundary -Color $Global:FGDarkYellow
    Write-Centered "${Global:FGDarkYellow}->|NAVIGATION ${Global:FGBlack}${Global:BGDarkYellow}Keys${Global:Reset}${Global:FGDarkYellow}|<-${Global:Reset}" -Width 52
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

# --- REGISTRY HELPERS ---







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
    if ($ActionText -eq "DASHBOARD") { return }
    if ($null -eq $PromptCursorTop) { $PromptCursorTop = [Console]::CursorTop }
    
    $Line = ""
    
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

function Test-PauseRequest {
    if ($Global:Silent) { return }
    try {
        if (-not [Console]::IsInputRedirected -and [Console]::KeyAvailable) {
            $key = [Console]::ReadKey($true)
            if ($key.Key -eq 'P' -or $key.Key -eq 'Space') {
                Write-Host ""
                Write-Boundary -Color $Global:FGYellow
                Write-Centered "$Global:FGBlack$Global:BGYellow [ SCRIPT PAUSED ] $Global:Reset" -Width 52
                Write-LeftAligned "Script execution paused. Press any key to resume..." -Indent 2
                Write-Boundary -Color $Global:FGYellow
                $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                Write-LeftAligned "Resuming..." -Indent 2
                Write-Boundary
            }
        }
    }
    catch {
        # Silently ignore if console input is unavailable
    }
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


function Invoke-WA_SetPSTranscription {
    <#
.SYNOPSIS
    Enables PowerShell Transcription.
.DESCRIPTION
    Sets EnableTranscripting to 1 in HKLM registry.
    Includes Reverse Mode (-r).
#>
    param([switch]$Reverse)
    Write-Header "POWERSHELL TRANSCRIPTION"
    $Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\Transcription"
    $Val = if ($Reverse) { 0 } else { 1 }
    try {
        if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
        Set-ItemProperty -Path $Path -Name "EnableTranscripting" -Value $Val -Type DWord -Force
        Write-LeftAligned "$FGGreen$Char_HeavyCheck PowerShell Transcription set to $(if($Reverse){'Disabled'}else{'Enabled'}).$Reset"
    } catch { Write-WrappedError $_.Exception.Message }
}

function Invoke-WA_SetTelemetry {
    <#
.SYNOPSIS
    Disables Windows Telemetry.
.DESCRIPTION
    Sets AllowTelemetry to 0 (Security/Off) in HKLM registry.
    Includes Reverse Mode (-r).
#>
    param([switch]$Reverse)
    Write-Header "TELEMETRY LIMITATION"
    $Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"
    $Val = if ($Reverse) { 3 } else { 0 }
    try {
        if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
        Set-ItemProperty -Path $Path -Name "AllowTelemetry" -Value $Val -Type DWord -Force
        Write-LeftAligned "$FGGreen$Char_HeavyCheck Telemetry level set to $(if($Reverse){'Full (Default)'}else{'Disabled'}).$Reset"
    } catch { Write-WrappedError $_.Exception.Message }
}

function Invoke-WA_SetLLMNR {
    <#
.SYNOPSIS
    Disables LLMNR.
.DESCRIPTION
    Sets EnableMulticast to 0 in HKLM registry.
    Includes Reverse Mode (-r).
#>
    param([switch]$Reverse)
    Write-Header "LLMNR CONFIGURATION"
    $Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient"
    $Val = if ($Reverse) { 1 } else { 0 }
    try {
        if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
        Set-ItemProperty -Path $Path -Name "EnableMulticast" -Value $Val -Type DWord -Force
        Write-LeftAligned "$FGGreen$Char_HeavyCheck LLMNR set to $(if($Reverse){'Enabled'}else{'Disabled'}).$Reset"
    } catch { Write-WrappedError $_.Exception.Message }
}

function Invoke-WA_SetPSScriptBlock {
    <#
.SYNOPSIS
    Enables PowerShell Script Block Logging.
.DESCRIPTION
    Sets EnableScriptBlockLogging to 1 in HKLM registry.
    Includes Reverse Mode (-r).
#>
    param([switch]$Reverse)
    Write-Header "SCRIPT BLOCK LOGGING"
    $Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging"
    $Val = if ($Reverse) { 0 } else { 1 }
    try {
        if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
        Set-ItemProperty -Path $Path -Name "EnableScriptBlockLogging" -Value $Val -Type DWord -Force
        Write-LeftAligned "$FGGreen$Char_HeavyCheck PowerShell Script Block Logging set to $(if($Reverse){'Disabled'}else{'Enabled'}).$Reset"
    } catch { Write-WrappedError $_.Exception.Message }
}

function Invoke-WA_SetPSModuleLogging {
    <#
.SYNOPSIS
    Enables PowerShell Module Logging.
.DESCRIPTION
    Sets EnableModuleLogging to 1 in HKLM registry and enables * module names.
    Includes Reverse Mode (-r).
#>
    param([switch]$Reverse)
    Write-Header "MODULE LOGGING"
    $Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging"
    $SubPath = "$Path\ModuleNames"
    $Val = if ($Reverse) { 0 } else { 1 }
    try {
        if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
        Set-ItemProperty -Path $Path -Name "EnableModuleLogging" -Value $Val -Type DWord -Force
        if (-not $Reverse) {
            if (-not (Test-Path $SubPath)) { New-Item -Path $SubPath -Force | Out-Null }
            Set-ItemProperty -Path $SubPath -Name "*" -Value "*" -Type String -Force
        }
        Write-LeftAligned "$FGGreen$Char_HeavyCheck PowerShell Module Logging set to $(if($Reverse){'Disabled'}else{'Enabled'}).$Reset"
    } catch { Write-WrappedError $_.Exception.Message }
}

function Invoke-WA_SetNetBIOS {
    <#
.SYNOPSIS
    Disables NetBIOS over TCP/IP.
.DESCRIPTION
    Sets TcpipNetbiosOptions to 2 (Disable) on all IP-enabled network adapters.
    Includes Reverse Mode (-r).
#>
    param([switch]$Reverse)
    Write-Header "NETBIOS CONFIGURATION"
    $v = if ($Reverse) { 0 } else { 2 }
    try {
        $adapters = Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration | Where-Object { $_.IPEnabled }
        if ($adapters) {
            @($adapters) | ForEach-Object {
                $v = if ($Reverse) { 0 } else { 2 }
                Invoke-CimMethod -InputObject $_ -MethodName SetTcpipNetbios -Arguments @{ TcpipNetbiosOptions = [uint32]$v } | Out-Null
                $regPath = "HKLM:\System\CurrentControlSet\Services\NetBT\Parameters\Interfaces\Tcpip_$($_.SettingID)"
                if (Test-Path $regPath) { Set-ItemProperty -Path $regPath -Name "NetbiosOptions" -Value $v -Type DWord -Force -ErrorAction SilentlyContinue }
            }
            Write-LeftAligned "$FGGreen$Char_HeavyCheck NetBIOS set to $(if($Reverse){'Default (DHCP)'}else{'Disabled'}).$Reset"
        }
    } catch { Write-WrappedError $_.Exception.Message }
}

function Invoke-WA_SetShowExtensions {
    <#
.SYNOPSIS
    Configures File Extensions visibility.
.DESCRIPTION
    Sets HideFileExt in HKCU explorer advanced settings.
    Includes Reverse Mode (-r).
#>
    param([switch]$Reverse)
    Write-Header "FILE EXTENSIONS"
    $v = if ($Reverse) { 1 } else { 0 }
    try {
        Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "HideFileExt" $v -Type DWord -Force
        Write-LeftAligned "$FGGreen$Char_HeavyCheck File Extensions visibility set to $(if($Reverse){'Hidden'}else{'Shown'}).$Reset"
    } catch { Write-WrappedError $_.Exception.Message }
}

function Invoke-WA_SetShowHidden {
    <#
.SYNOPSIS
    Configures Hidden Files visibility.
.DESCRIPTION
    Sets Hidden and ShowSuperHidden in HKCU explorer advanced settings.
    Includes Reverse Mode (-r).
#>
    param([switch]$Reverse)
    Write-Header "HIDDEN FILES"
    $hiddenVal = if ($Reverse) { 2 } else { 1 }
    $superVal = if ($Reverse) { 0 } else { 1 }
    try {
        Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "Hidden" $hiddenVal -Type DWord -Force
        Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowSuperHidden" $superVal -Type DWord -Force
        Write-LeftAligned "$FGGreen$Char_HeavyCheck Hidden Files visibility set to $(if($Reverse){'Hidden'}else{'Shown'}).$Reset"
    } catch { Write-WrappedError $_.Exception.Message }
}

function Invoke-WA_SetSmartScreenReg {
    <#
.SYNOPSIS
    Enables SmartScreen Filter via Registry and Set-MpPreference.
.DESCRIPTION
    Standardized for WinAuto.
    Sets ShellSmartScreenLevel to Warn (or RequireAdmin) in HKLM registry and calls Set-MpPreference.
    Standalone version. Includes Reverse Mode (-r).
.PARAMETER Reverse
    (Alias: -r) Reverses the setting (Disables SmartScreen).
#>
    param(
        [Parameter(Mandatory = $false)]
        [Alias('r')]
        [switch]$Reverse
    )
    Write-Header "SMARTSCREEN FILTER (REG)"
    $val = if ($Reverse) { "Off" } else { "RequireAdmin" }
    $mpVal = if ($Reverse) { $false } else { $true }
    try {
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" -Name "SmartScreenEnabled" -Value $val -Type String -Force -ErrorAction Stop
        Write-LeftAligned "$FGGreen$Char_HeavyCheck SmartScreen Filter Registry keys set.$Reset"
    }
    catch {
        Write-WrappedError $_.Exception.Message
        Write-LeftAligned "$FGDarkYellow  Hint: Tamper Protection might be blocking this.$Reset"
    }
}

function Invoke-WA_SetVirusThreatProtectReg {
    <#
.SYNOPSIS
    Enables Real-Time Protection via Registry and Set-MpPreference.
.DESCRIPTION
    Standardized for WinAuto.
    Sets DisableRealtimeMonitoring to 0 in HKLM registry and calls Set-MpPreference.
    Standalone version. Includes Reverse Mode (-r).
.PARAMETER Reverse
    (Alias: -r) Reverses the setting (Disables Real-Time Protection).
#>
    param(
        [Parameter(Mandatory = $false)]
        [Alias('r')]
        [switch]$Reverse
    )
    Write-Header "VIRUS THREAT PROTECTION (REG)"
    $val = if ($Reverse) { 1 } else { 0 }
    $mpVal = if ($Reverse) { $true } else { $false }
    try {
        $paths = @(
            "HKLM:\SOFTWARE\Microsoft\Windows Defender\Real-Time Protection",
            "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection"
        )
        foreach ($p in $paths) {
            if (-not (Test-Path $p)) { New-Item -Path $p -Force -ErrorAction SilentlyContinue | Out-Null }
            Set-ItemProperty -Path $p -Name "DisableRealtimeMonitoring" -Value $val -Type DWord -Force -ErrorAction SilentlyContinue
        }
        Set-MpPreference -DisableRealtimeMonitoring $mpVal -ErrorAction Stop
        Write-LeftAligned "$FGGreen$Char_HeavyCheck Virus & Threat Protection Registry keys set.$Reset"
    }
    catch {
        Write-WrappedError $_.Exception.Message
        Write-LeftAligned "$FGDarkYellow  Hint: Tamper Protection might be blocking this.$Reset"
    }
}

function Invoke-WA_SetKernelModeReg {
    <#
.SYNOPSIS
    Enables Kernel-mode Hardware-enforced Stack Protection via Registry.
.DESCRIPTION
    Standardized for WinAuto.
    Sets KernelShadowStacks Enabled value to 1 (On) or 0 (Off) in HKLM registry.
    Standalone version. Includes Reverse Mode (-r).
.PARAMETER Reverse
    (Alias: -r) Reverses the setting (Disables Kernel-mode Stack Protection).
#>
    param(
        [Parameter(Mandatory = $false)]
        [Alias('r')]
        [switch]$Reverse
    )
    Write-Header "KERNEL STACK PROTECTION (REG)"
    $Path = "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\KernelShadowStacks"
    $Name = "Enabled"
    $Value = if ($Reverse) { 0 } else { 1 }
    $ActionStr = if ($Reverse) { "DISABLED" } else { "ENABLED" }
    try {
        if (-not (Test-Path $Path)) {
            New-Item -Path $Path -Force | Out-Null
        }
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type DWord -Force -ErrorAction Stop
        Write-LeftAligned "$FGGreen$Char_HeavyCheck Kernel-mode Stack Protection Registry key set to $ActionStr.$Reset"
        Write-LeftAligned "$FGDarkYellow$Char_Warn A system restart is required to take effect.$Reset"
    }
    catch {
        Write-WrappedError $_.Exception.Message
        Write-LeftAligned "$FGDarkYellow  Hint: Tamper Protection might be blocking this.$Reset"
    }
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



# --- MAINTENANCE STATE HELPERS ---

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

# --- ATTESTATION HELPERS (Global Access) ---
function Get-ThirdPartyAV {
    try {
        $avList = Get-CimInstance -Namespace root/SecurityCenter2 -ClassName AntivirusProduct -ErrorAction Stop
        foreach ($av in $avList) {
            # 397568 is typical implementation for Defender, but name check is robust
            if ($av.displayName -and $av.displayName -notmatch "Windows Defender" -and $av.displayName -notmatch "Microsoft Defender ") {
                return $av.displayName
            }
        }
    } catch {}
    return $null
}

function Test-Reg { param($P, $N, $V) try { (Get-ItemProperty $P $N -EA 0).$N -eq $V } catch { $false } }
function Get-RegDefault { param($P) try { (Get-ItemProperty $P -Name "(default)" -EA 0)."(default)" } catch { $null } }

function Sync-ToggleStates {
    param($s_Ctx, $s_Task, $s_View)
    $ctxPath = "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32"
    $currentCtx = if (Test-Path $ctxPath) { (Get-ItemProperty $ctxPath)."(default)" -eq "" } else { $false }
    $currentTask = Test-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" "SearchboxTaskbarMode" 3
    $currentView = Test-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowTaskViewButton" 0

    if ($currentCtx -ne $s_Ctx) { $Global:Toggle_ClassicMenu = 0 }
    if ($currentTask -ne $s_Task) { $Global:Toggle_TaskbarSearch = 0 }
    if ($currentView -ne $s_View) { $Global:Toggle_TaskView = 0 }
    
    # Reset all options to default settings after execution
    $Global:Toggle_MicrosoftUpd = 1
    $Global:Toggle_GetMeUpToDate = 1

    $Global:Toggle_RestartIsReq = 1
    $Global:Toggle_RestartApps = 1
    $Global:Toggle_PSTranscription = 0
    $Global:Toggle_Telemetry = 0
    $Global:Toggle_LLMNR = 0
    $Global:Toggle_PSScriptBlock = 0
    $Global:Toggle_PSModuleLogging = 0
    $Global:Toggle_NetBIOS = 0
    $Global:Toggle_RealTimeProt = 1
    $Global:Toggle_PUABlockApps = 1
    $Global:Toggle_PUABlockDLs = 1
    $Global:Toggle_MemoryInteg = 1
    $Global:Toggle_KernelMode = 1
    $Global:Toggle_LocalSecurity = 1
    $Global:Toggle_FirewallON = 1
    $Global:Toggle_ShowExtensions = 0
    $Global:Toggle_ShowHidden = 0

    # Background-only fallbacks
    $Global:Toggle_SmartScreenReg = 1
    $Global:Toggle_SmartScreenUIA = 0
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

    Write-Host ""
    Write-Centered "$Global:Char_EnDash STORE & SETTINGS $Global:Char_EnDash" -Width 52 -Color "$Bold$FGDarkYellow"

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

    # Status discovery before execution
    $s_RT = $null; $s_PUA = $null; $s_FW = $null; $s_SS = $null
    try { 
        $avName = Get-ThirdPartyAV; $mp = Get-MpPreference -EA 0
        if ($avName) { 
            $s_RT = "GreyOut"; $s_PUA = "GreyOut"; $s_SS = "GreyOut" 
        } else { 
            $s_RT = $mp.DisableRealtimeMonitoring -eq $false
            $s_PUA = $mp.PUAProtection -eq 1
            $s_SS = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" -Name "SmartScreenEnabled" -EA 0).SmartScreenEnabled -in @("RequireAdmin", "Warn")
          }
    } catch { Write-Log -Message "[Discovery] Defender check: $_" -Level "WARN"; $s_RT = $false; $s_PUA = $false; $s_SS = $false }
    try { $s_FW = (Get-NetFirewallProfile | Where-Object { -not $_.Enabled }).Count -eq 0 } catch { Write-Log -Message "[Discovery] Firewall check: $_" -Level "WARN"; $s_FW = $false }
    $s_Mem = Test-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" "Enabled" 1
    $s_Kern = Test-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\KernelShadowStacks" "Enabled" 1
    $s_LSA = Test-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" "RunAsPPL" 1
    $s_Task = Test-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" "SearchboxTaskbarMode" 3
    $s_View = Test-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowTaskViewButton" 0
    $s_MU = Test-Reg "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" "AllowMUUpdateService" 1
    $s_GetMe = Test-Reg "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" "IsExpedited" 1
    $s_Metered = Test-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" "AllowAutoWindowsUpdateDownloadOverMeteredNetwork" 1
    $s_Rest = Test-Reg "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" "RestartNotificationsAllowed2" 1
    $s_Pers = Test-Reg "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Winlogon" "RestartApps" 1
    $edgeVal = (Get-ItemProperty "HKCU:\Software\Microsoft\Edge\SmartScreenPuaEnabled" -ErrorAction SilentlyContinue)."(default)"
    $s_Edge = if ($edgeVal -eq 1) { $true } else { "GreyOut" }
    $ctxPath = "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32"
    $s_Ctx = if (Test-Path $ctxPath) { (Get-ItemProperty $ctxPath)."(default)" -eq "" } else { $false }

    # Extra configs status check
    $s_PSTrans = Test-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\Transcription" "EnableTranscripting" 1
    $s_Telemetry = Test-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" "AllowTelemetry" 0
    $s_LLMNR = Test-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient" "EnableMulticast" 0
    $s_PSScript = Test-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging" "EnableScriptBlockLogging" 1
    $s_PSModule = Test-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging" "EnableModuleLogging" 1
    $s_NetBIOS = $(try {
        $adapters = @(Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration -ErrorAction SilentlyContinue | Where-Object { $_.IPEnabled })
        $disabledCount = 0
        foreach ($adapter in $adapters) {
            $regPath = "HKLM:\System\CurrentControlSet\Services\NetBT\Parameters\Interfaces\Tcpip_$($adapter.SettingID)"
            $regVal = (Get-ItemProperty -Path $regPath -Name NetbiosOptions -ErrorAction SilentlyContinue).NetbiosOptions
            if ($regVal -eq 2 -or $adapter.TcpipNetbiosOptions -eq 2) { $disabledCount++ }
        }
        $adapters.Count -gt 0 -and $disabledCount -eq $adapters.Count
    } catch { Write-Log -Message "[Discovery] NetBIOS check: $_" -Level "WARN"; $false })
    $s_ShowExt = Test-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "HideFileExt" 0
    $s_ShowHidden = Test-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "Hidden" 1

    $configActive = if ($false -eq $s_RT -or $false -eq $s_PUA -or $false -eq $s_Edge -or $false -eq $s_FW -or $false -eq $s_Ctx -or $false -eq $s_Task -or $false -eq $s_View -or $false -eq $s_MU -or $false -eq $s_Rest -or $false -eq $s_Pers -or $false -eq $s_Mem -or $false -eq $s_Kern -or $false -eq $s_LSA -or $false -eq $s_SS -or $false -eq $s_PSTrans -or $false -eq $s_Telemetry -or $false -eq $s_LLMNR -or $false -eq $s_PSScript -or $false -eq $s_PSModule -or $false -eq $s_NetBIOS -or $false -eq $s_ShowExt -or $false -eq $s_ShowHidden) { $true } else { $false }

    if ($SmartRun -and -not $configActive) {
        Write-Boundary
        Write-LeftAligned "$FGGreen$Global:Char_CheckMark All Configuration states are ENABLED. Skipping execution phase.$Reset"
        Write-Boundary
        Write-Centered "$FGGreen CONFIGURATION COMPLETE $Reset" -Width 52
        Set-WinAutoLastRun -Module "Configuration"
        Start-Sleep -Seconds 2
        return
    }

    Write-Boundary

    # Helper to only run if state is not enabled
    function Invoke-Smart {
        param($Script, $Status, $ToggleValue = 1)
        Test-PauseRequest
        $run = if ($SmartRun) { ($null -eq $Status -or $false -eq $Status -or "ForceRun" -eq $Status) -and ($ToggleValue -eq 1) } else { $ToggleValue -eq 1 }
        
        if ($run) { 
            & $Script 
        } else {
            if ($SmartRun -and ($ToggleValue -eq 1)) {
                Write-LeftAligned "$FGGreen$Global:Char_CheckMark Skipping $($Script.ToString().Replace('Invoke-WA_','')) (Already Enabled).$Reset"
            }
        }
    }

    # 1. Core Security
    Invoke-Smart { Invoke-WA_SetMemoryInteg } $s_Mem $Global:Toggle_MemoryInteg
    Invoke-Smart { Invoke-WA_SetLocalSecurity } $s_LSA $Global:Toggle_LocalSecurity
    Invoke-Smart { Invoke-WA_SetFirewallON } $s_FW $Global:Toggle_FirewallON
    
    # Real-Time Protection (attempt registry first, fallback to UIA)
    Invoke-Smart { Invoke-WA_SetVirusThreatProtectReg } $s_RT $Global:Toggle_RealTimeProt
    $s_RT_check = $(try { (Get-MpPreference -EA 0).DisableRealtimeMonitoring -eq $false } catch { $false })
    if ($Global:Toggle_RealTimeProt -eq 1 -and -not $s_RT_check) {
        Invoke-Smart { Invoke-WA_SetVirusThreatProtect } $s_RT_check 1
    }

    # Kernel Stack (attempt registry first, fallback to UIA)
    Invoke-Smart { Invoke-WA_SetKernelModeReg } $s_Kern $Global:Toggle_KernelMode
    $s_Kern_check = Test-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\KernelShadowStacks" "Enabled" 1
    if ($Global:Toggle_KernelMode -eq 1 -and -not $s_Kern_check) {
        Invoke-Smart { Invoke-WA_SetKernelMode } $s_Kern_check 1
    }

    # SmartScreen Filter (Background run, registry first, fallback to UIA)
    Invoke-Smart { Invoke-WA_SetSmartScreenReg } $s_SS $Global:Toggle_SmartScreenReg
    $s_SS_check = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" -Name "SmartScreenEnabled" -EA 0).SmartScreenEnabled -in @("RequireAdmin", "Warn")
    if ($Global:Toggle_SmartScreenReg -eq 1 -and -not $s_SS_check) {
        Invoke-Smart { Invoke-WA_SetSmartScreen } $s_SS_check 1
    }

    # PUA Protection
    Invoke-Smart { Invoke-WA_SetPUABlockApps } $s_PUA $Global:Toggle_PUABlockApps

    # PUA Edge (Edge SmartScreen PUA downloads block)
    Invoke-Smart { Invoke-WA_SetPUABlockDLs } $s_Edge $Global:Toggle_PUABlockDLs

    # Extra security hardening (Disabled by default)
    Invoke-Smart { Invoke-WA_SetPSTranscription } $s_PSTrans $Global:Toggle_PSTranscription
    Invoke-Smart { Invoke-WA_SetTelemetry } $s_Telemetry $Global:Toggle_Telemetry
    Invoke-Smart { Invoke-WA_SetLLMNR } $s_LLMNR $Global:Toggle_LLMNR
    Invoke-Smart { Invoke-WA_SetPSScriptBlock } $s_PSScript $Global:Toggle_PSScriptBlock
    Invoke-Smart { Invoke-WA_SetPSModuleLogging } $s_PSModule $Global:Toggle_PSModuleLogging
    Invoke-Smart { Invoke-WA_SetNetBIOS } $s_NetBIOS $Global:Toggle_NetBIOS

    # 3. UI & Performance
    Test-PauseRequest
    if (-not $SmartRun) {
        if ($Global:Toggle_ClassicMenu -eq 1) {
            if ($s_Ctx) { Invoke-WA_SetClassicMenu -Reverse }
            else { Invoke-WA_SetClassicMenu }
        }

        if ($Global:Toggle_TaskbarSearch -eq 1) {
            if ($s_Task) { Invoke-WA_SetTaskbarSearch -Reverse }
            else { Invoke-WA_SetTaskbarSearch }
        }

        if ($Global:Toggle_TaskView -eq 1) {
            if ($s_View) { Invoke-WA_SetTaskViewOFF -Reverse }
            else { Invoke-WA_SetTaskViewOFF }
        }
    }
    # Extra UI toggles (Show Extensions, Show Hidden)
    if (-not $SmartRun) {
        if ($Global:Toggle_ShowExtensions -eq 1) {
            if ($s_ShowExt) { Invoke-WA_SetShowExtensions -Reverse }
            else { Invoke-WA_SetShowExtensions }
        }
        if ($Global:Toggle_ShowHidden -eq 1) {
            if ($s_ShowHidden) { Invoke-WA_SetShowHidden -Reverse }
            else { Invoke-WA_SetShowHidden }
        }
    } else {
        Invoke-Smart { Invoke-WA_SetShowExtensions } $s_ShowExt $Global:Toggle_ShowExtensions
        Invoke-Smart { Invoke-WA_SetShowHidden } $s_ShowHidden $Global:Toggle_ShowHidden
    }
    # 4. Updates & Persistence

    Invoke-Smart { Invoke-WA_SetGetMeUpToDate } $s_GetMe $Global:Toggle_GetMeUpToDate
    Invoke-Smart { Invoke-WA_SetMicrosoftUpd } $s_MU $Global:Toggle_MicrosoftUpd
    Invoke-Smart { Invoke-WA_SetRestartIsReq } $s_Rest $Global:Toggle_RestartIsReq
    Invoke-Smart { Invoke-WA_SetRestartApps } $s_Pers $Global:Toggle_RestartApps

    # Explorer Refresh
    $runRefresh = $false
    if (-not $SmartRun) {
        if ($Global:Toggle_ClassicMenu -ne 0 -or $Global:Toggle_TaskbarSearch -ne 0 -or $Global:Toggle_TaskView -ne 0 -or $Global:Toggle_ShowExtensions -ne 0 -or $Global:Toggle_ShowHidden -ne 0) {
            $runRefresh = $true
        }
    }

    if ($runRefresh) {
        Write-LeftAligned "Refreshing Explorer to apply UI settings..."
        Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 1
        if (-not (Get-Process explorer -ErrorAction SilentlyContinue)) { Start-Process explorer }
    }

    # Post-execution audit generation
    try {
        $auditData = @{
            MicrosoftUpdate = Test-Reg "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" "AllowMUUpdateService" 1
            RestartNotifications = Test-Reg "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" "RestartNotificationsAllowed2" 1
            AppRestartPersist = Test-Reg "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Winlogon" "RestartApps" 1
            PSTranscription = Test-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\Transcription" "EnableTranscripting" 1
            WindowsTelemetry = Test-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" "AllowTelemetry" 0
            LLMNRConfiguration = Test-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient" "EnableMulticast" 0
            PSScriptBlockLog = Test-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging" "EnableScriptBlockLogging" 1
            PSModuleLogging = Test-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging" "EnableModuleLogging" 1
            NetBIOS = $s_NetBIOS
            RealTimeProtection = $(try { (Get-MpPreference -ErrorAction SilentlyContinue).DisableRealtimeMonitoring -eq $false } catch { $false })
            PUAProtection = $(try { (Get-MpPreference -ErrorAction SilentlyContinue).PUAProtection -eq 1 } catch { $false })
            PUAProtectionEdge = $(if ((Get-ItemProperty "HKCU:\Software\Microsoft\Edge\SmartScreenPuaEnabled" -ErrorAction SilentlyContinue)."(default)" -eq 1) { $true } else { $false })
            MemoryIntegrity = Test-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" "Enabled" 1
            KernelStackProtection = Test-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\KernelShadowStacks" "Enabled" 1
            LSAProtection = Test-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" "RunAsPPL" 1
            WindowsFirewall = $(try { (Get-NetFirewallProfile | Where-Object { -not $_.Enabled }).Count -eq 0 } catch { $false })
            ClassicContextMenu = $s_Ctx
            TaskbarSearchBox = Test-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" "SearchboxTaskbarMode" 3
            TaskViewToggle = Test-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowTaskViewButton" 0
            ShowFileExtensions = Test-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "HideFileExt" 0
            ShowHiddenFiles = Test-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "Hidden" 1
            Timestamp = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
        }
        $auditPath = Join-Path $PWD.Path "winauto_audit.json"
        $auditData | ConvertTo-Json | Out-File -FilePath $auditPath -Force -Encoding utf8
        Write-Host "    [v] Generated winauto_audit.json successfully." -ForegroundColor Cyan
    } catch {
        Write-Host "    [x] Failed to generate winauto_audit.json." -ForegroundColor Red
    }

    Sync-ToggleStates -s_Ctx $s_Ctx -s_Task $s_Task -s_View $s_View

    Write-Boundary
    Write-Centered "$FGGreen CONFIGURATION COMPLETE $Reset" -Width 52
    Set-WinAutoLastRun -Module "Configuration"
    Start-Sleep -Seconds 2
}

function Invoke-WinAutoMaintenance {
    param([switch]$SmartRun)
    Write-Header "WINDOWS MAINTENANCE PHASE"
    $lastRun = Get-WinAutoLastRun -Module "Maintenance"
    Write-LeftAligned "$FGGray Last Run: $FGWhite$lastRun$Reset"

    # Check if all maintenance tasks have 0 days since last run
    $mKeys = @("Maintenance_WinUpdate", "Maintenance_Disk", "Maintenance_Cleanup", "Maintenance_SFC")
    $allZero = $true
    if ($Global:Toggle_MaintainForced -eq 1 -or $Global:Toggle_MaintUpdate -eq 1 -or $Global:Toggle_MaintDisk -eq 1 -or $Global:Toggle_MaintCleanup -eq 1 -or $Global:Toggle_MaintSFC -eq 1) {
        $allZero = $false
    } else {
        foreach ($k in $mKeys) {
            $lr = Get-WinAutoLastRun -Module $k
            if ($lr -eq "Never") { $allZero = $false; break }
            try {
                $days = ((Get-Date) - (Get-Date $lr)).Days
                if ($days -ne 0) { $allZero = $false; break }
            } catch { $allZero = $false; break }
        }
    }

    if ($allZero) {
        Write-Boundary
        Write-LeftAligned "$FGGreen$Global:Char_CheckMark All maintenance tasks were run today (0 days since last run). Skipping Maintenance section.$Reset"
        Write-Boundary
        Write-Centered "$FGGreen MAINTENANCE SKIPPED $Reset" -Width 52
        Set-WinAutoLastRun -Module "Maintenance"
        Start-Sleep -Seconds 2
        return
    }
    
    function Test-RunNeeded {
        param($Key, $Days)
        if ($Global:Toggle_MaintainForced -eq 1) { return $true }
        if ($Key -eq "Maintenance_WinUpdate" -and $Global:Toggle_MaintUpdate -eq 1) { return $true }
        if ($Key -eq "Maintenance_Disk" -and $Global:Toggle_MaintDisk -eq 1) { return $true }
        if ($Key -eq "Maintenance_Cleanup" -and $Global:Toggle_MaintCleanup -eq 1) { return $true }
        if ($Key -eq "Maintenance_SFC" -and $Global:Toggle_MaintSFC -eq 1) { return $true }
        if (-not $SmartRun) {
            $anyToggled = ($Global:Toggle_MaintUpdate -eq 1 -or $Global:Toggle_MaintDisk -eq 1 -or $Global:Toggle_MaintCleanup -eq 1 -or $Global:Toggle_MaintSFC -eq 1)
            if (-not $anyToggled) { return $true }
        }
        if (-not $SmartRun) { return $false }
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
    
        Test-PauseRequest
        if (Test-RunNeeded -Key "Maintenance_SFC" -Days 30) {
            Invoke-WA_WindowsRepair
            Set-WinAutoLastRun -Module "Maintenance_SFC"
        }
    
        Test-PauseRequest
        if (Test-RunNeeded -Key "Maintenance_Disk" -Days 7) {
            Invoke-WA_OptimizeDisks
            Set-WinAutoLastRun -Module "Maintenance_Disk"
        }
    
        Test-PauseRequest
        if (Test-RunNeeded -Key "Maintenance_Cleanup" -Days 7) {
            Invoke-WA_SystemCleanup
            Set-WinAutoLastRun -Module "Maintenance_Cleanup"
        }
    
        Test-PauseRequest
        # Run Windows Update (Skip if run in last 24 hours)
        if (Test-RunNeeded -Key "Maintenance_WinUpdate" -Days 1) {
            Invoke-WA_WindowsUpdate
            Set-WinAutoLastRun -Module "Maintenance_WinUpdate"
        }


        Write-Host ""
        Write-Centered "$FGGreen MAINTENANCE COMPLETE $Reset" -Width 52
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


# --- EMBEDDED ATOMIC SCRIPTS ---

function Invoke-WA_SetRealTimeProt {
    <#
.SYNOPSIS
    Enables or Disables Real-time Protection.
.DESCRIPTION
    Standardized for WinAuto. Checks for Tamper Protection before changes.
    Standalone version.
    Includes Reverse Mode (-r).
.PARAMETER Reverse
    (Alias: -r) Reverses the setting (Disables Real-time Protection).
#>
    param(
        [Parameter(Mandatory = $false)]
        [Alias('r')]
        [switch]$Reverse
    )
    Write-Header "REAL-TIME PROTECTION"
    
    # --- PRE-CHECK: 3RD PARTY AV ---
    try {
        $avList = Get-CimInstance -Namespace root/SecurityCenter2 -ClassName AntivirusProduct -ErrorAction SilentlyContinue
        foreach ($av in $avList) {
            # 397568 is typical implementation for Defender, but name check is robust
            if ($av.displayName -and $av.displayName -notmatch "Windows Defender" -and $av.displayName -notmatch "Microsoft Defender Antivirus") {
                # UI Update: Show [-] in DarkGray for 3rd Party AV
                Write-LeftAligned "[$FGDarkGray-$Reset] Real-time Protection managed by $($av.displayName)."
                
                # Footer
                Write-Host ""
                $copyright = ""; $cPad = [Math]::Floor((60 - $copyright.Length) / 2); Write-Host (" " * $cPad + "${Global:FGWhite}$copyright$Reset"); Write-Host ""
                return
            }
        }
    }
    catch {}

    # --- MAIN ---

    try {
        $target = if ($Reverse) { $true } else { $false }
        $status = if ($Reverse) { "DISABLED" } else { "ENABLED" }

        $tp = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows Defender\Features" -Name "TamperProtection" -ErrorAction SilentlyContinue).TamperProtection

        if ($tp -eq 5) {
            Write-LeftAligned "$FGDarkYellow$Char_Warn Tamper Protection is ENABLED and blocking changes.$Reset"
        }
        else {
            Set-MpPreference -DisableRealtimeMonitoring $target -ErrorAction Stop

            # Verify
            $current = (Get-MpPreference).DisableRealtimeMonitoring
            if ($current -eq $target) {
                Write-LeftAligned "$FGGreen$Char_HeavyCheck  Real-time Protection is $status.$Reset"
            }
            else {
                Write-LeftAligned "$FGDarkYellow$Char_Warn Real-time Protection verification failed.$Reset"
            }
        }
    }
    catch {
        Write-WrappedError $_.Exception.Message
    }

}

function Invoke-WA_SetPUABlockApps {
    <#
.SYNOPSIS
    Enables or Disables PUA (Potentially Unwanted Application) Blocking.
.DESCRIPTION
    Standardized for WinAuto.
    Standalone version: Can be copy-pasted directly into PowerShell.
    Includes Reverse Mode (-r) to undo changes.
.PARAMETER Reverse
    (Alias: -r) Reverses the setting (Disables PUA blocking).
#>
    param(
        [Parameter(Mandatory = $false)]
        [Alias('r')]
        [switch]$Reverse,
        [switch]$Force
    )
    # --- MAIN LOGIC ---
    Write-Header "PUA BLOCK APPS"

    try {
        $targetMp = if ($Reverse) { 0 } else { 1 }
        $statusText = if ($Reverse) { "DISABLED" } else { "ENABLED" }

        # System-wide Defender PUA
        Set-MpPreference -PUAProtection $targetMp -ErrorAction Stop
        Write-LeftAligned "$FGGreen$Char_HeavyCheck  Defender PUA Blocking is $statusText.$Reset"

        # Verification
        $currentMp = (Get-MpPreference).PUAProtection
        if ($currentMp -ne $targetMp) {
            Write-LeftAligned "$FGDarkYellow$Char_Warn Verification failed for Defender PUA. Status: $currentMp$Reset"
        }

    }
    catch {
        Write-WrappedError $_.Exception.Message
    }

}

function Invoke-WA_SetPUABlockDLs {
    <#
.SYNOPSIS
    Enables or Disables Edge SmartScreen PUA Protection.
.DESCRIPTION
    Standardized for WinAuto. Configures User-specific Edge SmartScreen PUA (Block downloads).
    Standalone version: Can be copy-pasted directly into PowerShell.
    Includes Reverse Mode (-r) to undo changes.
.PARAMETER Reverse
    (Alias: -r) Reverses the setting (Disables PUA blocking).
#>
    param(
        [Parameter(Mandatory = $false)]
        [Alias('r')]
        [switch]$Reverse,
        [switch]$Force
    )
    # --- MAIN LOGIC ---
    Write-Header "PUA DOWNLOADS"

    try {
        $targetEdge = if ($Reverse) { 0 } else { 1 }
        $statusText = if ($Reverse) { "DISABLED" } else { "ENABLED" }

        # User-specific Edge SmartScreen PUA (Block downloads)
        $edgeKeyPath = "HKCU:\Software\Microsoft\Edge\SmartScreenPuaEnabled"
        if (-not (Test-Path $edgeKeyPath)) {
            New-Item -Path $edgeKeyPath -Force | Out-Null
        }
        Set-ItemProperty -Path $edgeKeyPath -Name "(default)" -Value $targetEdge -Type DWord -Force
    
        Write-LeftAligned "$FGGreen$Char_HeavyCheck  Edge 'Block downloads' is $statusText.$Reset"

    }
    catch {
        Write-WrappedError $_.Exception.Message
    }

}

function Invoke-WA_SetMemoryInteg {
    <#
.SYNOPSIS
    Enables Memory Integrity (Core Isolation) via Registry.
.DESCRIPTION
    Standardized for WinAuto.
    Sets HypervisorEnforcedCodeIntegrity 'Enabled' value to 1 (On) or 0 (Off).
    Requires System Restart.
    Standalone version. Includes Reverse Mode (-r).
.PARAMETER Reverse
    (Alias: -r) Reverses the setting (Disables Memory Integrity).
#>
    param(
        [Parameter(Mandatory = $false)]
        [Alias('r')]
        [switch]$Reverse
    )
    Write-Header "MEMORY INTEGRITY REG"

    $Path = "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity"
    $Name = "Enabled"
    $Value = if ($Reverse) { 0 } else { 1 }
    $ActionStr = if ($Reverse) { "DISABLED" } else { "ENABLED" }

    try {
        # Create Path if missing
        if (-not (Test-Path $Path)) {
            New-Item -Path $Path -Force | Out-Null
        }

        # Set Value
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type DWord -Force -ErrorAction Stop
    
        # Add Tracking Keys (if enabling)
        if (-not $Reverse) {
            Set-ItemProperty -Path $Path -Name "WasEnabledBy" -Value 2 -Type DWord -Force -ErrorAction SilentlyContinue
        }
    
        Write-LeftAligned "$FGGreen$Char_HeavyCheck  Memory Integrity Registry Key set to $ActionStr.$Reset"
        Write-LeftAligned "$FGDarkYellow$Char_Warn  A system restart is required to take effect.$Reset"
    }
    catch {
        Write-WrappedError $_.Exception.Message
        Write-LeftAligned "$FGDarkYellow  Hint: Tamper Protection might be blocking this.$Reset"
    }

}

# --- EMBEDDED ATOMIC SCRIPTS (Security Part 2) ---

function Invoke-WA_SetKernelMode {
    <#
.SYNOPSIS
    Enables 'Kernel-mode Hardware-enforced Stack Protection' in Windows Security via UI Automation.
.DESCRIPTION
    Launches Windows Security, navigates to Device Security > Core Isolation,
    and attempts to toggle 'Kernel-mode Hardware-enforced Stack Protection'.
    Standalone version. Includes Reverse Mode.
.PARAMETER Reverse
    (Alias: -r) Reverses the setting (Turns OFF Stack Protection).
#>

    & {
        param(
            [Parameter(Mandatory = $false)]
            [Alias('r')]
            [switch]$Reverse,
            [switch]$Force
        )

        Set-StrictMode -Version Latest
        $ErrorActionPreference = 'Stop'


        # --- MAIN SCRIPT ---
        Write-Header "KERNEL STACK UIA"
        
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

        Write-Log "Starting Windows Security Automation (Kernel-mode Stack Protection)..." "Cyan"

        $MaxRetries = 5
        $RetryCount = 0
        $Success = $false

        while (-not $Success -and ($RetryCount -lt $MaxRetries)) {
            $RetryCount++
        
            # 1. Launch / Relaunch Windows Security
            Write-Log "Launching Windows Security (Iteration $RetryCount)..." "Gray"
        
            Start-SecHealthUI


            # 2. Find the Main Window
            $Desktop = [System.Windows.Automation.AutomationElement]::RootElement
            $Window = Get-UIAElement -Parent $Desktop -Name "Windows Security" -ControlType ([System.Windows.Automation.ControlType]::Window) -Scope "Children" -TimeoutSeconds 10

            if (-not $Window) {
                Write-Log "Could not find 'Windows Security' window. Retrying..." "Yellow"
                continue
            }
            Write-Log "Found 'Windows Security' window." "Green"
            try { $Window.SetFocus() } catch {}

            # 3. Navigate to "Device security"
            Write-Log "Navigating to 'Device security'..." "Gray"
            $DeviceSecBtn = Get-UIAElement -Parent $Window -Name "Device security" -Scope "Descendants" -TimeoutSeconds 5
        
            if ($DeviceSecBtn) {
                Invoke-UIAElement -Element $DeviceSecBtn | Out-Null
                Start-Sleep -Seconds 2
            }
            else {
                Write-Log "Could not find 'Device security' navigation item." "Red"
                continue
            }

            # 4. Navigate to "Core isolation details"
            Write-Log "Navigating to 'Core isolation details'..." "Gray"
            $CoreIsoLink = Get-UIAElement -Parent $Window -Name "Core isolation details" -Scope "Descendants" -TimeoutSeconds 5
        
            if ($CoreIsoLink) {
                Invoke-UIAElement -Element $CoreIsoLink | Out-Null
                Start-Sleep -Seconds 2
            }
            else {
                Write-Log "Could not find 'Core isolation details' link. Checking if already there..." "Yellow"
            }

            # 5. Find Target Toggle
            Write-Log "Looking for 'Kernel-mode Hardware-enforced Stack Protection' toggle..." "Gray"

            $Condition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty, "Kernel-mode Hardware-enforced Stack Protection")
            $AllElements = $Window.FindAll([System.Windows.Automation.TreeScope]::Descendants, $Condition)

            $TargetToggle = $null
        
            # Priority: CheckBox > Group > Button
            foreach ($El in $AllElements) {
                $Type = $El.Current.ControlType
                if ($Type -eq [System.Windows.Automation.ControlType]::CheckBox) {
                    $TargetToggle = $El
                    break
                }
            }
        
            if (-not $TargetToggle) {
                foreach ($El in $AllElements) {
                    $Type = $El.Current.ControlType
                    if ($Type -ne [System.Windows.Automation.ControlType]::Text -and $Type -ne [System.Windows.Automation.ControlType]::Pane) {
                        $TargetToggle = $El
                        break
                    }
                }
            }

            if ($TargetToggle) {
                Write-Log "Found Target Element ($($TargetToggle.Current.ControlType.ProgrammaticName)). Checking state..." "Cyan"
                $State = Get-UIAToggleState -Element $TargetToggle
            
                # Determine Desired State based on Reverse logic
                $DesiredState = if ($Reverse) { 0 } else { 1 }
                $ActionStr = if ($Reverse) { "OFF" } else { "ON" }

                # Mapping: 0=Off, 1=On, 2=Indeterminate
                if ($State -eq $DesiredState) {
                    Write-Log "Feature is already $ActionStr." "Green"
                    $Success = $true
                }
                elseif ($null -ne $State) {
                    # State matches 0 or 1 but is not desired
                    Write-Log "Feature is $(if($State -eq 1){'ON'}else{'OFF'}). Toggling $ActionStr..." "Cyan"
                 
                    $Toggled = $false
                    # Try Toggle Pattern first
                    if (Invoke-UIAElement -Element $TargetToggle) {
                        $Toggled = $true
                    }
                    else {
                        # Fallback to Invoke (Click) if Toggle fails
                        Write-Log "Toggle pattern failed. Attempting Invoke (Click)..." "Yellow"
                        try {
                            $Invoke = $TargetToggle.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern)
                            $Invoke.Invoke()
                            $Toggled = $true
                        }
                        catch {
                            Write-Log "Invoke pattern also failed." "Red"
                        }
                    }

                    if ($Toggled) {
                        Write-Log "Action triggered. Waiting for update..." "Green"
                        Start-Sleep -Seconds 3
                     
                        $StateAfter = Get-UIAToggleState -Element $TargetToggle
                        if ($StateAfter -eq $DesiredState) {
                            Write-Log "Successfully verified state is $ActionStr." "Green"
                            $Success = $true
                        }
                        else {
                            Write-Log "State did not change. This is common if UAC is prompting or a reboot is pending." "Yellow"
                            # We assume success if we clicked it, as we can't automate the UAC prompt easily.
                            $Success = $true 
                        }
                    }
                    else {
                        Write-Log "Failed to interact with the toggle." "Red"
                    }
                }
                else {
                    # No toggle pattern (e.g. Button?)
                    Write-Log "Toggle state unknown (Element might be a Button). Attempting to Click..." "Yellow"
                    Invoke-UIAElement -Element $TargetToggle | Out-Null
                    $Success = $true
                }

            }
            else {
                Write-Log "Could not find 'Kernel-mode Hardware-enforced Stack Protection' toggle. Feature might not be supported on this hardware." "Red"
                $Success = $true 
            }
        }

        Write-Log "Automation complete." "Cyan"

        # --- FOOTER ---
        Write-Host ""
        $copyright = ""
        $cPad = [Math]::Floor((60 - $copyright.Length) / 2)
        Write-Host (" " * $cPad + "${Global:FGWhite}$copyright$Reset")
        Write-Host ""

    } @args
}

function Invoke-WA_SetLocalSecurity {
    <#
.SYNOPSIS
    Enables LSA Protection (RunAsPPL) via Registry.
.DESCRIPTION
    Standardized for WinAuto.
    Sets 'RunAsPPL' value to 1 (On) or 0 (Off) in HKLM\SYSTEM\CurrentControlSet\Control\Lsa.
    Standalone version. Includes Reverse Mode (-r).
.PARAMETER Reverse
    (Alias: -r) Reverses the setting (Disables LSA Protection).
#>
    param(
        [Parameter(Mandatory = $false)]
        [Alias('r')]
        [switch]$Reverse
    )
    Write-Header "LSA PROTECTION REG"

    $Path = "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa"
    $Name = "RunAsPPL"
    $Value = if ($Reverse) { 0 } else { 1 }
    $ActionStr = if ($Reverse) { "DISABLED" } else { "ENABLED" }

    try {
        if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }

        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type DWord -Force -ErrorAction Stop
    
        Write-LeftAligned "$FGGreen$Char_HeavyCheck  LSA Protection (RunAsPPL) set to $ActionStr.$Reset"
        Write-LeftAligned "$FGDarkYellow$Char_Warn  A system restart is required to take effect.$Reset"
    }
    catch {
        Write-WrappedError $_.Exception.Message
    }

}

function Invoke-WA_SetFirewallON {
    <#
.SYNOPSIS
    Enables Windows Firewall for all profiles.
.DESCRIPTION
    Standardized for WinAuto.
    Ensures Domain, Public, and Private firewall profiles are Enabled.
    Standalone version. Includes Reverse Mode (-r).
.PARAMETER Reverse
    (Alias: -r) Reverses the setting (Disables Firewall).
#>
    param(
        [Parameter(Mandatory = $false)]
        [Alias('r')]
        [switch]$Reverse
    )
    Write-Header "WINDOWS FIREWALL"

    try {
        $target = if ($Reverse) { "False" } else { "True" }
    
        Set-NetFirewallProfile -Profile Domain, Public, Private -Enabled $target -ErrorAction Stop
    
        $statusStr = if ($target -eq "True") { "ENABLED" } else { "DISABLED" }
        Write-LeftAligned "$FGGreen$Char_HeavyCheck  Firewall (All Profiles) is $statusStr.$Reset"
    }
    catch {
        Write-Log "Firewall Configuration Failed: $($_.Exception.Message)" -Level ERROR
        Write-WrappedError $_.Exception.Message
    }
}

# --- EMBEDDED ATOMIC SCRIPTS (UI Config Part 3) ---

function Invoke-WA_SetClassicMenu {
    <#
.SYNOPSIS
    Restores the Classic Context Menu (Windows 10 Style).
.DESCRIPTION
    Standardized for WinAuto.
    Modifies HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32
    Restarts Explorer to apply.
    Standalone version. Includes Reverse Mode (-r).
.PARAMETER Reverse
    (Alias: -r) Reverses the setting (Restores Windows 11 Menu).
#>
    param(
        [Parameter(Mandatory = $false)]
        [Alias('r')]
        [switch]$Reverse
    )
    Write-Header "CLASSIC CONTEXT MENU"
    
    $Key = "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}"
    $Path = "$Key\InprocServer32"
    
    try {
        if ($Reverse) {
            # Remove key to restore Win11 default
            if (Test-Path $Key) {
                Remove-Item -Path $Key -Recurse -Force -ErrorAction SilentlyContinue
                Write-LeftAligned "$FGGreen$Char_HeavyCheck Restored Windows 11 Context Menu.$Reset"
                Write-LeftAligned "$FGGray Restarting Explorer...$Reset"
                Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
                Start-Sleep -Seconds 1
            }
            else {
                Write-LeftAligned "$FGGray Windows 11 Menu is already active.$Reset"
            }
        }
        else {
            # Create Key for Classic Menu
            if (-not (Test-Path $Path)) {
                New-Item -Path $Path -Force | Out-Null
            }
            # Set default value to empty string
            Set-ItemProperty -Path $Path -Name "(default)" -Value "" -Force
         
            Write-LeftAligned "$FGGreen$Char_HeavyCheck Enabled Classic Context Menu.$Reset"
            Write-LeftAligned "$FGGray Restarting Explorer...$Reset"
            Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 1
        }
    }
    catch {
        Write-WrappedError $_.Exception.Message
    }

}

function Invoke-WA_SetTaskbarSearch {
    <#
.SYNOPSIS
    Sets Taskbar Search to 'Search icon only'.
.DESCRIPTION
    Standardized for WinAuto.
    Sets 'SearchboxTaskbarMode' to 3 (Icon Only) or 1 (Box).
    Restarts Explorer to apply.
    Standalone version. Includes Reverse Mode (-r).
.PARAMETER Reverse
    (Alias: -r) Reverses the setting (Sets to Search Box - Value 1).
#>
    param(
        [Parameter(Mandatory = $false)]
        [Alias('r')]
        [switch]$Reverse
    )
    Write-Header "TASKBAR SEARCH CONFIG"

    $Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search"
    $Name = "SearchboxTaskbarMode"
    
    # 3 = Icon Only (WinAuto Default), 1 = Search Box (Default Win11)
    $Value = if ($Reverse) { 1 } else { 3 } 
    $ActionStr = if ($Reverse) { "BOX" } else { "ICON ONLY" }

    try {
        if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
    
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type DWord -Force
    
        Write-LeftAligned "$FGGreen$Char_HeavyCheck Taskbar Search set to $ActionStr.$Reset"
        Write-LeftAligned "$FGGray Restarting Explorer...$Reset"
        Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 1
    }
    catch {
        Write-WrappedError $_.Exception.Message
    }

}

function Invoke-WA_SetTaskViewOFF {
    <#
.SYNOPSIS
    Hides the Task View button from the Taskbar.
.DESCRIPTION
    Standardized for WinAuto.
    Sets 'ShowTaskViewButton' to 0 (Off).
    Restarts Explorer to apply.
    Standalone version. Includes Reverse Mode (-r).
.PARAMETER Reverse
    (Alias: -r) Reverses the setting (Shows Task View).
#>
    param(
        [Parameter(Mandatory = $false)]
        [Alias('r')]
        [switch]$Reverse
    )
    Write-Header "TASK VIEW TOGGLE"

    $Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    $Name = "ShowTaskViewButton"
    
    $Value = if ($Reverse) { 1 } else { 0 } 
    $ActionStr = if ($Reverse) { "SHOWN" } else { "HIDDEN" }

    try {
        if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
    
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type DWord -Force
    
        Write-LeftAligned "$FGGreen$Char_HeavyCheck Task View button is $ActionStr.$Reset"
        Write-LeftAligned "$FGGray Restarting Explorer...$Reset"
        Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 1
    }
    catch {
        Write-WrappedError $_.Exception.Message
    }

}


function Invoke-WA_SetMicrosoftUpd {
    <#
.SYNOPSIS
    Sets 'Receive updates for other Microsoft products'.
.DESCRIPTION
    Standardized for WinAuto.
    Sets 'AllowMUUpdateService' registry key.
    Standalone version. Includes Reverse Mode (-r).
.PARAMETER Reverse
    (Alias: -r) Disables the setting.
#>
    param(
        [Parameter(Mandatory = $false)]
        [Alias('r')]
        [switch]$Reverse
    )
    Write-Header "MICROSOFT UPDATE"
    
    $Path = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings"
    $Name = "AllowMUUpdateService"
    $Value = if ($Reverse) { 0 } else { 1 } # 1=On
    $StatusStr = if ($Reverse) { "DISABLED" } else { "ENABLED" }

    try {
        if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type DWord -Force
    
        Write-LeftAligned "$FGGreen$Char_HeavyCheck MS Update Service is $StatusStr.$Reset"
    }
    catch {
        Write-WrappedError $_.Exception.Message
    }

}

function Invoke-WA_SetRestartIsReq {
    <#
.SYNOPSIS
    Sets 'Notify me when a restart is required'.
.DESCRIPTION
    Standardized for WinAuto.
    Sets 'RestartNotificationsAllowed2' registry key.
    Standalone version. Includes Reverse Mode (-r).
.PARAMETER Reverse
    (Alias: -r) Disables the setting.
#>
    param(
        [Parameter(Mandatory = $false)]
        [Alias('r')]
        [switch]$Reverse
    )
    Write-Header "RESTART NOTIFICATIONS"
    
    $Path = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings"
    $Name = "RestartNotificationsAllowed2"
    $Value = if ($Reverse) { 0 } else { 1 } # 1=On
    $StatusStr = if ($Reverse) { "DISABLED" } else { "ENABLED" }

    try {
        if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type DWord -Force
    
        Write-LeftAligned "$FGGreen$Char_HeavyCheck Restart Notification are $StatusStr.$Reset"
    }
    catch {
        Write-WrappedError $_.Exception.Message
    }

}

function Invoke-WA_SetRestartApps {
    <#
.SYNOPSIS
    Sets 'Restart apps after signing in'.
.DESCRIPTION
    Standardized for WinAuto.
    Sets 'RestartApps' registry key in Winlogon.
    Standalone version. Includes Reverse Mode (-r).
.PARAMETER Reverse
    (Alias: -r) Disables the setting.
#>
    param(
        [Parameter(Mandatory = $false)]
        [Alias('r')]
        [switch]$Reverse
    )
    Write-Header "APP RESTART PERSISTENCE"
    
    $Path = "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
    $Name = "RestartApps"
    $Value = if ($Reverse) { 0 } else { 1 } # 1=On
    $StatusStr = if ($Reverse) { "DISABLED" } else { "ENABLED" }

    try {
        if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type DWord -Force
    
        Write-LeftAligned "$FGGreen$Char_HeavyCheck App Restart Persistence is $StatusStr.$Reset"
    }
    catch {
        Write-WrappedError $_.Exception.Message
    }

}

# --- EMBEDDED ATOMIC SCRIPTS (Maintenance Part 4) ---



function Invoke-WA_OptimizeDisks {
    <#
.SYNOPSIS
    Optimizes all fixed disks (TRIM for SSD, Defrag for HDD).
.DESCRIPTION
    Standardized for WinAuto.
    Standalone version. Includes Reverse Mode (-r) stub.
.PARAMETER Reverse
    (Alias: -r) No-Op. Optimization cannot be reversed.
#>
    param(
        [Parameter(Mandatory = $false)]
        [Alias('r')]
        [switch]$Reverse
    )
    Write-Header "DISK OPTIMIZATION"

    if ($Reverse) {
        Write-LeftAligned "$FGYellow$Char_Warn Reverse Mode: Disk optimization cannot be reversed.$Reset"
        Write-Host ""
        return
    }

    try {
        $volumes = Get-Volume | Where-Object { $_.DriveLetter -and $_.DriveType -eq 'Fixed' }
        foreach ($v in $volumes) {
            $drive = $v.DriveLetter
            Write-LeftAligned "$FGWhite$Char_HeavyMinus Drive $drive`: $Reset"
        
            $isSSD = $false
            $part = Get-Partition -DriveLetter $drive -ErrorAction SilentlyContinue
            if ($part) {
                $disk = Get-Disk -Number $part.DiskNumber -ErrorAction SilentlyContinue
                if ($disk -and $disk.MediaType -eq 'SSD') { $isSSD = $true }
            }

            if ($isSSD) {
                Write-LeftAligned "  $FGYellow Type: SSD - Running TRIM...$Reset"
                Optimize-Volume -DriveLetter $drive -ReTrim | Out-Null
            }
            else {
                Write-LeftAligned "  $FGYellow Type: HDD - Running Defrag...$Reset"
                Optimize-Volume -DriveLetter $drive -Defrag | Out-Null
            }
            Write-LeftAligned "  $FGGreen$Char_HeavyCheck Optimization Complete.$Reset"
        }
    }
    catch {
        $errMsg = "$($_.Exception.Message)"
        Write-LeftAligned "$FGRed$Char_RedCross Error: $errMsg$Reset"
    }

}

function Invoke-WA_SystemCleanup {
    <#
.SYNOPSIS
    Performs System & User Temp Cleanup.
.DESCRIPTION
    Standardized for WinAuto. Removes files from Temp folders.
    Standalone version. Includes Reverse Mode (-r) stub.
.PARAMETER Reverse
    (Alias: -r) No-Op. File deletion cannot be reversed.
#>
    param(
        [Parameter(Mandatory = $false)]
        [Alias('r')]
        [switch]$Reverse
    )
    Write-Header "SYSTEM CLEANUP"

    if ($Reverse) {
        Write-LeftAligned "$FGYellow$Char_Warn Reverse Mode: File cleanup cannot be reversed.$Reset"
        Write-Host ""
        return
    }

    try {
        $paths = @("$env:TEMP", "$env:WINDIR\Temp")
        $total = 0

        foreach ($p in $paths) {
            if (Test-Path $p) {
                Write-LeftAligned "$FGWhite$Char_HeavyMinus Cleaning: $p$Reset"
                try {
                    $items = Get-ChildItem -Path $p -Recurse -Force -ErrorAction SilentlyContinue
                    if ($items) {
                        $c = @($items).Count
                        $items | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
                        Write-LeftAligned "  $FGGreen$Char_BallotCheck Removed $c items.$Reset"
                        $total += $c
                    }
                    else {
                        Write-LeftAligned "  $FGGray Already empty.$Reset"
                    }
                }
                catch {
                    Write-LeftAligned "  $FGRed$Char_Warn Partial cleanup failure.$Reset"
                }
            }
        }
    
        Write-Host ""
        Write-LeftAligned "$FGGreen$Char_HeavyCheck Cleanup Complete. Total items removed: $total$Reset"

    }
    catch {
        $errMsg = "$($_.Exception.Message)"
        Write-LeftAligned "$FGRed$Char_RedCross Error: $errMsg$Reset"
    }

}

function Invoke-WA_WindowsRepair {
    <#
.SYNOPSIS
    Windows System File Integrity & Repair Tool (SFC/DISM).
.DESCRIPTION
    Automated flow to check and repair Windows system files using SFC and DISM.
    Standalone version. Includes Reverse Mode (-r) stub.
.PARAMETER Reverse
    (Alias: -r) No-Op. System repairs cannot be reversed.
#>
    param(
        [Parameter(Mandatory = $false)]
        [Alias('r')]
        [switch]$Reverse
    )
    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'

    function Invoke-SFCScan {
        Write-Host ""
        Write-LeftAligned "$Bold$FGWhite$Char_HeavyMinus System File Checker (SFC)$Reset"
        Write-LeftAligned "$FGGray Initializing sfc /scannow...$Reset"
    
        try {
            $rawOutput = & sfc /scannow 2>&1
            $sfcOutput = ($rawOutput -join " ") -replace '[^\x20-\x7E]', '' # Keep only printable ASCII
            Write-Host ""
        
            if ($sfcOutput -match "did not find any integrity violations") {
                Write-LeftAligned "$FGGreen$Char_BallotCheck System files are healthy.$Reset"
                return "SUCCESS"
            }
            elseif ($sfcOutput -match "found corrupt files and successfully repaired them") {
                Write-LeftAligned "$FGGreen$Char_BallotCheck Corrupt files were found and repaired.$Reset"
                return "REPAIRED"
            }
            elseif ($sfcOutput -match "found corrupt files but was unable to fix some of them") {
                Write-LeftAligned "$FGRed$Char_RedCross SFC found unfixable corruption.$Reset"
                return "FAILED"
            }
            else {
                Write-LeftAligned "$FGDarkMagenta$Char_Warn SFC completed with unknown status.$Reset"
                return "UNKNOWN"
            }
        }
        catch {
            $errMsg = "$($_.Exception.Message)"
            Write-LeftAligned "$FGRed$Char_RedCross SFC execution error: $errMsg$Reset"
            return "ERROR"
        }
    }

    function Invoke-DISMRepair {
        Write-Host ""
        Write-LeftAligned "$Bold$FGWhite$Char_HeavyMinus Deployment Image Servicing (DISM)$Reset"
        Write-LeftAligned "$FGYellow Starting online image repair...$Reset"
        Write-LeftAligned "$FGGray This may take several minutes.$Reset"
    
        try {
            $dismOutput = & DISM /Online /Cleanup-Image /RestoreHealth 2>&1 | Out-String
        
            if ($dismOutput -match "The restore operation completed successfully") {
                Write-LeftAligned "$FGGreen$Char_BallotCheck DISM repair completed successfully.$Reset"
                return $true
            }
            else {
                Write-LeftAligned "$FGRed$Char_RedCross DISM repair failed.$Reset"
                return $false
            }
        }
        catch {
            $errMsg = "$($_.Exception.Message)"
            Write-LeftAligned "$FGRed$Char_RedCross DISM execution error: $errMsg$Reset"
            return $false
        }
    }

    Write-Header "SYSTEM REPAIR FLOW"

    if ($Reverse) {
        Write-LeftAligned "$FGYellow$Char_Warn Reverse Mode: System repairs cannot be reversed.$Reset"
        Write-Host ""
        return
    }

    $result = Invoke-SFCScan

    if ($result -eq "FAILED") {
        Write-Host ""
        Write-LeftAligned "$FGYellow Triggering DISM Repair to fix underlying component store...$Reset"
        $dismSuccess = Invoke-DISMRepair
    
        if ($dismSuccess) {
            Write-Host ""
            Write-LeftAligned "$FGYellow Re-running SFC to verify repairs...$Reset"
            Invoke-SFCScan | Out-Null
        }
    }

    Write-Host ""
    Write-Boundary
    Write-Centered "$FGGreen REPAIR FLOW COMPLETE $Reset" -Width 52
    Write-Boundary

}

# --- END OF EMBEDDING ---

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
        "Config"      { Invoke-WinAutoConfiguration }
        "Maintenance" { Invoke-WinAutoMaintenance }
    }
    
    Write-Log "CLI Execution Complete."
    return
}

Set-ConsoleSnapRight -Columns 60
$Global:MenuSelection = 0  # 0=SmartRun, 1=ManualMode, 2=Configure Operating System (Header), 3=Classic Context Menu, 4=Taskbar Search Box, 5=Task View Toggle, 6-19=Security/UI Toggles, 20=Maintain Operating System (Header)
# $Global:Toggle_MaintainForced is initialized at the top to support CLI/Silent mode
# Per-section expansion flags



$Global:WinAutoFirstLoad = $true
$Global:ManualModeExpanded = $false

while ($true) {
    # Maintain
    $Global:MaintenanceComplete = if ($Global:Toggle_MaintainForced -eq 1 -or $Global:Toggle_MaintUpdate -eq 1 -or $Global:Toggle_MaintDisk -eq 1 -or $Global:Toggle_MaintCleanup -eq 1 -or $Global:Toggle_MaintSFC -eq 1) { $false } else { Test-WA_MaintenanceRecentlyComplete }
    

    # --- LIVE STATUS CHECKS (Discovery for UI and SmartRUN Execution) ---
    $s_RT = $null; $s_PUA = $null; $s_FW = $null; $s_SS = $null
    try { 
        $avName = Get-ThirdPartyAV
        $mp = Get-MpPreference -ErrorAction SilentlyContinue
        if ($avName) { 
            $s_RT = "GreyOut"
            $s_PUA = "GreyOut" # PUA often managed by same engine
            $s_SS = "GreyOut"
        } else { 
            $s_RT = $mp.DisableRealtimeMonitoring -eq $false 
            $s_PUA = $mp.PUAProtection -eq 1
            $s_SS = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" -Name "SmartScreenEnabled" -EA 0).SmartScreenEnabled -in @("RequireAdmin", "Warn")
        }
    }
    catch { Write-Log -Message "[Discovery] Defender check: $_" -Level "WARN"; $s_RT = $false; $s_PUA = $false; $s_SS = $false }
    
    try {
        $profiles = Get-NetFirewallProfile
        $allEnabled = $true
        foreach ($fwProfile in $profiles) { if (-not $fwProfile.Enabled) { $allEnabled = $false } }
        $s_FW = $allEnabled
    } catch { Write-Log -Message "[Discovery] Firewall check: $_" -Level "WARN"; $s_FW = $false }
    
    $edgeVal = (Get-ItemProperty "HKCU:\Software\Microsoft\Edge\SmartScreenPuaEnabled" -ErrorAction SilentlyContinue)."(default)"
    $s_Edge = if ($edgeVal -eq 1) { $true } else { "GreyOut" }
    $s_Mem = Test-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" "Enabled" 1
    $s_Kern = Test-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\KernelShadowStacks" "Enabled" 1
    $s_LSA = Test-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" "RunAsPPL" 1
    $s_Task = Test-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" "SearchboxTaskbarMode" 3
    $s_View = Test-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowTaskViewButton" 0
    $s_MU = Test-Reg "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" "AllowMUUpdateService" 1
    $s_GetMe = Test-Reg "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" "IsExpedited" 1

    $s_Rest = Test-Reg "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" "RestartNotificationsAllowed2" 1
    $s_Pers = Test-Reg "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Winlogon" "RestartApps" 1

    # Extra configs status check
    $s_PSTrans = Test-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\Transcription" "EnableTranscripting" 1
    $s_Telemetry = Test-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" "AllowTelemetry" 0
    $s_LLMNR = Test-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient" "EnableMulticast" 0
    $s_PSScript = Test-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging" "EnableScriptBlockLogging" 1
    $s_PSModule = Test-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging" "EnableModuleLogging" 1
    $s_NetBIOS = $(try {
        $adapters = @(Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration -ErrorAction SilentlyContinue | Where-Object { $_.IPEnabled })
        $disabledCount = 0
        foreach ($adapter in $adapters) {
            $regPath = "HKLM:\System\CurrentControlSet\Services\NetBT\Parameters\Interfaces\Tcpip_$($adapter.SettingID)"
            $regVal = (Get-ItemProperty -Path $regPath -Name NetbiosOptions -ErrorAction SilentlyContinue).NetbiosOptions
            if ($regVal -eq 2 -or $adapter.TcpipNetbiosOptions -eq 2) { $disabledCount++ }
        }
        $adapters.Count -gt 0 -and $disabledCount -eq $adapters.Count
    } catch { Write-Log -Message "[Discovery] NetBIOS check: $_" -Level "WARN"; $false })
    $s_ShowExt = Test-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "HideFileExt" 0
    $s_ShowHidden = Test-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "Hidden" 1

    # Classic Context Menu Check
    $ctxPath = "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32"
    $s_Ctx = $false
    if (Test-Path $ctxPath) {
        $val = (Get-ItemProperty $ctxPath)."(default)"
        if ($val -eq "") { $s_Ctx = $true }
    }

    # Sectional Pending State Detection
    $configActive = if ($false -eq $s_RT -or $false -eq $s_PUA -or $false -eq $s_Edge -or $false -eq $s_FW -or $false -eq $s_Ctx -or $false -eq $s_Task -or $false -eq $s_View -or $false -eq $s_MU -or $false -eq $s_Rest -or $false -eq $s_Pers -or $false -eq $s_Mem -or $false -eq $s_Kern -or $false -eq $s_LSA -or $false -eq $s_SS -or $false -eq $s_PSTrans -or $false -eq $s_Telemetry -or $false -eq $s_LLMNR -or $false -eq $s_PSScript -or $false -eq $s_PSModule -or $false -eq $s_NetBIOS -or $false -eq $s_ShowExt -or $false -eq $s_ShowHidden) { $true } else { $false }

    
    $maintActive = $false
    if ($Global:Toggle_MaintainForced -eq 1 -or $Global:Toggle_MaintUpdate -eq 1 -or $Global:Toggle_MaintDisk -eq 1 -or $Global:Toggle_MaintCleanup -eq 1 -or $Global:Toggle_MaintSFC -eq 1) {
        $maintActive = $true
    } else {
        $mKeys = "Maintenance_WinUpdate", "Maintenance_Disk", "Maintenance_Cleanup", "Maintenance_SFC"
        foreach ($k in $mKeys) {
            $lr = Get-WinAutoLastRun -Module $k
            if ($lr -eq "Never") { $maintActive = $true; break }
            try {
                $th = 7; if ($k -eq "Maintenance_WinUpdate") { $th = 1 } elseif ($k -eq "Maintenance_SFC") { $th = 30 }
                if (((Get-Date) - (Get-Date $lr)).Days -gt $th) { $maintActive = $true; break }
            } catch {}
        }
    }

    $manualHeaderColor = if ($Global:MenuSelection -eq 0) { $FGDarkGray } else { $FGDarkYellow }

    $Global:DashboardBufferMode = $true
    $Global:DashboardBuffer = @()

    if ($Global:WinAutoFirstLoad) {
        Start-Sleep -Seconds 2
        Clear-Host
    } else {
        [Console]::SetCursorPosition(0,0)
    }
     Add-DashLine ""
    Write-Centered "${Global:FGBlack}${Global:BGWhite}= ATOMIC SCRIPTS =${Reset}" -Width 52
    Write-Centered "${Global:FGWhite}- WinAuto -${Reset}" -Width 52
    if ($Global:MenuSelection -eq 0) {
        Write-Boundary -Color $FGYellow
    } else {
        Write-Boundary -Color $FGWhite
    }

    if ($Global:MenuSelection -eq 0) {
        # Align with 52-char block (2 space indent + 52 char block)
        Add-DashLine "  $(' ' * 18)${FGYellow}->${Reset}${FGBlack}${BGYellow}| SmartRun |${Reset}${FGYellow}<-${Reset}$(' ' * 18)"
    }
    else {
        Add-DashLine (" " * 21 + "${FGDarkGray}| SmartRun |${Reset}")
    }
    
    Write-Boundary -Color $FGYellow
    
    # MANUAL-MODE Section
    if ($Global:MenuSelection -eq 1) {
        # Align with 52-char block (2 space indent + 52 char block)
        Add-DashLine "  $(' ' * 17)${FGYellow}->${Reset}${FGBlack}${BGYellow}| ManualMode |${Reset}${FGYellow}<-${Reset}$(' ' * 17)"
    } elseif ($Global:MenuSelection -gt 1) {
        Add-DashLine "  $(' ' * 18)${FGBlack}${BGYellow}| ManualMode |${Reset}$(' ' * 20)"
    }
    else {
        Add-DashLine (" " * 20 + "${manualHeaderColor}| ManualMode |${Reset}")
    }

    if ($Global:ManualModeExpanded) {
        $cHeaderColor = if ($Global:MenuSelection -ge 1 -or ($Global:MenuSelection -eq 0 -and $configActive)) { $FGWhite } else { $FGDarkGray }
        Write-Boundary -Color $manualHeaderColor
    
    if ($Global:MenuSelection -eq 2) {
        Add-DashLine (" " * 19 + "${FGYellow}> ${Global:Italic}Configure OS${Reset}")
    } elseif ($Global:MenuSelection -ge 3 -and $Global:MenuSelection -le 25) {
        Add-DashLine (" " * 19 + "${FGYellow}v ${FGBlack}${BGDarkYellow}${Global:Italic}Configure OS${Reset}")
    } else {
        Add-DashLine (" " * 20 + "${cHeaderColor}${Global:Italic}Configure OS${Reset}")
    }
    Add-DashLine ""
    
    $isNavConfig = ($Global:MenuSelection -ge 2 -and $Global:MenuSelection -le 23)
    $cTopColor = if ($Global:MenuSelection -ge 1 -or ($Global:MenuSelection -eq 0 -and $configActive)) { $FGWhite } else { $FGDarkGray }
    $cLabelColor = if ($isNavConfig -or ($Global:MenuSelection -eq 0 -and $configActive)) { $FGWhite } else { $FGDarkGray }
    
    Write-LeftAligned "${FGDarkGray}[${FGDarkGray}v${FGDarkGray}] ${cLabelColor}Enabled ${FGDarkGray}[ ] ${cLabelColor}Disabled ${FGDarkGray}|${cLabelColor} Atomic Script$Reset" -Indent 3
    Add-DashLine ("  ${FGDarkGray}$('-' * 52)${Reset}")
    
    $Global:cDetailColorGlobal = if ($isNavConfig) { $FGGray } else { $FGDarkGray }
    
    # --- AUTOMATION SUBSECTION ---
    Write-Centered "${Italic}Automation${Reset}" -Width 52 -Color $cLabelColor

    Write-ColItem "Get Me Up To Date" "SET_GetMeUpToDate" $s_GetMe -IsToggle -ToggleValue $Global:Toggle_GetMeUpToDate -IsSelected ($Global:MenuSelection -eq 4)
    Write-ColItem "Microsoft Update" "SET_MicrosoftUpd" $s_MU -IsToggle -ToggleValue $Global:Toggle_MicrosoftUpd -IsSelected ($Global:MenuSelection -eq 5)
    Write-ColItem "Restart Notification" "SET_RestartIsReq" $s_Rest -IsToggle -ToggleValue $Global:Toggle_RestartIsReq -IsSelected ($Global:MenuSelection -eq 6)
    Write-ColItem "App Restart Persist" "SET_RestartApps" $s_Pers -IsToggle -ToggleValue $Global:Toggle_RestartApps -IsSelected ($Global:MenuSelection -eq 7)
    Add-DashLine ("  ${FGDarkGray}$('-' * 52)${Reset}")

    # --- SECURITY SUBSECTION ---
    Write-Centered "${Italic}Security${Reset}" -Width 52 -Color $cLabelColor
    Write-ColItem "PS Transcription" "SET_PSTranscription" $s_PSTrans -IsToggle -ToggleValue $Global:Toggle_PSTranscription -IsSelected ($Global:MenuSelection -eq 8)
    Write-ColItem "Windows Telemetry" "SET_Telemetry" $s_Telemetry -IsToggle -ToggleValue $Global:Toggle_Telemetry -IsSelected ($Global:MenuSelection -eq 9)
    Write-ColItem "LLMNR Configuration" "SET_LLMNR" $s_LLMNR -IsToggle -ToggleValue $Global:Toggle_LLMNR -IsSelected ($Global:MenuSelection -eq 10)
    Write-ColItem "PS Script Block Log" "SET_PSScriptBlock" $s_PSScript -IsToggle -ToggleValue $Global:Toggle_PSScriptBlock -IsSelected ($Global:MenuSelection -eq 11)
    Write-ColItem "PS Module Logging" "SET_PSModuleLogging" $s_PSModule -IsToggle -ToggleValue $Global:Toggle_PSModuleLogging -IsSelected ($Global:MenuSelection -eq 12)
    Write-ColItem "NetBIOS over TCP/IP" "SET_NetBIOS" $s_NetBIOS -IsToggle -ToggleValue $Global:Toggle_NetBIOS -IsSelected ($Global:MenuSelection -eq 13)
    Write-ColItem "Real-Time Protection" "SET_RealTimeProt" $s_RT -IsToggle -ToggleValue $Global:Toggle_RealTimeProt -IsSelected ($Global:MenuSelection -eq 14)
    Write-ColItem "PUA Protection" "SET_PUABlockApps" $s_PUA -IsToggle -ToggleValue $Global:Toggle_PUABlockApps -IsSelected ($Global:MenuSelection -eq 15)
    Write-ColItem "PUA Edge" "SET_PUABlockDLs" $s_Edge -IsToggle -ToggleValue $Global:Toggle_PUABlockDLs -IsSelected ($Global:MenuSelection -eq 16)
    Write-ColItem "Memory Integrity" "SET_MemoryInteg" $s_Mem -IsToggle -ToggleValue $Global:Toggle_MemoryInteg -IsSelected ($Global:MenuSelection -eq 17)
    Write-ColItem "Kernel Stack" "SET_KernelMode" $s_Kern -IsToggle -ToggleValue $Global:Toggle_KernelMode -IsSelected ($Global:MenuSelection -eq 18)
    Write-ColItem "LSA Protection" "SET_LocalSecurity" $s_LSA -IsToggle -ToggleValue $Global:Toggle_LocalSecurity -IsSelected ($Global:MenuSelection -eq 19)
    Write-ColItem "Windows Firewall" "SET_FirewallON" $s_FW -IsToggle -ToggleValue $Global:Toggle_FirewallON -IsSelected ($Global:MenuSelection -eq 20)
    Add-DashLine ("  ${FGDarkGray}$('-' * 52)${Reset}")

    # --- USER INTERFACE SUBSECTION ---
    Write-Centered "${Italic}User Interface${Reset}" -Width 52 -Color $cLabelColor
    Write-ColItem "Classic Context Menu" "SET_ClassicMenu" $s_Ctx -IsToggle -ToggleValue $Global:Toggle_ClassicMenu -IsSelected ($Global:MenuSelection -eq 21)
    Write-ColItem "Taskbar Search Box" "SET_TaskbarSearch" $s_Task -IsToggle -ToggleValue $Global:Toggle_TaskbarSearch -IsSelected ($Global:MenuSelection -eq 22)
    Write-ColItem "Task View Toggle" "SET_TaskViewOFF" $s_View -IsToggle -ToggleValue $Global:Toggle_TaskView -IsSelected ($Global:MenuSelection -eq 23)
    Write-ColItem "Show Hidden Files" "SET_ShowHidden" $s_ShowHidden -IsToggle -ToggleValue $Global:Toggle_ShowHidden -IsSelected ($Global:MenuSelection -eq 24)
    Write-ColItem "Show File Extensions" "SET_ShowExtensions" $s_ShowExt -IsToggle -ToggleValue $Global:Toggle_ShowExtensions -IsSelected ($Global:MenuSelection -eq 25)
    Add-DashLine ""
    
    # Maintenance sub-section (inline under MANUAL-MODE)
    Add-DashLine "  ${manualHeaderColor}$('_' * 52)${Reset}"
    $mHeaderColor = if ($Global:MenuSelection -ge 1 -or ($Global:MenuSelection -eq 0 -and $maintActive)) { $FGWhite } else { $FGDarkGray }
    if ($Global:MenuSelection -eq 26) {
        Add-DashLine (" " * 19 + "${FGYellow}> ${Global:Italic}Maintain OS${Reset}")
    } elseif ($Global:MenuSelection -ge 27 -and $Global:MenuSelection -le 30) {
        Add-DashLine (" " * 19 + "${FGYellow}v ${FGBlack}${BGDarkYellow}${Global:Italic}Maintain OS${Reset}")
    } else {
        Add-DashLine (" " * 20 + "${mHeaderColor}${Global:Italic}Maintain OS${Reset}")
    }
    Add-DashLine ""
    
    # Maintenance Details
    $Global:mDetailColorGlobal = if ($Global:MenuSelection -ge 1) { $FGGray } else { $FGDarkGray }
    
    $mTopColor = if ($Global:MenuSelection -ge 1 -or ($Global:MenuSelection -eq 0 -and $maintActive)) { $FGWhite } else { $FGDarkGray }
    $mLabelColor = if ($Global:MenuSelection -ge 1 -or ($Global:MenuSelection -eq 0 -and $maintActive)) { $FGWhite } else { $FGDarkGray }
    Write-LeftAligned "${FGDarkGray}[${mTopColor}#${FGDarkGray}]${mLabelColor} Days Since Last Ran  ${FGDarkGray}|${mLabelColor} Atomic Script$Reset" -Indent 3
    Add-DashLine ("  ${FGDarkGray}$('-' * 52)${Reset}")
    Write-MaintItem "Get Updates" "RUN_UpdateSuite" "Maintenance_WinUpdate" -Threshold 1 -ToggleValue $Global:Toggle_MaintUpdate -IsSelected ($Global:MenuSelection -eq 27)
    Write-MaintItem "Drive Optimization" "RUN_OptimizeDisks" "Maintenance_Disk" -Threshold 7 -ToggleValue $Global:Toggle_MaintDisk -IsSelected ($Global:MenuSelection -eq 28)
    Write-MaintItem "Temp File Cleanup" "RUN_SystemCleanup" "Maintenance_Cleanup" -Threshold 7 -ToggleValue $Global:Toggle_MaintCleanup -IsSelected ($Global:MenuSelection -eq 29)
    Write-MaintItem "SFC / DISM Repair" "RUN_WindowsRepair" "Maintenance_SFC" -Threshold 30 -ToggleValue $Global:Toggle_MaintSFC -IsSelected ($Global:MenuSelection -eq 30)
    Add-DashLine ""
}

    Write-Footer

    if ($Global:DashboardBufferMode) {
        Write-Host ($Global:DashboardBuffer -join "`n") -NoNewline
        $Global:DashboardBufferMode = $false
    }

    $PromptRow = [Console]::CursorTop
    
    # Dynamic Footer Prompt Logic (Standard View Only now)
    $Act = "DASHBOARD"
    $Sel = $null
    $Pre = ""

    # Timeout logic: Only on first load
    $TimeoutSecs = 0
    if ($Global:WinAutoFirstLoad) {
        $TimeoutSecs = 5
        $Global:WinAutoFirstLoad = $false
    }

    $res = Invoke-AnimatedPause -ActionText $Act -Timeout $TimeoutSecs -SelectionChar $Sel -PreActionWord $Pre -OverrideCursorTop $PromptRow

    # --- NAVIGATION LOGIC ---
    if ($res.VirtualKeyCode -eq 38) {
        # Up
        $current = $Global:MenuSelection
        if ($current -eq 0) {
            $Global:MenuSelection = if ($Global:ManualModeExpanded) { 30 } else { 1 }
        }
        elseif ($current -eq 1) {
            $Global:MenuSelection = 0
        }
        elseif ($current -eq 2) {
            $Global:MenuSelection = 1
        }
        elseif ($current -eq 4) {
            $Global:MenuSelection = 2
        }
        elseif ($current -ge 5 -and $current -le 25) {
            $Global:MenuSelection = $current - 1
        }
        elseif ($current -eq 26) {
            $Global:MenuSelection = 2
        }
        elseif ($current -eq 27) {
            $Global:MenuSelection = 26
        }
        elseif ($current -ge 28 -and $current -le 30) {
            $Global:MenuSelection = $current - 1
        }
        continue
    }
    elseif ($res.VirtualKeyCode -eq 40) {
        # Down
        $current = $Global:MenuSelection
        if ($current -eq 0) {
            $Global:MenuSelection = 1
        }
        elseif ($current -eq 1) {
            $Global:MenuSelection = if ($Global:ManualModeExpanded) { 2 } else { 0 }
        }
        elseif ($current -eq 2) {
            $Global:MenuSelection = 26
        }
        elseif ($current -ge 3 -and $current -le 24) {
            $Global:MenuSelection = $current + 1
        }
        elseif ($current -eq 25) {
            $Global:MenuSelection = 26
        }
        elseif ($current -eq 26) {
            $Global:MenuSelection = 0
        }
        elseif ($current -ge 27 -and $current -le 29) {
            $Global:MenuSelection = $current + 1
        }
        elseif ($current -eq 30) {
            $Global:MenuSelection = 0
        }
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
        if ($Global:MenuSelection -ge 3 -and $Global:MenuSelection -le 25) {
            $Global:MenuSelection = 2
            continue
        }
        elseif ($Global:MenuSelection -ge 27 -and $Global:MenuSelection -le 30) {
            $Global:MenuSelection = 26
            continue
        }
        elseif ($Global:MenuSelection -eq 2 -or $Global:MenuSelection -eq 26) {
            $Global:MenuSelection = 1
            continue
        }
        
        # Esc or X -> Exit
        Write-Host ""
        Write-LeftAligned "$FGGray Exiting..$Reset"
        Start-Sleep -Seconds 1
        break
    }
    elseif ($res.VirtualKeyCode -eq 13) {
        # Enter Action Logic (Runs SmartRun or ManualMode)
        $Target = $Global:MenuSelection
        if ($Target -eq 0) {
            # [S]mart Run -> EXECUTE
            Invoke-WinAutoConfiguration -SmartRun
            Set-WinAutoLastRun -Module "Configuration"
            if (-not $Global:MaintenanceComplete) { Invoke-WinAutoMaintenance -SmartRun }
            Start-Sleep -Milliseconds 200
        }
        elseif ($Target -ge 1) {
            # MANUAL-MODE -> Run Configure + Maintain, all steps forced (no SmartRun)
            Invoke-WinAutoConfiguration
            Set-WinAutoLastRun -Module "Configuration"
            Invoke-WinAutoMaintenance
            Start-Sleep -Milliseconds 200
        }
        
        # Post-Execution Audit (Generate JSON)
        $AuditData = [PSCustomObject]@{
            Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            Session   = "Interactive"
            Config    = @{ 
                MicrosoftUpdate = $Global:Toggle_MicrosoftUpd;
                RestartNotifications = $Global:Toggle_RestartIsReq;
                AppRestartPersist = $Global:Toggle_RestartApps;
                PSTranscription = $Global:Toggle_PSTranscription;
                Telemetry = $Global:Toggle_Telemetry;
                LLMNR = $Global:Toggle_LLMNR;
                PSScriptBlock = $Global:Toggle_PSScriptBlock;
                PSModuleLogging = $Global:Toggle_PSModuleLogging;
                NetBIOS = $Global:Toggle_NetBIOS;
                RealTimeProt = $Global:Toggle_RealTimeProt;
                PUABlockApps = $Global:Toggle_PUABlockApps;
                PUABlockDLs = $Global:Toggle_PUABlockDLs;
                MemoryInteg = $Global:Toggle_MemoryInteg;
                KernelMode = $Global:Toggle_KernelMode;
                LocalSecurity = $Global:Toggle_LocalSecurity;
                FirewallON = $Global:Toggle_FirewallON;
                ClassicMenu = $Global:Toggle_ClassicMenu; 
                TaskbarSearch = $Global:Toggle_TaskbarSearch; 
                TaskView = $Global:Toggle_TaskView; 
                ShowExtensions = $Global:Toggle_ShowExtensions;
                ShowHidden = $Global:Toggle_ShowHidden
            }
            Maint     = @{ Update = $Global:Toggle_MaintUpdate; Disk = $Global:Toggle_MaintDisk; Cleanup = $Global:Toggle_MaintCleanup; SFC = $Global:Toggle_MaintSFC }
        }
        $AuditData | ConvertTo-Json | Out-File "$Global:WinAutoLogDir\PostRunAudit.json"
        
        continue
    }
    elseif ($res.Character -eq ' ' -or $res.VirtualKeyCode -eq 32) {
        # Space Action Logic (Only Toggle options)
        $Target = $Global:MenuSelection
        
        if ($Target -eq 1) {
            $Global:ManualModeExpanded = -not $Global:ManualModeExpanded
        }
        elseif ($Target -eq 2) {
            $Global:MenuSelection = 4
        }

        elseif ($Target -eq 4) {
            $Global:Toggle_GetMeUpToDate = if ($Global:Toggle_GetMeUpToDate -eq 1) { 0 } else { 1 }
        }
        elseif ($Target -eq 5) {
            $Global:Toggle_MicrosoftUpd = if ($Global:Toggle_MicrosoftUpd -eq 1) { 0 } else { 1 }
        }
        elseif ($Target -eq 6) {
            $Global:Toggle_RestartIsReq = if ($Global:Toggle_RestartIsReq -eq 1) { 0 } else { 1 }
        }
        elseif ($Target -eq 7) {
            $Global:Toggle_RestartApps = if ($Global:Toggle_RestartApps -eq 1) { 0 } else { 1 }
        }
        elseif ($Target -eq 8) {
            $Global:Toggle_PSTranscription = if ($Global:Toggle_PSTranscription -eq 1) { 0 } else { 1 }
        }
        elseif ($Target -eq 9) {
            $Global:Toggle_Telemetry = if ($Global:Toggle_Telemetry -eq 1) { 0 } else { 1 }
        }
        elseif ($Target -eq 10) {
            $Global:Toggle_LLMNR = if ($Global:Toggle_LLMNR -eq 1) { 0 } else { 1 }
        }
        elseif ($Target -eq 11) {
            $Global:Toggle_PSScriptBlock = if ($Global:Toggle_PSScriptBlock -eq 1) { 0 } else { 1 }
        }
        elseif ($Target -eq 12) {
            $Global:Toggle_PSModuleLogging = if ($Global:Toggle_PSModuleLogging -eq 1) { 0 } else { 1 }
        }
        elseif ($Target -eq 13) {
            $Global:Toggle_NetBIOS = if ($Global:Toggle_NetBIOS -eq 1) { 0 } else { 1 }
        }
        elseif ($Target -eq 14) {
            $Global:Toggle_RealTimeProt = if ($Global:Toggle_RealTimeProt -eq 1) { 0 } else { 1 }
        }
        elseif ($Target -eq 15) {
            $Global:Toggle_PUABlockApps = if ($Global:Toggle_PUABlockApps -eq 1) { 0 } else { 1 }
        }
        elseif ($Target -eq 16) {
            $Global:Toggle_PUABlockDLs = if ($Global:Toggle_PUABlockDLs -eq 1) { 0 } else { 1 }
        }
        elseif ($Target -eq 17) {
            $Global:Toggle_MemoryInteg = if ($Global:Toggle_MemoryInteg -eq 1) { 0 } else { 1 }
        }
        elseif ($Target -eq 18) {
            $Global:Toggle_KernelMode = if ($Global:Toggle_KernelMode -eq 1) { 0 } else { 1 }
        }
        elseif ($Target -eq 19) {
            $Global:Toggle_LocalSecurity = if ($Global:Toggle_LocalSecurity -eq 1) { 0 } else { 1 }
        }
        elseif ($Target -eq 20) {
            $Global:Toggle_FirewallON = if ($Global:Toggle_FirewallON -eq 1) { 0 } else { 1 }
        }
        elseif ($Target -eq 21) {
            $Global:Toggle_ClassicMenu = if ($Global:Toggle_ClassicMenu -eq 1) { 0 } else { 1 }
        }
        elseif ($Target -eq 22) {
            $Global:Toggle_TaskbarSearch = if ($Global:Toggle_TaskbarSearch -eq 1) { 0 } else { 1 }
        }
        elseif ($Target -eq 23) {
            $Global:Toggle_TaskView = if ($Global:Toggle_TaskView -eq 1) { 0 } else { 1 }
        }
        elseif ($Target -eq 24) {
            $Global:Toggle_ShowHidden = if ($Global:Toggle_ShowHidden -eq 1) { 0 } else { 1 }
        }
        elseif ($Target -eq 25) {
            $Global:Toggle_ShowExtensions = if ($Global:Toggle_ShowExtensions -eq 1) { 0 } else { 1 }
        }
        elseif ($Target -eq 26) {
            $Global:MenuSelection = 27
        }
        elseif ($Target -eq 27) {
            $Global:Toggle_MaintUpdate = if ($Global:Toggle_MaintUpdate -eq 1) { 0 } else { 1 }
        }
        elseif ($Target -eq 28) {
            $Global:Toggle_MaintDisk = if ($Global:Toggle_MaintDisk -eq 1) { 0 } else { 1 }
        }
        elseif ($Target -eq 29) {
            $Global:Toggle_MaintCleanup = if ($Global:Toggle_MaintCleanup -eq 1) { 0 } else { 1 }
        }
        elseif ($Target -eq 30) {
            $Global:Toggle_MaintSFC = if ($Global:Toggle_MaintSFC -eq 1) { 0 } else { 1 }
        }
        
        # Pause slightly if we toggled
        Start-Sleep -Milliseconds 200
        continue
    }
    else {
        # Any other key loop back
        Start-Sleep -Milliseconds 100
        continue
    }
}

Write-Log "Interactive Execution Complete."
function Invoke-WA_SetGetMeUpToDate {
    param([switch]$Reverse)
    Write-Header "GET ME UP TO DATE"
    $Path = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings"
    try {
        if ($Reverse) {
            Set-ItemProperty -Path $Path -Name "IsExpedited" -Value 0 -Type DWord -Force
            Write-LeftAligned "$FGGreen$Char_HeavyCheck Disabled Get Me Up To Date.$Reset"
        } else {
            Set-ItemProperty -Path $Path -Name "IsExpedited" -Value 1 -Type DWord -Force
            Write-LeftAligned "$FGGreen$Char_HeavyCheck Enabled Get Me Up To Date.$Reset"
        }
    } catch {
        Write-WrappedError $_
    }
}


