#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Toggles 'Automatically save restartable apps and restart them when I sign back in'.
.DESCRIPTION
    Toggles the "RestartApps" registry key in HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon.
    1 = Enabled
    0 = Disabled
.PARAMETER TurnOn
    Forces the setting to be Enabled, regardless of current state.
#>

param(
    [switch]$TurnOn
)

# --- SHARED FUNCTIONS ---
. "$PSScriptRoot\..\Shared\Shared_UI_Functions.ps1"

Write-Header "APP RESTART"

try {
    $regPath = "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
    $regName = "RestartApps"

    # Ensure path exists (Though HKCU Winlogon usually does)
    if (-not (Test-Path $regPath)) {
        New-Item -Path $regPath -Force | Out-Null
    }

    # Get current value (Default to 0 if not present)
    $currentVal = (Get-ItemProperty -Path $regPath -Name $regName -ErrorAction SilentlyContinue).$regName
    if ($null -eq $currentVal) { $currentVal = 0 }

    # Logic: If -TurnOn is used, force Enable. Else, Toggle.
    if ($TurnOn) {
        $newValue = 1
        $statusText = "ENABLED"
        $icon = $Char_HeavyCheck
        $color = $FGGreen
    }
    elseif ($currentVal -eq 1) {
        $newValue = 0
        $statusText = "DISABLED"
        $icon = $Char_Warn
        $color = $FGYellow
    }
    else {
        $newValue = 1
        $statusText = "ENABLED"
        $icon = $Char_HeavyCheck
        $color = $FGGreen
    }

    # Apply new value
    Set-ItemProperty -Path $regPath -Name $regName -Value $newValue -Type DWord -Force

    Write-LeftAligned "$color$icon  'Restart apps after signing in' is now $statusText.$Reset"

}
catch {
    Write-LeftAligned "$FGRed$Char_RedCross  Failed to modify setting: $($_.Exception.Message)$Reset"
}
