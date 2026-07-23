<#
.SYNOPSIS
    Configures Windows Security & Defender setting (WS_SetSmartScreenReg).
.DESCRIPTION
    Applies security hardening or system configuration for WS_SetSmartScreenReg in the Windows environment.
.PARAMETER Reverse
    If specified, reverses or restores default system behavior.
.EXAMPLE
    .\WS_SetSmartScreenReg.ps1
#>
param([switch]$Reverse)

# UI Location: Windows Security > App & browser control > Reputation-based protection settings

$Value = if ($Reverse) { "Off" } else { "RequireAdmin" }

Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" -Name "SmartScreenEnabled" -Value $Value -Type String -Force -ErrorAction SilentlyContinue

