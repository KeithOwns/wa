param([switch]$Reverse)

$Value = if ($Reverse) { "Off" } else { "RequireAdmin" }

Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" -Name "SmartScreenEnabled" -Value $Value -Type String -Force -ErrorAction SilentlyContinue
