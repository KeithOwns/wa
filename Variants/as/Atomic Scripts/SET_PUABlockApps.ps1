param([switch]$Undo)

if ($Undo) {
    Set-MpPreference -PUAProtection 0
} else {
    Set-MpPreference -PUAProtection 1
}
