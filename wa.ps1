<#
.SYNOPSIS
    AtomicScripts (Core Edition)
.DESCRIPTION
    A lightweight, single-file version of the AtomicScripts suite for Windows 11.
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
$Global:Toggle_GetMeUpToDate = 0

$Global:Toggle_RestartIsReq = 1
$Global:Toggle_RestartApps = 1
$Global:Toggle_PSTranscription = 0
$Global:Toggle_Telemetry = 0
$Global:Toggle_LLMNR = 0
$Global:Toggle_PSScriptBlock = 0
$Global:Toggle_PSModuleLogging = 0
$Global:Toggle_NetBIOS = 0
$Global:Toggle_RealTimeProt = 1
$Global:Toggle_RealTimeProtUI = 0
$Global:Toggle_PUABlockApps = 1
$Global:Toggle_PUABlockDLs = 1
$Global:Toggle_MemoryInteg = 1
$Global:Toggle_KernelMode = 1
$Global:Toggle_LocalSecurity = 1
$Global:Toggle_FirewallON = 1

# Extended hardening (security_audit.json parity)
$Global:Toggle_StoreSmartScreen = 1
$Global:Toggle_PhishingProtection = 1
$Global:Toggle_HideAdmin = 0
$Global:Toggle_AdvertisingID = 0
$Global:Toggle_MeteredUpdates = 0
$Global:Toggle_ARSOOptOut = 0
$Global:Toggle_UIAnimations = 0
$Global:Toggle_VisualEffects = 0

# Background-only fallbacks
$Global:Toggle_SmartScreenReg = 0
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
    $Global:WinAutoLogDir = Join-Path $env:USERPROFILE "logs"
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

# Script Palette (Foreground) — the 5 documented semantic colors, plus Red
# (failure/error text) and Dark Red/Dark Yellow (footer NAVIGATION keys only).
$Global:FGCyan = "$Esc[96m"
$Global:FGRed = "$Esc[91m"
$Global:FGDarkGray = "$Esc[90m"
$Global:FGDarkRed = "$Esc[31m"
$Global:FGWhite = "$Esc[97m"
$Global:FGGray = "$Esc[37m"
$Global:FGBlack = "$Esc[30m"
$Global:FGDarkYellow = "$Esc[33m"

# Script Palette (Background) — BGCyan pairs with FGBlack for "Inverted Cyan";
# BGDarkYellow/BGGray are reserved for the footer NAVIGATION keys and the
# "= ATOMIC SCRIPTS =" banner. BGDarkGreen/BGDarkGray belong to Write-FlexLine
# (currently unused by any caller).
$Global:BGDarkGreen = "$Esc[42m"
$Global:BGDarkGray = "$Esc[100m"
$Global:BGCyan = "$Esc[106m"
$Global:BGGray = "$Esc[47m"
$Global:BGDarkYellow = "$Esc[43m"

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
        # ── SECURITY: Remote Audit Script ──────────────────────────────────────
        # Pin the SHA-256 hash of the known-good Audit-System.ps1 below.
        # To find the hash, run once with no value — the actual hash is printed.
        # The remote script will NOT execute until a valid hash is set here.
        # Update this value whenever the remote script is intentionally updated.
        $KnownAuditScriptHash = "" # e.g. "a3f1c2...64 hex chars"
        # ───────────────────────────────────────────────────────────────────────
        try {
            Write-Host ""
            Write-LeftAligned "${Global:FGCyan}Running Automated System Audit Scanner...${Global:Reset}" -Indent 2
            $prevSecProto = [System.Net.ServicePointManager]::SecurityProtocol
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

            # Download script content (no ExecutionPolicy bypass needed for Invoke-RestMethod)
            $auditUri = "https://www.aiit.support/progress/posture/Audit-System.ps1"
            $auditStr = Invoke-RestMethod $auditUri -ErrorAction Stop

            # Compute SHA-256 of the downloaded content
            $auditBytes = [System.Text.Encoding]::UTF8.GetBytes($auditStr)
            $sha256     = [System.Security.Cryptography.SHA256]::Create()
            $actualHash = ([System.BitConverter]::ToString($sha256.ComputeHash($auditBytes))).Replace("-","").ToLower()
            $sha256.Dispose()

            [System.Net.ServicePointManager]::SecurityProtocol = $prevSecProto

            if ([string]::IsNullOrWhiteSpace($KnownAuditScriptHash)) {
                # Safe default: no hash pinned — download but do NOT execute
                Write-LeftAligned "${Global:FGCyan}[!] Audit script downloaded but NOT executed (no hash pinned).${Global:Reset}" -Indent 2
                Write-LeftAligned "${Global:FGCyan}[!] Actual SHA-256: $actualHash${Global:Reset}" -Indent 2
                Write-LeftAligned "${Global:FGCyan}[!] Set `$KnownAuditScriptHash = '$actualHash' in wa.ps1 to enable.${Global:Reset}" -Indent 2
                Write-Log "Remote audit blocked: no hash pinned. Actual=$actualHash" -Level "WARN"
                $quarantine = Join-Path $env:TEMP "WinAuto_AuditScript_UNVERIFIED.ps1"
                $auditStr | Out-File -FilePath $quarantine -Encoding utf8 -Force
                Write-LeftAligned "${Global:FGCyan}[!] Script saved for inspection: $quarantine (NOT executed)${Global:Reset}" -Indent 2

            } elseif ($actualHash -ne $KnownAuditScriptHash.ToLower().Replace("-","")) {
                # Hash mismatch — possible tampering; block and quarantine
                Write-LeftAligned "${Global:FGRed}[!] AUDIT SCRIPT HASH MISMATCH — Execution blocked.${Global:Reset}" -Indent 2
                Write-LeftAligned "${Global:FGRed}[!] Expected : $KnownAuditScriptHash${Global:Reset}" -Indent 2
                Write-LeftAligned "${Global:FGRed}[!] Actual   : $actualHash${Global:Reset}" -Indent 2
                Write-Log "Remote audit BLOCKED: hash mismatch. Expected=$KnownAuditScriptHash Actual=$actualHash" -Level "ERROR"
                $quarantine = Join-Path $env:TEMP "WinAuto_AuditScript_QUARANTINE.ps1"
                $auditStr | Out-File -FilePath $quarantine -Encoding utf8 -Force
                Write-LeftAligned "${Global:FGRed}[!] Quarantined to: $quarantine — review before trusting.${Global:Reset}" -Indent 2

            } else {
                # Hash verified — safe to execute
                Write-LeftAligned "${Global:FGCyan}[v] Audit script hash verified.${Global:Reset}" -Indent 2

                # Strip console-output section before execution
                $idx = $auditStr.IndexOf("# Output guidance to console")
                if ($idx -gt 0) { $auditStr = $auditStr.Substring(0, $idx) }
                $auditStr = $auditStr -replace 'posture_audit\.json', 'winauto_audit.json'

                # Execute verified script (suppress output)
                $null = Invoke-Expression $auditStr

                # Mirror to Desktop for Life_Organizer.html compatibility
                $desktop = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::Desktop)
                if (-not $desktop) { $desktop = Join-Path $env:USERPROFILE "Desktop" }
                $secAuditPath     = Join-Path $desktop "security_audit.json"
                $postureAuditPath = Join-Path $desktop "winauto_audit.json"
                if (Test-Path $secAuditPath) {
                    Copy-Item -Path $secAuditPath -Destination $postureAuditPath -Force -ErrorAction SilentlyContinue
                }
                Write-LeftAligned "${Global:FGCyan}The audit data is copied and ready to paste.${Global:Reset}" -Indent 2
                Write-Host ""
            }
        } catch {
            Write-LeftAligned "${Global:FGRed}[-] Failed to run system audit scanner: $_${Global:Reset}" -Indent 2
            Write-Host ""
        }
        Write-Boundary -Color $Global:FGWhite
        $copyright = "© $(Get-Date -Format 'yyyy') aiit.support"
        Write-Centered $copyright -Color $Global:FGWhite
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
        [bool]$IsSelected = $false,
        [bool]$IsDisableAction = $false
    )

    if ($IsToggle) {
        $iconSymbol = " "
        $iconColor = $Global:FGGray
        $bracketColor = $Global:FGGray
        $itemColor = $Global:FGGray

        if ($ToggleValue -eq 1) {
            # Pending Action
            if ($IsDisableAction -and $Status -eq $true) {
                # Pending DISABLE (steps whose compliant state is "feature off")
                $iconSymbol = "x"
                $iconColor = $Global:FGRed
                $bracketColor = $Global:FGGray
            } else {
                # Pending ENABLE
                $iconSymbol = "v"
                $iconColor = $Global:FGCyan
                $bracketColor = $Global:FGWhite
            }
            $itemColor = $Global:FGWhite
        } else {
            # Discovery State (No Toggle)
            if ($Status -eq $true) {
                # Already Enabled / Compliant
                $iconSymbol = "v"
                $iconColor = $Global:FGGray
                $bracketColor = $Global:FGGray
                $itemColor = $Global:FGWhite
            } else {
                # Disabled
                $iconSymbol = " "
                $iconColor = $Global:FGGray
                $bracketColor = $Global:FGGray
                $itemColor = $Global:FGGray
            }
        }

        if ($IsSelected) {
            $itemColor = "${Global:FGBlack}${Global:BGCyan}"
        }

        $icon = "${bracketColor}[${iconColor}${iconSymbol}${bracketColor}]${Reset}"
        $metColor = if ($ToggleValue -eq 1) { $Global:FGCyan } else { $Global:FGDarkGray }
        if ($IsSelected) { $metColor = "${Global:FGBlack}${Global:BGCyan}" }

        $pad = " " * (21 - $Txt.Length)
        $leftCursor = ""
        $indentSize = 2
        $rightCursor = ""
        Write-LeftAligned "$leftCursor$icon ${itemColor}$Txt${Reset}$pad${Global:FGGray}| ${metColor}$Met${Reset}$rightCursor" -Indent $indentSize  
        return
    }

    # Non-toggle items (Execution blocks)
    $itemColor = if ($IsSelected) { "${Global:FGBlack}${Global:BGCyan}" } else { $Global:FGGray }
    $icon = "${Global:FGGray}[ ]${Reset}"
    $pad = " " * (21 - $Txt.Length)
    $leftCursor = ""
    $rightCursor = ""
    Write-LeftAligned "$leftCursor$icon ${itemColor}$Txt${Reset}$pad${Global:FGGray}| ${itemColor}$Met${Reset}$rightCursor" -Indent 2
}

function Write-MaintItem {
    param($Txt, $Met, $Key, [int]$Threshold = 7, [int]$ToggleValue = 0, [bool]$IsSelected = $false, [switch]$AlwaysRun)

    $isPendingRun = $false
    $prefix = "-"
    if ($AlwaysRun) {
        $isPendingRun = $true
        $prefix = "v"
    }
    elseif ($Key) {
        $last = Get-WinAutoLastRun -Module $Key
        if ($last -eq "Never") { $isPendingRun = $true; $prefix = "!" }
        else {
            try {
                $days = ((Get-Date) - (Get-Date $last)).Days
                $prefix = $days
                if ($days -gt $Threshold) { $isPendingRun = $true }
            } catch { $isPendingRun = $true; $prefix = "!" }
        }
    }

    if ($Global:Toggle_MaintainForced -eq 1 -or $ToggleValue -eq 1) {
        $prefix = "v"
        $isPendingRun = $true
    }

    # Colors
    $bracketColor = $Global:FGGray
    $statusColor = $Global:FGGray
    $itemColor = $Global:FGGray
    $metColor = $Global:FGDarkGray

    if ($isPendingRun) {
        $statusColor = if ($prefix -eq "!" -or $prefix -eq "v") { $Global:FGCyan } else { $Global:FGWhite }
        if ($prefix -eq "v") { $bracketColor = $Global:FGWhite }
        $itemColor = $Global:FGWhite
        $metColor = $Global:FGCyan
    }

    if ($IsSelected) {
        $itemColor = "${Global:FGBlack}${Global:BGCyan}"
        $metColor = "${Global:FGBlack}${Global:BGCyan}"
    }

    $pad = " " * (21 - $Txt.Length);
    $leftCursor = ""
    $rightCursor = ""
    Write-LeftAligned "$leftCursor${bracketColor}[${statusColor}$prefix${bracketColor}]${itemColor} $Txt${Reset}$pad${Global:FGGray}| ${metColor}$Met${Reset}$rightCursor" -Indent 2
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

function Set-WinAutoForeground {
    # A newly launched Settings/Windows Security window opens INACTIVE when
    # another app (e.g. the PowerShell console running this script) holds the
    # foreground. While inactive, the page's XAML content is never rendered into
    # the UI Automation tree — only window chrome appears — so toggles are never
    # found and UIA steps silently do nothing. Forcing the window foreground
    # makes it render. (Verified: works even from a non-foreground process.)
    param([Parameter(Mandatory)]$Window)
    if (-not ([System.Management.Automation.PSTypeName]'WinAutoFG').Type) {
        Add-Type @"
using System;
using System.Runtime.InteropServices;
public class WinAutoFG {
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr hWnd, IntPtr after, int x, int y, int cx, int cy, uint flags);
}
"@
    }
    try {
        $hwnd = [IntPtr]$Window.Current.NativeWindowHandle
        if ($hwnd -ne [IntPtr]::Zero) {
            [WinAutoFG]::ShowWindow($hwnd, 9) | Out-Null               # SW_RESTORE
            [WinAutoFG]::SetWindowPos($hwnd, [IntPtr]::Zero, 0, 0, 0, 0, 0x0043) | Out-Null  # NOMOVE|NOSIZE|SHOWWINDOW
            [WinAutoFG]::SetForegroundWindow($hwnd) | Out-Null
        }
    }
    catch {}
    Start-Sleep -Seconds 2
}

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
    param([string]$Color = $Global:FGCyan)
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
    try { Clear-Host } catch {}
    Write-Host ""
    $WinAutoTitle = "AtomicScripts"
    Write-Centered "$Bold$FGCyan$WinAutoTitle$Reset" -Width 52
    Write-Centered "${Global:FGCyan}$($Title.ToUpper())$Reset" -Width 52
    if (-not $NoBottom) {
        Write-Boundary
    }
}

