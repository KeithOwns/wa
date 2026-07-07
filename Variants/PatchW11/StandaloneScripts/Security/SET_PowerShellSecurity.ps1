#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Enables advanced PowerShell Security Logging (Blue Team Hardening).
.DESCRIPTION
    Configures Group Policy Registry keys to enable:
    1. Script Block Logging (Event ID 4104) - Captures de-obfuscated code.
    2. Module Logging (Event ID 4103) - Captures pipeline execution.
    3. Transcription - Saves full session input/output to a local directory.
    
    This turns PowerShell into a "surveillance camera" for system activity.
#>

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

function Set-RegistryDword { param([string]$Path, [string]$Name, [int]$Value) if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }; Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type DWord -Force | Out-Null }
function Set-RegistryString { param([string]$Path, [string]$Name, [string]$Value) if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }; Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type String -Force | Out-Null }

Write-Header "POWERSHELL SECURITY"

$RegPath_PS = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell"
$RegPath_SBL = "$RegPath_PS\ScriptBlockLogging"
$RegPath_Mod = "$RegPath_PS\ModuleLogging"
$RegPath_Trn = "$RegPath_PS\Transcription"
$RegPath_ModNames = "$RegPath_Mod\ModuleNames"

$TranscriptDir = "$env:ProgramData\WinAuto\PowerShell_Transcripts"

try {
    # 1. Script Block Logging
    if (-not (Test-Path $RegPath_SBL)) { New-Item -Path $RegPath_SBL -Force | Out-Null }
    Set-RegistryDword -Path $RegPath_SBL -Name "EnableScriptBlockLogging" -Value 1
    Set-RegistryDword -Path $RegPath_SBL -Name "EnableScriptBlockInvocationLogging" -Value 1
    Write-LeftAligned "$FGGreen$Char_HeavyCheck Script Block Logging Enabled (Deep Visibility).$Reset"

    # 2. Module Logging
    if (-not (Test-Path $RegPath_ModNames)) { New-Item -Path $RegPath_ModNames -Force | Out-Null }
    Set-RegistryDword -Path $RegPath_Mod -Name "EnableModuleLogging" -Value 1
    Set-RegistryString -Path $RegPath_ModNames -Name "*" -Value "*"
    Write-LeftAligned "$FGGreen$Char_HeavyCheck Module Logging Enabled (All Modules).$Reset"

    # 3. Transcription
    if (-not (Test-Path $RegPath_Trn)) { New-Item -Path $RegPath_Trn -Force | Out-Null }
    
    # Create Transcript Directory
    if (-not (Test-Path $TranscriptDir)) { 
        New-Item -Path $TranscriptDir -ItemType Directory -Force | Out-Null 
        # Hide the directory
        $item = Get-Item -Path $TranscriptDir
        $item.Attributes = "Hidden"
    }

    Set-RegistryDword -Path $RegPath_Trn -Name "EnableTranscripting" -Value 1
    Set-RegistryString -Path $RegPath_Trn -Name "OutputDirectory" -Value $TranscriptDir
    Set-RegistryDword -Path $RegPath_Trn -Name "EnableInvocationHeader" -Value 1
    
    Write-LeftAligned "$FGGreen$Char_HeavyCheck Transcription Enabled.$Reset"
    Write-LeftAligned "   $FGGray Path: $TranscriptDir$Reset"

} catch {


;'WARNING'{$FGYellow};'SUCCESS'{$FGGreen};Default{$FGGray}}; Write-LeftAligned "$c$Message$Reset" }

# REGISTRY HELPER FUNCTIONS
function Set-RegistryDword { param([string]$Path, [string]$Name, [int]$Value) if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }; Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type DWord -Force | Out-Null }
function Set-RegistryString { param([string]$Path, [string]$Name, [string]$Value) if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }; Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type String -Force | Out-Null }

Write-Header "POWERSHELL SECURITY"

$RegPath_PS = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell"
$RegPath_SBL = "$RegPath_PS\ScriptBlockLogging"
$RegPath_Mod = "$RegPath_PS\ModuleLogging"
$RegPath_Trn = "$RegPath_PS\Transcription"
$RegPath_ModNames = "$RegPath_Mod\ModuleNames"

$TranscriptDir = "$env:ProgramData\WinAuto\PowerShell_Transcripts"

try {
    # 1. Script Block Logging
    if (-not (Test-Path $RegPath_SBL)) { New-Item -Path $RegPath_SBL -Force | Out-Null }
    Set-RegistryDword -Path $RegPath_SBL -Name "EnableScriptBlockLogging" -Value 1
    Set-RegistryDword -Path $RegPath_SBL -Name "EnableScriptBlockInvocationLogging" -Value 1
    Write-LeftAligned "$FGGreen$Char_HeavyCheck Script Block Logging Enabled (Deep Visibility).$Reset"

    # 2. Module Logging
    if (-not (Test-Path $RegPath_ModNames)) { New-Item -Path $RegPath_ModNames -Force | Out-Null }
    Set-RegistryDword -Path $RegPath_Mod -Name "EnableModuleLogging" -Value 1
    Set-RegistryString -Path $RegPath_ModNames -Name "*" -Value "*"
    Write-LeftAligned "$FGGreen$Char_HeavyCheck Module Logging Enabled (All Modules).$Reset"

    # 3. Transcription
    if (-not (Test-Path $RegPath_Trn)) { New-Item -Path $RegPath_Trn -Force | Out-Null }
    
    # Create Transcript Directory
    if (-not (Test-Path $TranscriptDir)) { 
        New-Item -Path $TranscriptDir -ItemType Directory -Force | Out-Null 
        # Hide the directory
        $item = Get-Item -Path $TranscriptDir
        $item.Attributes = "Hidden"
    }

    Set-RegistryDword -Path $RegPath_Trn -Name "EnableTranscripting" -Value 1
    Set-RegistryString -Path $RegPath_Trn -Name "OutputDirectory" -Value $TranscriptDir
    Set-RegistryDword -Path $RegPath_Trn -Name "EnableInvocationHeader" -Value 1
    
    Write-LeftAligned "$FGGreen$Char_HeavyCheck Transcription Enabled.$Reset"
    Write-LeftAligned "   $FGGray Path: $TranscriptDir$Reset"

} catch {
    Write-LeftAligned "$FGRed$Char_RedCross Failed to apply PowerShell hardening: $($_.Exception.Message)$Reset"
}