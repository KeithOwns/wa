$scripts = @{
    # Automation Scripts
    "SET_MicrosoftUpd.ps1" = 'Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" -Name "AllowMUUpdateService" -Value 1 -Type DWord -Force'
    "SET_RestartIsReq.ps1" = 'Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" -Name "RestartNotificationsAllowed2" -Value 1 -Type DWord -Force'
    "SET_RestartApps.ps1" = 'Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "RestartApps" -Value 1 -Type DWord -Force'
    
    # Security Scripts
    "SET_PSTranscription.ps1" = 'New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\Transcription" -Force | Out-Null; Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\Transcription" -Name "EnableTranscripting" -Value 1 -Type DWord -Force'
    "SET_Telemetry.ps1" = 'New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Force | Out-Null; Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -Value 0 -Type DWord -Force'
    "SET_LLMNR.ps1" = 'New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient" -Force | Out-Null; Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient" -Name "EnableMulticast" -Value 0 -Type DWord -Force'
    "SET_PSScriptBlock.ps1" = 'New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging" -Force | Out-Null; Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging" -Name "EnableScriptBlockLogging" -Value 1 -Type DWord -Force'
    "SET_PSModuleLogging.ps1" = 'New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging" -Force | Out-Null; Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging" -Name "EnableModuleLogging" -Value 1 -Type DWord -Force'
    "SET_NetBIOS.ps1" = 'Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration | Where-Object { $_.IPEnabled -eq $true } | ForEach-Object { $_.SetTCPIPNetBIOS(2) }'
    "SET_RealTimeProt.ps1" = 'Set-MpPreference -DisableRealtimeMonitoring $false'
    "SET_PUABlockApps.ps1" = 'Set-MpPreference -PUAProtection 1'
    "SET_PUABlockDLs.ps1" = 'New-Item -Path "HKCU:\Software\Microsoft\Edge" -Force | Out-Null; Set-ItemProperty -Path "HKCU:\Software\Microsoft\Edge" -Name "SmartScreenPuaEnabled" -Value 1 -Type DWord -Force'
    "SET_MemoryInteg.ps1" = 'New-Item -Path "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" -Force | Out-Null; Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" -Name "Enabled" -Value 1 -Type DWord -Force'
    "SET_KernelMode.ps1" = 'New-Item -Path "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\KernelShadowStacks" -Force | Out-Null; Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\KernelShadowStacks" -Name "Enabled" -Value 1 -Type DWord -Force'
    "SET_LocalSecurity.ps1" = 'Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "RunAsPPL" -Value 1 -Type DWord -Force'
    "SET_FirewallON.ps1" = 'Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True'

    # User Interface Scripts
    "SET_TaskbarSearch.ps1" = 'Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" -Name "SearchboxTaskbarMode" -Value 0 -Type DWord -Force'
    "SET_TaskViewOFF.ps1" = 'Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowTaskViewButton" -Value 0 -Type DWord -Force'
    "SET_ShowExtensions.ps1" = 'Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "HideFileExt" -Value 0 -Type DWord -Force'
    "SET_ShowHidden.ps1" = 'Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Hidden" -Value 1 -Type DWord -Force; Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowSuperHidden" -Value 1 -Type DWord -Force'

    # Maintenance Scripts
    "RUN_UpdateSuite.ps1" = 'Install-Module PSWindowsUpdate -Force -AcceptLicense; Get-WindowsUpdate -Install -AcceptAll -AutoReboot'
    "RUN_OptimizeDisks.ps1" = 'Optimize-Volume -DriveLetter C -ReTrim -Defrag -Verbose'
    "RUN_SystemCleanup.ps1" = 'Cleanmgr.exe /sagerun:1'
    "RUN_WindowsRepair.ps1" = 'sfc /scannow; DISM /Online /Cleanup-Image /RestoreHealth'
}

foreach ($key in $scripts.Keys) {
    $path = Join-Path $PSScriptRoot $key
    $content = $scripts[$key]
    Set-Content -Path $path -Value $content -Encoding UTF8
    Write-Host "Created $key"
}
