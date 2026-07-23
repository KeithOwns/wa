<#
.SYNOPSIS
    Configures Next-Gen Windows Hardening setting (NX_SetLLMNR).
.DESCRIPTION
    Applies security hardening or system configuration for NX_SetLLMNR in the Windows environment.
.PARAMETER Reverse
    If specified, reverses or restores default system behavior.
.EXAMPLE
    .\NX_SetLLMNR.ps1
#>
param([switch]$Reverse)

# UI Location: none (registry/GPO-only)

if ($Reverse) {
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient" -Name "EnableMulticast" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
} else {
    New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient" -Force | Out-Null; Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient" -Name "EnableMulticast" -Value 0 -Type DWord -Force
}

