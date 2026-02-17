#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Enables or Disables Windows Firewall for all network profiles.
.DESCRIPTION
    Standardized for WinAuto. Scans and configures Domain, Private, and Public profiles.
.PARAMETER Undo
    Reverses the setting (Disables Firewalls).
#>

param(
    [switch]$Undo
)

# --- SHARED FUNCTIONS ---
. "$PSScriptRoot\..\Shared\Shared_UI_Functions.ps1"

Write-Header "WINDOWS FIREWALL"

# --- MAIN ---

try {
    $target = if ($Undo) { 'False' } else { 'True' }
    $status = if ($Undo) { "DISABLED" } else { "ENABLED" }

    $profiles = Get-NetFirewallProfile

    foreach ($profile in $profiles) {
        if ($profile.Enabled -eq $target) {
            Write-LeftAligned "$FGGreen$Char_BallotCheck  $($profile.Name) Firewall is $status.$Reset"
        } else {
            try {
                Set-NetFirewallProfile -Name $profile.Name -Enabled $target -ErrorAction Stop
                Write-LeftAligned "$FGGreen$Char_HeavyCheck  $($profile.Name) Firewall is $status.$Reset"
            } catch {
                Write-LeftAligned "$FGRed$Char_RedCross  Failed to modify $($profile.Name) firewall: $($_.Exception.Message)$Reset"
            }
        }
    }

} catch {
    Write-LeftAligned "$FGRed$Char_RedCross  Critical Error: $($_.Exception.Message)$Reset"
}
