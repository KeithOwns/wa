param([switch]$Reverse)

$Path = "HKCU:\Control Panel\Desktop\WindowMetrics"
$Name = "MinAnimate"
$Value = if ($Reverse) { "1" } else { "0" }

if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type String -Force -ErrorAction SilentlyContinue
