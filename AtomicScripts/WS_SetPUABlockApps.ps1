param([switch]$Reverse)

# UI Location: Windows Security > App & browser control > Reputation-based protection settings

if ($Reverse) {
    Set-MpPreference -PUAProtection 0
} else {
    Set-MpPreference -PUAProtection 1
}
