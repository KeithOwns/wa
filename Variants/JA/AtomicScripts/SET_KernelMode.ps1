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

    # --- STANDALONE UI & LOGGING RESOURCES ---
    $Esc = [char]0x1B
    $Reset = "$Esc[0m"
    $Bold = "$Esc[1m"
    $FGCyan = "$Esc[96m"; $FGGreen = "$Esc[92m"; $FGRed = "$Esc[91m"; $FGYellow = "$Esc[93m"; $FGWhite = "$Esc[97m"; $FGGray = "$Esc[37m"; $FGDarkGray = "$Esc[90m"; $FGDarkBlue = "$Esc[34m"; $BGYellow = "$Esc[103m"; $FGBlack = "$Esc[30m"
    $Char_Warn = "!"; $Char_HeavyCheck = "[v]"

    function Write-Boundary { param([string]$Color = $FGDarkBlue) Write-Host "$Color$([string]'_' * 60)$Reset" }
    function Write-LeftAligned { param([string]$Text, [int]$Indent = 2) Write-Host (" " * $Indent + $Text) }
    function Write-Centered { param([string]$Text, [int]$Width = 60) $clean = $Text -replace "\x1B\[[0-9;]*m", ""; $pad = [Math]::Floor(($Width - $clean.Length) / 2); if ($pad -lt 0) { $pad = 0 }; Write-Host (" " * $pad + $Text) }
    function Write-Header {
        param([string]$Title)
        Clear-Host; Write-Host ""
        $WinAutoTitle = "- WinAuto -"
        $WinAutoPadding = [Math]::Floor((60 - $WinAutoTitle.Length) / 2)
        Write-Host (" " * $WinAutoPadding + "$Bold$FGCyan$WinAutoTitle$Reset")
        Write-Boundary
        $SubText = $Title.ToUpper()
        $SubPadding = [Math]::Floor((60 - $SubText.Length) / 2)
        Write-Host (" " * $SubPadding + "$Bold$FGCyan$SubText$Reset")
        Write-Boundary
    }
    function Write-Log { param([string]$Message, [string]$Level = 'INFO') $c = switch($Level){'ERROR'{$FGRed};'WARNING'{$FGYellow};'SUCCESS'{$FGGreen};Default{$FGGray}}; Write-LeftAligned "$c$Message$Reset" }

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
        try {
            $InvokePattern = $Element.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern)
            $InvokePattern.Invoke()
            return $true
        }
        catch {
            try {
                $TogglePattern = $Element.GetCurrentPattern([System.Windows.Automation.TogglePattern]::Pattern)
                $TogglePattern.Toggle()
                return $true
            }
            catch {
                try {
                    $SelectionItem = $Element.GetCurrentPattern([System.Windows.Automation.SelectionItemPattern]::Pattern)
                    $SelectionItem.Select()
                    return $true
                }
                catch {
                    Write-Log "Failed to interact with element: $_" "Red"
                    return $false
                }
            }
        }
    }

    function Get-UIAToggleState {
        param([System.Windows.Automation.AutomationElement]$Element)
        try {
            $p = $Element.GetCurrentPattern([System.Windows.Automation.TogglePattern]::Pattern)
            return $p.Current.ToggleState
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
        Write-Log "Launching Windows Security (Iteration $RetryCount)..." "Gray"
        Stop-Process -Name "SecHealthUI" -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 1
        Start-Process "windowsdefender:"
        Start-Sleep -Seconds 3

        $Desktop = [System.Windows.Automation.AutomationElement]::RootElement
        $Window = Get-UIAElement -Parent $Desktop -Name "Windows Security" -ControlType ([System.Windows.Automation.ControlType]::Window) -Scope "Children" -TimeoutSeconds 10

        if (-not $Window) { Write-Log "Could not find 'Windows Security' window." "Yellow"; continue }
        Write-Log "Found 'Windows Security' window." "Green"
        try { $Window.SetFocus() } catch {}

        Write-Log "Navigating to 'Device security'..." "Gray"
        $DeviceSecBtn = Get-UIAElement -Parent $Window -Name "Device security" -Scope "Descendants" -TimeoutSeconds 5
        if ($DeviceSecBtn) { Invoke-UIAElement -Element $DeviceSecBtn | Out-Null; Start-Sleep -Seconds 2 }
        else { Write-Log "Could not find 'Device security' item." "Red"; continue }

        Write-Log "Navigating to 'Core isolation details'..." "Gray"
        $CoreIsoLink = Get-UIAElement -Parent $Window -Name "Core isolation details" -Scope "Descendants" -TimeoutSeconds 5
        if ($CoreIsoLink) { Invoke-UIAElement -Element $CoreIsoLink | Out-Null; Start-Sleep -Seconds 2 }

        Write-Log "Looking for toggle..." "Gray"
        $Condition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty, "Kernel-mode Hardware-enforced Stack Protection")
        $AllElements = $Window.FindAll([System.Windows.Automation.TreeScope]::Descendants, $Condition)
        $TargetToggle = $null
        foreach ($El in $AllElements) { if ($El.Current.ControlType -eq [System.Windows.Automation.ControlType]::CheckBox) { $TargetToggle = $El; break } }
        if (-not $TargetToggle) { foreach ($El in $AllElements) { if ($El.Current.ControlType -ne [System.Windows.Automation.ControlType]::Text) { $TargetToggle = $El; break } } }

        if ($TargetToggle) {
            $State = Get-UIAToggleState -Element $TargetToggle
            $DesiredState = if ($Reverse) { 0 } else { 1 }
            $ActionStr = if ($Reverse) { "OFF" } else { "ON" }

            if ($State -eq $DesiredState) { Write-Log "Feature is already $ActionStr." "Green"; $Success = $true }
            elseif ($null -ne $State) {
                Write-Log "Toggling $ActionStr..." "Cyan"
                if (Invoke-UIAElement -Element $TargetToggle) {
                    Write-Log "Action triggered." "Green"; Start-Sleep -Seconds 3
                    if ((Get-UIAToggleState -Element $TargetToggle) -eq $DesiredState) { Write-Log "Verified $ActionStr." "Green"; $Success = $true }
                    else { Write-Log "State did not change (UAC expected)." "Yellow"; $Success = $true }
                }
            }
            else { Write-Log "State unknown. Attempting Click..." "Yellow"; Invoke-UIAElement -Element $TargetToggle | Out-Null; $Success = $true }
        }
        else { Write-Log "Toggle not found / Not supported." "Red"; $Success = $true }
    }

    Write-Host ""
    $copyright = "Copyright (c) 2026 WinAuto"
    $cPad = [Math]::Floor((60 - $copyright.Length) / 2)
    Write-Host (" " * $cPad + "$FGCyan$copyright$Reset")
    Write-Host ""

} @args