function Write-Footer {
    if ($Global:MenuSelection -eq 0) {
        $enterText = "Press ${Global:FGBlack}${Global:BGDarkYellow}Enter${Global:Reset} Key for ${Global:FGDarkYellow}|SmartRun|${Global:Reset}"
        $escText = "    ${Global:FGBlack}${Global:BGDarkYellow}Esc${Global:Reset} to ${Global:BGGray}${Global:FGDarkRed}<EXIT>${Global:Reset}"
        $suffixText = "${Global:FGDarkYellow}Toggle${Global:Reset} with ${Global:FGBlack}${Global:BGDarkYellow}Spacebar${Global:Reset}"
    } elseif ($Global:MenuSelection -eq 1) {
        $enterText = "Press ${Global:FGBlack}${Global:BGDarkYellow}Enter${Global:Reset} Key to ${Global:FGDarkYellow}|ManualMode|${Global:Reset}"
        $escText = "    ${Global:FGBlack}${Global:BGDarkYellow}Esc${Global:Reset} to go Back"
        $suffixText = "${Global:FGDarkYellow}Toggle${Global:Reset} with ${Global:FGBlack}${Global:BGDarkYellow}Spacebar${Global:Reset}"
    } else {
        $enterText = "Press ${Global:FGBlack}${Global:BGDarkYellow}Enter${Global:Reset} Key to ${Global:FGDarkYellow}|ManualMode|${Global:Reset}"
        $escText = "    ${Global:FGBlack}${Global:BGDarkYellow}Esc${Global:Reset} to go Back"
        $suffixText = "${Global:FGDarkYellow}Toggle${Global:Reset} with ${Global:FGBlack}${Global:BGDarkYellow}Spacebar${Global:Reset}"
    }

    # NAVIGATION Keys marker mirrors the active cursor depth
    if ($Global:NavLevel -eq 0)     { $navPre = '->|'; $navSuf = '|<-' }
    elseif ($Global:NavLevel -eq 1) { $navPre = '>|';  $navSuf = '|<' }
    else                            { $navPre = 'v|';  $navSuf = '|v' }

    Write-Boundary -Color $Global:FGGray
    Write-Centered "${Global:FGDarkYellow}${navPre}${Global:FGWhite}NAVIGATION ${Global:FGBlack}${Global:BGDarkYellow}Keys${Global:Reset}${Global:FGDarkYellow}${navSuf}${Global:Reset}" -Width 52
    Add-DashLine ""
    Add-DashLine "  $enterText $suffixText"
    Add-DashLine "   Use  ${Global:FGBlack}${Global:BGDarkYellow} ^ ${Global:Reset} ${Global:FGBlack}${Global:BGDarkYellow} v ${Global:Reset}  to select |$escText"
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
                Write-Boundary -Color $Global:FGCyan
                Write-Centered "$Global:FGBlack$Global:BGCyan [ SCRIPT PAUSED ] $Global:Reset" -Width 52
                Write-LeftAligned "Script execution paused. Press any key to resume..." -Indent 2
                Write-Boundary -Color $Global:FGCyan
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
.LOCATION
    none (registry/GPO-only)
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
        Write-LeftAligned "$FGCyan$Char_HeavyCheck PowerShell Transcription set to $(if($Reverse){'Disabled'}else{'Enabled'}).$Reset"
    } catch { Write-WrappedError $_.Exception.Message }
}

function Invoke-WA_SetTelemetry {
    <#
.SYNOPSIS
    Disables the "Send optional diagnostic data" toggle via the Settings app UI.
.LOCATION
    Settings > Privacy & Security > Diagnostics & feedback
.DESCRIPTION
    Drives the Settings > Privacy & Security > Diagnostics & feedback toggle
    instead of writing HKLM Policies\Microsoft\Windows\DataCollection\AllowTelemetry,
    which would lock that page as "managed by your organization." Note: the
    consumer Settings UI can only choose between Required (1) and Optional (3)
    diagnostic data — it cannot reach the stricter Security/Off (0) level the
    old registry-only approach targeted, since that level is Enterprise-policy-only.
    Includes Reverse Mode (-r).
#>
    param([switch]$Reverse)
    Write-Header "TELEMETRY LIMITATION (UIA)"

    # A prior run of the old registry-based version may have left the Policies
    # value behind, which locks the control regardless of what this does now.
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -Force -ErrorAction SilentlyContinue

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

    Write-LeftAligned "Opening Diagnostics & feedback..."
    try { Start-Process "ms-settings:privacy-feedback" -ErrorAction Stop }
    catch { Write-LeftAligned "$FGRed$Char_RedCross Failed to launch Settings.$Reset"; return }
    Start-Sleep -Seconds 2

    $timeout = 10
    $startTime = Get-Date
    $window = $null
    Write-LeftAligned "Searching for 'Settings' window..."
    do {
        $desktop = [System.Windows.Automation.AutomationElement]::RootElement
        $condition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty, "Settings")
        $window = $desktop.FindFirst([System.Windows.Automation.TreeScope]::Children, $condition)
        if ($null -ne $window) { break }
        Start-Sleep -Milliseconds 500
    } while ((Get-Date) -lt $startTime.AddSeconds($timeout))

    if (-not $window) {
        Write-LeftAligned "$FGRed$Char_RedCross Timeout waiting for Settings window.$Reset"
        return
    }
    Write-LeftAligned "$FGCyan$Char_HeavyCheck Window found.$Reset"

    # Force foreground so the page content actually renders into the UIA tree.
    Set-WinAutoForeground -Window $window

    # Match on name AND verify the element actually supports TogglePattern —
    # a heading/label Text control can also match the name search.
    $toggle = $null
    try {
        $allElements = $window.FindAll([System.Windows.Automation.TreeScope]::Descendants, [System.Windows.Automation.Condition]::TrueCondition)
        foreach ($el in $allElements) {
            if ($el.Current.Name -like "*optional diagnostic data*") {
                try {
                    $el.GetCurrentPattern([System.Windows.Automation.TogglePattern]::Pattern) | Out-Null
                    $toggle = $el
                    break
                } catch { continue }
            }
        }
    } catch {}

    if (-not $toggle) {
        Write-LeftAligned "$FGGray No optional diagnostic data toggle found (page layout may differ).$Reset"
    } else {
        $applied = $false
        try {
            $togglePattern = $toggle.GetCurrentPattern([System.Windows.Automation.TogglePattern]::Pattern)
            $current = $togglePattern.Current.ToggleState
            $targetState = if ($Reverse) { [System.Windows.Automation.ToggleState]::On } else { [System.Windows.Automation.ToggleState]::Off }
            if ($current -ne $targetState) {
                $togglePattern.Toggle()
                Write-LeftAligned "$FGCyan$Char_HeavyCheck Optional diagnostic data toggled $(if($Reverse){'ON'}else{'OFF'}).$Reset"
            } else {
                Write-LeftAligned "$FGGray Already $(if($Reverse){'ON'}else{'OFF'}).$Reset"
            }
            $applied = $true
        }
        catch {
            Write-LeftAligned "$FGCyan$Char_Warn Toggle found but could not be set: $($_.Exception.Message)$Reset"
        }
        if ($applied) {
            if ($Reverse) { Remove-ItemProperty -Path "HKLM:\SOFTWARE\WinAuto" -Name "LastRun_Telemetry" -Force -ErrorAction SilentlyContinue }
            else { Set-WinAutoLastRun -Module "Telemetry" }
        }
    }

    try {
        $windowPattern = $window.GetCurrentPattern([System.Windows.Automation.WindowPattern]::Pattern)
        if ($windowPattern) { $windowPattern.Close() }
    } catch {}
}

function Invoke-WA_SetLLMNR {
    <#
.SYNOPSIS
    Disables LLMNR.
.LOCATION
    none (registry/GPO-only)
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
        Write-LeftAligned "$FGCyan$Char_HeavyCheck LLMNR set to $(if($Reverse){'Enabled'}else{'Disabled'}).$Reset"
    } catch { Write-WrappedError $_.Exception.Message }
}

function Invoke-WA_SetPSScriptBlock {
    <#
.SYNOPSIS
    Enables PowerShell Script Block Logging.
.LOCATION
    none (registry/GPO-only)
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
        Write-LeftAligned "$FGCyan$Char_HeavyCheck PowerShell Script Block Logging set to $(if($Reverse){'Disabled'}else{'Enabled'}).$Reset"
    } catch { Write-WrappedError $_.Exception.Message }
}

function Invoke-WA_SetPSModuleLogging {
    <#
.SYNOPSIS
    Enables PowerShell Module Logging.
.LOCATION
    none (registry/GPO-only)
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
        Write-LeftAligned "$FGCyan$Char_HeavyCheck PowerShell Module Logging set to $(if($Reverse){'Disabled'}else{'Enabled'}).$Reset"
    } catch { Write-WrappedError $_.Exception.Message }
}

function Invoke-WA_SetNetBIOS {
    <#
.SYNOPSIS
    Disables NetBIOS over TCP/IP.
.LOCATION
    Network adapter Properties > IPv4 > Advanced > WINS tab
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
            Write-LeftAligned "$FGCyan$Char_HeavyCheck NetBIOS set to $(if($Reverse){'Default (DHCP)'}else{'Disabled'}).$Reset"
        }
    } catch { Write-WrappedError $_.Exception.Message }
}

function Invoke-WA_SetShowExtensions {
    <#
.SYNOPSIS
    Configures File Extensions visibility.
.LOCATION
    File Explorer > View > Show
.DESCRIPTION
    Sets HideFileExt in HKCU explorer advanced settings.
    Includes Reverse Mode (-r).
#>
    param([switch]$Reverse)
    Write-Header "FILE EXTENSIONS"
    $v = if ($Reverse) { 1 } else { 0 }
    try {
        Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "HideFileExt" $v -Type DWord -Force
        Write-LeftAligned "$FGCyan$Char_HeavyCheck File Extensions visibility set to $(if($Reverse){'Hidden'}else{'Shown'}).$Reset"
    } catch { Write-WrappedError $_.Exception.Message }
}

function Invoke-WA_SetShowHidden {
    <#
.SYNOPSIS
    Configures Hidden Files visibility.
.LOCATION
    File Explorer > View > Show
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
        Write-LeftAligned "$FGCyan$Char_HeavyCheck Hidden Files visibility set to $(if($Reverse){'Hidden'}else{'Shown'}).$Reset"
    } catch { Write-WrappedError $_.Exception.Message }
}

function Invoke-WA_SetSmartScreenReg {
    <#
.SYNOPSIS
    Enables SmartScreen Filter via Registry and Set-MpPreference.
.LOCATION
    Windows Security > App & browser control > Reputation-based protection settings
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
        Write-LeftAligned "$FGCyan$Char_HeavyCheck SmartScreen Filter Registry keys set.$Reset"
    }
    catch {
        Write-WrappedError $_.Exception.Message
        Write-LeftAligned "$FGGray  Hint: Tamper Protection might be blocking this.$Reset"
    }
}

