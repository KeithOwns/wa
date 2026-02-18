#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Toggles Windows 11 Widgets via UI Automation.
.DESCRIPTION
    Bypasses registry write locks by automating the 'ms-settings:taskbar' GUI.
    Standalone version. Includes Reverse Mode (-r).
.PARAMETER Reverse
    (Alias: -r) Reverses setting (Turns Widgets ON, if currently OFF, or forces ON).
#>

& {
    param()

    # --- STANDALONE HELPERS ---
    $Esc = [char]0x1B
    $Reset = "$Esc[0m"
    $Bold = "$Esc[1m"
    $FGGreen = "$Esc[92m"
    $FGRed = "$Esc[91m"
    $FGCyan = "$Esc[96m"
    $FGDarkBlue = "$Esc[34m"
    $FGYellow = "$Esc[93m"
    $FGGray = "$Esc[37m"
    
    $Char_HeavyCheck = "[v]"
    $Char_BallotCheck = "[v]"
    $Char_Warn = "!"
    $Char_RedCross = "x"

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
        function Write-LeftAligned {
            param([string]$Text, [int]$Indent = 2)
            Write-Host (" " * $Indent + $Text)
        }
    }

    Write-Header "TASKBAR WIDGETS"

    # --- UIA PREPARATION ---
    if (-not ([System.Management.Automation.PSTypeName]"System.Windows.Automation.AutomationElement").Type) {
        try {
            Add-Type -AssemblyName UIAutomationClient
            Add-Type -AssemblyName UIAutomationTypes
        }
        catch {}
    }

    # Local UIA Helper (Consistent with wa.ps1)
    function Get-UIAElement {
        param(
            [System.Windows.Automation.AutomationElement]$Parent,
            [string]$Name,
            [System.Windows.Automation.ControlType]$ControlType,
            [int]$TimeoutSeconds = 10
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
            return $null
        }

        $StopWatch = [System.Diagnostics.Stopwatch]::StartNew()
        while ($StopWatch.Elapsed.TotalSeconds -lt $TimeoutSeconds) {
            $Result = $Parent.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $Condition)
            if ($Result) { return $Result }
            Start-Sleep -Milliseconds 500
        }
        return $null
    }

    # --- MAIN LOGIC ---

    function Invoke-WA_SetWidgetsUIA {
        
        # 1. Launch Taskbar Settings
        Write-LeftAligned "Launching Taskbar Settings..."
        try {
            Start-Process "ms-settings:taskbar"
        }
        catch {
            Write-LeftAligned "$FGRed$Char_RedCross Failed to launch Settings: $($_.Exception.Message)$Reset"
            return
        }
        
        Start-Sleep -Seconds 3

        $Desktop = [System.Windows.Automation.AutomationElement]::RootElement
        $Window = $null
        
        # Locate Settings Window
        Write-LeftAligned "Searching for Settings window..."
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        while ($sw.Elapsed.TotalSeconds -lt 15) {
            foreach ($title in @("Settings", "Paramètres", "Einstellungen")) {
                $Window = $Desktop.FindFirst([System.Windows.Automation.TreeScope]::Children, 
                    (New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty, $title)))
                if ($Window) { break }
            }
            if ($Window) { break }
            Start-Sleep -Seconds 1
        }

        if ($Window) {
            try { $Window.SetFocus() } catch {}
            Start-Sleep -Seconds 1
            
            # 2. Find the Widgets Toggle
            # Group/Button name is 'Widgets' typically
            Write-LeftAligned "Searching for 'Widgets' toggle..."
            $Toggle = Get-UIAElement -Parent $Window -Name "Widgets" -ControlType "Button" -TimeoutSeconds 5
            
            # Fallback: Sometimes it's inside a group named Widgets
            if (-not $Toggle) {
                $Group = Get-UIAElement -Parent $Window -Name "Widgets" -ControlType "Group" -TimeoutSeconds 2
                if ($Group) {
                    $Toggle = Get-UIAElement -Parent $Group -ControlType "Button" -TimeoutSeconds 2
                }
            }
            
            if ($Toggle) {
                try {
                    # Attempt to use TogglePattern
                    $Pattern = $Toggle.GetCurrentPattern([System.Windows.Automation.TogglePattern]::Pattern)
                    $CurrentState = $Pattern.Current.ToggleState # 0=Off, 1=On
                    $DesiredState = 0 # FORCE OFF

                    if ($CurrentState -ne $DesiredState) {
                        $Pattern.Toggle()
                        Write-LeftAligned "$FGGreen$Char_HeavyCheck Successfully toggled Widgets to OFF.$Reset"
                        Start-Sleep -Seconds 1
                    }
                    else {
                        Write-LeftAligned "$FGGreen$Char_BallotCheck Widgets already in desired state (OFF).$Reset"
                    }
                }
                catch {
                    # Fallback to Invoke
                    # Logic: If InvokePattern is used, we assume it's a toggle. 
                    # But without knowing state, we might toggle it ON.
                    # Since we removed Reverse, we should be careful. 
                    # However, standard buttons usually just click. 
                    # If we can't read state, we can't reliably turn OFF unless we assume default or check something else.
                    # For now, we'll leave legacy fallback but log a warning if state unknown.
                    
                    Write-LeftAligned "$FGDarkYellow$Char_Warn Cannot read toggle state. Skipping 'click' to avoid accidental enable.$Reset"
                }
            }
            else {
                Write-LeftAligned "$FGRed$Char_RedCross Could not find 'Widgets' toggle button.$Reset"
            }
        }
        else {
            Write-LeftAligned "$FGRed$Char_RedCross Could not find Settings window.$Reset"
        }
        
        # 3. Cleanup
        Start-Sleep -Seconds 2
        Stop-Process -Name "SystemSettings" -Force -ErrorAction SilentlyContinue
    }

    Invoke-WA_SetWidgetsUIA

    # --- FOOTER ---
    Write-Host ""
    $copyright = "Copyright (c) 2026 WinAuto"
    $cPad = [Math]::Floor((60 - $copyright.Length) / 2)
    Write-Host (" " * $cPad + "$FGCyan$copyright$Reset")
    Write-Host ""
} @args
