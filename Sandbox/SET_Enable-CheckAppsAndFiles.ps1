#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Enables 'Check apps and files' in Windows Security > Reputation-based protection.
.DESCRIPTION
    Launches Windows Security directly to the App & browser control section,
    navigates to 'Reputation-based protection settings', and ensures 'Check apps and files' is On.
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

function Invoke-UIAToggle {
    param(
        [System.Windows.Automation.AutomationElement]$Element,
        [bool]$TurnOn = $true
    )
    
    if (-not $Element) { return $false }

    # Try TogglePattern
    try {
        $TogglePattern = $Element.GetCurrentPattern([System.Windows.Automation.TogglePattern]::Pattern)
        $CurrentState = $TogglePattern.Current.ToggleState 
        # On = 1, Off = 0, Indeterminate = 2
        
        $TargetState = if ($TurnOn) { [System.Windows.Automation.ToggleState]::On } else { [System.Windows.Automation.ToggleState]::Off }

        if ($CurrentState -eq $TargetState) {
            Write-Log "'$($Element.Current.Name)' is already in desired state." "Green"
            return $true
        }

        Write-Log "Toggling '$($Element.Current.Name)'..." "Cyan"
        $TogglePattern.Toggle()
        return $true
    } catch {
        # Fallback to InvokePattern (some checkboxes act like buttons)
        Write-Log "TogglePattern failed or not supported. Trying InvokePattern..." "Yellow"
        try {
            $InvokePattern = $Element.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern)
            $InvokePattern.Invoke()
            return $true
        } catch {
            Write-Log "Failed to toggle/invoke: $_" "Red"
            return $false
        }
    }
}

function Invoke-UIAButton {
    param([System.Windows.Automation.AutomationElement]$Button)
    if (-not $Button) { return $false }
    try {
        $InvokePattern = $Button.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern)
        $InvokePattern.Invoke()
        return $true
    } catch {
        Write-Log "Failed to invoke button: $_" "Red"
        return $false
    }
}

# --- MAIN SCRIPT ---

Write-Log "Starting Windows Security Automation (Reputation Protection)..." "Cyan"

# 1. Launch Windows Security directly to 'App & browser control'
Write-Log "Launching Windows Security (App & browser control)..." "Gray"
Stop-Process -Name "SecHealthUI" -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 1
Start-Process "windowsdefender://appbrowser"
Start-Sleep -Seconds 3

# 2. Find the Main Window
$Desktop = [System.Windows.Automation.AutomationElement]::RootElement
$Window = Get-UIAElement -Parent $Desktop -Name "Windows Security" -ControlType ([System.Windows.Automation.ControlType]::Window) -Scope "Children" -TimeoutSeconds 10

if (-not $Window) {
    Write-Log "Could not find 'Windows Security' window." "Red"
    exit 1
}
Write-Log "Found 'Windows Security' window." "Green"
try { $Window.SetFocus() } catch {}

# 3. Find and Click 'Reputation-based protection settings'
# Note: It might be a Link or a Button depending on OS version.
Write-Log "Navigating to 'Reputation-based protection settings'..." "Gray"

$RepSettingsLink = Get-UIAElement -Parent $Window -Name "Reputation-based protection settings" -ControlType ([System.Windows.Automation.ControlType]::Hyperlink) -Scope "Descendants" -TimeoutSeconds 3

if (-not $RepSettingsLink) {
    # Try searching for a Button if Hyperlink fails
    $RepSettingsLink = Get-UIAElement -Parent $Window -Name "Reputation-based protection settings" -ControlType ([System.Windows.Automation.ControlType]::Button) -Scope "Descendants" -TimeoutSeconds 3
}

if ($RepSettingsLink) {
    Invoke-UIAButton -Button $RepSettingsLink | Out-Null
    Write-Log "Clicked settings link. Waiting for page load..." "Green"
    Start-Sleep -Seconds 2
} else {
    Write-Log "Could not find 'Reputation-based protection settings' link." "Red"
    exit 1
}

# 4. Find 'Check apps and files' Toggle
Write-Log "Searching for 'Check apps and files' toggle..." "Gray"

# The toggle is usually named "Check apps and files" directly.
$CheckAppsToggle = Get-UIAElement -Parent $Window -Name "Check apps and files" -ControlType ([System.Windows.Automation.ControlType]::CheckBox) -Scope "Descendants" -TimeoutSeconds 3

if (-not $CheckAppsToggle) {
    # Sometimes it's a Button or custom control, or just "Toggle switch"
    # If the control type is different, we might need to search by Name only
    $CheckAppsToggle = Get-UIAElement -Parent $Window -Name "Check apps and files" -ControlType $null -Scope "Descendants" -TimeoutSeconds 3
}

if ($CheckAppsToggle) {
    Write-Log "Found 'Check apps and files' control." "Green"
    if (Invoke-UIAToggle -Element $CheckAppsToggle -TurnOn $true) {
        Write-Log "Successfully ensured 'Check apps and files' is On." "Green"
    } else {
        Write-Log "Failed to toggle setting." "Red"
    }
} else {
    Write-Log "Could not find 'Check apps and files' toggle." "Red"
    # Debug: List checkboxes? No, keep concise.
}

Write-Log "Automation complete." "Cyan"
