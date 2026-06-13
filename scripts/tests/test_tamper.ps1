# test_tamper.ps1
# Standalone test for Microsoft Defender Tamper Protection configuration

Write-Host "--- Tamper Protection Status Pre-Check ---" -ForegroundColor Cyan
$pref = Get-MpPreference
# Note: IsTamperProtected is the property in Get-MpPreference
Write-Host "IsTamperProtected (Get-MpPreference): $($pref.IsTamperProtected)"

$regPath = "HKLM:\SOFTWARE\Microsoft\Windows Defender\Features"
$tpReg = (Get-ItemProperty -Path $regPath -Name "TamperProtection" -ErrorAction SilentlyContinue).TamperProtection
Write-Host "TamperProtection (Registry Value): $tpReg"
Write-Host "  (0 = Disabled, 5 = Enabled/Locked)" -ForegroundColor Gray

Write-Host "`n--- Attempting to Enable Tamper Protection (Set-MpPreference) ---" -ForegroundColor Yellow
try {
    # -DisableTamperProtection $false means Enable it
    Set-MpPreference -DisableTamperProtection $false -ErrorAction Stop
    Write-Host "[+] Command executed without immediate error." -ForegroundColor Green
}
catch {
    Write-Host "[-] Command failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n--- Verifying Result ---" -ForegroundColor Cyan
$prefAfter = Get-MpPreference
$tpRegAfter = (Get-ItemProperty -Path $regPath -Name "TamperProtection" -ErrorAction SilentlyContinue).TamperProtection

Write-Host "IsTamperProtected (After): $($prefAfter.IsTamperProtected)"
Write-Host "TamperProtection Registry (After): $tpRegAfter"

if ($prefAfter.IsTamperProtected -eq $true -or $tpRegAfter -eq 5) {
    Write-Host "[v] SUCCESS: Tamper Protection is ENABLED." -ForegroundColor Green
} else {
    Write-Host "[x] FAILED: Tamper Protection is still DISABLED." -ForegroundColor Red
}

Write-Host "`nTest Complete."
