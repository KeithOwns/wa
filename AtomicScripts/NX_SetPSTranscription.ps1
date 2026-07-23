<#
.SYNOPSIS
    Configures Next-Gen Windows Hardening setting (NX_SetPSTranscription).
.DESCRIPTION
    Applies security hardening or system configuration for NX_SetPSTranscription in the Windows environment.
.PARAMETER Reverse
    If specified, reverses or restores default system behavior.
.EXAMPLE
    .\NX_SetPSTranscription.ps1
#>
param([switch]$Reverse)

# UI Location: none (registry/GPO-only)

if ($Reverse) {
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\Transcription" -Name "EnableTranscripting" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
} else {
    New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\Transcription" -Force | Out-Null; Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\Transcription" -Name "EnableTranscripting" -Value 1 -Type DWord -Force
}

