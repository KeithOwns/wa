#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Automates Windows Update and Microsoft Store updates via UI Automation.
.DESCRIPTION
    Launches Windows 11 Settings (Windows Update) and the Microsoft Store,
    and uses UI Automation to click "Check for updates", "Install all", etc.
    Standalone version. Includes Reverse Mode stub.
.PARAMETER Reverse
    (Alias: -r) No-Op. Updating cannot be reversed automatically.
#>

& {
    param(
        [Parameter(Mandatory = $false)]
        [Alias('r')]
        [switch]$Reverse,
        [switch]$Undo
    )

    if ($Undo) { $Reverse = $true }
    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'

    # --- STANDALONE UI & LOGGING RESOURCES ---
    $Esc = [char]0x1B
    $Reset = "$Esc[0m"
    $Bold = "$Esc[1m"
    $FGGreen = "$Esc[92m"; $FGRed = "$Esc[91m"; $FGCyan = "$Esc[96m"; $FGDarkBlue = "$Esc[34m"; $FGGray = "$Esc[37m"; $FGYellow = "$Esc[93m"
    $Char_HeavyCheck = "[v]"; $Char_Warn = "!"; $Char_EnDash = "-"

    function Write-Boundary { param([string]$Color = $FGDarkBlue) Write-Host "$Color$([string]'_' * 60)$Reset" }
    function Write-LeftAligned { param($Text) Write-Host "  $Text" }
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
    function Write-Centered {
        param([string]$Text, [int]$Width = 60, [string]$Color)
        $clean = $Text -replace "\x1B\[[0-9;]*m", ""; $pad = [Math]::Floor(($Width - $clean.Length) / 2)
        if ($Color) { Write-Host (" " * $pad + "$Color$Text$Reset") } else { Write-Host (" " * $pad + $Text) }
    }

    if ($Reverse) {
        Write-Header "WINDOWS UPDATE SCAN (UIA)"
        Write-LeftAligned "$FGYellow$Char_Warn Reverse Mode: Updating cannot be reversed automatically.$Reset"
        Write-Host ""; return
    }

    # UIA Preparation
    if (-not ([System.Management.Automation.PSTypeName]"System.Windows.Automation.AutomationElement").Type) {
        try { Add-Type -AssemblyName UIAutomationClient; Add-Type -AssemblyName UIAutomationTypes }
        catch { Write-LeftAligned "$FGRed$Char_Warn Failed to load UIA assemblies.$Reset"; return }
    }

    function Get-UIAElement {
        param([System.Windows.Automation.AutomationElement]$Parent, [string]$Name, [string]$AutomationId, [System.Windows.Automation.ControlType]$ControlType, [System.Windows.Automation.TreeScope]$Scope = [System.Windows.Automation.TreeScope]::Descendants, [int]$TimeoutSeconds = 5)
        $Conditions = @()
        if ($Name) { $Conditions += New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty, $Name) }
        if ($AutomationId) { $Conditions += New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::AutomationIdProperty, $AutomationId) }
        if ($ControlType) { $Conditions += New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, $ControlType) }
        if ($Conditions.Count -eq 0) { return $null }
        $Condition = if ($Conditions.Count -eq 1) { $Conditions[0] } else { New-Object System.Windows.Automation.AndCondition($Conditions) }
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        while ($sw.Elapsed.TotalSeconds -lt $TimeoutSeconds) { $Res = $Parent.FindFirst($Scope, $Condition); if ($Res) { return $Res }; Start-Sleep -Milliseconds 500 }
        return $null
    }

    function Invoke-UIAElement {
        param([System.Windows.Automation.AutomationElement]$El)
        if (-not $El) { return $false }
        foreach ($p in "InvokePattern", "TogglePattern", "SelectionItemPattern") {
            try { $pattern = $El.GetCurrentPattern([System.Windows.Automation]::$p::Pattern); if ($pattern) { if ($p -eq "TogglePattern") { $pattern.Toggle() } elseif ($p -eq "SelectionItemPattern") { $pattern.Select() } else { $pattern.Invoke() }; return $true } } catch {}
        }
        return $false
    }

    Write-Header "WINDOWS UPDATE SCAN (UIA)"
    Write-Centered "$Char_EnDash STORE & SETTINGS $Char_EnDash" -Color "$Bold$FGCyan"

    # 1. Windows Update
    Write-LeftAligned "Opening Windows Update Settings..."
    Start-Process "ms-settings:windowsupdate"
    $desktop = [System.Windows.Automation.AutomationElement]::RootElement
    $settingsWindow = $null
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 15) {
        $settingsWindow = Get-UIAElement -Parent $desktop -Name "Settings" -Scope "Children" -TimeoutSeconds 1
        if (-not $settingsWindow) { $settingsWindow = Get-UIAElement -Parent $desktop -Name "Windows Update" -Scope "Children" -TimeoutSeconds 1 }
        if ($settingsWindow) { break }; Start-Sleep -Milliseconds 500
    }
    if ($settingsWindow) {
        try { $settingsWindow.SetFocus() } catch {}
        Start-Sleep -Seconds 3
        $targets = @("Check for updates", "Download & install all", "Install all", "Restart now", "Resume updates")
        $found = $false
        foreach ($t in $targets) {
            $btn = Get-UIAElement -Parent $settingsWindow -Name $t -Scope "Descendants" -TimeoutSeconds 1
            if ($btn -and (Invoke-UIAElement -El $btn)) { Write-LeftAligned "$FGGreen$Char_HeavyCheck Clicked '$t'.$Reset"; $found = $true; break }
        }
        if (-not $found) { Write-LeftAligned "$FGGray No actionable buttons found in Settings.$Reset" }
    }

    # 2. Store
    Write-LeftAligned "Opening Microsoft Store Updates..."
    Start-Process "ms-windows-store://downloadsandupdates"
    $storeWindow = Get-UIAElement -Parent $desktop -Name "Microsoft Store" -Scope "Children" -TimeoutSeconds 10
    if ($storeWindow) {
        try { $storeWindow.SetFocus() } catch {}
        Start-Sleep -Seconds 2
        foreach ($t in @("Get updates", "Check for updates", "Update all")) {
            $btn = Get-UIAElement -Parent $storeWindow -Name $t -Scope "Descendants" -TimeoutSeconds 2
            if ($btn -and (Invoke-UIAElement -El $btn)) { Write-LeftAligned "$FGGreen$Char_HeavyCheck Clicked '$t'.$Reset"; break }
        }
    }

    Write-Host ""
    $copyright = "Copyright (c) 2026 WinAuto"; $cPad = [Math]::Floor((60 - $copyright.Length) / 2); Write-Host (" " * $cPad + "$FGCyan$copyright$Reset"); Write-Host ""
    Start-Sleep -Seconds 1

} @args
