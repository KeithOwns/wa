#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Click the "Turn on" button under "App & browser control" via UI Automation.
.DESCRIPTION
    Launches Windows Security to the App & browser control page, locates the "Turn on" button, and attempts to invoke it.
    Useful as an atomic script to enforce security settings when registry access is locked or hidden.
#>

param(
    [switch]$Undo # Unused for this specific "Turn on" action, but kept for signature consistency if needed
)

# --- STANDALONE UI & LOGGING RESOURCES ---
$Esc = [char]0x1B
$Reset = "$Esc[0m"
$Bold = "$Esc[1m"
$FGCyan = "$Esc[96m"; $FGGreen = "$Esc[92m"; $FGRed = "$Esc[91m"; $FGYellow = "$Esc[93m"; $FGWhite = "$Esc[97m"; $FGGray = "$Esc[37m"; $FGDarkGray = "$Esc[90m"; $FGDarkBlue = "$Esc[34m"; $BGYellow = "$Esc[103m"; $FGBlack = "$Esc[30m"
$Char_Warn = [char]0x26A0; $Char_BallotCheck = [char]0x2611; $Char_Keyboard = [char]0x2328; $Char_Loop = [char]::ConvertFromUtf32(0x1F504); $Char_Copyright = [char]0x00A9; $Char_Finger = [char]0x261B; $Char_HeavyCheck = [char]0x2705; $Char_RedCross = [char]0x2716; $Char_HeavyMinus = [char]0x2796; $Char_Skip = [char]0x23ED

function Write-Boundary { param([string]$Color = $FGDarkBlue) Write-Host "$Color$([string]'_' * 60)$Reset" }
function Write-LeftAligned { param([string]$Text, [int]$Indent = 2) Write-Host (" " * $Indent + $Text) }
function Write-Centered { param([string]$Text, [int]$Width = 60) $clean = $Text -replace "\x1B\[[0-9;]*m", ""; $pad = [Math]::Floor(($Width - $clean.Length) / 2); if ($pad -lt 0) { $pad = 0 }; Write-Host (" " * $pad + $Text) }
function Write-Header { param([string]$Title) Clear-Host; Write-Host ""; $t1 = "$([char]::ConvertFromUtf32(0x1FA9F)) WinAuto $Char_Loop"; Write-Centered "$Bold$FGCyan$t1$Reset"; Write-Boundary; Write-Centered "$Bold$FGCyan$($Title.ToUpper())$Reset"; Write-Boundary }
function Invoke-AnimatedPause { param([string]$ActionText = "CONTINUE", [int]$Timeout = 10) Write-Host ""; $top = [Console]::CursorTop; $StopWatch = [System.Diagnostics.Stopwatch]::StartNew(); while ($StopWatch.Elapsed.TotalSeconds -lt $Timeout) { if ([Console]::KeyAvailable) { $StopWatch.Stop(); return $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") }; $Elapsed = $StopWatch.Elapsed; $Filled = [Math]::Floor($Elapsed.TotalSeconds); $Dynamic = ""; for ($i=0;$i-lt 10;$i++) { $c = if ($i -lt 5) { "Enter"[$i] } else { " " }; if ($i -lt $Filled) { $Dynamic += "${BGYellow}${FGBlack}$c${Reset}" } else { $Dynamic += "${FGYellow}$c${Reset}" } }; Write-Centered "${FGWhite}$Char_Keyboard Press ${FGDarkGray}$Dynamic${FGDarkGray}${FGWhite} to ${FGYellow}$ActionText${FGDarkGray} | or SKIP$Char_Skip${Reset}"; try { [Console]::SetCursorPosition(0, $top) } catch {}; Start-Sleep -Milliseconds 100 }; $StopWatch.Stop(); return [PSCustomObject]@{VirtualKeyCode=13} }
function Write-Log { param([string]$Message, [string]$Level = 'INFO') $c = switch($Level){'ERROR'{$FGRed};'WARNING'{$FGYellow};'SUCCESS'{$FGGreen};Default{$FGGray}}; Write-LeftAligned "$c$Message$Reset" }

function Get-UIAElement {
    param(
        [System.Windows.Automation.AutomationElement]$Parent,
        [string]$Name,
        [string]$AutomationId,
        [string]$ControlType
    )
    
    $conditions = @()
    if ($Name) { $conditions += New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty, $Name) }
    if ($AutomationId) { $conditions += New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::AutomationIdProperty, $AutomationId) }
    if ($ControlType) { 
        # Convert string to ControlType object (e.g. "Button" -> [System.Windows.Automation.ControlType]::Button)
        $ct = [System.Windows.Automation.ControlType]::$ControlType
        $conditions += New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, $ct)
    }

    if ($conditions.Count -eq 0) { return $null }

    if ($conditions.Count -eq 1) {
        $finalCondition = $conditions[0]
    } else {
        $finalCondition = New-Object System.Windows.Automation.AndCondition($conditions)
    }

    return $Parent.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $finalCondition)
}


