$scripts = @{
    # Automation Scripts
    "SET_MicrosoftUpd.ps1" = @{
        normal = 'Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" -Name "AllowMUUpdateService" -Value 1 -Type DWord -Force'
        undo   = 'Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" -Name "AllowMUUpdateService" -Value 0 -Type DWord -Force'
    }
    "SET_RestartIsReq.ps1" = @{
        normal = 'Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" -Name "RestartNotificationsAllowed2" -Value 1 -Type DWord -Force'
        undo   = 'Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" -Name "RestartNotificationsAllowed2" -Value 0 -Type DWord -Force'
    }
    "SET_RestartApps.ps1" = @{
        normal = 'Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "RestartApps" -Value 1 -Type DWord -Force'
        undo   = 'Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "RestartApps" -Value 0 -Type DWord -Force'
    }
    
    # Security Scripts
    "SET_PSTranscription.ps1" = @{
        normal = 'New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\Transcription" -Force | Out-Null; Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\Transcription" -Name "EnableTranscripting" -Value 1 -Type DWord -Force'
        undo   = 'Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\Transcription" -Name "EnableTranscripting" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue'
    }
    "SET_Telemetry.ps1" = @{
        normal = 'New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Force | Out-Null; Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -Value 0 -Type DWord -Force'
        undo   = 'Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -Value 3 -Type DWord -Force -ErrorAction SilentlyContinue'
    }
    "SET_LLMNR.ps1" = @{
        normal = 'New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient" -Force | Out-Null; Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient" -Name "EnableMulticast" -Value 0 -Type DWord -Force'
        undo   = 'Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient" -Name "EnableMulticast" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue'
    }
    "SET_PSScriptBlock.ps1" = @{
        normal = 'New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging" -Force | Out-Null; Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging" -Name "EnableScriptBlockLogging" -Value 1 -Type DWord -Force'
        undo   = 'Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging" -Name "EnableScriptBlockLogging" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue'
    }
    "SET_PSModuleLogging.ps1" = @{
        normal = 'New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging" -Force | Out-Null; Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging" -Name "EnableModuleLogging" -Value 1 -Type DWord -Force'
        undo   = 'Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging" -Name "EnableModuleLogging" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue'
    }
    "SET_NetBIOS.ps1" = @{
        normal = 'Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration | Where-Object { $_.IPEnabled -eq $true } | ForEach-Object { $_.SetTCPIPNetBIOS(2) }'
        undo   = 'Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration | Where-Object { $_.IPEnabled -eq $true } | ForEach-Object { $_.SetTCPIPNetBIOS(0) }'
    }
    "SET_RealTimeProt.ps1" = @{
        normal = 'Set-MpPreference -DisableRealtimeMonitoring $false'
        undo   = 'Set-MpPreference -DisableRealtimeMonitoring $true'
    }
    "SET_PUABlockApps.ps1" = @{
        normal = 'Set-MpPreference -PUAProtection 1'
        undo   = 'Set-MpPreference -PUAProtection 0'
    }
    "SET_PUABlockDLs.ps1" = @{
        normal = 'New-Item -Path "HKCU:\Software\Microsoft\Edge" -Force | Out-Null; Set-ItemProperty -Path "HKCU:\Software\Microsoft\Edge" -Name "SmartScreenPuaEnabled" -Value 1 -Type DWord -Force'
        undo   = 'Set-ItemProperty -Path "HKCU:\Software\Microsoft\Edge" -Name "SmartScreenPuaEnabled" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue'
    }
    "SET_MemoryInteg.ps1" = @{
        normal = 'New-Item -Path "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" -Force | Out-Null; Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" -Name "Enabled" -Value 1 -Type DWord -Force'
        undo   = 'Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" -Name "Enabled" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue'
    }
    "SET_KernelMode.ps1" = @{
        normal = 'New-Item -Path "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\KernelShadowStacks" -Force | Out-Null; Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\KernelShadowStacks" -Name "Enabled" -Value 1 -Type DWord -Force'
        undo   = 'Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\KernelShadowStacks" -Name "Enabled" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue'
    }
    "SET_LocalSecurity.ps1" = @{
        normal = 'Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "RunAsPPL" -Value 1 -Type DWord -Force'
        undo   = 'Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "RunAsPPL" -Value 0 -Type DWord -Force'
    }
    "SET_FirewallON.ps1" = @{
        normal = 'Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True'
        undo   = 'Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False'
    }

    # User Interface Scripts
        normal = 'New-Item -Path "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" -Force | Set-ItemProperty -Name "(default)" -Value "" -Force'
        undo   = 'Remove-Item -Path "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}" -Recurse -Force -ErrorAction SilentlyContinue'
    }
    "SET_TaskbarSearch.ps1" = @{
        normal = 'Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" -Name "SearchboxTaskbarMode" -Value 0 -Type DWord -Force'
        undo   = 'Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" -Name "SearchboxTaskbarMode" -Value 3 -Type DWord -Force'
    }
    "SET_TaskViewOFF.ps1" = @{
        normal = 'Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowTaskViewButton" -Value 0 -Type DWord -Force'
        undo   = 'Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowTaskViewButton" -Value 1 -Type DWord -Force'
    }
    "SET_ShowExtensions.ps1" = @{
        normal = 'Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "HideFileExt" -Value 0 -Type DWord -Force'
        undo   = 'Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "HideFileExt" -Value 1 -Type DWord -Force'
    }
    "SET_ShowHidden.ps1" = @{
        normal = 'Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Hidden" -Value 1 -Type DWord -Force; Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowSuperHidden" -Value 1 -Type DWord -Force'
        undo   = 'Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Hidden" -Value 2 -Type DWord -Force; Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowSuperHidden" -Value 0 -Type DWord -Force'
    }
}

foreach ($key in $scripts.Keys) {
    $path = Join-Path $PSScriptRoot $key
    $normal = $scripts[$key].normal
    $undo = $scripts[$key].undo
    
    $content = @"
param([switch]`$Undo)

if (`$Undo) {
    $undo
} else {
    $normal
}
"@
    Set-Content -Path $path -Value $content -Encoding UTF8
    Write-Host "Updated $key"
}
