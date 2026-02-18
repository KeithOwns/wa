#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Detects and reports the state of Windows Firewall for all network profiles.
.DESCRIPTION
    Atomic detection script for WinAuto. Checks Domain, Private, and Public profiles
    and reports their enabled/disabled status without making any changes.
    Standalone version. Includes Reverse Mode (-r) stub (Read-Only).
.PARAMETER Reverse
    (Alias: -r) No-Op. Script is Read-Only.
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

    # --- STANDALONE HELPERS ---
    $Esc = [char]0x1B
    $Reset = "$Esc[0m"
    $Bold = "$Esc[1m"
    $FGGreen = "$Esc[92m"
    $FGRed = "$Esc[91m"
    $FGCyan = "$Esc[96m"
    $FGDarkBlue = "$Esc[34m"
    $FGDarkYellow = "$Esc[33m"
    
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
        function Write-LeftAligned { param($Text) Write-Host "  $Text" }
    }

    Write-Header "FIREWALL STATE"

    if ($Reverse) {
        Write-LeftAligned "$FGDarkYellow$Char_Warn Reverse Mode: This script is READ-ONLY. No changes to reverse.$Reset"
        Write-Host ""
        $copyright = "Copyright (c) 2026 WinAuto"; $cPad = [Math]::Floor((60 - $copyright.Length) / 2); Write-Host (" " * $cPad + "$FGCyan$copyright$Reset"); Write-Host ""
        return
    }

    try {
        $profiles = Get-NetFirewallProfile
        $allEnabled = $true

        foreach ($profile in $profiles) {
            $isEnabled = $profile.Enabled -eq $true
            if (-not $isEnabled) { $allEnabled = $false }

            if ($isEnabled) {
                Write-LeftAligned "$FGGreen$Char_BallotCheck  $($profile.Name) Firewall: ENABLED$Reset"
            }
            else {
                Write-LeftAligned "$FGRed$Char_RedCross  $($profile.Name) Firewall: DISABLED$Reset"
            }
        }

        Write-Host ""

        # Summary status
        if ($allEnabled) {
            Write-LeftAligned "$FGGreen$Char_HeavyCheck All firewall profiles are ENABLED.$Reset"
        }
        else {
            Write-LeftAligned "$FGDarkYellow$Char_Warn One or more firewall profiles are DISABLED.$Reset"
        }

    }
    catch {
        Write-LeftAligned "$FGRed$Char_RedCross  Error detecting firewall state: $($_.Exception.Message)$Reset"
    }

    # --- FOOTER ---
    Write-Host ""
    $copyright = "Copyright (c) 2026 WinAuto"
    $cPad = [Math]::Floor((60 - $copyright.Length) / 2)
    Write-Host (" " * $cPad + "$FGCyan$copyright$Reset")
    Write-Host ""
    Start-Sleep -Seconds 3
} @args
