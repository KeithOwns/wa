#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Enables or Disables Windows Defender PUA Protection.
.DESCRIPTION
    Standardized for WinAuto. Configures System-wide Windows Defender PUA Protection.
.PARAMETER Undo
    Reverses the setting (Disables PUA blocking).
#>

param(
    [switch]$Undo,
    [switch]$Force
)

# --- SHARED FUNCTIONS ---
. "$PSScriptRoot\..\Shared\Shared_UI_Functions.ps1"

Write-Header "DEFENDER PUA PROTECTION"

try {
    $targetMp = if ($Undo) { 0 } else { 1 }
    $statusText = if ($Undo) { "DISABLED" } else { "ENABLED" }

    # System-wide Defender PUA
    Set-MpPreference -PUAProtection $targetMp -ErrorAction Stop
    Write-LeftAligned "$FGGreen$Char_HeavyCheck  Defender PUA Blocking is $statusText.$Reset"

    # Verification
    $currentMp = (Get-MpPreference).PUAProtection
    if ($currentMp -ne $targetMp) {
        Write-LeftAligned "$FGDarkYellow$Char_Warn Verification failed for Defender PUA. Status: $currentMp$Reset"
    }

}
catch {
    Write-LeftAligned "$FGRed$Char_RedCross  Failed: $($_.Exception.Message)$Reset"
}
