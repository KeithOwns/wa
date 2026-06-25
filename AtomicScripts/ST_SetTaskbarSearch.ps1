param([switch]$Reverse)

# UI Location: Settings > Personalization > Taskbar

$Value = if ($Reverse) { 1 } else { 3 }
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" -Name "SearchboxTaskbarMode" -Value $Value -Type DWord -Force
Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
