param([switch]$Reverse)

if ($Reverse) {
    Set-MpPreference -PUAProtection 0
} else {
    Set-MpPreference -PUAProtection 1
}
