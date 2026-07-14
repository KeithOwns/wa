#Requires -RunAsAdministrator
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

try {
    Add-Type -AssemblyName UIAutomationClient
    Add-Type -AssemblyName UIAutomationTypes
} catch {
    Write-Error "Failed to load UIAutomation assemblies."
    exit 1
}

function Write-Log { param($Message) Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $Message" -ForegroundColor Cyan }

function Get-Element {
    param($Parent, $Name, $ControlType)
    $Condition = if ($Name -and $ControlType) {
        New-Object System.Windows.Automation.AndCondition(
            (New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty, $Name)),
            (New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, $ControlType))
        )
    } elseif ($Name) {
        New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty, $Name)
    } else {
        New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, $ControlType)
    }
    return $Parent.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $Condition)
}

function Dump-Children {
    param($Element, $Indent = 0)
    if (-not $Element) { return }
    
    $TreeWalker = [System.Windows.Automation.TreeWalker]::RawViewWalker
    $Child = $TreeWalker.GetFirstChild($Element)
    
    while ($Child) {
        $Name = $Child.Current.Name
        $Type = $Child.Current.LocalizedControlType
        $Space = " " * $Indent
        
        $Out = "$Space [$Type] '$Name'"
        Write-Host $Out
        $Out | Out-File "UI_DUMP.txt" -Append
        
        # Recurse (limit depth to avoid infinite loops/huge dumps)
        if ($Indent -lt 6) {
            Dump-Children -Element $Child -Indent ($Indent + 2)
        }
        
        $Child = $TreeWalker.GetNextSibling($Child)
    }
}

# --- MAIN ---

Write-Log "Launching Windows Security for Inspection..."
Stop-Process -Name "SecHealthUI" -Force -ErrorAction SilentlyContinue
Start-Process "windowsdefender:"

$Desktop = [System.Windows.Automation.AutomationElement]::RootElement

# Wait loop for Window
$Window = $null
for ($i=0; $i -lt 10; $i++) {
    Start-Sleep -Seconds 2
    $Window = Get-Element -Parent $Desktop -Name "Windows Security" -ControlType ([System.Windows.Automation.ControlType]::Window)
    if ($Window) { break }
    Write-Log "Waiting for window..."
}

if ($Window) {
    Write-Log "Navigating..."
    
    # Nav to Device Security
    $DevSec = Get-Element -Parent $Window -Name "Device security" 
    if ($DevSec) {
        try {
            $DevSec.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern).Invoke()
        } catch {
             try {
                $DevSec.GetCurrentPattern([System.Windows.Automation.SelectionItemPattern]::Pattern).Select()
             } catch {
                Write-Log "Failed to nav to Device Security"
             }
        }
        Start-Sleep -Seconds 2
    }
    
    # Nav to Core Isolation
    $CoreIso = Get-Element -Parent $Window -Name "Core isolation details"
    if ($CoreIso) {
         try {
            $CoreIso.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern).Invoke()
         } catch {
             # Maybe it's just a text link?
             Write-Log "Could not invoke Core Iso link, trying click..."
         }
         Start-Sleep -Seconds 2 
    }

    Write-Log "Dumping UI Tree to UI_DUMP.txt..."
    "--- UI DUMP ---" | Out-File "UI_DUMP.txt"
    
    # Dump the main scroll viewer or content area
    Dump-Children -Element $Window
    
    Write-Log "Done."
} else {
    Write-Error "Could not find window."
}
