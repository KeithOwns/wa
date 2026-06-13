param([switch]$Reverse)

if ($Reverse) {
    Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False
} else {
    Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True
}
