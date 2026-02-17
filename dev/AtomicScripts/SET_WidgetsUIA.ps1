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

# --- SHARED FUNCTIONS ---
. "$PSScriptRoot\..\Shared\Shared_UI_Functions.ps1"

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
        foreach ($title in @("Settings", "Paramètres", "Einstellungen")) {
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
