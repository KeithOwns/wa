<#
.SYNOPSIS
    Configures Windows System Configuration setting (Unlock_PhishingProtection).
.DESCRIPTION
    Applies security hardening or system configuration for Unlock_PhishingProtection in the Windows environment.
.EXAMPLE
    .\Unlock_PhishingProtection.ps1
#>
# Clears the "managed by your administrator" lock on Windows Security's
# Phishing protection toggle, without touching the toggle's On/Off state.
# Run this alone to confirm the lock itself is gone before re-testing
# SET_PhishingProtection.ps1's toggle logic.

Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WTDS\Components" -Name "ServiceEnabled" -Force -ErrorAction SilentlyContinue
Stop-Process -Name "SecHealthUI" -Force -ErrorAction SilentlyContinue
Restart-Service -Name "SecurityHealthService" -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 1

Start-Process "windowsdefender://appbrowser"

