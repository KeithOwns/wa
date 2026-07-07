#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Notification Setup for Automation
.DESCRIPTION
    Configures Webhook or Email notifications for the Automated Suite results.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# --- STYLE ---
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$Char_HeavyLine = [char]0x2501; $Char_BallotCheck = [char]0x2611; $Char_Warn = [char]0x26A0
$Esc = [char]0x1B; $Reset = "$Esc[0m"; $Bold = "$Esc[1m"
$FGCyan = "$Esc[96m"; $FGGreen = "$Esc[92m"; $FGYellow = "$Esc[93m"; $FGRed = "$Esc[91m"; $FGWhite = "$Esc[97m"
$FGDarkBlue = "$Esc[34m"
# Added for Timeout Functionality
$FGBlack = "$Esc[30m"; $FGDarkGray = "$Esc[90m"; $BGYellow = "$Esc[103m"; $FGGray = "$Esc[37m"
$Char_Finger = [char]0x261B; $Char_Keyboard = [char]0x2328; $Char_Skip = [char]0x23ED

function Write-Centered { param($Text, $Width = 60)

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



# --- MAIN ---

Write-Header "NOTIFICATION SETUP"

$ConfigPath = "$PSScriptRoot\Notification_Config.json"

Write-Host "  Select Notification Type:"
Write-Host "  [1] Webhook (Discord/Slack/Teams)"
Write-Host "  [2] Disable Notifications"
Write-Host ""
$choice = Read-Host "  Selection"

$config = @{ Enabled = $false; Type = "None"; Url = "" }

if ($choice -eq '1') {
    $url = Read-Host "  Enter Webhook URL"
    if (-not [string]::IsNullOrWhiteSpace($url)) {
        $config.Enabled = $true
        $config.Type = "Webhook"
        $config.Url = $url
        Write-Host "  $FGGreen$Char_BallotCheck Webhook configured.$Reset"
    }
} elseif ($choice -eq '2') {
    Write-Host "  $FGRed Notifications disabled.$Reset"
}

$json = $config | ConvertTo-Json
Set-Content -Path $ConfigPath -Value $json -Encoding UTF8

Write-Host ""
Write-Host "  Configuration saved to: $ConfigPath"
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



