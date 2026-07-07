#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Optimizes Visual Effects for Performance.
.DESCRIPTION
    Standardized for WinAuto. Tweaks HKCU registry for best performance.
.PARAMETER Undo
    Reverses the setting (Sets to 'Let Windows Choose').
#>

param([switch]$Undo)

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

Write-Header "VISUAL EFFECTS"

try {
    $target = if ($Undo) { 0 } else { 2 } # 2 = Best Perf, 0 = Windows Choose
    $status = if ($Undo) { "Reset to Default" } else { "Optimized for Performance" }

    $path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects"
    if (-not (Test-Path $path)) { New-Item -Path $path -Force | Out-Null }
    Set-ItemProperty -Path $path -Name "VisualFXSetting" -Value $target -Type DWord -Force

    # UI Tweaks
    $adv = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    $v = if ($Undo) { 1 } else { 0 }
    Set-ItemProperty -Path $adv -Name "ListviewAlphaSelect" -Value $v -Type DWord -Force
    Set-ItemProperty -Path $adv -Name "ListviewShadow" -Value $v -Type DWord -Force
    Set-ItemProperty -Path $adv -Name "TaskbarAnimations" -Value $v -Type DWord -Force

    Write-LeftAligned "$FGGreen$Char_HeavyCheck Visual effects $status successful.$Reset"
    Write-LeftAligned "$FGGray Note: Requires logout or restart to fully apply.$Reset"

} catch {
    $errMsg = "$($_.Exception.Message)"
    Write-LeftAligned "$FGRed$Char_RedCross Error: $errMsg$Reset"
    Write-Log "Visual Effects Error: $errMsg" -Level ERROR
}

Write-Host ""
Write-Boundary $FGDarkBlue
Start-Sleep -Seconds 1
Write-Host ""