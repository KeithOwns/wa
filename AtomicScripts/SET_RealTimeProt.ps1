param([switch]$Reverse)

# Non-policy Defender key only — the Policies\Microsoft\Windows Defender path
# would lock Windows Security's Real-Time Protection toggle as "managed by
# your organization." Set-MpPreference already applies the effect.
$val = if ($Reverse) { 1 } else { 0 }
$mpVal = if ($Reverse) { $true } else { $false }

$Path = "HKLM:\SOFTWARE\Microsoft\Windows Defender\Real-Time Protection"
if (-not (Test-Path $Path)) { New-Item -Path $Path -Force -ErrorAction SilentlyContinue | Out-Null }
Set-ItemProperty -Path $Path -Name "DisableRealtimeMonitoring" -Value $val -Type DWord -Force -ErrorAction SilentlyContinue
Set-MpPreference -DisableRealtimeMonitoring $mpVal -ErrorAction SilentlyContinue
