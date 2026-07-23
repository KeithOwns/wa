<#
.SYNOPSIS
    Configures System & Privacy Configuration setting (ST_SetAdvertisingID).
.DESCRIPTION
    Applies security hardening or system configuration for ST_SetAdvertisingID in the Windows environment.
.PARAMETER Reverse
    If specified, reverses or restores default system behavior.
.EXAMPLE
    .\ST_SetAdvertisingID.ps1
#>
param([switch]$Reverse)

# UI Location: Settings > Privacy & Security > General

$Path = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo"
$Name = "Enabled"
$Value = if ($Reverse) { 1 } else { 0 }

if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type DWord -Force -ErrorAction SilentlyContinue

