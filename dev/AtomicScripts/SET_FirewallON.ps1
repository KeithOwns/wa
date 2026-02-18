#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Enables or Disables Windows Firewall for all network profiles.
.DESCRIPTION
    Standardized for WinAuto. Scans and configures Domain, Private, and Public profiles.
    Standalone version: Can be copy-pasted directly into PowerShell.
    Includes Reverse Mode (-r) to undo changes.
.PARAMETER Reverse
    (Alias: -r) Reverses the setting (Disables Firewalls).
#>

& {
    param(
        [Parameter(Mandatory = $false)]
        [Alias('r')]
        [switch]$Reverse
    )

    # --- STANDALONE HELPERS ---
    $Esc = [char]0x1B
    $Reset = "$Esc[0m"
    $Bold = "$Esc[1m"
    $FGGreen = "$Esc[92m"
    $FGRed = "$Esc[91m"
    $FGCyan = "$Esc[96m"
    $FGDarkBlue = "$Esc[34m"
    
    $Char_BallotCheck = "[v]"
    $Char_HeavyCheck = "[v]"
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
    Write-Header "WINDOWS FIREWALL"

    try {
        $target = if ($Reverse) { 'False' } else { 'True' }
        $status = if ($Reverse) { "DISABLED" } else { "ENABLED" }

        $profiles = Get-NetFirewallProfile

        foreach ($profile in $profiles) {
            if ($profile.Enabled -eq $target) {
                Write-LeftAligned "$FGGreen$Char_BallotCheck  $($profile.Name) Firewall is $status.$Reset"
            }
            else {
                try {
                    Set-NetFirewallProfile -Name $profile.Name -Enabled $target -ErrorAction Stop
                    Write-LeftAligned "$FGGreen$Char_HeavyCheck  $($profile.Name) Firewall is $status.$Reset"
                }
                catch {
                    Write-LeftAligned "$FGRed$Char_RedCross  Failed to modify $($profile.Name) firewall: $($_.Exception.Message)$Reset"
                }
            }
        }

    }
    catch {
        Write-LeftAligned "$FGRed$Char_RedCross  Critical Error: $($_.Exception.Message)$Reset"
    }

    # --- FOOTER ---
    Write-Host ""
    $copyright = "Copyright (c) 2026 WinAuto"
    $cPad = [Math]::Floor((60 - $copyright.Length) / 2)
    Write-Host (" " * $cPad + "$FGCyan$copyright$Reset")
    Write-Host ""
} @args
