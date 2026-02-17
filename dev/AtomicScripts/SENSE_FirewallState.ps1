#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Detects and reports the state of Windows Firewall for all network profiles.
.DESCRIPTION
    Atomic detection script for WinAuto. Checks Domain, Private, and Public profiles
    and reports their enabled/disabled status without making any changes.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# --- SHARED FUNCTIONS ---
. "$PSScriptRoot\..\Shared\Shared_UI_Functions.ps1"

Write-Header "FIREWALL STATE"

# --- MAIN ---

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

Write-Host ""
Write-Boundary
Start-Sleep -Seconds 3
