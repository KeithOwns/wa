#Requires -RunAsAdministrator
<#
.SYNOPSIS
    WinGet Application Updater - Extracted from wa.ps1
.DESCRIPTION
    Updates all installed applications using Windows Package Manager (winget).
    Standalone version. Includes Reverse Mode (-r) stub.
.PARAMETER Reverse
    (Alias: -r) No-Op. Upgrades cannot be reversed automatically.
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

    # --- STANDALONE HELPERS ---
    $Esc = [char]0x1B
    $Reset = "$Esc[0m"
    $Bold = "$Esc[1m"
    $FGGreen = "$Esc[92m"
    $FGRed = "$Esc[91m"
    $FGCyan = "$Esc[96m"
    $FGDarkBlue = "$Esc[34m"
    $FGGray = "$Esc[37m"
    $FGYellow = "$Esc[93m"
    
    $Char_HeavyCheck = "[v]"
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

    Write-Header "WINGET APP UPDATE"

    if ($Reverse) {
        Write-LeftAligned "$FGYellow$Char_Warn Reverse Mode: App upgrades cannot be reversed automatically.$Reset"
        Write-Host ""
        $copyright = "Copyright (c) 2026 WinAuto"; $cPad = [Math]::Floor((60 - $copyright.Length) / 2); Write-Host (" " * $cPad + "$FGCyan$copyright$Reset"); Write-Host ""
        return
    }

    # Check for WinGet
    if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
        Write-LeftAligned "$FGRed$Char_Warn WinGet is not installed or not in PATH.$Reset"
        Write-LeftAligned "Please install App Installer from the Microsoft Store."
        Write-Host ""
        Write-Boundary
        Start-Sleep -Seconds 3
        return
    }

    Write-LeftAligned "$FGGray Running winget upgrade --all...$Reset"
    Write-Host ""

    try {
        $wingetArgs = @(
            "upgrade",
            "--all",
            "--include-unknown",
            "--accept-package-agreements",
            "--accept-source-agreements",
            "--silent"
        )
        
        Start-Process "winget.exe" -ArgumentList $wingetArgs -Wait -NoNewWindow
        
        Write-Host ""
        Write-LeftAligned "$FGGreen$Char_HeavyCheck WinGet update completed.$Reset"
    }
    catch {
        Write-LeftAligned "$FGRed$Char_Warn Update failed: $($_.Exception.Message)$Reset"
    }

    # --- FOOTER ---
    Write-Host ""
    $copyright = "Copyright (c) 2026 WinAuto"
    $cPad = [Math]::Floor((60 - $copyright.Length) / 2)
    Write-Host (" " * $cPad + "$FGCyan$copyright$Reset")
    Write-Host ""
    Start-Sleep -Seconds 3
} @args
