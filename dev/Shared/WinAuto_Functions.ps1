#Requires -RunAsAdministrator
function Get-ThirdPartyAV {
    <#
    .SYNOPSIS
        Detects if a third-party Antivirus (non-Microsoft) is installed and active.
    .DESCRIPTION
        Queries the WMI SecurityCenter2 namespace to identify installed antivirus products.
        It filters out Windows Defender/Microsoft Defender to return only third-party solutions.
    .RETURN VALUE
        [string] Name of the third-party AV (comma-separated if multiple), or $null if none found.
    #>
    try {
        # Query SecurityCenter2 for antivirus products
        $avStatus = Get-CimInstance -Namespace root/SecurityCenter2 -ClassName AntivirusProduct -ErrorAction Stop
        
        # Filter out Windows/Microsoft Defender to find 3rd party tools
        $thirdPartyAV = $avStatus | Where-Object { 
            $_.displayName -notlike "*Windows Defender*" -and 
            $_.displayName -notlike "*Microsoft Defender*" 
        }

        if ($thirdPartyAV) {
            # Join multiple detected AVs into a single string to return a clean [string] type
            return ($thirdPartyAV.displayName -join ", ")
        }
        return $null
    }
    catch {
        # Note: SecurityCenter2 namespace does not exist on Windows Server.
        # This catch block is expected behavior on Server OS.
        Write-Verbose "Could not query SecurityCenter2 (This is normal on Windows Server): $($_.Exception.Message)"
        return $null
    }
}

function Test-TamperProtection {
    <#
    .SYNOPSIS
        Checks the status of Windows Defender Tamper Protection.
    .DESCRIPTION
        Tamper Protection prevents malicious modification of security settings.
        This function checks the status via the MPComputerStatus cmdlet or Registry.
    .RETURN VALUE
        [bool] $true if Enabled, $false if Disabled.
    #>
    try {
        # Method 1: Modern Windows (Preferred)
        # Check using the official Defender cmdlet
        if (Get-Command "Get-MpComputerStatus" -ErrorAction SilentlyContinue) {
            $mpStatus = Get-MpComputerStatus -ErrorAction SilentlyContinue
            if ($mpStatus) {
                return [bool]$mpStatus.IsTamperProtected
            }
        }

        # Method 2: Registry Fallback
        # 5 = Enabled, 0/4 = Disabled (approximate values for this key)
        $regPath = "HKLM:\SOFTWARE\Microsoft\Windows Defender\Features"
        $regName = "TamperProtection"
        
        $tpValue = Get-ItemProperty -Path $regPath -Name $regName -ErrorAction SilentlyContinue
        
        # Check if the key exists AND if the specific property exists on that key
        if ($tpValue -and $tpValue.PSObject.Properties[$regName]) {
            return [bool]($tpValue.$regName -eq 5)
        }

        return $false
    }
    catch {
        Write-Verbose "Could not determine Tamper Protection status: $($_.Exception.Message)"
        return $false
    }
}

function Initialize-WinAutoLogging {
    <#
    .SYNOPSIS
        Loads and initializes the WinAuto logging module.
    #>
    $LoggingModule = "$PSScriptRoot\MODULE_Logging.ps1"
    if (Test-Path $LoggingModule) {
        . $LoggingModule
        Init-Logging
    } else {
        Write-Warning "Logging module not found at $LoggingModule"
    }
}

function Set-WUSettings {
    <#
    .SYNOPSIS
        Applies Windows Update registry configurations based on security mode.
    .PARAMETER EnhancedSecurity
        If true, enables expedited updates and metered downloads.
    #>
    param([switch]$EnhancedSecurity)
    
    # REGISTRY PATHS
    $Path_UX = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings"
    $Path_Policy = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
    
    try {
        if ($EnhancedSecurity) {
            # Set other expedited settings
            Set-RegistryDword -Path $Path_UX -Name "IsExpedited" -Value 1
            Set-RegistryDword -Path $Path_UX -Name "AllowAutoWindowsUpdateDownloadOverMeteredNetwork" -Value 1
        } else {
            Set-RegistryDword -Path $Path_UX -Name "IsExpedited" -Value 0
            Set-RegistryDword -Path $Path_UX -Name "AllowAutoWindowsUpdateDownloadOverMeteredNetwork" -Value 0
        }
        
        # General Required Settings
        Set-RegistryDword -Path $Path_UX -Name "AllowMUUpdateService" -Value 1
        Set-RegistryDword -Path $Path_UX -Name "RestartNotificationsAllowed2" -Value 1
        
        # Enable Restartable Apps
        $WinlogonPath = "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
        Set-ItemProperty -Path $WinlogonPath -Name "RestartApps" -Value 1 -Type DWord -Force
        
        # Kill Settings app to refresh UI
        Get-Process "SystemSettings" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        
    }
    catch {
        Write-Host "ERROR in Set-WUSettings: $($_.Exception.Message)" -ForegroundColor Red
    }
}
