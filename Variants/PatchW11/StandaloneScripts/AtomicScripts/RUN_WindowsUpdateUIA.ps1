#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Automates Windows Update and Microsoft Store updates via UI Automation.
.DESCRIPTION
    Launches Windows 11 Settings (Windows Update) and the Microsoft Store,
    and uses UI Automation to click "Check for updates", "Install all", etc.
    Extracted from wa.ps1 (Invoke-WA_WindowsUpdate).
    Standalone version. Includes Reverse Mode (-r) stub.
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
            [string]$AutomationId,
            [System.Windows.Automation.ControlType]$ControlType,
            [System.Windows.Automation.TreeScope]$Scope = [System.Windows.Automation.TreeScope]::Descendants,
            [int]$TimeoutSeconds = 5
        )
        
        $Conditions = @()
        if ($Name) { $Conditions += New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty, $Name) }
        if ($AutomationId) { $Conditions += New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::AutomationIdProperty, $AutomationId) }
        if ($ControlType) { $Conditions += New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, $ControlType) }

        $Condition = if ($Conditions.Count -eq 1) { $Conditions[0] }
                     elseif ($Conditions.Count -gt 1) { New-Object System.Windows.Automation.AndCondition($Conditions) }
                     else { return $null }

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
            if ($Element.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern)) {
                $Element.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern).Invoke()
                return $true
            }
        } catch {}
        try {
            if ($Element.GetCurrentPattern([System.Windows.Automation.TogglePattern]::Pattern)) {
                $Element.GetCurrentPattern([System.Windows.Automation.TogglePattern]::Pattern).Toggle()
                return $true
            }
        } catch {}
        try {
            $Element.GetCurrentPattern([System.Windows.Automation.SelectionItemPattern]::Pattern).Select()
            return $true
        } catch {}
        return $false
    }
    
    Write-Host ""
    Write-Centered "$Char_EnDash STORE & SETTINGS $Char_EnDash" -Color "$Bold$FGCyan"

    # 1. Windows Update Settings (UIA)
    Write-LeftAligned "Opening Windows Update Settings..."
    Start-Process "ms-settings:windowsupdate"

    $desktop = [System.Windows.Automation.AutomationElement]::RootElement
    $settingsWindow = $null

    $stopWatch = [System.Diagnostics.Stopwatch]::StartNew()
    while ($stopWatch.Elapsed.TotalSeconds -lt 15) {
        # Try by Name
        $settingsWindow = Get-UIAElement -Parent $desktop -Name "Settings" -Scope "Children" -TimeoutSeconds 1
        if (-not $settingsWindow) { $settingsWindow = Get-UIAElement -Parent $desktop -Name "Windows Update" -Scope "Children" -TimeoutSeconds 1 }

        # Try by Process
        if (-not $settingsWindow) {
            $ssProc = Get-Process "SystemSettings" -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($ssProc) {
                $settingsWindow = $desktop.FindFirst([System.Windows.Automation.TreeScope]::Children, (New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ProcessIdProperty, $ssProc.Id)))
            }
        }

        if ($settingsWindow) { break }
        Start-Sleep -Milliseconds 500
    }

    if ($settingsWindow) {
        try { $settingsWindow.SetFocus() } catch {}
        Start-Sleep -Seconds 3

        $targetButtons = @(
            @{ Name = "Check for updates"; Id = "SystemSettings_MusUpdate_CheckForUpdates_Button" },
            @{ Name = "Check for updates"; Id = "SystemSettings_MicrosoftUpdate_CheckForUpdates_Button" },
            @{ Name = "Check for updates"; Id = "Check for updates" },
            @{ Name = "Download & install all"; Id = "SystemSettings_MusUpdate_DownloadAndInstallAll_Button" },
            @{ Name = "Install all"; Id = "SystemSettings_MusUpdate_InstallAll_Button" },
            @{ Name = "Restart now"; Id = "SystemSettings_MusUpdate_RestartNow_Button" },
            @{ Name = "Resume updates"; Id = "SystemSettings_MusUpdate_ResumeUpdates_Button" },
            @{ Name = "Retry all"; Id = "" },
            @{ Name = "Retry"; Id = "" },
            @{ Name = "Check updates"; Id = "" }
        )

        $buttonFound = $false

        # Priority 1: Exact AutomationId (Most reliable)
        foreach ($btnInfo in $targetButtons) {
            if ($btnInfo.Id) {
                $button = Get-UIAElement -Parent $settingsWindow -AutomationId $btnInfo.Id -Scope "Descendants" -TimeoutSeconds 1
                if ($button -and (Invoke-UIAElement -Element $button)) {
                    Write-LeftAligned "$FGGreen$Char_HeavyCheck Clicked '$($btnInfo.Name)' (ID)$Reset"
                    $buttonFound = $true; break
                }
            }
        }

        # Priority 2: Exact Name
        if (-not $buttonFound) {
            foreach ($btnInfo in $targetButtons) {
                if ($btnInfo.Name) {
                    $button = Get-UIAElement -Parent $settingsWindow -Name $btnInfo.Name -Scope "Descendants" -TimeoutSeconds 1
                    if ($button -and (Invoke-UIAElement -Element $button)) {
                        Write-LeftAligned "$FGGreen$Char_HeavyCheck Clicked '$($btnInfo.Name)' (Name)$Reset"
                        $buttonFound = $true; break
                    }
                }
            }
        }

        # Priority 3: Fuzzy search (Search for ANY button containing "update", "check", "install", or "retry")
        if (-not $buttonFound) {
            Write-LeftAligned "$FGGray Primary buttons not found. Attempting fuzzy search...$Reset"
            $allButtons = $settingsWindow.FindAll([System.Windows.Automation.TreeScope]::Descendants, (New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Button)))
            foreach ($btn in $allButtons) {
                $n = $btn.Current.Name
                if ($n -match "update" -or $n -match "check" -or $n -match "install" -or $n -match "retry") {
                    if (Invoke-UIAElement -Element $btn) {
                        Write-LeftAligned "$FGGreen$Char_HeavyCheck Clicked '$n' (Fuzzy)$Reset"
                        $buttonFound = $true; break
                    }
                }
            }
        }

        if (-not $buttonFound) { Write-LeftAligned "$FGGray No actionable buttons found in Settings.$Reset" }
    }
    else { Write-LeftAligned "$FGRed$Char_Warn Could not attach to Settings window.$Reset" }

    # 2. Microsoft Store (UIA)
    Write-LeftAligned "Opening Microsoft Store Updates..."
    Start-Process "ms-windows-store://downloadsandupdates"

    $storeWindow = Get-UIAElement -Parent $desktop -Name "Microsoft Store" -Scope "Children" -TimeoutSeconds 10

    if ($storeWindow) {
        try { $storeWindow.SetFocus() } catch {}
        Start-Sleep -Seconds 2

        $buttonTexts = @("Get updates", "Check for updates", "Update all")
        $buttonFound = $false
        foreach ($buttonText in $buttonTexts) {
            $button = Get-UIAElement -Parent $storeWindow -Name $buttonText -Scope "Descendants" -TimeoutSeconds 2
            if ($button -and (Invoke-UIAElement -Element $button)) {
                Write-LeftAligned "$FGGreen$Char_HeavyCheck Clicked '$buttonText'$Reset"
                $buttonFound = $true; break
            }
        }
        if (-not $buttonFound) { Write-LeftAligned "$FGGray No update button found in Store.$Reset" }
    }
    else { Write-LeftAligned "$FGRed$Char_Warn Could not attach to Store window.$Reset" }

    Write-Host ""
    
    # --- FOOTER ---
    Write-Host ""
    $copyright = "Copyright (c) 2026 WinAuto"
    $cPad = [Math]::Floor((60 - $copyright.Length) / 2)
    Write-Host (" " * $cPad + "$FGCyan$copyright$Reset")
    Write-Host ""
    Start-Sleep -Seconds 3
} @args


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

    # --- STANDALONE HELPERS ---
    $Esc = [char]0x1B
    $Reset = "$Esc[0m"
    $Bold = "$Esc[1m"
    $FGGreen = "$Esc[92m"
    $FGRed = "$Esc[91m"
    $FGCyan = "$Esc[96m"
    $FGDarkBlue = "$Esc[34m"
    $FGGray = "$Esc[37m"
    $FGYellow = "$Esc[93m"
    
    $Char_HeavyCheck = "[v]"
    $Char_Warn = "!"
    $Char_EnDash = "-"
    
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
    
    if (-not (Get-Command Write-LeftAligned -ErrorAction SilentlyContinue)) {
        function Write-LeftAligned { param($Text) Write-Host "  $Text" }
    }
    
    if (-not (Get-Command Write-Centered -ErrorAction SilentlyContinue)) {
        function Write-Centered {
            param([string]$Text, [int]$Width = 60, [string]$Color)
            $cleanText = $Text -replace "$Esc\[[0-9;]*m", ""
            $padLeft = [Math]::Floor(($Width - $cleanText.Length) / 2)
            if ($padLeft -lt 0) { $padLeft = 0 }
            if ($Color) { Write-Host (" " * $padLeft + "$Color$Text$Reset") }
            else { Write-Host (" " * $padLeft + $Text) }
        }
    }

    Write-Header "WINDOWS UPDATE SCAN (UIA)"

    if ($Reverse) {
        Write-LeftAligned "$FGYellow$Char_Warn Reverse Mode: Updating cannot be reversed automatically.$Reset"
        Write-Host ""
        $copyright = "Copyright (c) 2026 WinAuto"; $cPad = [Math]::Floor((60 - $copyright.Length) / 2); Write-Host (" " * $cPad + "$FGCyan$copyright$Reset"); Write-Host ""
        return
    }

    # UI Automation Preparation
    if (-not ([System.Management.Automation.PSTypeName]"System.Windows.Automation.AutomationElement").Type) {
        try {
            Add-Type -AssemblyName UIAutomationClient
            Add-Type -AssemblyName UIAutomationTypes
        }
        catch {
            Write-LeftAligned "$FGRed$Char_Warn Failed to load UI Automation assemblies.$Reset"
            return
        }
    }

    function Get-UIAElement {
        param(
            [System.Windows.Automation.AutomationElement]$Parent,
            [string]$Name,
            [string]$AutomationId,
            [System.Windows.Automation.ControlType]$ControlType,
            [System.Windows.Automation.TreeScope]$Scope = [System.Windows.Automation.TreeScope]::Descendants,
            [int]$TimeoutSeconds = 5
        )
        
        $Conditions = @()
        if ($Name) { $Conditions += New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty, $Name) }
        if ($AutomationId) { $Conditions += New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::AutomationIdProperty, $AutomationId) }
        if ($ControlType) { $Conditions += New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, $ControlType) }

        $Condition = if ($Conditions.Count -eq 1) { $Conditions[0] }
                     elseif ($Conditions.Count -gt 1) { New-Object System.Windows.Automation.AndCondition($Conditions) }
                     else { return $null }

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
            if ($Element.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern)) {
                $Element.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern).Invoke()
                return $true
            }
        } catch {}
        try {
            if ($Element.GetCurrentPattern([System.Windows.Automation.TogglePattern]::Pattern)) {
                $Element.GetCurrentPattern([System.Windows.Automation.TogglePattern]::Pattern).Toggle()
                return $true
            }
        } catch {}
        try {
            $Element.GetCurrentPattern([System.Windows.Automation.SelectionItemPattern]::Pattern).Select()
            return $true
        } catch {}
        return $false
    }
    
    Write-Host ""
    Write-Centered "$Char_EnDash STORE & SETTINGS $Char_EnDash" -Color "$Bold$FGCyan"

    # 1. Windows Update Settings (UIA)
    Write-LeftAligned "Opening Windows Update Settings..."
    Start-Process "ms-settings:windowsupdate"

    $desktop = [System.Windows.Automation.AutomationElement]::RootElement
    $settingsWindow = $null

    $stopWatch = [System.Diagnostics.Stopwatch]::StartNew()
    while ($stopWatch.Elapsed.TotalSeconds -lt 15) {
        # Try by Name
        $settingsWindow = Get-UIAElement -Parent $desktop -Name "Settings" -Scope "Children" -TimeoutSeconds 1
        if (-not $settingsWindow) { $settingsWindow = Get-UIAElement -Parent $desktop -Name "Windows Update" -Scope "Children" -TimeoutSeconds 1 }

        # Try by Process
        if (-not $settingsWindow) {
            $ssProc = Get-Process "SystemSettings" -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($ssProc) {
                $settingsWindow = $desktop.FindFirst([System.Windows.Automation.TreeScope]::Children, (New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ProcessIdProperty, $ssProc.Id)))
            }
        }

        if ($settingsWindow) { break }
        Start-Sleep -Milliseconds 500
    }

    if ($settingsWindow) {
        try { $settingsWindow.SetFocus() } catch {}
        Start-Sleep -Seconds 3

        $targetButtons = @(
            @{ Name = "Check for updates"; Id = "SystemSettings_MusUpdate_CheckForUpdates_Button" },
            @{ Name = "Check for updates"; Id = "SystemSettings_MicrosoftUpdate_CheckForUpdates_Button" },
            @{ Name = "Check for updates"; Id = "Check for updates" },
            @{ Name = "Download & install all"; Id = "SystemSettings_MusUpdate_DownloadAndInstallAll_Button" },
            @{ Name = "Install all"; Id = "SystemSettings_MusUpdate_InstallAll_Button" },
            @{ Name = "Restart now"; Id = "SystemSettings_MusUpdate_RestartNow_Button" },
            @{ Name = "Resume updates"; Id = "SystemSettings_MusUpdate_ResumeUpdates_Button" },
            @{ Name = "Retry all"; Id = "" },
            @{ Name = "Retry"; Id = "" },
            @{ Name = "Check updates"; Id = "" }
        )

        $buttonFound = $false

        # Priority 1: Exact AutomationId (Most reliable)
        foreach ($btnInfo in $targetButtons) {
            if ($btnInfo.Id) {
                $button = Get-UIAElement -Parent $settingsWindow -AutomationId $btnInfo.Id -Scope "Descendants" -TimeoutSeconds 1
                if ($button -and (Invoke-UIAElement -Element $button)) {
                    Write-LeftAligned "$FGGreen$Char_HeavyCheck Clicked '$($btnInfo.Name)' (ID)$Reset"
                    $buttonFound = $true; break
                }
            }
        }

        # Priority 2: Exact Name
        if (-not $buttonFound) {
            foreach ($btnInfo in $targetButtons) {
                if ($btnInfo.Name) {
                    $button = Get-UIAElement -Parent $settingsWindow -Name $btnInfo.Name -Scope "Descendants" -TimeoutSeconds 1
                    if ($button -and (Invoke-UIAElement -Element $button)) {
                        Write-LeftAligned "$FGGreen$Char_HeavyCheck Clicked '$($btnInfo.Name)' (Name)$Reset"
                        $buttonFound = $true; break
                    }
                }
            }
        }

        # Priority 3: Fuzzy search (Search for ANY button containing "update", "check", "install", or "retry")
        if (-not $buttonFound) {
            Write-LeftAligned "$FGGray Primary buttons not found. Attempting fuzzy search...$Reset"
            $allButtons = $settingsWindow.FindAll([System.Windows.Automation.TreeScope]::Descendants, (New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Button)))
            foreach ($btn in $allButtons) {
                $n = $btn.Current.Name
                if ($n -match "update" -or $n -match "check" -or $n -match "install" -or $n -match "retry") {
                    if (Invoke-UIAElement -Element $btn) {
                        Write-LeftAligned "$FGGreen$Char_HeavyCheck Clicked '$n' (Fuzzy)$Reset"
                        $buttonFound = $true; break
                    }
                }
            }
        }

        if (-not $buttonFound) { Write-LeftAligned "$FGGray No actionable buttons found in Settings.$Reset" }
    }
    else { Write-LeftAligned "$FGRed$Char_Warn Could not attach to Settings window.$Reset" }

    # 2. Microsoft Store (UIA)
    Write-LeftAligned "Opening Microsoft Store Updates..."
    Start-Process "ms-windows-store://downloadsandupdates"

    $storeWindow = Get-UIAElement -Parent $desktop -Name "Microsoft Store" -Scope "Children" -TimeoutSeconds 10

    if ($storeWindow) {
        try { $storeWindow.SetFocus() } catch {}
        Start-Sleep -Seconds 2

        $buttonTexts = @("Get updates", "Check for updates", "Update all")
        $buttonFound = $false
        foreach ($buttonText in $buttonTexts) {
            $button = Get-UIAElement -Parent $storeWindow -Name $buttonText -Scope "Descendants" -TimeoutSeconds 2
            if ($button -and (Invoke-UIAElement -Element $button)) {
                Write-LeftAligned "$FGGreen$Char_HeavyCheck Clicked '$buttonText'$Reset"
                $buttonFound = $true; break
            }
        }
        if (-not $buttonFound) { Write-LeftAligned "$FGGray No update button found in Store.$Reset" }
    }
    else { Write-LeftAligned "$FGRed$Char_Warn Could not attach to Store window.$Reset" }

    Write-Host ""
    
    # --- FOOTER ---
    Write-Host ""
    $copyright = "Copyright (c) 2026 WinAuto"
    $cPad = [Math]::Floor((60 - $copyright.Length) / 2)
    Write-Host (" " * $cPad + "$FGCyan$copyright$Reset")
    Write-Host ""
    Start-Sleep -Seconds 3
} @args
