param([switch]$Reverse)

$Path = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppHost"
$Name = "EnableWebContentEvaluation"
$Value = if ($Reverse) { 0 } else { 1 }

if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type DWord -Force -ErrorAction SilentlyContinue
