#Requires -RunAsAdministrator
<#
.SYNOPSIS
    WinAuto Logging Module
.DESCRIPTION
    Provides centralized logging capabilities for WinAuto scripts.
    Supports console output (with colors) and file logging (with timestamps).
    Generates execution reports.
#>

# --- LOGGING INITIALIZATION ---

function Init-Logging {
    <#
    .SYNOPSIS
        Initializes the logging system.
    .DESCRIPTION
        Creates the 'logs' directory at the project root if it doesn't exist.
        Sets the global log file path with a timestamp.
        Respects existing log sessions to prevent fragmentation.
    #>
    
    # If a log path is already set and valid, just ensure Transcript is running and return.
    if ($Global:WinAutoLogPath -and (Test-Path $Global:WinAutoLogPath)) {
        try { 
            Start-Transcript -Path $Global:WinAutoLogPath -Append -Force -ErrorAction SilentlyContinue | Out-Null
        } catch {}
        return
    }

    $ProjectRoot = Resolve-Path "$PSScriptRoot\..\.."
    $LogDir = Join-Path $ProjectRoot "logs"
    
    if (-not (Test-Path $LogDir)) {
        New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
    }

    $Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $Global:WinAutoLogPath = Join-Path $LogDir "WinAuto_Log_$Timestamp.txt"
    
    # Initialize log file with header
    $Header = "WinAuto Log Started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Set-Content -Path $Global:WinAutoLogPath -Value $Header -Encoding UTF8
    
    # Write to console using existing UI function if available, otherwise host
    if (Get-Command "Write-Log" -ErrorAction SilentlyContinue) {
        Write-Host "Logging initialized: $Global:WinAutoLogPath" -ForegroundColor DarkGray
    }

    # Start Transcript to capture all output
    try { 
        Stop-Transcript -ErrorAction SilentlyContinue 
        Start-Transcript -Path $Global:WinAutoLogPath -Append -Force -ErrorAction SilentlyContinue | Out-Null
    } catch {}
}

# --- CORE LOGGING FUNCTION ---

function Write-Log {
    <#
    .SYNOPSIS
        Writes a message to the console and the log file.
    .DESCRIPTION
        - Console: Displays the message with appropriate color based on severity.
        - File: Appends the message with a timestamp and severity tag.
    .PARAMETER Message
        The text to log.
    .PARAMETER Level
        Severity level: INFO, WARNING, ERROR, SUCCESS.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet('INFO', 'WARNING', 'ERROR', 'SUCCESS')]
        [string]$Level = 'INFO',

        [string]$Path = $Global:WinAutoLogPath
    )

    # 1. Console Output (Visuals)
    
    # Fallback for missing globals (prevents crashes if Global_Resources isn't loaded)
    $L_Check = if (Get-Variable -Name "Char_HeavyCheck" -Scope Global -ErrorAction SilentlyContinue) { $global:Char_HeavyCheck } else { "V" }
    $L_Warn  = if (Get-Variable -Name "Char_Warn" -Scope Global -ErrorAction SilentlyContinue) { $global:Char_Warn } else { "!" }
    $L_Cross = if (Get-Variable -Name "Char_RedCross" -Scope Global -ErrorAction SilentlyContinue) { $global:Char_RedCross } else { "X" }
    
    switch ($Level) {
        'INFO' {
            # Standard info, maybe dark gray or default
            # Using Write-LeftAligned if available for consistency
            if (Get-Command "Write-LeftAligned" -ErrorAction SilentlyContinue) {
                Write-LeftAligned "$FGGray$Message$Reset"
            } else {
                Write-Host "   $Message" -ForegroundColor Gray
            }
        }
        'WARNING' {
            if (Get-Command "Write-LeftAligned" -ErrorAction SilentlyContinue) {
                Write-LeftAligned "$FGYellow$L_Warn $Message$Reset"
            } else {
                Write-Host " [!] $Message" -ForegroundColor Yellow
            }
        }
        'ERROR' {
            if (Get-Command "Write-LeftAligned" -ErrorAction SilentlyContinue) {
                Write-LeftAligned "$FGRed$L_Cross $Message$Reset"
            } else {
                Write-Host " [X] $Message" -ForegroundColor Red
            }
        }
        'SUCCESS' {
            if (Get-Command "Write-LeftAligned" -ErrorAction SilentlyContinue) {
                Write-LeftAligned "$FGGreen$L_Check $Message$Reset"
            } else {
                Write-Host " [V] $Message" -ForegroundColor Green
            }
        }
    }

    # 2. File Output
    if ($Global:WinAutoLogPath) {
        $FileTimestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $LogEntry = "[$FileTimestamp] [$Level] $Message"
        Add-Content -Path $Global:WinAutoLogPath -Value $LogEntry -Encoding UTF8 -ErrorAction SilentlyContinue
    }
}

# --- REPORTING ---

function Get-LogReport {
    <#
    .SYNOPSIS
        Generates a summary report of the current log session.
    .DESCRIPTION
        Reads the current log file and counts the occurrences of each severity level.
    #>
    if (-not $Global:WinAutoLogPath -or -not (Test-Path $Global:WinAutoLogPath)) {
        Write-Warning "No active log file found."
        return
    }

    $Content = @(Get-Content -Path $Global:WinAutoLogPath)
    $TotalLines = $Content.Count
    
    # Count strict log tags AND visual indicators captured by transcript
    $Errors    = @($Content | Select-String -Pattern "\[ERROR\]|✖|❌").Count
    $Warnings  = @($Content | Select-String -Pattern "\[WARNING\]|⚠|!").Count
    $Successes = @($Content | Select-String -Pattern "\[SUCCESS\]|✅|✔|☑").Count
    
    Write-Host ""
    Write-Boundary
    Write-Centered "SESSION REPORT"
    Write-Boundary
    Write-LeftAligned "Log File: $Global:WinAutoLogPath"
    Write-Host ""
    Write-LeftAligned "Total Entries : $TotalLines"
    Write-LeftAligned "Successes     : $Successes"
    Write-LeftAligned "Warnings      : $Warnings"
    Write-LeftAligned "Errors        : $Errors"
    Write-Boundary
    Write-Host ""
}
