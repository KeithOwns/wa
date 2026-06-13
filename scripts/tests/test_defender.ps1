# test_defender.ps1
# Standalone test for Microsoft Defender Real-time Protection configuration

Write-Host "--- Defender Status Pre-Check ---" -ForegroundColor Cyan
$pref = Get-MpPreference
Write-Host "DisableRealtimeMonitoring: $($pref.DisableRealtimeMonitoring)"
Write-Host "TamperProtection: $((Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows Defender\Features" -Name "TamperProtection" -ErrorAction SilentlyContinue).TamperProtection)"

Write-Host "`n--- Attempting to Enable Real-time Protection (Set-MpPreference) ---" -ForegroundColor Yellow
try {
    # -DisableRealtimeMonitoring $false means Enable it
    Set-MpPreference -DisableRealtimeMonitoring $false -ErrorAction Stop
    Write-Host "[+] Command executed without immediate error." -ForegroundColor Green
}
catch {
    Write-Host "[-] Command failed: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.Exception.Message -match "Access is denied") {
        Write-Host "    Note: This is expected if Tamper Protection is enabled." -ForegroundColor Gray
    }
}

Write-Host "`n--- Verifying Result ---" -ForegroundColor Cyan
$prefAfter = Get-MpPreference
if ($prefAfter.DisableRealtimeMonitoring -eq $false) {
    Write-Host "[v] SUCCESS: Real-time Protection is ENABLED." -ForegroundColor Green
} else {
    Write-Host "[x] FAILED: Real-time Protection is still DISABLED." -ForegroundColor Red
}

Write-Host "`nTest Complete."
