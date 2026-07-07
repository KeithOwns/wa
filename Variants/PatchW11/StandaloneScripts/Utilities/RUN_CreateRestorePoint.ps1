#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Enables System Protection and Creates a System Restore Point in Windows 11
.DESCRIPTION
    Standardized for WinAuto. Ensures C: is protected and creates point.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

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

Write-Header "SYSTEM RESTORE POINT CREATOR"

# STEP 1: Enable Protection
Write-LeftAligned "$FGWhite$Char_HeavyMinus STEP 1: Enabling System Protection$Reset"
try {
    Write-LeftAligned "  $FGYellow Attempting to enable System Protection on C:\...$Reset"
    Enable-ComputerRestore -Drive "C:\"
    Write-LeftAligned "  $FGGreen$Char_HeavyCheck Successfully enabled System Protection.$Reset"
    Start-Sleep -Seconds 1
} catch {
    Write-LeftAligned "  $FGGray  (System Protection may already be enabled or managed by policy)$Reset"
}

# STEP 2: Create Point
Write-Host ""
Write-LeftAligned "$FGWhite$Char_HeavyMinus STEP 2: Creating Restore Point$Reset"
$description = "WinAuto Manual Point - $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
Write-LeftAligned "  $FGYellow Description: $description$Reset"

try {
    Checkpoint-Computer -Description $description -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
    Write-Host ""
    Write-LeftAligned "$FGGreen$Char_BallotCheck Restore Point created successfully!$Reset"
} catch {
    Write-Host ""
    Write-LeftAligned "$FGRed$Char_RedCross Failed to create restore point.$Reset"
    Write-LeftAligned "  Details: $($_.Exception.Message)" -ForegroundColor Gray
}

Write-Host ""
Write-Boundary $FGDarkBlue
Start-Sleep -Seconds 1
Write-Host ""






