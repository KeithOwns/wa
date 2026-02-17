<#
.SYNOPSIS
    Enables Memory Integrity (Core Isolation) via Registry.
    Part of WinAuto RegEdit (waR) branch.

.DESCRIPTION
    Sets the HypervisorEnforcedCodeIntegrity 'Enabled' value to 1.
    This change requires a system restart to take effect.
    This method allows the user to disable it later via Windows Security GUI.

.NOTES
    Key: HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity
    Value: Enabled (DWORD) = 1
#>

#Requires -RunAsAdministrator


$Path = "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity"
$Name = "Enabled"
$Value = 1

try {
    # Create Path if missing
    if (-not (Test-Path $Path)) {
        New-Item -Path $Path -Force | Out-Null
    }

    # Set Value
    Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type DWord -Force -ErrorAction Stop
    
    # Add Tracking Keys
    Set-ItemProperty -Path $Path -Name "WasEnabledBy" -Value 2 -Type DWord -Force -ErrorAction SilentlyContinue
    


    Write-Host "[SUCCESS] Memory Integrity Registry Keys set." -ForegroundColor Green
    Write-Host "A system restart is required for this change to take effect." -ForegroundColor Cyan
}
catch {
    Write-Host "[ERROR] Failed to set registry key: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Possible causes: Tamper Protection is active, or insufficient permissions." -ForegroundColor Gray
}