#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Click the "Turn on" button under "App & browser control" via UI Automation.
.DESCRIPTION
    Launches Windows Security to the App & browser control page, locates the "Turn on" button, and attempts to invoke it.
    Useful as an atomic script to enforce security settings when registry access is locked or hidden.
#>

param(
    [switch]$Undo # Unused for this specific "Turn on" action, but kept for signature consistency if needed
)

# --- UIA PREPARATION ---
if (-not ([System.Management.Automation.PSTypeName]"System.Windows.Automation.AutomationElement").Type) {
    try {
        Add-Type -AssemblyName UIAutomationClient
        Add-Type -AssemblyName UIAutomationTypes
    }
    catch {
        Write-Host "[!] Failed to load UIAutomation assemblies." -ForegroundColor Red
        exit
    }
}

# Local UIA Helper
function Get-UIAElement {
    param(
        [System.Windows.Automation.AutomationElement]$Parent,
        [string]$Name,
        [string]$AutomationId,
        [string]$ControlType
    )
    
    $conditions = @()
    if ($Name) { $conditions += New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty, $Name) }
    if ($AutomationId) { $conditions += New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::AutomationIdProperty, $AutomationId) }
    if ($ControlType) { 
        # Convert string to ControlType object (e.g. "Button" -> [System.Windows.Automation.ControlType]::Button)
        $ct = [System.Windows.Automation.ControlType]::$ControlType
        $conditions += New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, $ct)
    }

    if ($conditions.Count -eq 0) { return $null }

    if ($conditions.Count -eq 1) {
        $finalCondition = $conditions[0]
    } else {
        $finalCondition = New-Object System.Windows.Automation.AndCondition($conditions)
    }

    return $Parent.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $finalCondition)
}

function Invoke-WA_TurnOnAppBrowserControl {
    
    Write-Host "[*] Launching Windows Security (App & browser control)..." -ForegroundColor Cyan
    try {
        Start-Process "windowsdefender://appbrowser"
    }
    catch {
        Write-Host "[X] Failed to launch Windows Security: $($_.Exception.Message)" -ForegroundColor Red
        return
    }
    
    Start-Sleep -Seconds 3

    $Desktop = [System.Windows.Automation.AutomationElement]::RootElement
    $Window = $null
    
    # Locate Windows Security Window
    Write-Host "[*] Searching for Windows Security window..." -ForegroundColor Gray
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 15) {
        $Window = Get-UIAElement -Parent $Desktop -Name "Windows Security" -ControlType "Window"
        if ($Window) { break }
        Start-Sleep -Seconds 1
    }

    if ($Window) {
        try { $Window.SetFocus() } catch {}
        Start-Sleep -Seconds 1
        
        Write-Host "[*] Searching for 'Turn on' button..." -ForegroundColor Gray
        
        # Typically, the button is named "Turn on" or has a specific AutomationId depending on OS version
        $TurnOnBtn = Get-UIAElement -Parent $Window -Name "Turn on" -ControlType "Button"
        
        if ($TurnOnBtn) {
            try {
                $InvokePattern = $TurnOnBtn.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern)
                $InvokePattern.Invoke()
                Write-Host "[V] Successfully clicked 'Turn on' button." -ForegroundColor Green
            }
            catch {
                Write-Host "[X] Found button but failed to click it: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
        else {
            Write-Host "[!] Could not find 'Turn on' button. It might already be turned on, or the UI layout differs." -ForegroundColor Yellow
        }
        
    }
    else {
        Write-Host "[X] Could not find Windows Security window." -ForegroundColor Red
    }
    
    # Cleanup / Let user observe before closing (optional)
    Start-Sleep -Seconds 2
    # Stop-Process -Name "SecHealthUI" -Force -ErrorAction SilentlyContinue # Optional auto-close
}

Invoke-WA_TurnOnAppBrowserControl
