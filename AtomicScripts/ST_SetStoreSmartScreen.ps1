<#
.SYNOPSIS
    Configures System & Privacy Configuration setting (ST_SetStoreSmartScreen).
.DESCRIPTION
    Applies security hardening or system configuration for ST_SetStoreSmartScreen in the Windows environment.
.PARAMETER Reverse
    If specified, reverses or restores default system behavior.
.EXAMPLE
    .\ST_SetStoreSmartScreen.ps1
#>
param([switch]$Reverse)

# UI Location: Settings > Privacy & Security > General

$Path = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppHost"
$Name = "EnableWebContentEvaluation"
$Value = if ($Reverse) { 0 } else { 1 }

if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type DWord -Force -ErrorAction SilentlyContinue

