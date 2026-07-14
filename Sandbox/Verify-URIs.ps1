# Verify-URIs.ps1
# Helper script to continuously validate that Windows Settings and Defender URIs exist.
# Since invalid ms-settings URIs silently fall back to the Settings home page,
# this script opens each one and asks for visual confirmation.

$UrisToTest = @(
    [pscustomobject]@{ Description = "Windows Update > Advanced options"; Uri = "ms-settings:windowsupdate-options" }
    [pscustomobject]@{ Description = "Accounts > Sign-in options"; Uri = "ms-settings:signinoptions" }
    [pscustomobject]@{ Description = "Privacy & Security > Diagnostics & feedback"; Uri = "ms-settings:privacy-feedback" }
    [pscustomobject]@{ Description = "Privacy & Security > General"; Uri = "ms-settings:privacy-general" }
    [pscustomobject]@{ Description = "Personalization > Taskbar"; Uri = "ms-settings:taskbar" }
    [pscustomobject]@{ Description = "Accessibility > Visual effects"; Uri = "ms-settings:easeofaccess-visualeffects" }
    [pscustomobject]@{ Description = "System > Storage"; Uri = "ms-settings:storagesense" }
    [pscustomobject]@{ Description = "Windows Security > Virus & threat protection"; Uri = "windowsdefender://threat" }
    [pscustomobject]@{ Description = "Windows Security > App & browser control"; Uri = "windowsdefender://appbrowser" }
    [pscustomobject]@{ Description = "Windows Security > Device security"; Uri = "windowsdefender://devicesecurity" }
    [pscustomobject]@{ Description = "Windows Security > Firewall & network protection"; Uri = "windowsdefender://network" }
)

$Results = @()

Clear-Host
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "       Windows URI Verifier Tool          " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "For each URI, a window will pop open. Please check if it navigated to the correct specific page."
Write-Host "Note: If a URI is invalid, Windows will usually fallback to the default Home page."
Write-Host ""

foreach ($item in $UrisToTest) {
    Write-Host "Testing: $($item.Description)" -ForegroundColor Yellow
    Write-Host "URI: $($item.Uri)" -ForegroundColor Gray
    
    try {
        Start-Process $item.Uri -ErrorAction Stop
    } catch {
        Write-Host "Failed to launch process for $($item.Uri)." -ForegroundColor Red
        $Results += [pscustomobject]@{ Description = $item.Description; URI = $item.Uri; Status = "Failed to launch" }
        Write-Host ""
        continue
    }

    # Give the UI a moment to render
    Start-Sleep -Seconds 2

    $response = Read-Host "Did it open to the correct sub-page? (y/n)"
    if ($response -match "^y") {
        Write-Host "--> Passed" -ForegroundColor Green
        $Results += [pscustomobject]@{ Description = $item.Description; URI = $item.Uri; Status = "Pass" }
    } else {
        Write-Host "--> Failed / Incorrect" -ForegroundColor Red
        $Results += [pscustomobject]@{ Description = $item.Description; URI = $item.Uri; Status = "Fail" }
    }
    
    # Try to close Settings or SecHealthUI to keep the screen clean for the next test
    if ($item.Uri -match "ms-settings") {
        Stop-Process -Name "SystemSettings" -ErrorAction SilentlyContinue
    } elseif ($item.Uri -match "windowsdefender") {
        Stop-Process -Name "SecHealthUI" -ErrorAction SilentlyContinue
    }
    
    Write-Host "------------------------------------------"
}

Write-Host "VERIFICATION REPORT" -ForegroundColor Cyan
$Results | Format-Table -AutoSize
