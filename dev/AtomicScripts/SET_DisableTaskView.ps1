# Sets the Registry Key to Disable the Task View Button
$registryPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
$name = "ShowTaskViewButton"

# Set value to 0 (Off)
Set-ItemProperty -Path $registryPath -Name $name -Value 0

# Restart Explorer to apply changes immediately
Stop-Process -Name explorer -Force