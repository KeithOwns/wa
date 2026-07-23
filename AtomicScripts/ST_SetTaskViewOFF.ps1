<#
.SYNOPSIS
    Configures System & Privacy Configuration setting (ST_SetTaskViewOFF).
.DESCRIPTION
    Applies security hardening or system configuration for ST_SetTaskViewOFF in the Windows environment.
.PARAMETER Reverse
    If specified, reverses or restores default system behavior.
.EXAMPLE
    .\ST_SetTaskViewOFF.ps1
#>
param([switch]$Reverse)

# UI Location: Settings > Personalization > Taskbar

$Value = if ($Reverse) { 1 } else { 0 }
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowTaskViewButton" -Value $Value -Type DWord -Force
Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue

