#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Enables 'Virus & threat protection' in Windows Security via UI Automation.
.DESCRIPTION
    Launches Windows Security and attempts to click the 'Turn on' button
    associated with 'Virus & threat protection'.
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

Write-Log "Starting Windows Security Automation..." "Cyan"

$MaxRetries = 20
$RetryCount = 0
$KeepLooping = $true

while ($KeepLooping -and ($RetryCount -lt $MaxRetries)) {
    $RetryCount++
    $KeepLooping = $false # Default to stop unless we trigger a restart

    # 1. Launch / Relaunch Windows Security
    Write-Log "Launching Windows Security (Iteration $RetryCount)..." "Gray"
    
    # Force close any existing instances to ensure a fresh state
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

    # 3. Focus Window
    try {
        $Window.SetFocus()
    } catch {
        Write-Log "Could not set focus (might be minimized), attempting to continue..." "Yellow"
    }

    # 4. Search for Section
    Write-Log "Searching for 'Virus & threat protection' section..." "Gray"
    $Section = Get-UIAElement -Parent $Window -Name "Virus & threat protection" -Scope "Descendants" -TimeoutSeconds 5

    if ($Section) {
        Write-Log "Found 'Virus & threat protection' section." "Green"
        
        # 5. Look for 'Turn on' button
        Write-Log "Looking for 'Turn on' button..." "Gray"
        $TurnOnBtn = Get-UIAElement -Parent $Section -Name "Turn on" -ControlType ([System.Windows.Automation.ControlType]::Button) -Scope "Descendants" -TimeoutSeconds 2
        
        if (-not $TurnOnBtn) {
            # Fallback: Search entire window
            $TurnOnBtn = Get-UIAElement -Parent $Window -Name "Turn on" -ControlType ([System.Windows.Automation.ControlType]::Button) -Scope "Descendants" -TimeoutSeconds 2
        }

        if ($TurnOnBtn) {
            Write-Log "Found 'Turn on' button. Clicking..." "Cyan"
            if (Invoke-UIAButton -Button $TurnOnBtn) {
                Write-Log "Successfully clicked 'Turn on'. Restarting app..." "Green"
                $KeepLooping = $true
                Start-Sleep -Seconds 5
                # Process will be killed at start of next iteration
            } else {
                Write-Log "Failed to click 'Turn on'." "Red"
            }
        } else {
            Write-Log "No 'Turn on' button detected. Checks complete." "Green"
        }

    } else {
        Write-Log "Could not find 'Virus & threat protection' section." "Red"
    }
}

Write-Log "Automation complete." "Cyan"
