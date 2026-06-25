param([switch]$Reverse)

# UI Location: legacy Performance Options dialog (SystemPropertiesPerformance.exe), reached via Settings > System > About > Advanced system settings

$Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects"
$Name = "VisualFXSetting"
$Value = if ($Reverse) { 0 } else { 2 }

if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type DWord -Force -ErrorAction SilentlyContinue
