<#
.SYNOPSIS
    Configures Next-Gen Windows Hardening setting (NX_SetPSScriptBlock).
.DESCRIPTION
    Applies security hardening or system configuration for NX_SetPSScriptBlock in the Windows environment.
.PARAMETER Reverse
    If specified, reverses or restores default system behavior.
.EXAMPLE
    .\NX_SetPSScriptBlock.ps1
#>
param([switch]$Reverse)

# UI Location: none (registry/GPO-only)

if ($Reverse) {
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging" -Name "EnableScriptBlockLogging" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
} else {
    New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging" -Force | Out-Null; Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging" -Name "EnableScriptBlockLogging" -Value 1 -Type DWord -Force
}

