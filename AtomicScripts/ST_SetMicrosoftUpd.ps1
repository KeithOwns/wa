<#
.SYNOPSIS
    Configures System & Privacy Configuration setting (ST_SetMicrosoftUpd).
.DESCRIPTION
    Applies security hardening or system configuration for ST_SetMicrosoftUpd in the Windows environment.
.PARAMETER Reverse
    If specified, reverses or restores default system behavior.
.EXAMPLE
    .\ST_SetMicrosoftUpd.ps1
#>
param([switch]$Reverse)

# UI Location: Settings > Windows Update > Advanced options

if ($Reverse) {
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" -Name "AllowMUUpdateService" -Value 0 -Type DWord -Force
} else {
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" -Name "AllowMUUpdateService" -Value 1 -Type DWord -Force
}

