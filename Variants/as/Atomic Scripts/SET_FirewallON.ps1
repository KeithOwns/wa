param([switch]$Undo)

if ($Undo) {
    Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False
} else {
    Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True
}