function Invoke-WA_SetVirusThreatProtectReg {
    <#
.SYNOPSIS
    Enables Real-Time Protection via Registry and Set-MpPreference.
.LOCATION
    Windows Security > Virus & threat protection > Manage settings
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

    # Non-policy Defender key only — the Policies\Microsoft\Windows Defender path
    # would lock Windows Security's Real-Time Protection toggle as "managed by
    # your organization." Set-MpPreference already applies the effect.
    # A prior run of the old version may have left that Policies value behind,
    # which locks the toggle regardless of what this does now — remove it.
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" -Name "DisableRealtimeMonitoring" -Force -ErrorAction SilentlyContinue

    # --- PRE-CHECK: 3RD PARTY AV ---
    $avName = $null
    try {
        $avList = Get-CimInstance -Namespace root/SecurityCenter2 -ClassName AntivirusProduct -ErrorAction SilentlyContinue
        foreach ($av in $avList) {
            if ($av.displayName -and $av.displayName -notmatch "Windows Defender" -and $av.displayName -notmatch "Microsoft Defender Antivirus") {
                $avName = $av.displayName
                break
            }
        }
    }
    catch {}
    if ($avName) {
        Write-LeftAligned "$FGGray[-] Real-Time Protection managed by $avName.$Reset"
        return
    }

    $val = if ($Reverse) { 1 } else { 0 }
    $mpVal = if ($Reverse) { $true } else { $false }
    $status = if ($Reverse) { "DISABLED" } else { "ENABLED" }

    # --- PRE-CHECK: TAMPER PROTECTION ---
    $tp = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows Defender\Features" -Name "TamperProtection" -ErrorAction SilentlyContinue).TamperProtection
    if ($tp -eq 5) {
        Write-LeftAligned "$FGCyan$Char_Warn Tamper Protection is ENABLED and blocking changes.$Reset"
        return
    }

    try {
        $Path = "HKLM:\SOFTWARE\Microsoft\Windows Defender\Real-Time Protection"
        if (-not (Test-Path $Path)) { New-Item -Path $Path -Force -ErrorAction SilentlyContinue | Out-Null }
        Set-ItemProperty -Path $Path -Name "DisableRealtimeMonitoring" -Value $val -Type DWord -Force -ErrorAction SilentlyContinue
        Set-MpPreference -DisableRealtimeMonitoring $mpVal -ErrorAction Stop

        $current = (Get-MpPreference).DisableRealtimeMonitoring
        if ($current -eq $mpVal) {
            Write-LeftAligned "$FGCyan$Char_HeavyCheck Real-Time Protection is $status.$Reset"
        }
        else {
            Write-LeftAligned "$FGCyan$Char_Warn Real-Time Protection verification failed.$Reset"
        }
    }
    catch {
        Write-WrappedError $_.Exception.Message
        Write-LeftAligned "$FGGray  Hint: Tamper Protection might be blocking this.$Reset"
    }
}

function Invoke-WA_SetKernelModeReg {
    <#
.SYNOPSIS
    Enables Kernel-mode Hardware-enforced Stack Protection via Registry.
.LOCATION
    Windows Security > Device security > Core isolation details
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
        Write-LeftAligned "$FGCyan$Char_HeavyCheck Kernel-mode Stack Protection Registry key set to $ActionStr.$Reset"
        Write-LeftAligned "$FGCyan$Char_Warn A system restart is required to take effect.$Reset"
    }
    catch {
        Write-WrappedError $_.Exception.Message
        Write-LeftAligned "$FGGray  Hint: Tamper Protection might be blocking this.$Reset"
    }
}

