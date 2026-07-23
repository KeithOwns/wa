<#
.SYNOPSIS
    Configures Windows Security & Defender setting (WS_SetKernelMode).
.DESCRIPTION
    Applies security hardening or system configuration for WS_SetKernelMode in the Windows environment.
.PARAMETER Reverse
    If specified, reverses or restores default system behavior.
.EXAMPLE
    .\WS_SetKernelMode.ps1
#>
param([switch]$Reverse)

# UI Location: Windows Security > Device security > Core isolation details

if ($Reverse) {
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\KernelShadowStacks" -Name "Enabled" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
} else {
    New-Item -Path "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\KernelShadowStacks" -Force | Out-Null; Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\KernelShadowStacks" -Name "Enabled" -Value 1 -Type DWord -Force
}

