param([switch]$Reverse)

if ($Reverse) {
    # Removing the property entirely gives control back to the Windows Settings GUI
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" -Name "AllowAutoWindowsUpdateDownloadOverMeteredNetwork" -Force -ErrorAction SilentlyContinue
} else {
    New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" -Force | Out-Null
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" -Name "AllowAutoWindowsUpdateDownloadOverMeteredNetwork" -Value 1 -Type DWord -Force
}
