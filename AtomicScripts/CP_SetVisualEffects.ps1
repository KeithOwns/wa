<#
.SYNOPSIS
    Configures Control Panel / Disk Optimization setting (CP_SetVisualEffects).
.DESCRIPTION
    Applies security hardening or system configuration for CP_SetVisualEffects in the Windows environment.
.PARAMETER Reverse
    If specified, reverses or restores default system behavior.
.EXAMPLE
    .\CP_SetVisualEffects.ps1
#>
param([switch]$Reverse)

# UI Location: legacy Performance Options dialog (SystemPropertiesPerformance.exe), reached via Settings > System > About > Advanced system settings

$Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects"
$Name = "VisualFXSetting"
$Value = if ($Reverse) { 0 } else { 2 }

if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type DWord -Force -ErrorAction SilentlyContinue

