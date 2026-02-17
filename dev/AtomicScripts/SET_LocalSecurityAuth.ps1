#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Enables or Disables Local Security Authority (LSA) protection.
.DESCRIPTION
    Standardized for WinAuto. Sets RunAsPPL=1 (Enable) or 0 (Disable) in Registry.
.PARAMETER Undo
    Reverses the setting (Disables LSA Protection).
#>

param(
    [switch]$Undo
)

# --- SHARED FUNCTIONS ---
. "$PSScriptRoot\..\Shared\Shared_UI_Functions.ps1"

Write-Header "LSA PROTECTION"

# --- CONFIG ---
$regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa"
$regName = "RunAsPPL"
$targetValue = if ($Undo) { 0 } else { 1 }
$statusText = if ($Undo) { "DISABLED" } else { "ENABLED" }

# --- MAIN ---

try {
    # Check current status
    $current = (Get-ItemProperty -Path $regPath -Name $regName -ErrorAction SilentlyContinue).$regName
    if ($current -eq $targetValue) {
        Write-LeftAligned "$FGGreen$Char_BallotCheck  LSA Protection is $statusText.$Reset"
    } else {
        Set-RegistryDword -Path $regPath -Name $regName -Value $targetValue
        Write-LeftAligned "$FGGreen$Char_HeavyCheck  LSA Protection is $statusText.$Reset"
    }

} catch {
    Write-LeftAligned "$FGRed$Char_RedCross  Failed to modify LSA protection: $($_.Exception.Message)$Reset"
}
