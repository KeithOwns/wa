param([switch]$Reverse)

# UI Location: Windows Security > Firewall & network protection

if ($Reverse) {
    Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False
} else {
    Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True
}
