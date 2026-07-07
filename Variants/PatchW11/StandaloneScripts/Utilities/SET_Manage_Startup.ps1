#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Startup App Manager
.DESCRIPTION
    Lists applications configured to start automatically with Windows.
    Allows removal of specific startup entries from Registry and Startup Folder.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# --- STYLE ---
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$Char_HeavyLine = [char]0x2501; $Char_BallotCheck = [char]0x2611; $Char_Trash = [char]::ConvertFromUtf32(0x1F5D1); $Char_Finger = [char]0x261B; $Char_Keyboard = [char]0x2328; $Char_Eject = [char]0x23CF
$Esc = [char]0x1B; $Reset = "$Esc[0m"; $Bold = "$Esc[1m"
$FGCyan = "$Esc[96m"; $FGGreen = "$Esc[92m"; $FGYellow = "$Esc[93m"; $FGRed = "$Esc[91m"; $FGWhite = "$Esc[97m"; $FGGray = "$Esc[37m"
$FGDarkBlue = "$Esc[34m"; $FGDarkGray = "$Esc[90m"; $FGBlack = "$Esc[30m"; $BGYellow = "$Esc[103m"
$Char_Skip = [char]0x23ED

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



#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Startup App Manager
.DESCRIPTION
    Lists applications configured to start automatically with Windows.
    Allows removal of specific startup entries from Registry and Startup Folder.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# --- STYLE ---
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$Char_HeavyLine = [char]0x2501; $Char_BallotCheck = [char]0x2611; $Char_Trash = [char]::ConvertFromUtf32(0x1F5D1); $Char_Finger = [char]0x261B; $Char_Keyboard = [char]0x2328; $Char_Eject = [char]0x23CF
$Esc = [char]0x1B; $Reset = "$Esc[0m"; $Bold = "$Esc[1m"
$FGCyan = "$Esc[96m"; $FGGreen = "$Esc[92m"; $FGYellow = "$Esc[93m"; $FGRed = "$Esc[91m"; $FGWhite = "$Esc[97m"; $FGGray = "$Esc[37m"
$FGDarkBlue = "$Esc[34m"; $FGDarkGray = "$Esc[90m"; $FGBlack = "$Esc[30m"; $BGYellow = "$Esc[103m"
$Char_Skip = [char]0x23ED

function Write-Centered { param($Text, $Width = 60) $clean = $Text -replace "$Esc\[[0-9;]*m", ""; $pad = [Math]::Floor(($Width - $clean.Length) / 2); if ($pad -lt 0) { $pad = 0 }; Write-Host (" " * $pad + $Text) }
function Write-LeftAligned { param($Text, $Indent = 2) Write-Host (" " * $Indent + $Text) }
function Write-Header { param($Title) Write-Host ""; Write-Centered "$Bold$FGCyan $Char_HeavyLine WinAuto $Char_HeavyLine $Reset"; Write-Centered "$Bold$FGCyan$Title$Reset"; Write-Host "$FGDarkBlue$([string]$Char_HeavyLine * 60)$Reset" }
function Write-Boundary { param($Color = $FGDarkBlue) Write-Host "$Color$([string]$Char_HeavyLine * 60)$Reset" }

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

function Invoke-AnimatedPause {
    Write-Host ""
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
        $PromptStr = "${FGWhite}$Char_Keyboard  Press ${FGDarkGray}$DynamicPart${FGDarkGray}${FGWhite}to${FGDarkGray} ${FGYellow}CONTINUE${FGDarkGray} ${FGWhite}|${FGDarkGray} or any other key ${FGWhite}to SKIP$Char_Skip${Reset}"
        try { [Console]::SetCursorPosition(0, $PromptCursorTop); Write-Centered $PromptStr } catch {}
    }

    $null = Wait-KeyPressWithTimeout -Seconds 10 -OnTick $TickAction
    Write-Host ""
}

# --- DISCOVERY ---
function Get-StartupApps {
    $apps = @()
    
    $searchPaths = @(
        @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"; Type = "Registry (User)" },
        @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"; Type = "Registry (Machine)" },
        @{ Path = "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run"; Type = "Registry (Machine x86)" }
    )

    foreach ($entry in $searchPaths) {
        $path = $entry.Path
        if (Test-Path $path) {
            $key = Get-Item $path
            if ($key.Property) {
                foreach ($prop in $key.Property) {
                    $val = (Get-ItemProperty $path).$prop
                    $apps += [pscustomobject]@{ Name = $prop; Path = $path; Command = $val; Type = $entry.Type }
                }
            }
        }
    }
    
    # Startup Folder
    $path = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
    if (Test-Path $path) {
        Get-ChildItem $path -File | ForEach-Object {
            $apps += [pscustomobject]@{ Name = $_.Name; Path = $_.FullName; Command = $_.FullName; Type = "Folder" }
        }
    }
    
    return $apps
}

# --- MAIN LOOP ---
$running = $true
while ($running) {

    Write-Header "STARTUP MANAGER"
    
    $apps = Get-StartupApps
    
    if ($apps.Count -eq 0) {
        Write-Host ""
        Write-LeftAligned "$FGGreen No startup apps found.$Reset"
    } else {
        for ($i=0; $i -lt $apps.Count; $i++) {
            $a = $apps[$i]
            $id = "$FGYellow[$($i+1)]$Reset"
            Write-LeftAligned "$id $($a.Name)"
            Write-LeftAligned "   $FGDarkGray$($a.Type)$Reset"
        }
    }
    
    Write-Host ""
    Write-Boundary
    $prompt = "${FGWhite}$Char_Keyboard  Type${FGYellow} ID ${FGWhite}to Delete${FGWhite}|${FGDarkGray}any other to ${FGWhite}EXIT$Char_Eject${Reset}"
    Write-Centered $prompt
    
    Write-Host ""
    $val = Read-Host "  $Char_Finger Selection"
    
    if ($val -match '^\d+$') {
        $idx = [int]$val - 1
        if ($idx -ge 0 -and $idx -lt $apps.Count) {
            $target = $apps[$idx]
            Write-Host ""
            $confirm = Read-Host "  $FGRed Delete '$($target.Name)'? (Y/N)$Reset"
            if ($confirm -match '^[Yy]') {
                try {
                    if ($target.Type -eq "Folder") {
                        Remove-Item $target.Path -Force
                    } else {
                        Remove-ItemProperty -Path $target.Path -Name $target.Name
                    }
                    Write-LeftAligned "$FGGreen$Char_Trash Removed.$Reset"
                    Start-Sleep -Seconds 1
                } catch {
                    Write-LeftAligned "$FGRed Failed: $($_.Exception.Message)$Reset"
                    Start-Sleep -Seconds 1
                }
            }
        }
    } else {
        $running = $false
    }
}




