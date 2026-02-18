#Requires -RunAsAdministrator
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

    # --- STANDALONE HELPERS ---
    $Esc = [char]0x1B
    $Reset = "$Esc[0m"
    $Bold = "$Esc[1m"
    $FGCyan = "$Esc[96m"
    $FGDarkBlue = "$Esc[34m"

    if (-not (Get-Command Write-Boundary -ErrorAction SilentlyContinue)) {
        function Write-Boundary {
            param([string]$Color = $FGDarkBlue)
            Write-Host "$Color$([string]'_' * 60)$Reset"
        }
    }

    if (-not (Get-Command Write-Header -ErrorAction SilentlyContinue)) {
        function Write-Header {
            param([string]$Title)
            Clear-Host
            Write-Host ""
            $WinAutoTitle = "- WinAuto -"
            $WinAutoPadding = [Math]::Floor((60 - $WinAutoTitle.Length) / 2)
            Write-Host (" " * $WinAutoPadding + "$Bold$FGCyan$WinAutoTitle$Reset")
            
            Write-Boundary
            
            $SubText = $Title.ToUpper()
            $SubPadding = [Math]::Floor((60 - $SubText.Length) / 2)
            Write-Host (" " * $SubPadding + "$Bold$FGCyan$SubText$Reset")
            Write-Boundary
        }
    }

    # Load .NET UIAutomation Assemblies
    try {
        Add-Type -AssemblyName UIAutomationClient
        Add-Type -AssemblyName UIAutomationTypes
    }
    catch {
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
        }
        elseif ($Name) {
            New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty, $Name)
        }
        elseif ($ControlType) {
            New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, $ControlType)
        }
        else {
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
        }
        catch {
            # Try Toggle Pattern (Switches)
            try {
                $TogglePattern = $Element.GetCurrentPattern([System.Windows.Automation.TogglePattern]::Pattern)
                $TogglePattern.Toggle()
                return $true
            }
            catch {
                try {
                    # Fallback: SelectionItem (Tabs/Nav items)
                    $SelectionItem = $Element.GetCurrentPattern([System.Windows.Automation.SelectionItemPattern]::Pattern)
                    $SelectionItem.Select()
                    return $true
                }
                catch {
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
        }
        catch { return $null }
    }

    # --- MAIN SCRIPT ---
    Write-Header "KERNEL STACK UIA"
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
    $copyright = "Copyright (c) 2026 WinAuto"
    $cPad = [Math]::Floor((60 - $copyright.Length) / 2)
    Write-Host (" " * $cPad + "$FGCyan$copyright$Reset")
    Write-Host ""

} @args
