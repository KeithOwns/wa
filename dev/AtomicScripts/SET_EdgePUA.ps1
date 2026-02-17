#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Enables or Disables Edge SmartScreen PUA Protection.
.DESCRIPTION
    Standardized for WinAuto. Configures User-specific Edge SmartScreen PUA (Block downloads).
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
Write-Header "EDGE PUA PROTECTION"

try {
    $targetEdge = if ($Undo) { 0 } else { 1 }
    $statusText = if ($Undo) { "DISABLED" } else { "ENABLED" }

    # User-specific Edge SmartScreen PUA (Block downloads)
    $edgeKeyPath = "HKCU:\Software\Microsoft\Edge\SmartScreenPuaEnabled"
    if (-not (Test-Path $edgeKeyPath)) {
        New-Item -Path $edgeKeyPath -Force | Out-Null
    }
    Set-ItemProperty -Path $edgeKeyPath -Name "(default)" -Value $targetEdge -Type DWord -Force
    
    Write-LeftAligned "$FGGreen$Char_HeavyCheck  Edge 'Block downloads' is $statusText.$Reset"

}
catch {
    Write-LeftAligned "$FGRed$Char_RedCross  Failed: $($_.Exception.Message)$Reset"
}
