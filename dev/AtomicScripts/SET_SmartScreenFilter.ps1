#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Enables SmartScreen Filter via UI Automation.
.DESCRIPTION
    Opens Windows Security > App & browser control and clicks "Turn on".
    Standalone version: Can be copy-pasted directly into PowerShell.
#>

& {
    param(
        [Parameter(Mandatory = $false)]
        [Alias('r')]
        [switch]$Reverse,
        [switch]$Force
    )

    # --- STANDALONE HELPERS ---
    $Esc = [char]0x1B
    $Reset = "$Esc[0m"
    $Bold = "$Esc[1m"
    $FGGreen = "$Esc[92m"
    $FGRed = "$Esc[91m"
    $FGDarkYellow = "$Esc[33m"
    $FGCyan = "$Esc[96m"
    $FGDarkBlue = "$Esc[34m"

    $Char_HeavyCheck = "[v]"
    $Char_RedCross = "[x]"
    $Char_Warn = "!"

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
            $WinAutoTitle = "WinAuto (Atomic)"
            $WinAutoPadding = [Math]::Floor((60 - $WinAutoTitle.Length) / 2)
            Write-Host (" " * $WinAutoPadding + "$Bold$FGCyan$WinAutoTitle$Reset")
            
            $SubText = $Title.ToUpper()
            $SubPadding = [Math]::Floor((60 - $SubText.Length) / 2)
            Write-Host (" " * $SubPadding + "$Bold$FGCyan$SubText$Reset")
            Write-Boundary
        }
    }

    if (-not (Get-Command Write-LeftAligned -ErrorAction SilentlyContinue)) {
        function Write-LeftAligned {
            param([string]$Text, [int]$Indent = 2)
            Write-Host (" " * $Indent + $Text)
        }
    }

    # --- UIA PREPARATION ---
    if (-not ([System.Management.Automation.PSTypeName]"System.Windows.Automation.AutomationElement").Type) {
        try {
            Add-Type -AssemblyName UIAutomationClient
            Add-Type -AssemblyName UIAutomationTypes
        }
        catch {
            Write-LeftAligned "$FGRed$Char_RedCross Failed to load UI Automation assemblies.$Reset"
            exit
        }
    }

    # --- MAIN LOGIC ---
    Write-Header "SMARTSCREEN FILTER (UIA)"

    # 1. Launch Windows Security at App & Browser Control
    Write-LeftAligned "Opening Windows Security..."
    Start-Process "windowsdefender://appbrowser"
    Start-Sleep -Seconds 2

    # 2. Find Window
    $timeout = 10
    $startTime = Get-Date
    $window = $null

    Write-LeftAligned "Searching for 'Windows Security' window..."

    do {
        $desktop = [System.Windows.Automation.AutomationElement]::RootElement
        $condition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty, "Windows Security")
        $window = $desktop.FindFirst([System.Windows.Automation.TreeScope]::Children, $condition)
        if ($null -ne $window) { break }
        Start-Sleep -Milliseconds 500
    } while ((Get-Date) -lt $startTime.AddSeconds($timeout))

    if ($window) {
        Write-LeftAligned "$FGGreen$Char_HeavyCheck Window found.$Reset"
        
        # 3. Search for Button
        $TargetName = if ($Reverse) { "Turn off" } else { "Turn on" }
        Write-LeftAligned "Searching for '$TargetName' button..."
        
        $buttonCondition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty, $TargetName)
        
        # Search Descendants (deep search)
        $button = $window.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $buttonCondition)
        
        if ($button) {
            try {
                $invokePattern = $button.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern)
                if ($invokePattern) {
                    $invokePattern.Invoke()
                    Write-LeftAligned "$FGGreen$Char_HeavyCheck Clicked '$TargetName'.$Reset"
                    Start-Sleep -Seconds 1
                }
                else {
                    Write-LeftAligned "$FGDarkYellow$Char_Warn '$TargetName' button found but not clickable.$Reset"
                }
            }
            catch {
                Write-LeftAligned "$FGRed$Char_RedCross Failed to click button: $($_.Exception.Message)$Reset"
            }
        }
        else {
            Write-LeftAligned "$FGGray Desired button '$TargetName' not found (Step may be redundant).$Reset"
        }
    }
    else {
        Write-LeftAligned "$FGRed$Char_RedCross Timeout waiting for Windows Security window.$Reset"
    }

} @args