function Invoke-WA_SetSmartScreen {
    # UI Location: Windows Security > App & browser control > Reputation-based protection settings (same as SetSmartScreenReg)
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
        Write-LeftAligned "$FGCyan$Char_HeavyCheck Window found.$Reset"

        # Force foreground so the page content actually renders into the UIA tree.
        Set-WinAutoForeground -Window $window

        # 3. Search for 'Turn on' button
        $buttonCondition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty, "Turn on")
        
        # Search Descendants (deep search)
        $button = $window.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $buttonCondition)
        
        if ($button) {
            try {
                $invokePattern = $button.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern)
                if ($invokePattern) {
                    $invokePattern.Invoke()
                    Write-LeftAligned "$FGCyan$Char_HeavyCheck Clicked 'Turn on'.$Reset"
                    Start-Sleep -Seconds 1
                }
                else {
                    Write-LeftAligned "$FGCyan$Char_Warn 'Turn on' button found but not clickable.$Reset"
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
    # UI Location: Windows Security > Virus & threat protection > Manage settings
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
        Write-LeftAligned "$FGCyan$Global:Char_HeavyCheck Window found.$Reset"

        # Force foreground so the page content actually renders into the UIA tree.
        Set-WinAutoForeground -Window $window

        # 3. Search for 'Turn on' (or 'Restart now') button
        $targets = @("Turn on", "Restart now")
        $button = $null
        
        foreach ($t in $targets) {
            $cond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty, $t)
            $button = $window.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $cond)
            if ($button) { 
                Write-LeftAligned "$FGCyan$Global:Char_HeavyCheck Found '$t' button.$Reset"
                break 
            }
        }
        
        if ($button) {
            try {
                $invokePattern = $button.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern)
                if ($invokePattern) {
                    $invokePattern.Invoke()
                    Write-LeftAligned "$FGCyan$Global:Char_HeavyCheck Clicked button.$Reset"
                    Start-Sleep -Seconds 1
                }
                else {
                    Write-LeftAligned "$FGCyan$Global:Char_Warn Button found but not clickable.$Reset"
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

function Test-FirewallCompliant {
    # Get-NetFirewallProfile is CIM-backed and occasionally throws transiently under load; retry before reporting non-compliant.
    for ($i = 0; $i -lt 3; $i++) {
        try { return (Get-NetFirewallProfile | Where-Object { -not $_.Enabled }).Count -eq 0 }
        catch { Start-Sleep -Milliseconds 300 }
    }
    return $false
}

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
    $Global:Toggle_GetMeUpToDate = 0

    $Global:Toggle_RestartIsReq = 1
    $Global:Toggle_RestartApps = 1
    $Global:Toggle_PSTranscription = 0
    $Global:Toggle_Telemetry = 0
    $Global:Toggle_LLMNR = 0
    $Global:Toggle_PSScriptBlock = 0
    $Global:Toggle_PSModuleLogging = 0
    $Global:Toggle_NetBIOS = 0
    $Global:Toggle_RealTimeProt = 1
    $Global:Toggle_RealTimeProtUI = 0
    $Global:Toggle_PUABlockApps = 1
    $Global:Toggle_PUABlockDLs = 1
    $Global:Toggle_MemoryInteg = 1
    $Global:Toggle_KernelMode = 1
    $Global:Toggle_LocalSecurity = 1
    $Global:Toggle_FirewallON = 1
    $Global:Toggle_ShowExtensions = 0
    $Global:Toggle_ShowHidden = 0

    # Extended hardening (security_audit.json parity)
    $Global:Toggle_StoreSmartScreen = 1
    $Global:Toggle_PhishingProtection = 1
    $Global:Toggle_HideAdmin = 0
    $Global:Toggle_AdvertisingID = 0
    $Global:Toggle_MeteredUpdates = 0
    $Global:Toggle_ARSOOptOut = 0
    $Global:Toggle_UIAnimations = 0
    $Global:Toggle_VisualEffects = 0

    # Background-only fallbacks
    $Global:Toggle_SmartScreenReg = 0
    $Global:Toggle_SmartScreenUIA = 0
}


# --- MAINTENANCE FUNCTIONS ---

function Invoke-WA_SystemPreCheck {
    Write-Header "SYSTEM PRE-FLIGHT CHECK"
    $os = Get-CimInstance Win32_OperatingSystem
    Write-LeftAligned "$FGWhite OS: $($os.Caption) ($($os.Version))$Reset"
    $uptime = (Get-Date) - $os.LastBootUpTime
    $color = & { if ($uptime.Days -gt 7) { $FGRed } else { $FGWhite } }
    Write-LeftAligned "$FGWhite Uptime: $color$($uptime.Days) days$Reset"
    
    $drive = Get-Volume -DriveLetter C
    $freeGB = [math]::Round($drive.SizeRemaining / 1GB, 2)
    $dColor = & { if ($freeGB -lt 10) { $FGRed } else { $FGWhite } }
    Write-LeftAligned "$FGWhite Free Space (C:): $dColor$freeGB GB$Reset"
    
    $pending = $false
    if (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending") { $pending = $true }
    if ($pending) { Write-LeftAligned "$FGRed$Char_Warn REBOOT PENDING$Reset" } 
    else { Write-LeftAligned "$FGCyan$Char_BallotCheck System Ready$Reset" }
    
    $res = Invoke-AnimatedPause -Timeout 5
    if ($res.VirtualKeyCode -eq 27) { throw "UserCancelled" }
}

function Invoke-WA_WindowsUpdate {
    # UI Location: Settings > Windows Update (also opens Microsoft Store > Library / Downloads & updates)
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
    Write-Centered "$Global:Char_EnDash STORE & SETTINGS $Global:Char_EnDash" -Width 52 -Color "$Bold$FGWhite"

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
                    Write-LeftAligned "$FGCyan$Char_HeavyCheck Clicked '$($btnInfo.Name)' (ID)$Reset"
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
                        Write-LeftAligned "$FGCyan$Char_HeavyCheck Clicked '$($btnInfo.Name)' (Name)$Reset"
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
                        Write-LeftAligned "$FGCyan$Char_HeavyCheck Clicked '$n' (Fuzzy)$Reset"
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
                Write-LeftAligned "$FGCyan$Char_HeavyCheck Clicked '$buttonText'$Reset"
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
    try { $s_FW = Test-FirewallCompliant } catch { Write-Log -Message "[Discovery] Firewall check: $_" -Level "WARN"; $s_FW = $false }
    $s_Mem = Test-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" "Enabled" 1
    $s_Kern = Test-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\KernelShadowStacks" "Enabled" 1
    $s_LSA = Test-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" "RunAsPPL" 1
    $s_Task = Test-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" "SearchboxTaskbarMode" 3
    $s_View = Test-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowTaskViewButton" 0
    $s_MU = Test-Reg "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" "AllowMUUpdateService" 1
    $s_GetMe = Test-Reg "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" "IsExpedited" 1
    $s_Metered = (Get-WinAutoLastRun -Module "MeteredUpdates") -ne "Never"
    $s_ARSO = (Get-WinAutoLastRun -Module "ARSOOptOut") -ne "Never"
    $s_Rest = Test-Reg "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" "RestartNotificationsAllowed2" 1
    $s_Pers = Test-Reg "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Winlogon" "RestartApps" 1
    $edgeVal = (Get-ItemProperty "HKCU:\Software\Microsoft\Edge\SmartScreenPuaEnabled" -ErrorAction SilentlyContinue)."(default)"
    $s_Edge = if ($edgeVal -eq 1) { $true } else { "GreyOut" }
    $ctxPath = "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32"
    $s_Ctx = if (Test-Path $ctxPath) { (Get-ItemProperty $ctxPath)."(default)" -eq "" } else { $false }

    # Extra configs status check
    $s_PSTrans = Test-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\Transcription" "EnableTranscripting" 1
    $s_Telemetry = (Get-WinAutoLastRun -Module "Telemetry") -ne "Never"
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

    # Extended hardening status check (security_audit.json parity)
    $s_StoreSS = Test-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppHost" "EnableWebContentEvaluation" 1
    $s_Phish = (Get-WinAutoLastRun -Module "PhishingProtection") -ne "Never"
    $s_HideAdmin = Test-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\SpecialAccounts\UserList" "Administrator" 0
    $s_AdvID = Test-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo" "Enabled" 0
    $s_Anim = Test-Reg "HKCU:\Control Panel\Desktop\WindowMetrics" "MinAnimate" "0"
    $s_VisFX = Test-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" "VisualFXSetting" 2
    $s_RebootPending = $(
        (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending") -or
        (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired") -or
        ($null -ne (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" -Name "PendingFileRenameOperations" -ErrorAction SilentlyContinue))
    )

    # SmartRun re-applies default-enabled settings only once every 30 days,
    # regardless of their current compliance state. "Get Updates" is the only
    # step that always runs every time the script runs (see Invoke-WinAutoMaintenance).
    $lastFullRun = Get-WinAutoLastRun -Module "WinAuto"
    $daysSinceLastRun = if ($lastFullRun -eq "Never") { [int]::MaxValue } else { try { ((Get-Date) - (Get-Date $lastFullRun)).Days } catch { [int]::MaxValue } }
    $thirtyDayGateOpen = $daysSinceLastRun -gt 30

    if ($SmartRun -and -not $thirtyDayGateOpen) {
        Write-Boundary
        Write-LeftAligned "$FGCyan$Global:Char_CheckMark Less than 30 days since the last full run. Skipping Configuration phase.$Reset"
        Write-Boundary
        Write-Centered "$FGCyan CONFIGURATION COMPLETE $Reset" -Width 52
        Set-WinAutoLastRun -Module "Configuration"
        Start-Sleep -Seconds 2
        return
    }

    Write-Boundary

    # Helper: in SmartRun, a step only runs if it's default-enabled (ToggleValue)
    # AND the 30-day gate is open; in ManualMode, a step runs whenever toggled on.
    function Invoke-Smart {
        param($Script, $Status, $ToggleValue = 1)
        Test-PauseRequest
        $run = if ($SmartRun) { ($ToggleValue -eq 1) -and $thirtyDayGateOpen } else { $ToggleValue -eq 1 }

        if ($run) {
            & $Script
        } else {
            if ($SmartRun -and ($ToggleValue -eq 1)) {
                Write-LeftAligned "$FGCyan$Global:Char_CheckMark Skipping $($Script.ToString().Replace('Invoke-WA_','')) (Last full run < 30 days ago).$Reset"
            }
        }
    }

    # 1. Core Security
    Invoke-Smart { Invoke-WA_SetMemoryInteg } $s_Mem $Global:Toggle_MemoryInteg
    Invoke-Smart { Invoke-WA_SetLocalSecurity } $s_LSA $Global:Toggle_LocalSecurity
    Invoke-Smart { Invoke-WA_SetFirewallON } $s_FW $Global:Toggle_FirewallON
    
    # Real-Time Protection - Registry (default step)
    Invoke-Smart { Invoke-WA_SetVirusThreatProtectReg } $s_RT $Global:Toggle_RealTimeProt
    # Real-Time Protection - Windows Security UI (optional; user-selected, off by default)
    $s_RT_check = $(try { (Get-MpPreference -EA 0).DisableRealtimeMonitoring -eq $false } catch { $false })
    Invoke-Smart { Invoke-WA_SetVirusThreatProtect } $s_RT_check $Global:Toggle_RealTimeProtUI

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

    # Extended hardening (security_audit.json parity)
    Invoke-Smart { Invoke-WA_SetStoreSmartScreen } $s_StoreSS $Global:Toggle_StoreSmartScreen
    Invoke-Smart { Invoke-WA_SetPhishingProtection } $s_Phish $Global:Toggle_PhishingProtection
    Invoke-Smart { Invoke-WA_SetHideAdmin } $s_HideAdmin $Global:Toggle_HideAdmin
    Invoke-Smart { Invoke-WA_SetAdvertisingID } $s_AdvID $Global:Toggle_AdvertisingID

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
    # Extra UI toggles (Show Extensions, Show Hidden, Animations, Visual Effects)
    if (-not $SmartRun) {
        if ($Global:Toggle_ShowExtensions -eq 1) {
            if ($s_ShowExt) { Invoke-WA_SetShowExtensions -Reverse }
            else { Invoke-WA_SetShowExtensions }
        }
        if ($Global:Toggle_ShowHidden -eq 1) {
            if ($s_ShowHidden) { Invoke-WA_SetShowHidden -Reverse }
            else { Invoke-WA_SetShowHidden }
        }
        if ($Global:Toggle_UIAnimations -eq 1) {
            if ($s_Anim) { Invoke-WA_SetUIAnimations -Reverse }
            else { Invoke-WA_SetUIAnimations }
        }
        if ($Global:Toggle_VisualEffects -eq 1) {
            if ($s_VisFX) { Invoke-WA_SetVisualEffects -Reverse }
            else { Invoke-WA_SetVisualEffects }
        }
    } else {
        Invoke-Smart { Invoke-WA_SetShowExtensions } $s_ShowExt $Global:Toggle_ShowExtensions
        Invoke-Smart { Invoke-WA_SetShowHidden } $s_ShowHidden $Global:Toggle_ShowHidden
        Invoke-Smart { Invoke-WA_SetUIAnimations } $s_Anim $Global:Toggle_UIAnimations
        Invoke-Smart { Invoke-WA_SetVisualEffects } $s_VisFX $Global:Toggle_VisualEffects
    }
    # 4. Updates & Persistence

    Invoke-Smart { Invoke-WA_SetGetMeUpToDate } $s_GetMe $Global:Toggle_GetMeUpToDate
    Invoke-Smart { Invoke-WA_SetMicrosoftUpd } $s_MU $Global:Toggle_MicrosoftUpd
    Invoke-Smart { Invoke-WA_SetRestartIsReq } $s_Rest $Global:Toggle_RestartIsReq
    Invoke-Smart { Invoke-WA_SetRestartApps } $s_Pers $Global:Toggle_RestartApps
    Invoke-Smart { Invoke-WA_SetMeteredUpdates } $s_Metered $Global:Toggle_MeteredUpdates
    Invoke-Smart { Invoke-WA_SetARSOOptOut } $s_ARSO $Global:Toggle_ARSOOptOut

    # Explorer Refresh
    $runRefresh = $false
    if (-not $SmartRun) {
        if ($Global:Toggle_ClassicMenu -ne 0 -or $Global:Toggle_TaskbarSearch -ne 0 -or $Global:Toggle_TaskView -ne 0 -or $Global:Toggle_ShowExtensions -ne 0 -or $Global:Toggle_ShowHidden -ne 0 -or $Global:Toggle_UIAnimations -ne 0 -or $Global:Toggle_VisualEffects -ne 0) {
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
            WindowsTelemetry = $s_Telemetry
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
            WindowsFirewall = $(try { Test-FirewallCompliant } catch { $false })
            ClassicContextMenu = $s_Ctx
            TaskbarSearchBox = Test-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" "SearchboxTaskbarMode" 3
            TaskViewToggle = Test-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowTaskViewButton" 0
            ShowFileExtensions = Test-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "HideFileExt" 0
            ShowHiddenFiles = Test-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "Hidden" 1
            SmartScreenFilter = $s_SS
            StoreSmartScreen = $s_StoreSS
            PhishingProtection = $s_Phish
            HideAdminAccount = $s_HideAdmin
            AdvertisingID = $s_AdvID
            MeteredUpdates = $s_Metered
            AutoRestartSignOn = $s_ARSO
            UIAnimations = $s_Anim
            VisualEffects = $s_VisFX
            RebootPending = $s_RebootPending
            Timestamp = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
        }
        $auditPath = Join-Path $Global:WinAutoLogDir "winauto_audit.json"
        $auditData | ConvertTo-Json | Out-File -FilePath $auditPath -Force -Encoding utf8
        Write-Host "    [v] Generated winauto_audit.json successfully." -ForegroundColor Cyan
    } catch {
        Write-Host "    [x] Failed to generate winauto_audit.json." -ForegroundColor Red
    }

    Sync-ToggleStates -s_Ctx $s_Ctx -s_Task $s_Task -s_View $s_View

    Write-Boundary
    Write-Centered "$FGCyan CONFIGURATION COMPLETE $Reset" -Width 52
    Set-WinAutoLastRun -Module "Configuration"
    Start-Sleep -Seconds 2
}

function Invoke-WinAutoMaintenance {
    param([switch]$SmartRun)
    Write-Header "WINDOWS MAINTENANCE PHASE"
    $lastRun = Get-WinAutoLastRun -Module "Maintenance"
    Write-LeftAligned "$FGGray Last Run: $FGWhite$lastRun$Reset"

    # "Get Updates" always runs, every time the script runs. Every other
    # maintenance step runs only if it's default-enabled (ToggleValue) AND
    # the 30-day gate is open (see Get-WinAutoLastRun -Module "WinAuto").
    $lastFullRun = Get-WinAutoLastRun -Module "WinAuto"
    $daysSinceLastRun = if ($lastFullRun -eq "Never") { [int]::MaxValue } else { try { ((Get-Date) - (Get-Date $lastFullRun)).Days } catch { [int]::MaxValue } }
    $thirtyDayGateOpen = $daysSinceLastRun -gt 30

    function Test-RunNeeded {
        param($Key, [int]$ToggleValue = 0)
        if ($Global:Toggle_MaintainForced -eq 1) { return $true }
        if ($Key -eq "Maintenance_WinUpdate") { return $true }
        if (-not $SmartRun) {
            $anyToggled = ($Global:Toggle_MaintUpdate -eq 1 -or $Global:Toggle_MaintDisk -eq 1 -or $Global:Toggle_MaintCleanup -eq 1 -or $Global:Toggle_MaintSFC -eq 1)
            if (-not $anyToggled) { return $true }
            return $ToggleValue -eq 1
        }
        if ($ToggleValue -ne 1) { return $false }
        if (-not $thirtyDayGateOpen) {
            Write-LeftAligned "$FGCyan$Global:Char_CheckMark Skipping $Key (Last full run < 30 days ago).$Reset"
            return $false
        }
        return $true
    }

    try {
        Write-Boundary
        Invoke-WA_SystemPreCheck

        Test-PauseRequest
        if (Test-RunNeeded -Key "Maintenance_SFC" -ToggleValue $Global:Toggle_MaintSFC) {
            Invoke-WA_WindowsRepair
            Set-WinAutoLastRun -Module "Maintenance_SFC"
        }

        Test-PauseRequest
        if (Test-RunNeeded -Key "Maintenance_Disk" -ToggleValue $Global:Toggle_MaintDisk) {
            Invoke-WA_OptimizeDisks
            Set-WinAutoLastRun -Module "Maintenance_Disk"
        }

        Test-PauseRequest
        if (Test-RunNeeded -Key "Maintenance_Cleanup" -ToggleValue $Global:Toggle_MaintCleanup) {
            Invoke-WA_SystemCleanup
            Set-WinAutoLastRun -Module "Maintenance_Cleanup"
        }

        Test-PauseRequest
        # Get Updates always runs (see Test-RunNeeded above).
        if (Test-RunNeeded -Key "Maintenance_WinUpdate" -ToggleValue $Global:Toggle_MaintUpdate) {
            Invoke-WA_WindowsUpdate
            Set-WinAutoLastRun -Module "Maintenance_WinUpdate"
        }


        Write-Host ""
        Write-Centered "$FGCyan MAINTENANCE COMPLETE $Reset" -Width 52
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

function Invoke-WA_SetPUABlockApps {
    <#
.SYNOPSIS
    Enables or Disables PUA (Potentially Unwanted Application) Blocking.
.LOCATION
    Windows Security > App & browser control > Reputation-based protection settings
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
        Write-LeftAligned "$FGCyan$Char_HeavyCheck  Defender PUA Blocking is $statusText.$Reset"

        # Verification
        $currentMp = (Get-MpPreference).PUAProtection
        if ($currentMp -ne $targetMp) {
            Write-LeftAligned "$FGCyan$Char_Warn Verification failed for Defender PUA. Status: $currentMp$Reset"
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
.LOCATION
    Microsoft Edge > Settings > Privacy, search, and services > Security
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
    
        Write-LeftAligned "$FGCyan$Char_HeavyCheck  Edge 'Block downloads' is $statusText.$Reset"

    }
    catch {
        Write-WrappedError $_.Exception.Message
    }

}

function Invoke-WA_SetMemoryInteg {
    <#
.SYNOPSIS
    Enables Memory Integrity (Core Isolation) via Registry.
.LOCATION
    Windows Security > Device security > Core isolation
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
    
        Write-LeftAligned "$FGCyan$Char_HeavyCheck  Memory Integrity Registry Key set to $ActionStr.$Reset"
        Write-LeftAligned "$FGCyan$Char_Warn  A system restart is required to take effect.$Reset"
    }
    catch {
        Write-WrappedError $_.Exception.Message
        Write-LeftAligned "$FGGray  Hint: Tamper Protection might be blocking this.$Reset"
    }

}

# --- EMBEDDED ATOMIC SCRIPTS (Security Part 2) ---

function Invoke-WA_SetKernelMode {
    <#
.SYNOPSIS
    Enables 'Kernel-mode Hardware-enforced Stack Protection' in Windows Security via UI Automation.
.LOCATION
    Windows Security > Device security > Core isolation details (same as SetKernelModeReg)
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
            # Win32 force-foreground too — SetFocus alone can be flaky on UWP and
            # an inactive window won't render its content into the UIA tree.
            Set-WinAutoForeground -Window $Window

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
.LOCATION
    Windows Security > Device security > Core isolation (Local Security Authority protection — only present on newer Windows 11 builds)
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
    
        Write-LeftAligned "$FGCyan$Char_HeavyCheck  LSA Protection (RunAsPPL) set to $ActionStr.$Reset"
        Write-LeftAligned "$FGCyan$Char_Warn  A system restart is required to take effect.$Reset"
    }
    catch {
        Write-WrappedError $_.Exception.Message
    }

}

function Invoke-WA_SetFirewallON {
    <#
.SYNOPSIS
    Enables Windows Firewall for all profiles.
.LOCATION
    Windows Security > Firewall & network protection
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
        Write-LeftAligned "$FGCyan$Char_HeavyCheck  Firewall (All Profiles) is $statusStr.$Reset"
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
.LOCATION
    none (no Settings page; only visible by right-clicking the desktop)
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
                Write-LeftAligned "$FGCyan$Char_HeavyCheck Restored Windows 11 Context Menu.$Reset"
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
         
            Write-LeftAligned "$FGCyan$Char_HeavyCheck Enabled Classic Context Menu.$Reset"
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
.LOCATION
    Settings > Personalization > Taskbar
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
    
        Write-LeftAligned "$FGCyan$Char_HeavyCheck Taskbar Search set to $ActionStr.$Reset"
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
.LOCATION
    Settings > Personalization > Taskbar
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
    
        Write-LeftAligned "$FGCyan$Char_HeavyCheck Task View button is $ActionStr.$Reset"
        Write-LeftAligned "$FGGray Restarting Explorer...$Reset"
        Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 1
    }
    catch {
        Write-WrappedError $_.Exception.Message
    }

}


function Invoke-WA_SetGetMeUpToDate {
    param([switch]$Reverse)
    # UI Location: none (registry/GPO-only, no known visible toggle)
    Write-Header "GET ME UP TO DATE"
    $Path = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings"
    try {
        if ($Reverse) {
            Set-ItemProperty -Path $Path -Name "IsExpedited" -Value 0 -Type DWord -Force
            Write-LeftAligned "$FGCyan$Char_HeavyCheck Disabled Get Me Up To Date.$Reset"
        } else {
            Set-ItemProperty -Path $Path -Name "IsExpedited" -Value 1 -Type DWord -Force
            Write-LeftAligned "$FGCyan$Char_HeavyCheck Enabled Get Me Up To Date.$Reset"
        }
    } catch {
        Write-WrappedError $_
    }
}

function Invoke-WA_SetMicrosoftUpd {
    <#
.SYNOPSIS
    Sets 'Receive updates for other Microsoft products'.
.LOCATION
    Settings > Windows Update > Advanced options
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
    
        Write-LeftAligned "$FGCyan$Char_HeavyCheck MS Update Service is $StatusStr.$Reset"
    }
    catch {
        Write-WrappedError $_.Exception.Message
    }

}

function Invoke-WA_SetRestartIsReq {
    <#
.SYNOPSIS
    Sets 'Notify me when a restart is required'.
.LOCATION
    Settings > Windows Update > Advanced options
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
    
        Write-LeftAligned "$FGCyan$Char_HeavyCheck Restart Notification is $StatusStr.$Reset"
    }
    catch {
        Write-WrappedError $_.Exception.Message
    }

}

function Invoke-WA_SetRestartApps {
    <#
.SYNOPSIS
    Sets 'Restart apps after signing in'.
.LOCATION
    Settings > Accounts > Sign-in options
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
    
        Write-LeftAligned "$FGCyan$Char_HeavyCheck App Restart Persistence is $StatusStr.$Reset"
    }
    catch {
        Write-WrappedError $_.Exception.Message
    }

}

# --- EXTENDED HARDENING (security_audit.json parity) ---

function Invoke-WA_SetStoreSmartScreen {
    <#
.SYNOPSIS
    Enables SmartScreen for Microsoft Store apps.
.LOCATION
    Settings > Privacy & Security > General
.DESCRIPTION
    Standardized for WinAuto.
    Sets EnableWebContentEvaluation in HKCU AppHost registry.
    Standalone version. Includes Reverse Mode (-r).
.PARAMETER Reverse
    (Alias: -r) Reverses the setting (Disables Store SmartScreen).
#>
    param(
        [Parameter(Mandatory = $false)]
        [Alias('r')]
        [switch]$Reverse
    )
    Write-Header "STORE SMARTSCREEN"
    $Path = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppHost"
    $Name = "EnableWebContentEvaluation"
    $Value = if ($Reverse) { 0 } else { 1 }
    $ActionStr = if ($Reverse) { "DISABLED" } else { "ENABLED" }
    try {
        if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type DWord -Force -ErrorAction Stop
        Write-LeftAligned "$FGCyan$Char_HeavyCheck Store SmartScreen is $ActionStr.$Reset"
    }
    catch { Write-WrappedError $_.Exception.Message }
}

function Invoke-WA_SetPhishingProtection {
    <#
.SYNOPSIS
    Enables Enhanced Phishing Protection via the Windows Security app UI.
.LOCATION
    Windows Security > App & browser control > Reputation-based protection settings
.DESCRIPTION
    Drives the "Phishing protection" toggle on Windows Security's
    Reputation-based protection settings page, instead of writing
    HKLM Policies\Microsoft\Windows\WTDS\Components\ServiceEnabled, which would
    lock that page as "managed by your organization."
    Standalone version. Includes Reverse Mode (-r).
.PARAMETER Reverse
    (Alias: -r) Reverses the setting (Disables Phishing Protection).
#>
    param(
        [Parameter(Mandatory = $false)]
        [Alias('r')]
        [switch]$Reverse
    )
    Write-Header "PHISHING PROTECTION (UIA)"

    # A prior run of the old registry-based version may have left the Policies
    # value behind, which locks the control regardless of what this does now.
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WTDS\Components" -Name "ServiceEnabled" -Force -ErrorAction SilentlyContinue

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

    # Windows Security keeps its own running process (SecHealthUI) and re-using
    # an already-open window can show a stale "managed by your administrator"
    # lock left over from before the registry value above was removed. Force a
    # fresh instance so the page re-reads current policy state.
    Stop-Process -Name "SecHealthUI" -Force -ErrorAction SilentlyContinue

    # SecurityHealthService (the background service feeding that UI) can also
    # cache the policy-managed flag independently of both the registry value
    # and the UI process. Restarting it requires elevation this script already has.
    Restart-Service -Name "SecurityHealthService" -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1

    Write-LeftAligned "Opening Windows Security..."
    try { Start-Process "windowsdefender://appbrowser" -ErrorAction Stop }
    catch { Write-LeftAligned "$FGRed$Char_RedCross Failed to launch Windows Security.$Reset"; return }
    Start-Sleep -Seconds 2

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

    if (-not $window) {
        Write-LeftAligned "$FGRed$Char_RedCross Timeout waiting for Windows Security window.$Reset"
        return
    }
    Write-LeftAligned "$FGCyan$Char_HeavyCheck Window found.$Reset"

    # Force foreground so the page content actually renders into the UIA tree.
    Set-WinAutoForeground -Window $window

    # The toggle lives one level deeper, under "Reputation-based protection settings".
    # Drill in if that link is present; if not, assume we're already on the right page.
    try {
        $drillCondition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty, "Reputation-based protection settings")
        $drillLink = $window.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $drillCondition)
        if ($drillLink) {
            $drillLink.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern).Invoke()
            Start-Sleep -Seconds 1
        }
    } catch {}

    # Match on name AND verify the element actually supports TogglePattern —
    # a heading/label Text control can also match the name search.
    $toggle = $null
    try {
        $allElements = $window.FindAll([System.Windows.Automation.TreeScope]::Descendants, [System.Windows.Automation.Condition]::TrueCondition)
        foreach ($el in $allElements) {
            if ($el.Current.Name -like "*Phishing protection*") {
                try {
                    $el.GetCurrentPattern([System.Windows.Automation.TogglePattern]::Pattern) | Out-Null
                    $toggle = $el
                    break
                } catch { continue }
            }
        }
    } catch {}

    if (-not $toggle) {
        Write-LeftAligned "$FGGray No Phishing protection toggle found (page layout may differ).$Reset"
    } else {
        $applied = $false
        try {
            $togglePattern = $toggle.GetCurrentPattern([System.Windows.Automation.TogglePattern]::Pattern)
            $current = $togglePattern.Current.ToggleState
            $targetState = if ($Reverse) { [System.Windows.Automation.ToggleState]::Off } else { [System.Windows.Automation.ToggleState]::On }
            if ($current -ne $targetState) {
                $togglePattern.Toggle()
                Write-LeftAligned "$FGCyan$Char_HeavyCheck Phishing Protection toggled $(if($Reverse){'OFF'}else{'ON'}).$Reset"
            } else {
                Write-LeftAligned "$FGGray Already $(if($Reverse){'OFF'}else{'ON'}).$Reset"
            }
            $applied = $true
        }
        catch {
            Write-LeftAligned "$FGCyan$Char_Warn Toggle found but could not be set: $($_.Exception.Message)$Reset"
        }
        if ($applied) {
            if ($Reverse) { Remove-ItemProperty -Path "HKLM:\SOFTWARE\WinAuto" -Name "LastRun_PhishingProtection" -Force -ErrorAction SilentlyContinue }
            else { Set-WinAutoLastRun -Module "PhishingProtection" }
        }
    }

    try {
        $windowPattern = $window.GetCurrentPattern([System.Windows.Automation.WindowPattern]::Pattern)
        if ($windowPattern) { $windowPattern.Close() }
    } catch {}
}

