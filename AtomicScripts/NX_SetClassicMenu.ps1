<#
.SYNOPSIS
    Configures Next-Gen Windows Hardening setting (NX_SetClassicMenu).
.DESCRIPTION
    Applies security hardening or system configuration for NX_SetClassicMenu in the Windows environment.
.PARAMETER Reverse
    If specified, reverses or restores default system behavior.
.EXAMPLE
    .\NX_SetClassicMenu.ps1
#>
param([switch]$Reverse)

# UI Location: none (no Settings page; only visible by right-clicking the desktop)

$Key = "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}"
$Path = "$Key\InprocServer32"

if ($Reverse) {
    if (Test-Path $Key) {
        Remove-Item -Path $Key -Recurse -Force -ErrorAction SilentlyContinue
        Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    }
} else {
    if (-not (Test-Path $Path)) {
        New-Item -Path $Path -Force | Out-Null
    }
    Set-ItemProperty -Path $Path -Name "(default)" -Value "" -Force
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
}

