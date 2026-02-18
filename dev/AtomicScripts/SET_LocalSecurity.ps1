#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Enables or Disables Local Security Authority (LSA) protection.
.DESCRIPTION
    Standardized for WinAuto. Sets RunAsPPL=1 (Enable) or 0 (Disable) in Registry.
    Standalone version: Can be copy-pasted directly into PowerShell.
    Includes Reverse Mode (-r) to undo changes.
.PARAMETER Reverse
    (Alias: -r) Reverses the setting (Disables LSA Protection).
#>

& {
    param(
        [Parameter(Mandatory = $false)]
        [Alias('r')]
        [switch]$Reverse
    )

    # --- STANDALONE HELPERS ---
    $Esc = [char]0x1B
    $Reset = "$Esc[0m"
    $Bold = "$Esc[1m"
    $FGGreen = "$Esc[92m"
    $FGRed = "$Esc[91m"
    $FGCyan = "$Esc[96m"
    $FGDarkBlue = "$Esc[34m"
    
    $Char_BallotCheck = "[v]"
    $Char_HeavyCheck = "[v]"
    $Char_RedCross = "x"
    
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
            $WinAutoTitle = "- WinAuto -"
            $WinAutoPadding = [Math]::Floor((60 - $WinAutoTitle.Length) / 2)
            Write-Host (" " * $WinAutoPadding + "$Bold$FGCyan$WinAutoTitle$Reset")
            
            Write-Boundary
            
            $SubText = $Title.ToUpper()
            $SubPadding = [Math]::Floor((60 - $SubText.Length) / 2)
            Write-Host (" " * $SubPadding + "$Bold$FGCyan$SubText$Reset")
            Write-Boundary
        }
    }
    
    if (-not (Get-Command Write-LeftAligned -ErrorAction SilentlyContinue)) {
        function Write-LeftAligned { param($Text) Write-Host "  $Text" }
    }
    
    if (-not (Get-Command Set-RegistryDword -ErrorAction SilentlyContinue)) {
        function Set-RegistryDword { param($Path, $Name, $Value) New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType DWord -Force | Out-Null }
    }

    Write-Header "LSA PROTECTION"

    # --- CONFIG ---
    $regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa"
    $regName = "RunAsPPL"
    $targetValue = if ($Reverse) { 0 } else { 1 }
    $statusText = if ($Reverse) { "DISABLED" } else { "ENABLED" }

    # --- MAIN ---

    try {
        # Check current status
        $current = (Get-ItemProperty -Path $regPath -Name $regName -ErrorAction SilentlyContinue).$regName
        if ($current -eq $targetValue) {
            Write-LeftAligned "$FGGreen$Char_BallotCheck  LSA Protection is $statusText.$Reset"
        }
        else {
            Set-RegistryDword -Path $regPath -Name $regName -Value $targetValue
            Write-LeftAligned "$FGGreen$Char_HeavyCheck  LSA Protection is $statusText.$Reset"
        }

    }
    catch {
        Write-LeftAligned "$FGRed$Char_RedCross  Failed to modify LSA protection: $($_.Exception.Message)$Reset"
    }

    # --- FOOTER ---
    Write-Host ""
    $copyright = "Copyright (c) 2026 WinAuto"
    $cPad = [Math]::Floor((60 - $copyright.Length) / 2)
    Write-Host (" " * $cPad + "$FGCyan$copyright$Reset")
    Write-Host ""
} @args
