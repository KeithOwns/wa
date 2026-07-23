<#
.SYNOPSIS
    Configures Windows Security & Defender setting (WS_SetPUABlockApps).
.DESCRIPTION
    Applies security hardening or system configuration for WS_SetPUABlockApps in the Windows environment.
.PARAMETER Reverse
    If specified, reverses or restores default system behavior.
.EXAMPLE
    .\WS_SetPUABlockApps.ps1
#>
param([switch]$Reverse)

# UI Location: Windows Security > App & browser control > Reputation-based protection settings

if ($Reverse) {
    Set-MpPreference -PUAProtection 0
} else {
    Set-MpPreference -PUAProtection 1
}

