<#
.SYNOPSIS
    Configures Windows Security & Defender setting (WS_SetFirewallON).
.DESCRIPTION
    Applies security hardening or system configuration for WS_SetFirewallON in the Windows environment.
.PARAMETER Reverse
    If specified, reverses or restores default system behavior.
.EXAMPLE
    .\WS_SetFirewallON.ps1
#>
param([switch]$Reverse)

# UI Location: Windows Security > Firewall & network protection

if ($Reverse) {
    Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False
} else {
    Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True
}

