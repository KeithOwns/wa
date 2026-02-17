#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Enables or Disables Edge SmartScreen PUA Protection.
.DESCRIPTION
    Standardized for WinAuto. Configures User-specific Edge SmartScreen PUA (Block downloads).
.PARAMETER Undo
    Reverses the setting (Disables PUA blocking).
#>

param(
    [switch]$Undo,
    [switch]$Force
)

# --- SHARED FUNCTIONS ---
. "$PSScriptRoot\..\Shared\Shared_UI_Functions.ps1"

Write-Header "EDGE PUA PROTECTION"

try {
    $targetEdge = if ($Undo) { 0 } else { 1 }
    $statusText = if ($Undo) { "DISABLED" } else { "ENABLED" }

    # User-specific Edge SmartScreen PUA (Block downloads)
    $edgeKeyPath = "HKCU:\Software\Microsoft\Edge\SmartScreenPuaEnabled"
    if (!(Test-Path $edgeKeyPath)) {
        New-Item -Path $edgeKeyPath -Force | Out-Null
    }
    Set-ItemProperty -Path $edgeKeyPath -Name "(default)" -Value $targetEdge -Type DWord -Force
    
    Write-LeftAligned "$FGGreen$Char_HeavyCheck  Edge 'Block downloads' is $statusText.$Reset"

}
catch {
    Write-LeftAligned "$FGRed$Char_RedCross  Failed: $($_.Exception.Message)$Reset"
}
