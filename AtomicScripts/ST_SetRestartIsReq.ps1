<#
.SYNOPSIS
    Configures System & Privacy Configuration setting (ST_SetRestartIsReq).
.DESCRIPTION
    Applies security hardening or system configuration for ST_SetRestartIsReq in the Windows environment.
.PARAMETER Reverse
    If specified, reverses or restores default system behavior.
.EXAMPLE
    .\ST_SetRestartIsReq.ps1
#>
param([switch]$Reverse)

# UI Location: Settings > Windows Update > Advanced options

if ($Reverse) {
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" -Name "RestartNotificationsAllowed2" -Value 0 -Type DWord -Force
} else {
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" -Name "RestartNotificationsAllowed2" -Value 1 -Type DWord -Force
}

