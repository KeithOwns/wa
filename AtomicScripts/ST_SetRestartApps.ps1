param([switch]$Reverse)

# UI Location: Settings > Accounts > Sign-in options

if ($Reverse) {
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "RestartApps" -Value 0 -Type DWord -Force
} else {
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "RestartApps" -Value 1 -Type DWord -Force
}
