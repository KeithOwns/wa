#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Windows System File Integrity & Repair Tool (SFC/DISM)
.DESCRIPTION
    Automated flow to check and repair Windows system files using SFC and DISM.
    Standalone version. Includes Reverse Mode (-r) stub.
.PARAMETER Reverse
    (Alias: -r) No-Op. System repairs cannot be reversed.
#>

& {
    param(
        [Parameter(Mandatory = $false)]
        [Alias('r')]
        [switch]$Reverse,
        [switch]$Undo
    )

    if ($Undo) { $Reverse = $true }

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

    function Invoke-SFCScan {
        Write-Host ""
        Write-LeftAligned "$Bold$FGWhite$Char_HeavyMinus System File Checker (SFC)$Reset"
        Write-LeftAligned "$FGGray Initializing sfc /scannow...$Reset"
        
        try {
            $rawOutput = & sfc /scannow 2>&1
            $sfcOutput = ($rawOutput -join " ") -replace '[^\x20-\x7E]', '' # Keep only printable ASCII
            Write-Host ""
            
            if ($sfcOutput -match "did not find any integrity violations") {
                Write-LeftAligned "$FGGreen$Char_BallotCheck System files are healthy.$Reset"
                return "SUCCESS"
            }
            elseif ($sfcOutput -match "found corrupt files and successfully repaired them") {
                Write-LeftAligned "$FGGreen$Char_BallotCheck Corrupt files were found and repaired.$Reset"
                return "REPAIRED"
            }
            elseif ($sfcOutput -match "found corrupt files but was unable to fix some of them") {
                Write-LeftAligned "$FGRed$Char_RedCross SFC found unfixable corruption.$Reset"
                return "FAILED"
            }
            else {
                Write-LeftAligned "$FGDarkMagenta$Char_Warn SFC completed with unknown status.$Reset"
                return "UNKNOWN"
            }
        }
        catch {
            $errMsg = "$($_.Exception.Message)"
            Write-LeftAligned "$FGRed$Char_RedCross SFC execution error: $errMsg$Reset"
            return "ERROR"
        }
    }

    function Invoke-DISMRepair {
        Write-Host ""
        Write-LeftAligned "$Bold$FGWhite$Char_HeavyMinus Deployment Image Servicing (DISM)$Reset"
        Write-LeftAligned "$FGYellow Starting online image repair...$Reset"
        Write-LeftAligned "$FGGray This may take several minutes.$Reset"
        
        try {
            $dismOutput = & DISM /Online /Cleanup-Image /RestoreHealth 2>&1 | Out-String
            
            if ($dismOutput -match "The restore operation completed successfully") {
                Write-LeftAligned "$FGGreen$Char_BallotCheck DISM repair completed successfully.$Reset"
                return $true
            }
            else {
                Write-LeftAligned "$FGRed$Char_RedCross DISM repair failed.$Reset"
                return $false
            }
        }
        catch {
            $errMsg = "$($_.Exception.Message)"
            Write-LeftAligned "$FGRed$Char_RedCross DISM execution error: $errMsg$Reset"
            return $false
        }
    }

    # --- MAIN FLOW ---
    Write-Header "SYSTEM REPAIR FLOW"

    if ($Reverse) {
        Write-LeftAligned "$FGYellow$Char_Warn Reverse Mode: System repairs cannot be reversed.$Reset"
        Write-Host ""
        $copyright = "Copyright (c) 2026 WinAuto"; $cPad = [Math]::Floor((60 - $copyright.Length) / 2); Write-Host (" " * $cPad + "$FGCyan$copyright$Reset"); Write-Host ""
        return
    }

    $result = Invoke-SFCScan

    if ($result -eq "FAILED") {
        Write-Host ""
        Write-LeftAligned "$FGYellow Triggering DISM Repair to fix underlying component store...$Reset"
        $dismSuccess = Invoke-DISMRepair
        
        if ($dismSuccess) {
            Write-Host ""
            Write-LeftAligned "$FGYellow Re-running SFC to verify repairs...$Reset"
            Invoke-SFCScan | Out-Null
        }
    }

    Write-Host ""
    Write-Boundary
    Write-Centered "$FGGreen REPAIR FLOW COMPLETE $Reset"
    Write-Boundary

    # --- FOOTER ---
    Write-Host ""
    $copyright = "Copyright (c) 2026 WinAuto"
    $cPad = [Math]::Floor((60 - $copyright.Length) / 2)
    Write-Host (" " * $cPad + "$FGCyan$copyright$Reset")
    Write-Host ""
    Start-Sleep -Seconds 10
} @args


