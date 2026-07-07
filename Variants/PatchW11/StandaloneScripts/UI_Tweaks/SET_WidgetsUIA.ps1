#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Toggles Windows 11 Widgets via UI Automation.
.DESCRIPTION
    Bypasses registry write locks by automating the 'ms-settings:taskbar' GUI.
#>

param(
    [switch]$Undo
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
        [System.Windows.Automation.ControlType]$ControlType,
        [int]$TimeoutSeconds = 10
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
        $Result = $Parent.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $Condition)
        if ($Result) { return $Result }
        Start-Sleep -Milliseconds 500
    }
    return $null
}


;'WARNING'{$FGYellow};'SUCCESS'{$FGGreen};Default{$FGGray}}; Write-LeftAligned "$c$Message$Reset" }

Write-Header "TASKBAR WIDGETS"

# --- UIA PREPARATION ---
if (-not ([System.Management.Automation.PSTypeName]"System.Windows.Automation.AutomationElement").Type) {
    try {
        Add-Type -AssemblyName UIAutomationClient
        Add-Type -AssemblyName UIAutomationTypes
    }
    catch {}
}

# Local UIA Helper (Consistent with wa.ps1)
function Get-UIAElement {
    param(
        [System.Windows.Automation.AutomationElement]$Parent,
        [string]$Name,
        [System.Windows.Automation.ControlType]$ControlType,
        [int]$TimeoutSeconds = 10
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
        $Result = $Parent.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $Condition)
        if ($Result) { return $Result }
        Start-Sleep -Milliseconds 500
    }
    return $null
}

# --- MAIN LOGIC ---

function Invoke-WA_SetWidgetsUIA {
    param([switch]$Undo)
    
    # 1. Launch Taskbar Settings
    Write-LeftAligned "Launching Taskbar Settings..."
    try {
        Start-Process "ms-settings:taskbar"
    }
    catch {
        Write-LeftAligned "$FGRed$Char_RedCross Failed to launch Settings: $($_.Exception.Message)$Reset"
        return
    }
    
    Start-Sleep -Seconds 3

    $Desktop = [System.Windows.Automation.AutomationElement]::RootElement
    $Window = $null
    
    # Locate Settings Window
    Write-LeftAligned "Searching for Settings window..."
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 15) {
        foreach ($title in @("Settings", "ParamÃ¨tres", "Einstellungen")) {
            $Window = $Desktop.FindFirst([System.Windows.Automation.TreeScope]::Children, 
                (New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty, $title)))
            if ($Window) { break }
        }
        if ($Window) { break }
        Start-Sleep -Seconds 1
    }

    if ($Window) {
        try { $Window.SetFocus() } catch {}
        Start-Sleep -Seconds 1
        
        # 2. Find the Widgets Toggle
        # Group/Button name is 'Widgets' typically
        Write-LeftAligned "Searching for 'Widgets' toggle..." ($FGGray)
        $Toggle = Get-UIAElement -Parent $Window -Name "Widgets" -ControlType "Button" -TimeoutSeconds 5
        
        # Fallback: Sometimes it's inside a group named Widgets
        if (-not $Toggle) {
            $Group = Get-UIAElement -Parent $Window -Name "Widgets" -ControlType "Group" -TimeoutSeconds 2
            if ($Group) {
                $Toggle = Get-UIAElement -Parent $Group -ControlType "Button" -TimeoutSeconds 2
            }
        }
        
        if ($Toggle) {
            try {
                # Attempt to use TogglePattern
                $Pattern = $Toggle.GetCurrentPattern([System.Windows.Automation.TogglePattern]::Pattern)
                $CurrentState = $Pattern.Current.ToggleState # 0=Off, 1=On
                $DesiredState = if ($Undo) { 1 } else { 0 } # Default to OFF

                if ($CurrentState -ne $DesiredState) {
                    $Pattern.Toggle()
                    $StateStr = if ($DesiredState -eq 0) { 'OFF' } else { 'ON' }
                    Write-LeftAligned "$FGGreen$Char_HeavyCheck Successfully toggled Widgets to $StateStr.$Reset"
                }
                else {
                    $StateStr = if ($CurrentState -eq 0) { 'OFF' } else { 'ON' }
                    Write-LeftAligned "$FGGreen$Char_BallotCheck Widgets already in desired state ($StateStr).$Reset"
                }
            }
            catch {
                # Fallback to Invoke
                try {
                    $Invoke = $Toggle.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern)
                    $Invoke.Invoke()
                    Write-LeftAligned "$FGGreen$Char_HeavyCheck Invoked toggle click (Fallback).$Reset"
                }
                catch {
                    Write-LeftAligned "$FGRed$Char_RedCross Failed to toggle: $($_.Exception.Message)$Reset"
                }
            }
        }
        else {
            Write-LeftAligned "$FGRed$Char_RedCross Could not find 'Widgets' toggle button.$Reset"
        }
    }
    else {
        Write-LeftAligned "$FGRed$Char_RedCross Could not find Settings window.$Reset"
    }
    
    # 3. Cleanup
    Start-Sleep -Seconds 2
    Stop-Process -Name "SystemSettings" -Force -ErrorAction SilentlyContinue
    
    Write-Host ""
    Write-Boundary
}

Invoke-WA_SetWidgetsUIA -Undo:$Undo