function Invoke-WA_SetHideAdmin {
    <#
.SYNOPSIS
    Hides the built-in Administrator account from the sign-in screen.
.LOCATION
    none (no GUI control exists)
.DESCRIPTION
    Standardized for WinAuto.
    Sets the 'Administrator' DWORD under Winlogon\SpecialAccounts\UserList to 0.
    Does not disable the account, only hides it from the logon UI.
    Standalone version. Includes Reverse Mode (-r).
.PARAMETER Reverse
    (Alias: -r) Reverses the setting (Shows the Administrator account).
#>
    param(
        [Parameter(Mandatory = $false)]
        [Alias('r')]
        [switch]$Reverse
    )
    Write-Header "HIDE ADMIN ACCOUNT"
    $Path = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\SpecialAccounts\UserList"
    $Name = "Administrator"
    $Value = if ($Reverse) { 1 } else { 0 }
    $ActionStr = if ($Reverse) { "VISIBLE" } else { "HIDDEN" }
    try {
        if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type DWord -Force -ErrorAction Stop
        Write-LeftAligned "$FGCyan$Char_HeavyCheck Administrator account is now $ActionStr on the sign-in screen.$Reset"
    }
    catch { Write-WrappedError $_.Exception.Message }
}

function Invoke-WA_SetAdvertisingID {
    <#
.SYNOPSIS
    Disables the per-user Advertising ID.
.LOCATION
    Settings > Privacy & Security > General
.DESCRIPTION
    Standardized for WinAuto.
    Sets Enabled in HKCU AdvertisingInfo registry.
    Standalone version. Includes Reverse Mode (-r).
.PARAMETER Reverse
    (Alias: -r) Reverses the setting (Enables Advertising ID).
#>
    param(
        [Parameter(Mandatory = $false)]
        [Alias('r')]
        [switch]$Reverse
    )
    Write-Header "ADVERTISING ID"
    $Path = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo"
    $Name = "Enabled"
    $Value = if ($Reverse) { 1 } else { 0 }
    $ActionStr = if ($Reverse) { "Enabled" } else { "Disabled" }
    try {
        if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type DWord -Force -ErrorAction Stop
        Write-LeftAligned "$FGCyan$Char_HeavyCheck Advertising ID set to $ActionStr.$Reset"
    }
    catch { Write-WrappedError $_.Exception.Message }
}

