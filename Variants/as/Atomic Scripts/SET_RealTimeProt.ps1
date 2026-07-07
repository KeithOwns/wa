param([switch]$Undo)

if ($Undo) {
    Set-MpPreference -DisableRealtimeMonitoring $true
} else {
    Set-MpPreference -DisableRealtimeMonitoring $false
}
