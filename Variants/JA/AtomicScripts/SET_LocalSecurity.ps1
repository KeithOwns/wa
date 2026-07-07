#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Enables or Disables Local Security Authority (LSA) protection.
.DESCRIPTION
    Standardized for WinAuto. Sets RunAsPPL=1 (Enable) or 0 (Disable) in Registry.
    Standalone version. Includes Reverse Mode.
.PARAMETER Reverse
    (Alias: -r) Reverses the setting (Disables LSA Protection).
#>

& {
    param(
        [Parameter(Mandatory = $false)]
        [Alias('r')]
        [switch]$Reverse
    )

    # --- STANDALONE UI & LOGGING RESOURCES ---
    $Esc = [char]0x1B
    $Reset = "$Esc[0m"
    $Bold = "$Esc[1m"
    $FGGreen = "$Esc[92m"; $FGRed = "$Esc[91m"; $FGCyan = "$Esc[96m"; $FGDarkBlue = "$Esc[34m"

    $Char_HeavyCheck = "[v]"; $Char_RedCross = "[x]"

    function Write-Boundary { param([string]$Color = $FGDarkBlue) Write-Host "$Color$([string]'_' * 60)$Reset" }
    function Write-LeftAligned { param([string]$Text, [int]$Indent = 2) Write-Host (" " * $Indent + $Text) }
    function Write-Header {
        param([string]$Title)
        Clear-Host; Write-Host ""
        $WinAutoTitle = "- WinAuto -"
        $WinAutoPadding = [Math]::Floor((60 - $WinAutoTitle.Length) / 2)
        Write-Host (" " * $WinAutoPadding + "$Bold$FGCyan$WinAutoTitle$Reset")
        Write-Boundary
        $SubText = $Title.ToUpper()
        $SubPadding = [Math]::Floor((60 - $SubText.Length) / 2)
        Write-Host (" " * $SubPadding + "$Bold$FGCyan$SubText$Reset")
        Write-Boundary
    }

    Write-Header "LSA PROTECTION"

    $regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa"
    $regName = "RunAsPPL"
    $targetValue = if ($Reverse) { 0 } else { 1 }
    $statusText = if ($Reverse) { "DISABLED" } else { "ENABLED" }

    try {
        $current = (Get-ItemProperty -Path $regPath -Name $regName -ErrorAction SilentlyContinue).$regName
        if ($current -eq $targetValue) {
            Write-LeftAligned "$FGGreen$Char_HeavyCheck  LSA Protection is already $statusText.$Reset"
        }
        else {
            if (-not (Test-Path $regPath)) { New-Item -Path $regPath -Force | Out-Null }
            New-ItemProperty -Path $regPath -Name $regName -Value $targetValue -PropertyType DWord -Force | Out-Null
            Write-LeftAligned "$FGGreen$Char_HeavyCheck  LSA Protection is $statusText.$Reset"
        }
    }
    catch {
        Write-LeftAligned "$FGRed$Char_RedCross  Failed to modify LSA protection: $($_.Exception.Message)$Reset"
    }

    Write-Host ""
    $copyright = "Copyright (c) 2026 WinAuto"
    $cPad = [Math]::Floor((60 - $copyright.Length) / 2)
    Write-Host (" " * $cPad + "$FGCyan$copyright$Reset")
    Write-Host ""

} @args
