#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Click the "Turn on" button under "App & browser control" via UI Automation.
.DESCRIPTION
    Launches Windows Security to the App & browser control page, locates the "Turn on" button, and attempts to invoke it.
    Useful as an atomic script to enforce security settings when registry access is locked or hidden.
#>

& {
    param(
        [Parameter(Mandatory = $false)]
        [Alias('r')]
        [switch]$Reverse
    )

    # --- STANDALONE UI & LOGGING RESOURCES ---
    $Esc = [char]0x1B
    $Reset = "$Esc[0m"
    $Bold = "$Esc[1m"
    $FGGreen = "$Esc[92m"; $FGRed = "$Esc[91m"; $FGDarkYellow = "$Esc[33m"; $FGCyan = "$Esc[96m"; $FGDarkBlue = "$Esc[34m"; $FGGray = "$Esc[37m"

    $Char_HeavyCheck = "[v]"; $Char_RedCross = "[x]"; $Char_Warn = "!"

    function Write-Boundary { param([string]$Color = $FGDarkBlue) Write-Host "$Color$([string]'_' * 60)$Reset" }
    function Write-LeftAligned { param([string]$Text, [int]$Indent = 2) Write-Host (" " * $Indent + $Text) }
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

    # --- UIA PREPARATION ---
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
            $ct = [System.Windows.Automation.ControlType]::$ControlType
            $conditions += New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, $ct)
        }

        if ($conditions.Count -eq 0) { return $null }
        $finalCondition = if ($conditions.Count -eq 1) { $conditions[0] } else { New-Object System.Windows.Automation.AndCondition($conditions) }
        return $Parent.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $finalCondition)
    }

    Write-Header "APP & BROWSER CONTROL (UIA)"
    
    Write-LeftAligned "Launching Windows Security..."
    try { Start-Process "windowsdefender://appbrowser" } catch { Write-LeftAligned "$FGRed$Char_RedCross Failed: $($_.Exception.Message)$Reset"; return }
    
    Start-Sleep -Seconds 3

    $Desktop = [System.Windows.Automation.AutomationElement]::RootElement
    Write-LeftAligned "Searching for Windows Security window..."
    $Window = $null
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 15) {
        $Window = Get-UIAElement -Parent $Desktop -Name "Windows Security" -ControlType "Window"
        if ($Window) { break }
        Start-Sleep -Seconds 1
    }

    if ($Window) {
        try { $Window.SetFocus() } catch {}
        Start-Sleep -Seconds 1
        
        $TargetName = if ($Reverse) { "Turn off" } else { "Turn on" }
        Write-LeftAligned "Searching for '$TargetName' button..."
        $btn = Get-UIAElement -Parent $Window -Name $TargetName -ControlType "Button"
        
        if ($btn) {
            try {
                $InvokePattern = $btn.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern)
                $InvokePattern.Invoke()
                Write-LeftAligned "$FGGreen$Char_HeavyCheck Successfully clicked '$TargetName'.$Reset"
            }
            catch { Write-LeftAligned "$FGRed$Char_RedCross Failed to click: $($_.Exception.Message)$Reset" }
        }
        else { Write-LeftAligned "$FGDarkYellow$Char_Warn '$TargetName' button not found.$Reset" }
    }
    else { Write-LeftAligned "$FGRed$Char_RedCross Could not find Windows Security window.$Reset" }
    
    Start-Sleep -Seconds 1

} @args
