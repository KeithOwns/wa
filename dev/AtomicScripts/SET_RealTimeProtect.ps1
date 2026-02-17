#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Enables or Disables Real-time Protection.
.DESCRIPTION
    Standardized for WinAuto. Checks for Tamper Protection before changes.
.PARAMETER Undo
    Reverses the setting (Disables Real-time Protection).
#>

param(
    [switch]$Undo
)

# --- SHARED FUNCTIONS ---
$ScriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { $PWD.Path }
. "$ScriptRoot\..\Shared\Shared_UI_Functions.ps1"

Write-Header "REAL-TIME PROTECTION"

# --- MAIN ---

try {
    $target = if ($Undo) { $true } else { $false }
    $status = if ($Undo) { "DISABLED" } else { "ENABLED" }

    $tp = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows Defender\Features" -Name "TamperProtection" -ErrorAction SilentlyContinue).TamperProtection

    if ($tp -eq 5) {
        Write-LeftAligned "$FGDarkYellow$Char_Warn Tamper Protection is ENABLED and blocking changes.$Reset"
        return
    }

    Set-MpPreference -DisableRealtimeMonitoring $target -ErrorAction Stop

    # Verify
    $current = (Get-MpPreference).DisableRealtimeMonitoring
    if ($current -eq $target) {
        Write-LeftAligned "$FGGreen$Char_HeavyCheck  Real-time Protection is $status.$Reset"
    }
    else {
        Write-LeftAligned "$FGDarkYellow$Char_Warn Real-time Protection verification failed.$Reset"
    }

}
catch {
    Write-LeftAligned "$FGRed$Char_RedCross  Failed: $($_.Exception.Message)$Reset"
}
