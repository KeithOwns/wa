<#
.SYNOPSIS
    Configures Windows Security & Defender setting (WS_SetMemoryInteg).
.DESCRIPTION
    Applies security hardening or system configuration for WS_SetMemoryInteg in the Windows environment.
.PARAMETER Reverse
    If specified, reverses or restores default system behavior.
.EXAMPLE
    .\WS_SetMemoryInteg.ps1
#>
param([switch]$Reverse)

# UI Location: Windows Security > Device security > Core isolation

$Path = "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity"

if ($Reverse) {
    Set-ItemProperty -Path $Path -Name "Enabled" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
} else {
    if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
    Set-ItemProperty -Path $Path -Name "Enabled" -Value 1 -Type DWord -Force
    Set-ItemProperty -Path $Path -Name "WasEnabledBy" -Value 2 -Type DWord -Force -ErrorAction SilentlyContinue
}

