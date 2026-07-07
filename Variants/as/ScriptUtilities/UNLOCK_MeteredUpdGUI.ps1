# This script completely removes the Group Policy registry key for Metered Updates.
# By removing the key rather than setting it to 0, it removes the "Managed by your organization"
# lock and returns full control of the setting back to the Windows Settings GUI.

Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" -Name "AllowAutoWindowsUpdateDownloadOverMeteredNetwork" -Force -ErrorAction SilentlyContinue
Write-Host "Policy removed. The Windows Settings GUI is now unlocked." -ForegroundColor Green
