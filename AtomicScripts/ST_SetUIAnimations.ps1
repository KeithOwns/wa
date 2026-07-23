<#
.SYNOPSIS
    Configures System & Privacy Configuration setting (ST_SetUIAnimations).
.DESCRIPTION
    Applies security hardening or system configuration for ST_SetUIAnimations in the Windows environment.
.PARAMETER Reverse
    If specified, reverses or restores default system behavior.
.EXAMPLE
    .\ST_SetUIAnimations.ps1
#>
param([switch]$Reverse)

# UI Location: Settings > Accessibility > Visual effects

$Path = "HKCU:\Control Panel\Desktop\WindowMetrics"
$Name = "MinAnimate"
$Value = if ($Reverse) { "1" } else { "0" }

if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type String -Force -ErrorAction SilentlyContinue