# --- LOGIC ---

    function Invoke-SFCScan {
        Write-Host ""
        Write-LeftAligned "$Bold$FGWhite$Char_HeavyMinus System File Checker (SFC)$Reset"
        Write-LeftAligned "$FGGray Initializing sfc /scannow...$Reset"
        
        try {
            $rawOutput = & sfc /scannow 2>&1
            $sfcOutput = ($rawOutput -join " ") -replace '[^\x20-\x7E]', '' # Keep only printable ASCII
            Write-Host ""
            
            if ($sfcOutput -match "did not find any integrity violations") {
                Write-LeftAligned "$FGGreen$Char_BallotCheck System files are healthy.$Reset"
                return "SUCCESS"
            }
            elseif ($sfcOutput -match "found corrupt files and successfully repaired them") {
                Write-LeftAligned "$FGGreen$Char_BallotCheck Corrupt files were found and repaired.$Reset"
                return "REPAIRED"
            }
            elseif ($sfcOutput -match "found corrupt files but was unable to fix some of them") {
                Write-LeftAligned "$FGRed$Char_RedCross SFC found unfixable corruption.$Reset"
                return "FAILED"
            }
            else {
                Write-LeftAligned "$FGDarkMagenta$Char_Warn SFC completed with unknown status.$Reset"
                return "UNKNOWN"
            }
        }
        catch {
            $errMsg = "$($_.Exception.Message)"
            Write-LeftAligned "$FGRed$Char_RedCross SFC execution error: $errMsg$Reset"
            return "ERROR"
        }
    }

    function Invoke-DISMRepair {
        Write-Host ""
        Write-LeftAligned "$Bold$FGWhite$Char_HeavyMinus Deployment Image Servicing (DISM)$Reset"
        Write-LeftAligned "$FGYellow Starting online image repair...$Reset"
        Write-LeftAligned "$FGGray This may take several minutes.$Reset"
        
        try {
            $dismOutput = & DISM /Online /Cleanup-Image /RestoreHealth 2>&1 | Out-String
            
            if ($dismOutput -match "The restore operation completed successfully") {
                Write-LeftAligned "$FGGreen$Char_BallotCheck DISM repair completed successfully.$Reset"
                return $true
            }
            else {
                Write-LeftAligned "$FGRed$Char_RedCross DISM repair failed.$Reset"
                return $false
            }
        }
        catch {
            $errMsg = "$($_.Exception.Message)"
            Write-LeftAligned "$FGRed$Char_RedCross DISM execution error: $errMsg$Reset"
            return $false
        }
    }

    # --- MAIN FLOW ---
    Write-Header "SYSTEM REPAIR FLOW"

    if ($Reverse) {
        Write-LeftAligned "$FGYellow$Char_Warn Reverse Mode: System repairs cannot be reversed.$Reset"
        Write-Host ""
        $copyright = "Copyright (c) 2026 WinAuto"; $cPad = [Math]::Floor((60 - $copyright.Length) / 2); Write-Host (" " * $cPad + "$FGCyan$copyright$Reset"); Write-Host ""
        return
    }

    $result = Invoke-SFCScan

    if ($result -eq "FAILED") {
        Write-Host ""
        Write-LeftAligned "$FGYellow Triggering DISM Repair to fix underlying component store...$Reset"
        $dismSuccess = Invoke-DISMRepair
        
        if ($dismSuccess) {
            Write-Host ""
            Write-LeftAligned "$FGYellow Re-running SFC to verify repairs...$Reset"
            Invoke-SFCScan | Out-Null
        }
    }

    Write-Host ""
    Write-Boundary
    Write-Centered "$FGGreen REPAIR FLOW COMPLETE $Reset"
    Write-Boundary

    # --- FOOTER ---
    Write-Host ""
    $copyright = "Copyright (c) 2026 WinAuto"
    $cPad = [Math]::Floor((60 - $copyright.Length) / 2)
    Write-Host (" " * $cPad + "$FGCyan$copyright$Reset")
    Write-Host ""
    Start-Sleep -Seconds 10
} @args
