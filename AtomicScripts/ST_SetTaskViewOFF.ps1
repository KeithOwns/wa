param([switch]$Reverse)

# UI Location: Settings > Personalization > Taskbar

$Value = if ($Reverse) { 1 } else { 0 }
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowTaskViewButton" -Value $Value -Type DWord -Force
Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