function Invoke-WA_SetMeteredUpdates {
    <#
.SYNOPSIS
    Blocks automatic Windows Update downloads over metered connections, via the Settings app UI.
.LOCATION
    Settings > Windows Update > Advanced options (metered connection toggle)
.DESCRIPTION
    Drives the "Get updates over metered connections" toggle on Windows Update's
    Advanced options page, instead of writing HKLM Policies\Microsoft\Windows\
    WindowsUpdate\AllowAutoWindowsUpdateDownloadOverMeteredNetwork, which would
    lock that page as "managed by your organization."
    Standalone version. Includes Reverse Mode (-r).
.PARAMETER Reverse
    (Alias: -r) Reverses the setting (Allows metered downloads).
#>
    param(
        [Parameter(Mandatory = $false)]
        [Alias('r')]
        [switch]$Reverse
    )
    Write-Header "METERED UPDATE DOWNLOADS (UIA)"

    # A prior run of the old registry-based version may have left the Policies
    # value behind, which locks the control regardless of what this does now.
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" -Name "AllowAutoWindowsUpdateDownloadOverMeteredNetwork" -Force -ErrorAction SilentlyContinue

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

    Write-LeftAligned "Opening Windows Update Advanced options..."
    try { Start-Process "ms-settings:windowsupdate-options" -ErrorAction Stop }
    catch { Write-LeftAligned "$FGRed$Char_RedCross Failed to launch Settings.$Reset"; return }
    Start-Sleep -Seconds 2

    $timeout = 10
    $startTime = Get-Date
    $window = $null
    Write-LeftAligned "Searching for 'Settings' window..."
    do {
        $desktop = [System.Windows.Automation.AutomationElement]::RootElement
        $condition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty, "Settings")
        $window = $desktop.FindFirst([System.Windows.Automation.TreeScope]::Children, $condition)
        if ($null -ne $window) { break }
        Start-Sleep -Milliseconds 500
    } while ((Get-Date) -lt $startTime.AddSeconds($timeout))

    if (-not $window) {
        Write-LeftAligned "$FGRed$Char_RedCross Timeout waiting for Settings window.$Reset"
        return
    }
    Write-LeftAligned "$FGCyan$Char_HeavyCheck Window found.$Reset"

    # Force foreground so the page content actually renders into the UIA tree.
    Set-WinAutoForeground -Window $window

    # Match on name AND verify the element actually supports TogglePattern —
    # the heading text "Download updates over metered connections" also
    # matches the name search but is a plain Text control, not the switch.
    $toggle = $null
    try {
        $allElements = $window.FindAll([System.Windows.Automation.TreeScope]::Descendants, [System.Windows.Automation.Condition]::TrueCondition)
        foreach ($el in $allElements) {
            if ($el.Current.Name -like "*metered connection*") {
                try {
                    $el.GetCurrentPattern([System.Windows.Automation.TogglePattern]::Pattern) | Out-Null
                    $toggle = $el
                    break
                } catch { continue }
            }
        }
    } catch {}

    if (-not $toggle) {
        Write-LeftAligned "$FGGray No metered-connection toggle found (page layout may differ).$Reset"
    } else {
        $applied = $false
        try {
            $togglePattern = $toggle.GetCurrentPattern([System.Windows.Automation.TogglePattern]::Pattern)
            $current = $togglePattern.Current.ToggleState
            $targetState = if ($Reverse) { [System.Windows.Automation.ToggleState]::Off } else { [System.Windows.Automation.ToggleState]::On }
            if ($current -ne $targetState) {
                $togglePattern.Toggle()
                Write-LeftAligned "$FGCyan$Char_HeavyCheck Metered-connection update downloads toggled $(if($Reverse){'OFF'}else{'ON'}).$Reset"
            } else {
                Write-LeftAligned "$FGGray Already $(if($Reverse){'OFF'}else{'ON'}).$Reset"
            }
            $applied = $true
        }
        catch {
            Write-LeftAligned "$FGCyan$Char_Warn Toggle found but could not be set: $($_.Exception.Message)$Reset"
        }
        if ($applied) {
            if ($Reverse) { Remove-ItemProperty -Path "HKLM:\SOFTWARE\WinAuto" -Name "LastRun_MeteredUpdates" -Force -ErrorAction SilentlyContinue }
            else { Set-WinAutoLastRun -Module "MeteredUpdates" }
        }
    }

    try {
        $windowPattern = $window.GetCurrentPattern([System.Windows.Automation.WindowPattern]::Pattern)
        if ($windowPattern) { $windowPattern.Close() }
    } catch {}
}

function Invoke-WA_SetARSOOptOut {
    <#
.SYNOPSIS
    Opts out of Automatic Restart Sign-On (ARSO) via the Settings app UI.
.LOCATION
    Settings > Accounts > Sign-in options
.DESCRIPTION
    Standardized for WinAuto.
    Drives the actual Settings toggle ("Use my sign-in info to automatically
    finish setting up my device and reopen my apps after an update or restart")
    on the Sign-in options page, instead of writing the
    HKLM Policies\System\DisableAutomaticRestartSignOn Group Policy registry value.
    Writing that policy value directly would lock the toggle in a "managed by
    your organization" state; driving the UI control keeps it interactive.
    Standalone version. Includes Reverse Mode (-r).
.PARAMETER Reverse
    (Alias: -r) Reverses the setting (turns the toggle back on, re-enabling ARSO).
#>
    param(
        [Parameter(Mandatory = $false)]
        [Alias('r')]
        [switch]$Reverse
    )
    Write-Header "AUTO RESTART SIGN-ON (UIA)"

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

    Write-LeftAligned "Opening Sign-in options..."
    try { Start-Process "ms-settings:signinoptions" -ErrorAction Stop }
    catch { Write-LeftAligned "$FGRed$Char_RedCross Failed to launch Settings.$Reset"; return }
    Start-Sleep -Seconds 2

    $timeout = 10
    $startTime = Get-Date
    $window = $null
    Write-LeftAligned "Searching for 'Settings' window..."
    do {
        $desktop = [System.Windows.Automation.AutomationElement]::RootElement
        $condition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty, "Settings")
        $window = $desktop.FindFirst([System.Windows.Automation.TreeScope]::Children, $condition)
        if ($null -ne $window) { break }
        Start-Sleep -Milliseconds 500
    } while ((Get-Date) -lt $startTime.AddSeconds($timeout))

    if (-not $window) {
        Write-LeftAligned "$FGRed$Char_RedCross Timeout waiting for Settings window.$Reset"
        return
    }
    Write-LeftAligned "$FGCyan$Char_HeavyCheck Window found.$Reset"

    # The toggle may be virtualized off-screen; nudge the page so it's realized.
    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
        [System.Windows.Forms.SendKeys]::SendWait("{END}")
        Start-Sleep -Milliseconds 500
    } catch {}

    $toggle = $null
    try {
        $allElements = $window.FindAll([System.Windows.Automation.TreeScope]::Descendants, [System.Windows.Automation.Condition]::TrueCondition)
        foreach ($el in $allElements) {
            if ($el.Current.Name -like "*automatically finish setting up*") { $toggle = $el; break }
        }
    } catch {}

    if (-not $toggle) {
        Write-LeftAligned "$FGGray No automatic sign-in toggle found (page layout may differ).$Reset"
    } else {
        $applied = $false
        try {
            $togglePattern = $toggle.GetCurrentPattern([System.Windows.Automation.TogglePattern]::Pattern)
            $current = $togglePattern.Current.ToggleState
            $targetState = if ($Reverse) { [System.Windows.Automation.ToggleState]::On } else { [System.Windows.Automation.ToggleState]::Off }
            if ($current -ne $targetState) {
                $togglePattern.Toggle()
                Write-LeftAligned "$FGCyan$Char_HeavyCheck Automatic Restart Sign-On toggled $(if($Reverse){'ON'}else{'OFF'}).$Reset"
            } else {
                Write-LeftAligned "$FGGray Already $(if($Reverse){'ON'}else{'OFF'}).$Reset"
            }
            $applied = $true
        }
        catch {
            Write-LeftAligned "$FGCyan$Char_Warn Toggle found but could not be set: $($_.Exception.Message)$Reset"
        }
        if ($applied) {
            if ($Reverse) { Remove-ItemProperty -Path "HKLM:\SOFTWARE\WinAuto" -Name "LastRun_ARSOOptOut" -Force -ErrorAction SilentlyContinue }
            else { Set-WinAutoLastRun -Module "ARSOOptOut" }
        }
    }

    try {
        $windowPattern = $window.GetCurrentPattern([System.Windows.Automation.WindowPattern]::Pattern)
        if ($windowPattern) { $windowPattern.Close() }
    } catch {}
}

function Invoke-WA_SetUIAnimations {
    <#
.SYNOPSIS
    Disables window minimize/maximize animations.
.LOCATION
    Settings > Accessibility > Visual effects
.DESCRIPTION
    Standardized for WinAuto.
    Sets MinAnimate in HKCU Control Panel\Desktop\WindowMetrics registry.
    Standalone version. Includes Reverse Mode (-r).
.PARAMETER Reverse
    (Alias: -r) Reverses the setting (Enables animations).
#>
    param(
        [Parameter(Mandatory = $false)]
        [Alias('r')]
        [switch]$Reverse
    )
    Write-Header "UI ANIMATIONS"
    $Path = "HKCU:\Control Panel\Desktop\WindowMetrics"
    $Name = "MinAnimate"
    $Value = if ($Reverse) { "1" } else { "0" }
    $ActionStr = if ($Reverse) { "ENABLED" } else { "DISABLED" }
    try {
        if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type String -Force -ErrorAction Stop
        Write-LeftAligned "$FGCyan$Char_HeavyCheck UI Animations are $ActionStr.$Reset"
    }
    catch { Write-WrappedError $_.Exception.Message }
}

function Invoke-WA_SetVisualEffects {
    <#
.SYNOPSIS
    Sets visual effects to 'Adjust for best performance'.
.LOCATION
    legacy Performance Options dialog (SystemPropertiesPerformance.exe), reached via Settings > System > About > Advanced system settings
.DESCRIPTION
    Standardized for WinAuto.
    Sets VisualFXSetting in HKCU Explorer\VisualEffects registry.
    Standalone version. Includes Reverse Mode (-r).
.PARAMETER Reverse
    (Alias: -r) Reverses the setting (Lets Windows choose).
#>
    param(
        [Parameter(Mandatory = $false)]
        [Alias('r')]
        [switch]$Reverse
    )
    Write-Header "VISUAL EFFECTS"
    $Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects"
    $Name = "VisualFXSetting"
    $Value = if ($Reverse) { 0 } else { 2 }
    $ActionStr = if ($Reverse) { "Let Windows choose" } else { "Best performance" }
    try {
        if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type DWord -Force -ErrorAction Stop
        Write-LeftAligned "$FGCyan$Char_HeavyCheck Visual Effects set to '$ActionStr'.$Reset"
    }
    catch { Write-WrappedError $_.Exception.Message }
}

# --- EMBEDDED ATOMIC SCRIPTS (Maintenance Part 4) ---



