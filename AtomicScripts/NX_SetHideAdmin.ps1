<#
.SYNOPSIS
    Configures Next-Gen Windows Hardening setting (NX_SetHideAdmin).
.DESCRIPTION
    Applies security hardening or system configuration for NX_SetHideAdmin in the Windows environment.
.PARAMETER Reverse
    If specified, reverses or restores default system behavior.
.EXAMPLE
    .\NX_SetHideAdmin.ps1
#>
param([switch]$Reverse)

# UI Location: none (no GUI control exists)

$Path = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\SpecialAccounts\UserList"
$Name = "Administrator"
$Value = if ($Reverse) { 1 } else { 0 }

if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type DWord -Force -ErrorAction SilentlyContinue

