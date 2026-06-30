param([switch]$Reverse)

# Non-policy Defender key only — the Policies\Microsoft\Windows Defender path
# would lock Windows Security's Real-Time Protection toggle as "managed by
# your organization." Set-MpPreference already applies the effect.
# A prior run of the old version may have already left that Policies value
# behind, which locks the toggle regardless of what this script does now —
# remove it so the toggle is actually interactive.
# UI Location: Windows Security > Virus & threat protection > Manage settings
Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" -Name "DisableRealtimeMonitoring" -Force -ErrorAction SilentlyContinue

# A registered 3rd-party AV owns real-time scanning — Defender's own engine is inactive,
# so there's nothing for Set-MpPreference to meaningfully change here.
$avName = $null
try {
    $avList = Get-CimInstance -Namespace root/SecurityCenter2 -ClassName AntivirusProduct -ErrorAction SilentlyContinue
    foreach ($av in $avList) {
        if ($av.displayName -and $av.displayName -notmatch "Windows Defender" -and $av.displayName -notmatch "Microsoft Defender Antivirus") {
            $avName = $av.displayName
            break
        }
    }
}
catch {}
if ($avName) {
    Write-Host "Real-Time Protection managed by $avName — skipping." -ForegroundColor Yellow
    return
}

$val = if ($Reverse) { 1 } else { 0 }
$mpVal = if ($Reverse) { $true } else { $false }

$tp = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows Defender\Features" -Name "TamperProtection" -ErrorAction SilentlyContinue).TamperProtection
if ($tp -eq 5) {
    Write-Host "Tamper Protection is ENABLED and blocking changes." -ForegroundColor Yellow
    return
}

$Path = "HKLM:\SOFTWARE\Microsoft\Windows Defender\Real-Time Protection"
if (-not (Test-Path $Path)) { New-Item -Path $Path -Force -ErrorAction SilentlyContinue | Out-Null }
Set-ItemProperty -Path $Path -Name "DisableRealtimeMonitoring" -Value $val -Type DWord -Force -ErrorAction SilentlyContinue
Set-MpPreference -DisableRealtimeMonitoring $mpVal -ErrorAction SilentlyContinue
