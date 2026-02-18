#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Optimizes all fixed disks (TRIM for SSD, Defrag for HDD).
.DESCRIPTION
    Standardized for WinAuto.
    Standalone version. Includes Reverse Mode (-r) stub.
.PARAMETER Reverse
    (Alias: -r) No-Op. Optimization cannot be reversed.
#>

& {
    param(
        [Parameter(Mandatory = $false)]
        [Alias('r')]
        [switch]$Reverse,
        [switch]$Undo
    )

    if ($Undo) { $Reverse = $true }

    # --- STANDALONE HELPERS ---
    $Esc = [char]0x1B
    $Reset = "$Esc[0m"
    $Bold = "$Esc[1m"
    $FGGreen = "$Esc[92m"
    $FGRed = "$Esc[91m"
    $FGCyan = "$Esc[96m"
    $FGDarkBlue = "$Esc[34m"
    $FGWhite = "$Esc[97m"
    $FGYellow = "$Esc[93m"
    
    $Char_HeavyCheck = "[v]"
    $Char_HeavyMinus = "-"
    $Char_RedCross = "x"
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

    Write-Header "DISK OPTIMIZATION"

    if ($Reverse) {
        Write-LeftAligned "$FGYellow$Char_Warn Reverse Mode: Disk optimization cannot be reversed.$Reset"
        Write-Host ""
        $copyright = "Copyright (c) 2026 WinAuto"; $cPad = [Math]::Floor((60 - $copyright.Length) / 2); Write-Host (" " * $cPad + "$FGCyan$copyright$Reset"); Write-Host ""
        return
    }

    try {
        $volumes = Get-Volume | Where-Object { $_.DriveLetter -and $_.DriveType -eq 'Fixed' }
        foreach ($v in $volumes) {
            $drive = $v.DriveLetter
            Write-LeftAligned "$FGWhite$Char_HeavyMinus Drive $drive`: $Reset"
            
            $isSSD = $false
            $part = Get-Partition -DriveLetter $drive -ErrorAction SilentlyContinue
            if ($part) {
                $disk = Get-Disk -Number $part.DiskNumber -ErrorAction SilentlyContinue
                if ($disk -and $disk.MediaType -eq 'SSD') { $isSSD = $true }
            }

            if ($isSSD) {
                Write-LeftAligned "  $FGYellow Type: SSD - Running TRIM...$Reset"
                Optimize-Volume -DriveLetter $drive -ReTrim | Out-Null
            }
            else {
                Write-LeftAligned "  $FGYellow Type: HDD - Running Defrag...$Reset"
                Optimize-Volume -DriveLetter $drive -Defrag | Out-Null
            }
            Write-LeftAligned "  $FGGreen$Char_HeavyCheck Optimization Complete.$Reset"
        }
    }
    catch {
        $errMsg = "$($_.Exception.Message)"
        Write-LeftAligned "$FGRed$Char_RedCross Error: $errMsg$Reset"
    }

    # --- FOOTER ---
    Write-Host ""
    $copyright = "Copyright (c) 2026 WinAuto"
    $cPad = [Math]::Floor((60 - $copyright.Length) / 2)
    Write-Host (" " * $cPad + "$FGCyan$copyright$Reset")
    Write-Host ""
    Start-Sleep -Seconds 1
} @args
