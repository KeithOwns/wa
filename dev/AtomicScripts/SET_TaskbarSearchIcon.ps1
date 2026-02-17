# Script to set Taskbar Search to "Search icon and label"
# Value 0 = Hidden
# Value 1 = Search icon only
# Value 2 = Search box
# Value 3 = Search icon and label

$regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search"
$regName = "SearchboxTaskbarMode"
$desiredValue = 3

try {
    # Verify path exists
    if (-not (Test-Path $regPath)) {
        Write-Host "Creating Registry Path..."
        New-Item -Path $regPath -Force | Out-Null
    }

    # Set the registry value
    Set-ItemProperty -Path $regPath -Name $regName -Value $desiredValue -Type DWord -Force

    Write-Host "Search mode set to 'Icon and Label' (Value: $desiredValue)."
    Write-Host "Restarting Windows Explorer to apply changes..."
    
    # Restart Explorer to refresh the taskbar
    Stop-Process -Name explorer -Force
    
    Write-Host "Done."
}
catch {
    Write-Error "An error occurred: $_"
}