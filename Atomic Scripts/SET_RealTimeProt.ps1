param([switch]$Reverse)

if ($Reverse) {
    Set-MpPreference -DisableRealtimeMonitoring $true
} else {
    Set-MpPreference -DisableRealtimeMonitoring $false
}
