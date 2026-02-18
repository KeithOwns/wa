#Requires -RunAsAdministrator
<#
.SYNOPSIS
    WinAuto Task Scheduler
.DESCRIPTION
    Creates a Windows Scheduled Task to run WinAuto_Master_AUTO.ps1 automatically.
    Default schedule: First Monday of every month at 12:00 PM.
    Standalone version. Includes Reverse Mode (-r) to delete the task.
.PARAMETER Reverse
    (Alias: -r) Removes the scheduled task.
#>

& {
    param(
        [Parameter(Mandatory = $false)]
        [Alias('r')]
        [switch]$Reverse
    )

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
    $FGYellow = "$Esc[93m"
    $Char_HeavyCheck = "[v]"
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
        function Write-LeftAligned { param($Text) Write-Host "  $Text" }
    }

    # --- MAIN ---
    Write-Header "AUTOMATION SCHEDULER"

    $TaskName = "WinAuto Maintenance"
    
    # --- REVERSE MODE ---
    if ($Reverse) {
        if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
            Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
            Write-LeftAligned "$FGGreen$Char_HeavyCheck Task '$TaskName' has been removed.$Reset"
        }
        else {
            Write-LeftAligned "$FGYellow$Char_Warn Task '$TaskName' not found.$Reset"
        }
        
        # Footer & Exit
        Write-Host ""; $copyright = "Copyright (c) 2026 WinAuto"; $cPad = [Math]::Floor((60 - $copyright.Length) / 2); Write-Host (" " * $cPad + "$FGCyan$copyright$Reset"); Write-Host ""
        return
    }

    # --- CREATE MODE ---
    $ScriptPath = "$PSScriptRoot\A1_WinAuto_Master_AUTO.ps1"
    $PowershellPath = (Get-Command powershell.exe).Source

    Write-LeftAligned "Target Script: $ScriptPath"
    Write-Host ""

    # Check existing
    $existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($existing) {
        Write-LeftAligned "$FGYellow$Char_Warn Task '$TaskName' already exists.$Reset"
        $choice = Read-Host "  Recreate/Update it? (Y/N)"
        if ($choice -notmatch "^[Yy]") { 
            # Footer & Exit
            Write-Host ""; $copyright = "Copyright (c) 2026 WinAuto"; $cPad = [Math]::Floor((60 - $copyright.Length) / 2); Write-Host (" " * $cPad + "$FGCyan$copyright$Reset"); Write-Host ""
            return 
        }
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    }

    # Create Action
    $Action = New-ScheduledTaskAction -Execute $PowershellPath -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`""

    # Create Trigger (Monthly, First Monday @ 12pm)
    $Trigger = New-ScheduledTaskTrigger -Monthly -Days 1 -At 12:00

    # Create Settings (Run elevated, wake to run)
    $Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries:$false -DontStopIfGoingOnBatteries:$false -StartWhenAvailable -RunOnlyIfNetworkAvailable -ExecutionTimeLimit (New-TimeSpan -Hours 2)

    # Register
    try {
        # Run as SYSTEM (NT AUTHORITY\SYSTEM) for full automation without login
        Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Settings $Settings -User "NT AUTHORITY\SYSTEM" -RunLevel Highest | Out-Null
        
        Write-Host ""
        Write-LeftAligned "$FGGreen$Char_HeavyCheck Task '$TaskName' created successfully!$Reset"
        Write-LeftAligned "Schedule: Monthly on Day 1 at 12:00 PM"
        Write-LeftAligned "Runs as:  SYSTEM (Hidden)"
        
    }
    catch {
        Write-Host ""
        Write-LeftAligned "$FGRed$Char_RedCross Error creating task: $($_.Exception.Message)$Reset"
    }

    # --- FOOTER ---
    Write-Host ""
    $copyright = "Copyright (c) 2026 WinAuto"
    $cPad = [Math]::Floor((60 - $copyright.Length) / 2)
    Write-Host (" " * $cPad + "$FGCyan$copyright$Reset")
    Write-Host ""
} @args