function Invoke-WA_OptimizeDisks {
    <#
.SYNOPSIS
    Optimizes all fixed disks (TRIM for SSD, Defrag for HDD).
.LOCATION
    legacy Optimize Drives dialog (dfrgui.exe), reached via Settings > System > Storage > Disks & volumes
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
        Write-LeftAligned "$FGGray$Char_Warn Reverse Mode: Disk optimization cannot be reversed.$Reset"
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
                Write-LeftAligned "  $FGCyan Type: SSD - Running TRIM...$Reset"
                Optimize-Volume -DriveLetter $drive -ReTrim | Out-Null
            }
            else {
                Write-LeftAligned "  $FGCyan Type: HDD - Running Defrag...$Reset"
                Optimize-Volume -DriveLetter $drive -Defrag | Out-Null
            }
            Write-LeftAligned "  $FGCyan$Char_HeavyCheck Optimization Complete.$Reset"
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
.LOCATION
    Settings > System > Storage > Temporary files
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
        Write-LeftAligned "$FGGray$Char_Warn Reverse Mode: File cleanup cannot be reversed.$Reset"
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
                        Write-LeftAligned "  $FGCyan$Char_BallotCheck Removed $c items.$Reset"
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
        Write-LeftAligned "$FGCyan$Char_HeavyCheck Cleanup Complete. Total items removed: $total$Reset"

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
.LOCATION
    none (console-only: sfc /scannow, DISM /Online /Cleanup-Image /RestoreHealth)
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
                Write-LeftAligned "$FGCyan$Char_BallotCheck System files are healthy.$Reset"
                return "SUCCESS"
            }
            elseif ($sfcOutput -match "found corrupt files and successfully repaired them") {
                Write-LeftAligned "$FGCyan$Char_BallotCheck Corrupt files were found and repaired.$Reset"
                return "REPAIRED"
            }
            elseif ($sfcOutput -match "found corrupt files but was unable to fix some of them") {
                Write-LeftAligned "$FGRed$Char_RedCross SFC found unfixable corruption.$Reset"
                return "FAILED"
            }
            else {
                Write-LeftAligned "$FGGray$Char_Warn SFC completed with unknown status.$Reset"
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
        Write-LeftAligned "$FGCyan Starting online image repair...$Reset"
        Write-LeftAligned "$FGGray This may take several minutes.$Reset"
    
        try {
            $dismOutput = & DISM /Online /Cleanup-Image /RestoreHealth 2>&1 | Out-String
        
            if ($dismOutput -match "The restore operation completed successfully") {
                Write-LeftAligned "$FGCyan$Char_BallotCheck DISM repair completed successfully.$Reset"
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
        Write-LeftAligned "$FGGray$Char_Warn Reverse Mode: System repairs cannot be reversed.$Reset"
        Write-Host ""
        return
    }

    $result = Invoke-SFCScan

    if ($result -eq "FAILED") {
        Write-Host ""
        Write-LeftAligned "$FGCyan Triggering DISM Repair to fix underlying component store...$Reset"
        $dismSuccess = Invoke-DISMRepair
    
        if ($dismSuccess) {
            Write-Host ""
            Write-LeftAligned "$FGCyan Re-running SFC to verify repairs...$Reset"
            Invoke-SFCScan | Out-Null
        }
    }

    Write-Host ""
    Write-Boundary
    Write-Centered "$FGCyan REPAIR FLOW COMPLETE $Reset" -Width 52
    Write-Boundary

}

# --- END OF EMBEDDING ---

# --- MAIN EXECUTION ---
# Ensure log directory exists
if (-not (Test-Path $Global:WinAutoLogDir)) { New-Item -Path $Global:WinAutoLogDir -ItemType Directory -Force | Out-Null }
Write-Log "AtomicScripts Standalone Session Started" -Level INFO

# --- CLI CONTROLLER ---
if ($Silent -or $Module) {
    if ($Module) { Write-Log "Starting CLI Mode (Module: $Module)" }
    else { Write-Log "Starting CLI Mode (Silent Default)" }

    if (-not $Module -and $Silent) { $Module = "SmartRun" }
    switch ($Module) {
        "SmartRun" {
            Invoke-WinAutoConfiguration -SmartRun
            Invoke-WinAutoMaintenance -SmartRun
            Set-WinAutoLastRun -Module "WinAuto"
        }
        "Config"      { Invoke-WinAutoConfiguration }
        "Maintenance" { Invoke-WinAutoMaintenance }
    }
    
    Write-Log "CLI Execution Complete."
    return
}

$Global:MenuSelection = 0  # Footer compatibility only: 0 = SmartRun focused, 1 = ManualMode / structured nav
# $Global:Toggle_MaintainForced is initialized at the top to support CLI/Silent mode

# --- Hierarchical navigation state ---
# NavLevel: 0 = Landing (SmartRun/ManualMode), 1 = Sections (CONFIGURE/MAINTAIN),
#           2 = CONFIGURE subcategories (Automation/Security/User Interface), 3 = Leaf items
$Global:NavLevel   = 0   # current navigation depth
$Global:LandingIdx = 0   # Level 0 cursor: 0 = SmartRun, 1 = ManualMode
$Global:SectionIdx = 0   # Level 1 cursor: 0 = CONFIGURE, 1 = MAINTAIN
$Global:SubcatIdx  = 0   # Level 2 cursor: 0 = Automation, 1 = Security, 2 = User Interface
$Global:ItemIdx    = 0   # Level 3 cursor: index within the focused item list

$Global:WinAutoFirstLoad = $true

while ($true) {

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
    
    try { $s_FW = Test-FirewallCompliant } catch { Write-Log -Message "[Discovery] Firewall check: $_" -Level "WARN"; $s_FW = $false }
    
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
    $s_Telemetry = (Get-WinAutoLastRun -Module "Telemetry") -ne "Never"
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

    # Extended hardening status check (security_audit.json parity)
    $s_Metered = (Get-WinAutoLastRun -Module "MeteredUpdates") -ne "Never"
    $s_ARSO = (Get-WinAutoLastRun -Module "ARSOOptOut") -ne "Never"
    $s_StoreSS = Test-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppHost" "EnableWebContentEvaluation" 1
    $s_Phish = (Get-WinAutoLastRun -Module "PhishingProtection") -ne "Never"
    $s_HideAdmin = Test-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\SpecialAccounts\UserList" "Administrator" 0
    $s_AdvID = Test-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo" "Enabled" 0
    $s_Anim = Test-Reg "HKCU:\Control Panel\Desktop\WindowMetrics" "MinAnimate" "0"
    $s_VisFX = Test-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" "VisualFXSetting" 2
    $s_RebootPending = $(
        (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending") -or
        (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired") -or
        ($null -ne (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" -Name "PendingFileRenameOperations" -ErrorAction SilentlyContinue))
    )

    # Classic Context Menu Check
    $ctxPath = "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32"
    $s_Ctx = $false
    if (Test-Path $ctxPath) {
        $val = (Get-ItemProperty $ctxPath)."(default)"
        if ($val -eq "") { $s_Ctx = $true }
    }

    # Sectional Pending State Detection
    $configActive = if ($false -eq $s_RT -or $false -eq $s_PUA -or $false -eq $s_Edge -or $false -eq $s_FW -or $false -eq $s_Ctx -or $false -eq $s_Task -or $false -eq $s_View -or $false -eq $s_MU -or $false -eq $s_Rest -or $false -eq $s_Pers -or $false -eq $s_Mem -or $false -eq $s_Kern -or $false -eq $s_LSA -or $false -eq $s_SS -or $false -eq $s_PSTrans -or $false -eq $s_Telemetry -or $false -eq $s_LLMNR -or $false -eq $s_PSScript -or $false -eq $s_PSModule -or $false -eq $s_NetBIOS -or $false -eq $s_ShowExt -or $false -eq $s_ShowHidden -or $false -eq $s_Metered -or $false -eq $s_ARSO -or $false -eq $s_StoreSS -or $false -eq $s_Phish -or $false -eq $s_HideAdmin -or $false -eq $s_AdvID -or $false -eq $s_Anim -or $false -eq $s_VisFX) { $true } else { $false }

    
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

    try { Clear-Host } catch {}
    Add-DashLine ""
    Write-Centered "${Global:FGBlack}${Global:BGDarkYellow}= ATOMIC SCRIPTS =${Reset}" -Width 52
    Write-Centered "${Global:FGWhite}- WinAuto -${Reset}" -Width 52
    
    # --- Derived navigation flags ---
    $onSmartRun  = ($Global:NavLevel -eq 0 -and $Global:LandingIdx -eq 0)
    $flatPreview = ($Global:NavLevel -eq 0 -and $Global:LandingIdx -eq 1)
    $structured  = ($Global:NavLevel -ge 1)
    $bodyShown   = (-not $onSmartRun)
    $Global:MenuSelection = if ($onSmartRun) { 0 } else { 1 }   # keep footer logic working

    # --- Menu data model (rebuilt each frame so $s_* live status is current) ---
    $autoItems = @(
        @{ Label = "Get Me Up To Date";    Met = "NX_SetGetMeUpToDate";   Status = $s_GetMe;     Toggle = "Toggle_GetMeUpToDate" }
        @{ Label = "Microsoft Update";     Met = "ST_SetMicrosoftUpd";    Status = $s_MU;        Toggle = "Toggle_MicrosoftUpd" }
        @{ Label = "Restart Notification"; Met = "ST_SetRestartIsReq";    Status = $s_Rest;      Toggle = "Toggle_RestartIsReq" }
        @{ Label = "App Restart Persist";  Met = "ST_SetRestartApps";     Status = $s_Pers;      Toggle = "Toggle_RestartApps" }
        @{ Label = "Metered Updates";      Met = "ST_SetMeteredUpdates";  Status = $s_Metered;   Toggle = "Toggle_MeteredUpdates" }
        @{ Label = "Auto Restart Sign-On"; Met = "ST_SetARSOOptOut";      Status = $s_ARSO;      Toggle = "Toggle_ARSOOptOut";     Invert = $true }
    )
    $secItems = @(
        @{ Label = "PS Transcription";     Met = "NX_SetPSTranscription"; Status = $s_PSTrans;   Toggle = "Toggle_PSTranscription" }
        @{ Label = "Windows Telemetry";    Met = "ST_SetTelemetry";       Status = $s_Telemetry; Toggle = "Toggle_Telemetry";  Invert = $true }
        @{ Label = "LLMNR Configuration";  Met = "NX_SetLLMNR";           Status = $s_LLMNR;     Toggle = "Toggle_LLMNR";      Invert = $true }
        @{ Label = "PS Script Block Log";  Met = "NX_SetPSScriptBlock";   Status = $s_PSScript;  Toggle = "Toggle_PSScriptBlock" }
        @{ Label = "PS Module Logging";    Met = "NX_SetPSModuleLogging"; Status = $s_PSModule;  Toggle = "Toggle_PSModuleLogging" }
        @{ Label = "NetBIOS over TCP/IP";  Met = "CP_SetNetBIOS";         Status = $s_NetBIOS;   Toggle = "Toggle_NetBIOS";    Invert = $true }
        @{ Label = "Real-Time Protection"; Met = "WS_SetRealTimeProt";    Status = $s_RT;        Toggle = "Toggle_RealTimeProt" }
        @{ Label = "Real-Time Prot (UI)"; Met = "WS_SetRealTimeProtUI";  Status = $s_RT;        Toggle = "Toggle_RealTimeProtUI" }
        @{ Label = "PUA Protection";       Met = "WS_SetPUABlockApps";    Status = $s_PUA;       Toggle = "Toggle_PUABlockApps" }
        @{ Label = "PUA Edge";             Met = "EG_SetPUABlockDLs";     Status = $s_Edge;      Toggle = "Toggle_PUABlockDLs" }
        @{ Label = "Memory Integrity";     Met = "WS_SetMemoryInteg";     Status = $s_Mem;       Toggle = "Toggle_MemoryInteg" }
        @{ Label = "Kernel Stack";         Met = "WS_SetKernelMode";      Status = $s_Kern;      Toggle = "Toggle_KernelMode" }
        @{ Label = "LSA Protection";       Met = "WS_SetLocalSecurity";   Status = $s_LSA;       Toggle = "Toggle_LocalSecurity" }
        @{ Label = "Windows Firewall";     Met = "WS_SetFirewallON";      Status = $s_FW;        Toggle = "Toggle_FirewallON" }
        @{ Label = "SmartScreen Filter";   Met = "WS_SetSmartScreenReg";  Status = $s_SS;        Toggle = "Toggle_SmartScreenReg" }
        @{ Label = "Store SmartScreen";    Met = "ST_SetStoreSmartScreen";Status = $s_StoreSS;   Toggle = "Toggle_StoreSmartScreen" }
        @{ Label = "Phishing Protection";  Met = "WS_SetPhishing";Status = $s_Phish;   Toggle = "Toggle_PhishingProtection" }
        @{ Label = "Hide Admin Account";   Met = "NX_SetHideAdmin";       Status = $s_HideAdmin; Toggle = "Toggle_HideAdmin";      Invert = $true }
        @{ Label = "Advertising ID";      Met = "ST_SetAdvertisingID";   Status = $s_AdvID;     Toggle = "Toggle_AdvertisingID";  Invert = $true }
    )
    $uiItems = @(
        @{ Label = "Classic Context Menu"; Met = "NX_SetClassicMenu";     Status = $s_Ctx;       Toggle = "Toggle_ClassicMenu" }
        @{ Label = "Taskbar Search Box";   Met = "ST_SetTaskbarSearch";   Status = $s_Task;      Toggle = "Toggle_TaskbarSearch" }
        @{ Label = "Task View Toggle";     Met = "ST_SetTaskViewOFF";     Status = $s_View;      Toggle = "Toggle_TaskView";   Invert = $true }
        @{ Label = "Show Hidden Files";    Met = "FE_SetShowHidden";      Status = $s_ShowHidden;Toggle = "Toggle_ShowHidden" }
        @{ Label = "Show File Extensions"; Met = "FE_SetShowExtensions";  Status = $s_ShowExt;   Toggle = "Toggle_ShowExtensions" }
        @{ Label = "UI Animations";        Met = "ST_SetUIAnimations";    Status = $s_Anim;      Toggle = "Toggle_UIAnimations";  Invert = $true }
        @{ Label = "Visual Effects";       Met = "CP_SetVisualEffects";   Status = $s_VisFX;     Toggle = "Toggle_VisualEffects" }
    )
    $subcats = @(
        @{ Label = "Automation";     Items = $autoItems }
        @{ Label = "Security";       Items = $secItems }
        @{ Label = "User Interface"; Items = $uiItems }
    )
    $maintModel = @(
        @{ Label = "Get Updates";        Met = "ST_RunUpdateSuite";   MKey = "Maintenance_WinUpdate"; Threshold = 30; AlwaysRun = $true; Toggle = "Toggle_MaintUpdate" }
        @{ Label = "Drive Optimization"; Met = "CP_RunOptimizeDisks"; MKey = "Maintenance_Disk";      Threshold = 30; AlwaysRun = $false; Toggle = "Toggle_MaintDisk" }
        @{ Label = "Temp File Cleanup";  Met = "ST_RunSystemCleanup"; MKey = "Maintenance_Cleanup";   Threshold = 30; AlwaysRun = $false; Toggle = "Toggle_MaintCleanup" }
        @{ Label = "SFC / DISM Repair";  Met = "NX_RunWindowsRepair"; MKey = "Maintenance_SFC";       Threshold = 30; AlwaysRun = $false; Toggle = "Toggle_MaintSFC" }
    )

    $padding = if ($bodyShown) { "" } else { "`n`n`n`n" }
    Add-DashLine $padding

    # --- LANDING PAGE OPTIONS (SmartRun / ManualMode) ---
    if ($onSmartRun) {
        Write-Centered "${Global:FGCyan}->|SmartRun|<-${Reset}" -Width 52
        Add-DashLine ""
        Write-Centered "${Global:FGGray} |ManualMode| ${Reset}" -Width 52
    }
    else {
        # ManualMode selected (flat preview) or navigating the structured tree
        Write-Centered "${Global:FGGray} |SmartRun| ${Reset}" -Width 52
        Add-DashLine ""
        Write-Centered "${Global:FGCyan}->|ManualMode|<-${Reset}" -Width 52
    }

    if ($bodyShown) {
        # ===================== CONFIGURE =====================
        $configFocused = ($structured -and $Global:SectionIdx -eq 0)
        $configBoundColor = if ($configFocused) { $Global:FGCyan } else { $Global:FGGray }
        Write-Boundary -Color $configBoundColor

        # Section headers are left-aligned to a common column so CONFIGURE and
        # MAINTAIN line up vertically; the >|/v| focus marker sits in the 2-col gutter.
        $hdrCol = 23; $hdrGutter = $hdrCol - 2
        if ($flatPreview) {
            Add-DashLine ((" " * $hdrCol) + "${Global:FGWhite}CONFIGURE${Reset}")
        } elseif ($configFocused -and $Global:NavLevel -eq 1) {
            Add-DashLine ((" " * $hdrGutter) + "${Global:FGCyan}>|CONFIGURE|<${Reset}")
        } elseif ($configFocused -and $Global:NavLevel -ge 2) {
            Add-DashLine ((" " * $hdrGutter) + "${Global:FGCyan}v|${Global:FGBlack}${Global:BGCyan}CONFIGURE${Reset}${Global:FGCyan}|v${Reset}")
        } else {
            Add-DashLine ((" " * $hdrCol) + "${Global:FGWhite}CONFIGURE${Reset}")
        }

        if ($flatPreview) {
            # Flat dump: every config item, no subcategory headers, nothing highlighted.
            # Optional (default-OFF) steps are listed first, then default-ON steps.
            # Ordering is fixed by each step's DEFAULT toggle value, not its live/current
            # value, so items don't jump around the list as the user flips toggles
            # elsewhere (e.g. in the accordion view) and returns to this screen.
            Add-DashLine ""
            Write-LeftAligned "${FGDarkGray}[${FGDarkGray}v${FGDarkGray}] ${FGWhite}Enabled ${FGDarkGray}[ ] ${FGWhite}Disabled ${FGDarkGray}|${FGWhite} Atomic Script$Reset" -Indent 2
            Add-DashLine ("  ${FGDarkGray}$('-' * 52)${Reset}")
            $optionalToggles = @(
                'Toggle_GetMeUpToDate', 'Toggle_MeteredUpdates', 'Toggle_ARSOOptOut',
                'Toggle_PSTranscription', 'Toggle_Telemetry', 'Toggle_LLMNR', 'Toggle_PSScriptBlock', 'Toggle_PSModuleLogging', 'Toggle_NetBIOS', 'Toggle_RealTimeProtUI', 'Toggle_SmartScreenReg', 'Toggle_HideAdmin', 'Toggle_AdvertisingID',
                'Toggle_ClassicMenu', 'Toggle_TaskbarSearch', 'Toggle_TaskView', 'Toggle_ShowHidden', 'Toggle_ShowExtensions', 'Toggle_UIAnimations', 'Toggle_VisualEffects'
            )
            $flatAll = foreach ($sc in $subcats) { foreach ($it in $sc.Items) { $it } }
            $flatOrdered = @($flatAll | Where-Object { $_.Toggle -in $optionalToggles }) + @($flatAll | Where-Object { $_.Toggle -notin $optionalToggles })
            foreach ($it in $flatOrdered) {
                $tv = Get-Variable -Name $it.Toggle -Scope Global -ValueOnly
                Write-ColItem $it.Label $it.Met $it.Status -IsToggle -ToggleValue $tv -IsSelected $false -IsDisableAction ([bool]$it['Invert'])
            }
            Add-DashLine ""
        }
        elseif ($configFocused) {
            # Accordion: 3 subcategory headers; the focused one expands with its items
            Add-DashLine ""
            $configExpanded = ($Global:NavLevel -ge 2)
            for ($si = 0; $si -lt $subcats.Count; $si++) {
                $sc = $subcats[$si]
                $isOpen = ($configExpanded -and $Global:SubcatIdx -eq $si)
                # Center the subcategory NAME; the "> " selection marker sits in the
                # gutter to its left so the name stays put whether or not it is selected.
                $subNameLead = [int][Math]::Floor((52 - $sc.Label.Length) / 2) + 2
                if ($isOpen) {
                    Add-DashLine ((" " * ($subNameLead - 2)) + "${Global:FGCyan}> $($sc.Label)${Reset}")
                    Add-DashLine ""
                    Write-LeftAligned "${FGDarkGray}[${FGDarkGray}v${FGDarkGray}] ${FGWhite}Enabled ${FGDarkGray}[ ] ${FGWhite}Disabled ${FGDarkGray}|${FGWhite} Atomic Script$Reset" -Indent 2
                    Add-DashLine ("  ${FGDarkGray}$('-' * 52)${Reset}")
                    for ($ii = 0; $ii -lt $sc.Items.Count; $ii++) {
                        $it = $sc.Items[$ii]
                        $tv = Get-Variable -Name $it.Toggle -Scope Global -ValueOnly
                        $sel = ($Global:NavLevel -eq 3 -and $Global:SubcatIdx -eq $si -and $Global:ItemIdx -eq $ii)
                        Write-ColItem $it.Label $it.Met $it.Status -IsToggle -ToggleValue $tv -IsSelected $sel -IsDisableAction ([bool]$it['Invert'])
                    }
                } else {
                    Add-DashLine ((" " * $subNameLead) + "${Global:FGWhite}$($sc.Label)${Reset}")
                }
                if ($configExpanded) { Add-DashLine "" }
            }
            if (-not $configExpanded) { Add-DashLine "" }
        }
        # (When MAINTAIN is the focused section, CONFIGURE shows only its bare header above.)

        # ===================== MAINTAIN =====================
        $maintFocused = ($structured -and $Global:SectionIdx -eq 1)
        $maintBoundColor = if ($maintFocused) { $Global:FGCyan } else { $Global:FGGray }
        Write-Boundary -Color $maintBoundColor

        if ($flatPreview) {
            Add-DashLine ((" " * $hdrCol) + "${Global:FGWhite}MAINTAIN${Reset}")
        } elseif ($maintFocused -and $Global:NavLevel -eq 1) {
            Add-DashLine ((" " * $hdrGutter) + "${Global:FGCyan}>|MAINTAIN|<${Reset}")
        } elseif ($maintFocused -and $Global:NavLevel -ge 3) {
            Add-DashLine ((" " * $hdrGutter) + "${Global:FGCyan}v|${Global:FGBlack}${Global:BGCyan}MAINTAIN${Reset}${Global:FGCyan}|v${Reset}")
        } else {
            Add-DashLine ((" " * $hdrCol) + "${Global:FGWhite}MAINTAIN${Reset}")
        }

        if ($flatPreview -or $maintFocused) {
            Add-DashLine ""
            Write-LeftAligned "${FGDarkGray}[${FGWhite}#${FGDarkGray}]${FGWhite} Days Since Last Ran  ${FGDarkGray}|${FGWhite} Atomic Script$Reset" -Indent 2
            Add-DashLine ("  ${FGDarkGray}$('-' * 52)${Reset}")
            for ($mi = 0; $mi -lt $maintModel.Count; $mi++) {
                $m = $maintModel[$mi]
                $tv = Get-Variable -Name $m.Toggle -Scope Global -ValueOnly
                $sel = ($maintFocused -and $Global:NavLevel -eq 3 -and $Global:ItemIdx -eq $mi)
                Write-MaintItem $m.Label $m.Met $m.MKey -Threshold $m.Threshold -ToggleValue $tv -IsSelected $sel -AlwaysRun:([bool]$m.AlwaysRun)
            }
        }
        Add-DashLine ""
        Add-DashLine ""
    } else {
        Add-DashLine ""
        Add-DashLine ""
        Add-DashLine ""
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

    # --- NAVIGATION LOGIC (hierarchical) ---
    $onSmartRun = ($Global:NavLevel -eq 0 -and $Global:LandingIdx -eq 0)
    $itemCount = if ($Global:SectionIdx -eq 0) { $subcats[$Global:SubcatIdx].Items.Count } else { $maintModel.Count }

    if ($res.VirtualKeyCode -eq 38 -or $res.VirtualKeyCode -eq 40) {
        # Up / Down -> move within the current level (wraps)
        $dir = if ($res.VirtualKeyCode -eq 38) { -1 } else { 1 }
        switch ($Global:NavLevel) {
            0 { $Global:LandingIdx = ($Global:LandingIdx + $dir + 2) % 2; break }
            1 { $Global:SectionIdx = ($Global:SectionIdx + $dir + 2) % 2; break }
            2 { $Global:SubcatIdx  = ($Global:SubcatIdx + $dir + 3) % 3; break }
            3 { $Global:ItemIdx    = ($Global:ItemIdx + $dir + $itemCount) % $itemCount; break }
        }
        continue
    }
    elseif ($res.VirtualKeyCode -eq 39 -or $res.VirtualKeyCode -eq 37) {
        # Left / Right -> reserved
        continue
    }
    elseif ($res.VirtualKeyCode -eq 27) {
        # Esc -> ascend one level (exit only from SmartRun)
        if ($Global:NavLevel -eq 0 -and $Global:LandingIdx -eq 0) {
            Write-Host ""
            Write-LeftAligned "$FGGray Exiting..$Reset"
            Start-Sleep -Seconds 1
            break
        }
        if ($Global:NavLevel -eq 0) {
            $Global:LandingIdx = 0
        }
        elseif ($Global:NavLevel -eq 1) {
            $Global:NavLevel = 0; $Global:LandingIdx = 1
        }
        elseif ($Global:NavLevel -eq 2) {
            $Global:NavLevel = 1; $Global:SectionIdx = 0
        }
        elseif ($Global:NavLevel -eq 3) {
            if ($Global:SectionIdx -eq 0) { $Global:NavLevel = 2 }
            else { $Global:NavLevel = 1; $Global:SectionIdx = 1 }
        }
        continue
    }
    elseif ($res.VirtualKeyCode -eq 13) {
        # Enter Action Logic (Runs SmartRun or ManualMode)
        if ($onSmartRun) {
            # [S]mart Run -> EXECUTE
            Invoke-WinAutoConfiguration -SmartRun
            Set-WinAutoLastRun -Module "Configuration"
            Invoke-WinAutoMaintenance -SmartRun
            Start-Sleep -Milliseconds 200
        }
        else {
            # MANUAL-MODE -> Run Configure + Maintain, all steps forced (no SmartRun)
            Invoke-WinAutoConfiguration
            Set-WinAutoLastRun -Module "Configuration"
            Invoke-WinAutoMaintenance
            Start-Sleep -Milliseconds 200
        }
        Set-WinAutoLastRun -Module "WinAuto"

        # Post-Execution Audit (Generate JSON)
        $AuditData = [PSCustomObject]@{
            Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            Session   = "Interactive"
            RebootPending = $s_RebootPending
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
                RealTimeProtUI = $Global:Toggle_RealTimeProtUI;
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
                ShowHidden = $Global:Toggle_ShowHidden;
                SmartScreenReg = $Global:Toggle_SmartScreenReg;
                StoreSmartScreen = $Global:Toggle_StoreSmartScreen;
                PhishingProtection = $Global:Toggle_PhishingProtection;
                HideAdmin = $Global:Toggle_HideAdmin;
                AdvertisingID = $Global:Toggle_AdvertisingID;
                MeteredUpdates = $Global:Toggle_MeteredUpdates;
                ARSOOptOut = $Global:Toggle_ARSOOptOut;
                UIAnimations = $Global:Toggle_UIAnimations;
                VisualEffects = $Global:Toggle_VisualEffects
            }
            Maint     = @{ Update = $Global:Toggle_MaintUpdate; Disk = $Global:Toggle_MaintDisk; Cleanup = $Global:Toggle_MaintCleanup; SFC = $Global:Toggle_MaintSFC }
        }
        $AuditData | ConvertTo-Json | Out-File "$Global:WinAutoLogDir\PostRunAudit.json"

        try { Clear-Host } catch {}
        continue
    }
    elseif ($res.Character -eq ' ' -or $res.VirtualKeyCode -eq 32) {
        # Space -> descend a level, or flip the focused leaf toggle
        switch ($Global:NavLevel) {
            0 {
                # Only ManualMode toggles into the structured view
                if ($Global:LandingIdx -eq 1) {
                    $Global:NavLevel = 1
                    $Global:SectionIdx = 0
                }
                break
            }
            1 {
                if ($Global:SectionIdx -eq 0) {
                    $Global:NavLevel = 2; $Global:SubcatIdx = 0
                } else {
                    $Global:NavLevel = 3; $Global:ItemIdx = 0
                }
                break
            }
            2 {
                $Global:NavLevel = 3; $Global:ItemIdx = 0
                break
            }
            3 {
                # Flip the focused leaf's pending-action toggle
                if ($Global:SectionIdx -eq 0) {
                    $name = $subcats[$Global:SubcatIdx].Items[$Global:ItemIdx].Toggle
                } else {
                    $name = $maintModel[$Global:ItemIdx].Toggle
                }
                $cur = Get-Variable -Name $name -Scope Global -ValueOnly
                Set-Variable -Name $name -Scope Global -Value $(if ($cur -eq 1) { 0 } else { 1 })
                break
            }
        }
        # Pause slightly if we toggled
        Start-Sleep -Milliseconds 150
        continue
    }
    else {
        # Any other key loop back
        Start-Sleep -Milliseconds 100
        continue
    }
}

Write-Log "Interactive Execution Complete."


