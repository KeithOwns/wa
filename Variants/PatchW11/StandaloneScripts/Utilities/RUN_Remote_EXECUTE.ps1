#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Remote Execution Module for WinAuto
.DESCRIPTION
    Deploys the WinAuto Auto-Suite to a remote computer, executes it, 
    and retrieves the results. Requires WinRM to be enabled on the target.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# --- STYLE ---
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$Char_HeavyLine = [char]0x2501; $Char_BallotCheck = [char]0x2611; $Char_Warn = [char]0x26A0
$Char_Finger = [char]0x261B; $Char_Network = [char]::ConvertFromUtf32(0x1F5A5)
$Esc = [char]0x1B; $Reset = "$Esc[0m"; $Bold = "$Esc[1m"
$FGCyan = "$Esc[96m"; $FGGreen = "$Esc[92m"; $FGYellow = "$Esc[93m"; $FGRed = "$Esc[91m"
$FGDarkBlue = "$Esc[34m"; $FGWhite = "$Esc[97m"; $FGGray = "$Esc[37m"

function Write-Header { param($Title)

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

Write-Header "REMOTE DEPLOYMENT"

# 1. Get Target
Write-Host ""
$target = Read-Host "  $Char_Finger Enter Target Computer Name or IP"
if ([string]::IsNullOrWhiteSpace($target)) { exit }

# 2. Get Creds (Optional)
Write-Host ""
Write-LeftAligned "Use current credentials? (Y/N)"
$useCurrent = Read-Host "  $Char_Finger Selection"
$creds = $null
if ($useCurrent -notmatch '^[Yy]') {
    $creds = Get-Credential
}

# 3. Connection
Write-Host ""
Write-LeftAligned "$FGYellow Connecting to $target...$Reset"

try {
    $sessionParams = @{ ComputerName = $target }
    if ($creds) { $sessionParams.Credential = $creds }
    
    $session = New-PSSession @sessionParams
    Write-LeftAligned "$FGGreen$Char_BallotCheck Connection Established.$Reset"
} catch {
    Write-LeftAligned "$FGRed$Char_Warn Connection Failed: $($_.Exception.Message)$Reset"
    Write-LeftAligned "$FGGray Ensure WinRM is enabled on target (Enable-PSRemoting).$Reset"
    Pause
    exit
}

# 4. Deployment
$RemotePath = "C:\WinAuto_Remote"
Write-LeftAligned "$FGYellow Deploying scripts to $RemotePath...$Reset"

try {
    # Create Dir
    Invoke-Command -Session $session -ScriptBlock { param($p) New-Item -Path $p -ItemType Directory -Force | Out-Null } -ArgumentList $RemotePath
    
    # Copy Files (Main folder scripts + required configs)
    # We need: C6_WinAuto_Master_AUTO.ps1, and all modules it calls.
    # Easiest is to copy the whole 'Main' folder content.
    
    $LocalMain = $PSScriptRoot
    
    # Copy-Item -ToSession requires PS 5+, simpler to map drive or just loop contents?
    # Copy-Item -ToSession is available in newer PS, but strict PS 5.1 compatibility is key.
    # We will use Copy-Item with -ToSession if available, or just push via PSSession.
    
    Copy-Item -Path "$LocalMain\*" -Destination $RemotePath -ToSession $session -Recurse -Force
    
    Write-LeftAligned "$FGGreen$Char_BallotCheck Deployment Complete.$Reset"
} catch {
    Write-LeftAligned "$FGRed$Char_Warn Deployment Failed: $($_.Exception.Message)$Reset"
    Remove-PSSession $session
    exit
}

# 5. Execution
Write-Host ""
Write-LeftAligned "$FGYellow Executing Auto-Suite remotely...$Reset"
Write-LeftAligned "$FGGray This may take several minutes. Please wait.$Reset"

$scriptBlock = {
    param($Path)
    $Script = Join-Path $Path "C6_WinAuto_Master_AUTO.ps1"
    # Execute and capture output
    & $Script
}

try {
    Invoke-Command -Session $session -ScriptBlock $scriptBlock -ArgumentList $RemotePath | ForEach-Object {
        # Stream remote output to local console with simple indent
        Write-Host "  [REMOTE] $_"
    }
    Write-LeftAligned "$FGGreen$Char_BallotCheck Remote Execution Finished.$Reset"
} catch {
    Write-LeftAligned "$FGRed$Char_Warn Execution Error: $($_.Exception.Message)$Reset"
}

# 6. Cleanup
Write-Host ""
Write-LeftAligned "$FGYellow Cleaning up remote files...$Reset"
try {
    Invoke-Command -Session $session -ScriptBlock { param($p) Remove-Item -Path $p -Recurse -Force -ErrorAction SilentlyContinue } -ArgumentList $RemotePath
    Write-LeftAligned "$FGGreen$Char_BallotCheck Cleanup Complete.$Reset"
} catch {
    Write-LeftAligned "$FGRed$Char_Warn Cleanup Failed.$Reset"
}

Remove-PSSession $session
Write-Host ""
Pause


