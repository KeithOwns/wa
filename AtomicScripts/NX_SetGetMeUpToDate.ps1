param([switch]$Reverse)

# UI Location: none (registry/GPO-only, no known visible toggle)

if ($Reverse) {
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" -Name "IsExpedited" -Value 0 -Type DWord -Force
} else {
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" -Name "IsExpedited" -Value 1 -Type DWord -Force
}
