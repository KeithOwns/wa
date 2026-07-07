<#
.SYNOPSIS
    WinAuto Atomic Hub - Dynamic Script Launcher
.DESCRIPTION
    Dynamically scans the .\AtomicScripts folder and provides an interactive menu
    to run individual standalone scripts.
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

# --- MAIN HUB LOGIC ---

while ($true) {
    Write-Header "ATOMIC HUB"
    
    # 1. Scan for scripts
    $AtomicDir = Join-Path $PSScriptRoot "AtomicScripts"
    if (-not (Test-Path $AtomicDir)) {
        Write-Log "AtomicScripts directory not found!" "ERROR"
        break
    }
    
    $Scripts = Get-ChildItem -Path $AtomicDir -Recurse -Filter "*.ps1" | Sort-Object Name
    
    if ($Scripts.Count -eq 0) {
        Write-Log "No atomic scripts found in $AtomicDir" "WARNING"
        Invoke-AnimatedPause -ActionText "EXIT"
        break
    }

    # 2. Display Menu
    Write-LeftAligned "${FGWhite}Available Atomic Operations:${Reset}"
    Write-Host ""
    
    for ($i = 0; $i -lt $Scripts.Count; $i++) {
        $num = ($i + 1).ToString().PadLeft(2)
        $name = $Scripts[$i].BaseName
        $color = if ($name -match "^RUN_") { $FGCyan } elseif ($name -match "^SET_") { $FGYellow } elseif ($name -match "^INSTALL_") { $FGGreen } else { $FGWhite }
        Write-LeftAligned "${FGDarkGray}[${FGWhite}$num${FGDarkGray}]${Reset} ${color}$name${Reset}"
    }
    
    Write-Host ""
    Write-Boundary $FGDarkGray
    Write-LeftAligned "${FGDarkGray}Type a number to run, or 'Q' to quit.${Reset}"
    Write-Host ""
    
    # 3. Handle Input
    $Input = Read-Host "  Select Operation"
    
    if ($Input -eq 'q' -or $Input -eq 'Q') {
        Write-Log "Exiting Atomic Hub..." "INFO"
        Start-Sleep -Seconds 1
        break
    }
    
    if ([int]::TryParse($Input, [ref]$Selection) -and $Selection -ge 1 -and $Selection -le $Scripts.Count) {
        $SelectedScript = $Scripts[$Selection - 1]
        
        Write-Header "EXECUTING: $($SelectedScript.BaseName)"
        Write-Log "Launching: $($SelectedScript.FullName)" "INFO"
        Write-Boundary $FGDarkBlue
        
        # Execute the script
        & $SelectedScript.FullName
        
        Write-Host ""
        Write-Boundary $FGDarkBlue
        Write-Log "Execution of $($SelectedScript.BaseName) complete." "SUCCESS"
        Invoke-AnimatedPause -ActionText "RETURN TO HUB" -Timeout 15
    }
    else {
        Write-Log "Invalid selection: '$Input'" "ERROR"
        Start-Sleep -Seconds 1
    }
}
