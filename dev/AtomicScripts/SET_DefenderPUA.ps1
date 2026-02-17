#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Enables or Disables Windows Defender PUA Protection.
.DESCRIPTION
    Standardized for WinAuto. Configures System-wide Windows Defender PUA Protection.
    Standalone version: Can be copy-pasted directly into PowerShell.
.PARAMETER Undo
    Reverses the setting (Disables PUA blocking).
#>

param(
    [switch]$Undo,
    [switch]$Force
)

# --- STANDALONE HELPERS ---
# Essential definitions for standalone execution
$Esc = [char]0x1B
$Reset = "$Esc[0m"
$Bold = "$Esc[1m"
$FGGreen = "$Esc[92m"
$FGRed = "$Esc[91m"
$FGDarkYellow = "$Esc[33m"
$FGCyan = "$Esc[96m"
$FGDarkBlue = "$Esc[34m"

$Char_HeavyCheck = "[v]"
$Char_RedCross = "[x]"
$Char_Warn = "!"

if (-not (Get-Command Write-Boundary -ErrorAction SilentlyContinue)) {
    function Write-Boundary {
        param([string]$Color = $FGDarkBlue)
        Write-Host "$Color$([string]'_' * 60)$Reset"
    }
}

if (-not (Get-Command Write-Header -ErrorAction SilentlyContinue)) {
    function Write-Header {
        param([string]$Title)
        Clear-Host
        Write-Host ""
        $WinAutoTitle = "WinAuto (Atomic)"
        $WinAutoPadding = [Math]::Floor((60 - $WinAutoTitle.Length) / 2)
        Write-Host (" " * $WinAutoPadding + "$Bold$FGCyan$WinAutoTitle$Reset")
        
        $SubText = $Title.ToUpper()
        $SubPadding = [Math]::Floor((60 - $SubText.Length) / 2)
        Write-Host (" " * $SubPadding + "$Bold$FGCyan$SubText$Reset")
        Write-Boundary
    }
}

if (-not (Get-Command Write-LeftAligned -ErrorAction SilentlyContinue)) {
    function Write-LeftAligned {
        param([string]$Text, [int]$Indent = 2)
        Write-Host (" " * $Indent + $Text)
    }
}

# --- MAIN LOGIC ---
Write-Header "DEFENDER PUA PROTECTION"

try {
    $targetMp = if ($Undo) { 0 } else { 1 }
    $statusText = if ($Undo) { "DISABLED" } else { "ENABLED" }

    # System-wide Defender PUA
    Set-MpPreference -PUAProtection $targetMp -ErrorAction Stop
    Write-LeftAligned "$FGGreen$Char_HeavyCheck  Defender PUA Blocking is $statusText.$Reset"

    # Verification
    $currentMp = (Get-MpPreference).PUAProtection
    if ($currentMp -ne $targetMp) {
        Write-LeftAligned "$FGDarkYellow$Char_Warn Verification failed for Defender PUA. Status: $currentMp$Reset"
    }

}
catch {
    Write-LeftAligned "$FGRed$Char_RedCross  Failed: $($_.Exception.Message)$Reset"
}
