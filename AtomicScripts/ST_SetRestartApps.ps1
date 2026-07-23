<#
.SYNOPSIS
    Configures System & Privacy Configuration setting (ST_SetRestartApps).
.DESCRIPTION
    Applies security hardening or system configuration for ST_SetRestartApps in the Windows environment.
.PARAMETER Reverse
    If specified, reverses or restores default system behavior.
.EXAMPLE
    .\ST_SetRestartApps.ps1
#>
param([switch]$Reverse)

# UI Location: Settings > Accounts > Sign-in options

if ($Reverse) {
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "RestartApps" -Value 0 -Type DWord -Force
} else {
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "RestartApps" -Value 1 -Type DWord -Force
}

