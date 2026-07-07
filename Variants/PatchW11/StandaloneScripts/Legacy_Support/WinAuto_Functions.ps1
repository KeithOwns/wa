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

# --- STANDALONE UI & LOGGING RESOURCES ---
$Esc = [char]0x1B
$Reset = "$Esc[0m"
$Bold = "$Esc[1m"
$FGCyan = "$Esc[96m"; $FGGreen = "$Esc[92m"; $FGRed = "$Esc[91m"; $FGYellow = "$Esc[93m"; $FGWhite = "$Esc[97m"; $FGGray = "$Esc[37m"; $FGDarkGray = "$Esc[90m"; $FGDarkBlue = "$Esc[34m"; $BGYellow = "$Esc[103m"; $FGBlack = "$Esc[30m"
$Char_Warn = [char]0x26A0; $Char_BallotCheck = [char]0x2611; $Char_Keyboard = [char]0x2328; $Char_Loop = [char]::ConvertFromUtf32(0x1F504); $Char_Copyright = [char]0x00A9; $Char_Finger = [char]0x261B; $Char_HeavyCheck = [char]0x2705; $Char_RedCross = [char]0x2716; $Char_HeavyMinus = [char]0x2796; $Char_Skip = [char]0x23ED

function Write-Boundary { param([string]$Color = $FGDarkBlue) Write-Host "$Color$([string]'_' * 60)$Reset" }
function Write-LeftAligned { param([string]$Text, [int]$Indent = 2) Write-Host (" " * $Indent + $Text) }
function Write-Centered { param([string]$Text, [int]$Width = 60) $clean = $Text -replace "\x1B\[[0-9;]*m", ""; $pad = [Math]::Floor(($Width - $clean.Length) / 2); if ($pad -lt 0) { $pad = 0 }; Write-Host (" " * $pad + $Text) }
function Write-Header { param([string]$Title) Clear-Host; Write-Host ""; $t1 = "$([char]::ConvertFromUtf32(0x1FA9F)) WinAuto $Char_Loop"; Write-Centered "$Bold$FGCyan$t1$Reset"; Write-Boundary; Write-Centered "$Bold$FGCyan$($Title.ToUpper())$Reset"; Write-Boundary }
function Invoke-AnimatedPause { param([string]$ActionText = "CONTINUE", [int]$Timeout = 10) Write-Host ""; $top = [Console]::CursorTop; $StopWatch = [System.Diagnostics.Stopwatch]::StartNew(); while ($StopWatch.Elapsed.TotalSeconds -lt $Timeout) { if ([Console]::KeyAvailable) { $StopWatch.Stop(); return $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") }; $Elapsed = $StopWatch.Elapsed; $Filled = [Math]::Floor($Elapsed.TotalSeconds); $Dynamic = ""; for ($i=0;$i-lt 10;$i++) { $c = if ($i -lt 5) { "Enter"[$i] } else { " " }; if ($i -lt $Filled) { $Dynamic += "${BGYellow}${FGBlack}$c${Reset}" } else { $Dynamic += "${FGYellow}$c${Reset}" } }; Write-Centered "${FGWhite}$Char_Keyboard Press ${FGDarkGray}$Dynamic${FGDarkGray}${FGWhite} to ${FGYellow}$ActionText${FGDarkGray} | or SKIP$Char_Skip${Reset}"; try { [Console]::SetCursorPosition(0, $top) } catch {}; Start-Sleep -Milliseconds 100 }; $StopWatch.Stop(); return [PSCustomObject]@{VirtualKeyCode=13} }
function Write-Log { param([string]$Message, [string]$Level = 'INFO') $c = switch($Level){'ERROR'{$FGRed};'WARNING'{$FGYellow};'SUCCESS'{$FGGreen};Default{$FGGray}}; Write-LeftAligned "$c$Message$Reset" }



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
