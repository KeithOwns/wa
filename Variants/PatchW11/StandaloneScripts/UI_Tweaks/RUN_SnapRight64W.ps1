#Requires -RunAsAdministrator
#Requires -Version 5.1
<#
.SYNOPSIS
    Resizes console to 64 columns and snaps to right edge.
.DESCRIPTION
    Standardized for WinAuto. Adjusts window dimensions and position.
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



# --- MAIN ---
try {
    Write-LeftAligned "$FGYellow Snapping window to right (64W)...$Reset"

    $targetWidth = 64
    $targetHeight = 50
    $currentHeight = $Host.UI.RawUI.WindowSize.Height
    if ($currentHeight -gt $targetHeight) { $targetHeight = $currentHeight }

    $window = $Host.UI.RawUI.WindowSize
    $window.Width = $targetWidth
    $window.Height = $targetHeight

    $buffer = $Host.UI.RawUI.BufferSize
    if ($buffer.Height -lt $targetHeight) {
        $buffer.Height = $targetHeight
        $Host.UI.RawUI.BufferSize = $buffer
    }

    $Host.UI.RawUI.WindowSize = $window
    $buffer = $Host.UI.RawUI.BufferSize
    $buffer.Width = $targetWidth
    $Host.UI.RawUI.BufferSize = $buffer

    $hWnd = [WinAuto.WinUtils]::GetConsoleWindow()
    $screenW = [WinAuto.WinUtils]::GetSystemMetrics(0) # SM_CXSCREEN
    $screenH = [WinAuto.WinUtils]::GetSystemMetrics(1) # SM_CYSCREEN

    $targetW = [Math]::Floor($screenW / 3)
    $targetX = $screenW - $targetW

    # We need to respect the console font/buffer width if possible, but MoveWindow sets the pixel size.
    # The original script prioritized 64 columns text width. 
    # If we want to strictly follow "Right Third", we should set pixel width to targetW.
    
    $null = [WinAuto.WinUtils]::MoveWindow($hWnd, $targetX, 0, $targetW, $screenH, $true)

    Write-LeftAligned "$FGGreen$Char_HeavyCheck Success! Console resized and snapped.$Reset"

} catch {
    Write-LeftAligned "$FGRed$Char_RedCross Failed: $($_.Exception.Message)$Reset"
}

Start-Sleep -Seconds 1



