<#
.SYNOPSIS
    Configures System & Privacy Configuration setting (ST_SetTaskbarSearch).
.DESCRIPTION
    Applies security hardening or system configuration for ST_SetTaskbarSearch in the Windows environment.
.PARAMETER Reverse
    If specified, reverses or restores default system behavior.
.EXAMPLE
    .\ST_SetTaskbarSearch.ps1
#>
param([switch]$Reverse)

# UI Location: Settings > Personalization > Taskbar

$Value = if ($Reverse) { 1 } else { 3 }
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" -Name "SearchboxTaskbarMode" -Value $Value -Type DWord -Force
Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue

