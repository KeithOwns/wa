<#
.SYNOPSIS
    Configures Next-Gen Windows Hardening setting (NX_SetGetMeUpToDate).
.DESCRIPTION
    Applies security hardening or system configuration for NX_SetGetMeUpToDate in the Windows environment.
.PARAMETER Reverse
    If specified, reverses or restores default system behavior.
.EXAMPLE
    .\NX_SetGetMeUpToDate.ps1
#>
param([switch]$Reverse)

# UI Location: none (registry/GPO-only, no known visible toggle)

if ($Reverse) {
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" -Name "IsExpedited" -Value 0 -Type DWord -Force
} else {
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" -Name "IsExpedited" -Value 1 -Type DWord -Force
}

