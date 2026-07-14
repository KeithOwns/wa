#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Enables 'Kernel-mode Hardware-enforced Stack Protection' in Windows Security via UI Automation.
.DESCRIPTION
    Launches Windows Security, navigates to Device Security > Core Isolation,
    and attempts to toggle 'Kernel-mode Hardware-enforced Stack Protection' to On.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Load .NET UIAutomation Assemblies
try {
    Add-Type -AssemblyName UIAutomationClient
    Add-Type -AssemblyName UIAutomationTypes
} catch {
    Write-Error "Failed to load UIAutomation assemblies. Ensure .NET Framework is installed."
    exit 1
}

# --- HELPER FUNCTIONS ---

function Write-Log {
    param(
        [string]$Message,
        [ConsoleColor]$Color = "White"
    )
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $Message" -ForegroundColor $Color
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
    } elseif ($Name) {
        New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty, $Name)
    } elseif ($ControlType) {
        New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, $ControlType)
    } else {
        throw "Must provide Name or ControlType"
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
    
    # Try Invoke Pattern (Buttons, Links)
    try {
        $InvokePattern = $Element.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern)
        $InvokePattern.Invoke()
        return $true
    } catch {
        # Try Toggle Pattern (Switches)
        try {
            $TogglePattern = $Element.GetCurrentPattern([System.Windows.Automation.TogglePattern]::Pattern)
            $TogglePattern.Toggle()
            return $true
        } catch {
            try {
                # Fallback: SelectionItem (Tabs/Nav items)
                $SelectionItem = $Element.GetCurrentPattern([System.Windows.Automation.SelectionItemPattern]::Pattern)
                $SelectionItem.Select()
                return $true
            } catch {
                 Write-Log "Failed to invoke/toggle/select element: $_" "Red"
                 return $false
            }
        }
    }
}

function Get-UIAToggleState {
    param([System.Windows.Automation.AutomationElement]$Element)
    try {
        $p = $Element.GetCurrentPattern([System.Windows.Automation.TogglePattern]::Pattern)
        return $p.Current.ToggleState # On, Off, Indeterminate
    } catch { return $null }
}

# --- MAIN SCRIPT ---

Write-Log "Starting Windows Security Automation (Kernel-mode Stack Protection)..." "Cyan"

$MaxRetries = 5
$RetryCount = 0
$Success = $false

while (-not $Success -and ($RetryCount -lt $MaxRetries)) {
    $RetryCount++
    
    # 1. Launch / Relaunch Windows Security
    Write-Log "Launching Windows Security (Iteration $RetryCount)..." "Gray"
    
    Stop-Process -Name "SecHealthUI" -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
    
    Start-Process "windowsdefender:"
    Start-Sleep -Seconds 3

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
    } else {
        Write-Log "Could not find 'Device security' navigation item." "Red"
        continue
    }

    # 4. Navigate to "Core isolation details"
    Write-Log "Navigating to 'Core isolation details'..." "Gray"
    $CoreIsoLink = Get-UIAElement -Parent $Window -Name "Core isolation details" -Scope "Descendants" -TimeoutSeconds 5
    
    if ($CoreIsoLink) {
        Invoke-UIAElement -Element $CoreIsoLink | Out-Null
        Start-Sleep -Seconds 2
    } else {
        Write-Log "Could not find 'Core isolation details' link. Checking if already there..." "Yellow"
    }

    # 5. Find Target Toggle
    Write-Log "Looking for 'Kernel-mode Hardware-enforced Stack Protection' toggle..." "Gray"

    # Strategy: Find ALL elements with this name, then pick the one that is actionable (Toggle/Button)
    $Condition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty, "Kernel-mode Hardware-enforced Stack Protection")
    $AllElements = $Window.FindAll([System.Windows.Automation.TreeScope]::Descendants, $Condition)

    $TargetToggle = $null
    
    foreach ($El in $AllElements) {
        $Type = $El.Current.ControlType
        $TypeName = $Type.ProgrammaticName
        
        # We want to ignore Text labels. We want CheckBox, Button, or potentially Group if it acts as a container.
        if ($Type -ne [System.Windows.Automation.ControlType]::Text) {
             Write-Log "Found candidate element of type: $TypeName" "Gray"
             $TargetToggle = $El
             break
        }
    }

    if (-not $TargetToggle) {
        # Fallback: Sometimes the name is slightly different or it's a generic "On" switch next to the label?
        # But our dump confirmed the name is exact.
        # Let's try finding by ControlType CheckBox only if we can narrow scope? 
        # No, that's risky.
        
        Write-Log "Could not identify the specific Toggle element (only found labels?)." "Red"
    }
    
    if ($TargetToggle) {
        Write-Log "Found Target Element. Checking state..." "Cyan"
        $State = Get-UIAToggleState -Element $TargetToggle
        
        # Mapping: 0=Off, 1=On, 2=Indeterminate
        if ($State -eq 1) {
             Write-Log "Feature is already ON." "Green"
             $Success = $true
        } elseif ($State -eq 0) {
             Write-Log "Feature is OFF. Toggling ON..." "Cyan"
             if (Invoke-UIAElement -Element $TargetToggle) {
                 Write-Log "Toggled. Waiting for update..." "Green"
                 Start-Sleep -Seconds 2
                 
                 $StateAfter = Get-UIAToggleState -Element $TargetToggle
                 if ($StateAfter -eq 1) {
                     Write-Log "Successfully verified state is ON." "Green"
                     $Success = $true
                 } else {
                     Write-Log "State did not change (UAC prompt might be blocking?)" "Yellow"
                     $Success = $true 
                 }
             } else {
                 Write-Log "Failed to toggle." "Red"
             }
        } else {
             # Maybe no toggle pattern? Try invoking anyway
             Write-Log "Toggle state unknown. Attempting to Click..." "Yellow"
             Invoke-UIAElement -Element $TargetToggle | Out-Null
             $Success = $true
        }

    } else {
        Write-Log "Could not find 'Kernel-mode Hardware-enforced Stack Protection' toggle. Feature might not be supported on this hardware." "Red"
        $Success = $true 
    }
}

Write-Log "Automation complete." "Cyan"