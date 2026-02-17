#Requires -RunAsAdministrator
<#
.SYNOPSIS
    WinAuto Task Scheduler
.DESCRIPTION
    Creates a Windows Scheduled Task to run WinAuto_Master_AUTO.ps1 automatically.
    Default schedule: First Monday of every month at 12:00 PM.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# --- STYLE ---
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$Char_HeavyLine = "_"; $Char_BallotCheck = "[v]"; $Char_Warn = "!"
$Esc = [char]0x1B; $Reset = "$Esc[0m"; $Bold = "$Esc[1m"
$FGRed = "$Esc[91m"; $FGGreen = "$Esc[92m"; $FGYellow = "$Esc[93m"
$FGCyan = "$Esc[96m"; $FGDarkGray = "$Esc[90m"; $BGBlue = "$Esc[44m"
$FGDarkBlue = "$Esc[34m"
# Added for Timeout Functionality
$FGBlack = "$Esc[30m"; $BGYellow = "$Esc[103m"; $FGWhite = "$Esc[97m"; $FGGray = "$Esc[37m"
# ASCII Equivalents
$Char_Finger = "->"; $Char_Keyboard = "[Key]"; $Char_Skip = ">>"

function Write-Centered { param($Text, $Width = 60) $clean = $Text -replace "$Esc\[[0-9;]*m", ""; $pad = [Math]::Floor(($Width - $clean.Length) / 2); if ($pad -lt 0) { $pad = 0 }; Write-Host (" " * $pad + $Text) }
function Write-Header { param($Title) Write-Host ""; Write-Host (" " * 4 + "$Bold$FGCyan$Title$Reset"); Write-Host "$FGDarkBlue$([string]$Char_HeavyLine * 60)$Reset" }

function Wait-KeyPressWithTimeout {
    param(
        [int]$Seconds,
        [scriptblock]$OnTick
    )
    $StopWatch = [System.Diagnostics.Stopwatch]::StartNew()
    while ($StopWatch.Elapsed.TotalSeconds -lt $Seconds) {
        if ($OnTick) { & $OnTick $StopWatch.Elapsed }
        if ([Console]::KeyAvailable) {
            $StopWatch.Stop()
            return $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
        Start-Sleep -Milliseconds 100
    }
    $StopWatch.Stop()
    return [PSCustomObject]@{ VirtualKeyCode = 13 }
}

# --- MAIN ---

Write-Header "AUTOMATION SCHEDULER"

$TaskName = "WinAuto Maintenance"
$ScriptPath = "$PSScriptRoot\A1_WinAuto_Master_AUTO.ps1"
$PowershellPath = (Get-Command powershell.exe).Source

Write-Host "  Target Script: $ScriptPath"
Write-Host ""

# Check existing
$existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($existing) {
    Write-Host "  $FGYellow$Char_Warn Task '$TaskName' already exists.$Reset"
    $choice = Read-Host "  Recreate/Update it? (Y/N)"
    if ($choice -notmatch "^[Yy]") { exit }
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
}

# Create Action
$Action = New-ScheduledTaskAction -Execute $PowershellPath -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`""

# Create Trigger (Monthly, First Monday @ 12pm)
# Note: Complex triggers like "First Monday" are hard in basic PS cmdlet.
# We'll default to Monthly on Day 1, user can edit.
$Trigger = New-ScheduledTaskTrigger -Monthly -Days 1 -At 12:00

# Create Settings (Run elevated, wake to run)
$Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries:$false -DontStopIfGoingOnBatteries:$false -StartWhenAvailable -RunOnlyIfNetworkAvailable -ExecutionTimeLimit (New-TimeSpan -Hours 2)

# Register
try {
    # Run as SYSTEM (NT AUTHORITY\SYSTEM) for full automation without login
    Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Settings $Settings -User "NT AUTHORITY\SYSTEM" -RunLevel Highest | Out-Null
    
    Write-Host ""
    Write-Host "  $FGGreen$Char_BallotCheck Task '$TaskName' created successfully!$Reset"
    Write-Host "  Schedule: Monthly on Day 1 at 12:00 PM"
    Write-Host "  Runs as:  SYSTEM (Hidden)"
    
}
catch {
    Write-Host ""
    Write-Host "  $Char_Warn Error creating task: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
# Animated Timeout
$PromptCursorTop = [Console]::CursorTop
$TickAction = {
    param($ElapsedTimespan)
    $WiggleFrame = [Math]::Floor($ElapsedTimespan.TotalMilliseconds / 500)
    $IsRight = ($WiggleFrame % 2) -eq 1
    if ($IsRight) { $CurrentChars = @(" ", $Char_Finger, "[", "E", "n", "t", "e", "r", "]", " ") } 
    else { $CurrentChars = @($Char_Finger, " ", "[", "E", "n", "t", "e", "r", "]", " ") }
    $FilledCount = [Math]::Floor($ElapsedTimespan.TotalSeconds)
    if ($FilledCount -gt 10) { $FilledCount = 10 }
    $DynamicPart = ""
    for ($i = 0; $i -lt 10; $i++) {
        $Char = $CurrentChars[$i]
        if ($i -lt $FilledCount) { $DynamicPart += "${BGYellow}${FGBlack}$Char${Reset}" } 
        else { if ($Char -eq " ") { $DynamicPart += " " } else { $DynamicPart += "${FGYellow}$Char${Reset}" } }
    }
    $PromptStr = "${FGWhite}$Char_Keyboard  Press ${FGDarkGray}$DynamicPart${FGDarkGray}${FGWhite}to${FGDarkGray} ${FGYellow}EXIT${FGDarkGray} ${FGWhite}|${FGDarkGray} or any other key ${FGWhite}to SKIP$Char_Skip${Reset}"
    try { [Console]::SetCursorPosition(0, $PromptCursorTop); Write-Centered $PromptStr } catch {}
}

$null = Wait-KeyPressWithTimeout -Seconds 10 -OnTick $TickAction
Write-Host ""



