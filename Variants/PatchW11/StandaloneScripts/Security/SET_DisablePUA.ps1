#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Disables or Enables Potentially Unwanted App (PUA) Protection at Device Level.
.DESCRIPTION
    Standardized for WinAuto. Uses Group Policy to configure PUA protection.
.PARAMETER Undo
    Reverses the setting (Enables PUA Protection).
#>

[CmdletBinding()]
param(
    [switch]$Undo,
    [switch]$Rollback
)

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

Write-Header "$actionText PUA PROTECTION"

if ($Rollback) {
    Write-Step "Searching for backups..." -Level Warning
    $latest = Get-ChildItem $env:TEMP -Filter "PUAProtection-Backup-W11-*.json" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($latest) {
        if (Restore-PUAState -Path $latest.FullName) { Write-Step "Rollback successful." -Level Success }
        else { Write-Step "Rollback failed." -Level Error }
    } else { Write-Step "No backup found." -Level Error }
    Start-Sleep -Seconds 1
    exit
}

# Status Check
$gp = (Get-ItemProperty -Path $Script:GroupPolicyPath -Name $Script:GroupPolicyValue -ErrorAction SilentlyContinue).$Script:GroupPolicyValue
if ($gp -eq $targetValue) {
    Write-Step "PUA Protection is already $statusText via Group Policy." -Level Success
    Start-Sleep -Seconds 1
    exit
}

# Warning
if (-not $Undo) {
    Write-Boundary $FGRed
    Write-Centered "$Bold$FGRed SECURITY WARNING $Reset"
    Write-LeftAligned "Disabling PUA Protection lowers device security."
    Write-Boundary $FGRed
    Write-Host ""
}

Backup-CurrentState

# Configure
Write-Step "Applying Group Policy (PUAProtection = $targetValue)..."
try {
    if (-not (Test-Path $Script:GroupPolicyPath)) { New-Item -Path $Script:GroupPolicyPath -Force | Out-Null }
    Set-ItemProperty -Path $Script:GroupPolicyPath -Name $Script:GroupPolicyValue -Value $targetValue -Type DWord -Force
    
    $pref = if ($targetValue -eq 1) { 'Enabled' } else { 'Disabled' }
    Set-MpPreference -PUAProtection $pref -ErrorAction SilentlyContinue
    
    Write-Step "Policy applied. Forcing Group Policy update..."
    & gpupdate /force | Out-Null
    Write-Step "Operation complete. PUA Protection is $statusText." -Level Success
} catch {
    Write-Step "Failed to apply policy: $($_.Exception.Message)" -Level Error
}

Write-Host ""
Write-Boundary $FGDarkGray
Write-Centered "RESTART RECOMMENDED"
Write-Boundary $FGDarkGray

Start-Sleep -Seconds 1
Write-Host ""






