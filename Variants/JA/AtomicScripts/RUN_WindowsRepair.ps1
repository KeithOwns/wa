#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Windows System File Integrity & Repair Tool (SFC/DISM)
.DESCRIPTION
    Automated flow to check and repair Windows system files using SFC and DISM.
    Standalone version. Includes Reverse Mode.
.PARAMETER Reverse
    (Alias: -r) No-Op. System repairs cannot be reversed.
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

    # --- STANDALONE UI & LOGGING RESOURCES ---
    $Esc = [char]0x1B
    $Reset = "$Esc[0m"
    $Bold = "$Esc[1m"
    $FGGreen = "$Esc[92m"; $FGRed = "$Esc[91m"; $FGYellow = "$Esc[93m"; $FGCyan = "$Esc[96m"; $FGDarkBlue = "$Esc[34m"; $FGWhite = "$Esc[97m"; $FGGray = "$Esc[37m"

    $Char_Warn = "!"; $Char_HeavyCheck = "[v]"; $Char_RedCross = "[x]"; $Char_HeavyMinus = "-"

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

    function Invoke-SFCScan {
        Write-Host ""; Write-LeftAligned "$Bold$FGWhite$Char_HeavyMinus System File Checker (SFC)$Reset"
        Write-LeftAligned "$FGGray Initializing sfc /scannow...$Reset"
        try {
            $rawOutput = & sfc /scannow 2>&1
            $sfcOutput = ($rawOutput -join " ") -replace '[^\x20-\x7E]', ''
            Write-Host ""
            if ($sfcOutput -match "did not find any integrity violations") { Write-LeftAligned "$FGGreen[v] System files are healthy.$Reset"; return "SUCCESS" }
            elseif ($sfcOutput -match "found corrupt files and successfully repaired them") { Write-LeftAligned "$FGGreen[v] Corrupt files were found and repaired.$Reset"; return "REPAIRED" }
            elseif ($sfcOutput -match "found corrupt files but was unable to fix some of them") { Write-LeftAligned "$FGRed[x] SFC found unfixable corruption.$Reset"; return "FAILED" }
            else { Write-LeftAligned "$FGYellow! SFC completed with unknown status.$Reset"; return "UNKNOWN" }
        }
        catch { Write-LeftAligned "$FGRed[x] SFC execution error: $($_.Exception.Message)$Reset"; return "ERROR" }
    }

    function Invoke-DISMRepair {
        Write-Host ""; Write-LeftAligned "$Bold$FGWhite$Char_HeavyMinus Deployment Image Servicing (DISM)$Reset"
        Write-LeftAligned "$FGYellow Starting online image repair...$Reset"
        try {
            $dismOutput = & DISM /Online /Cleanup-Image /RestoreHealth 2>&1 | Out-String
            if ($dismOutput -match "The restore operation completed successfully") { Write-LeftAligned "$FGGreen[v] DISM repair completed successfully.$Reset"; return $true }
            else { Write-LeftAligned "$FGRed[x] DISM repair failed.$Reset"; return $false }
        }
        catch { Write-LeftAligned "$FGRed[x] DISM execution error: $($_.Exception.Message)$Reset"; return $false }
    }

    Write-Header "SYSTEM REPAIR FLOW"

    if ($Reverse) {
        Write-LeftAligned "$FGYellow$Char_Warn Reverse Mode: System repairs cannot be reversed.$Reset"
        Write-Host ""
        $copyright = "Copyright (c) 2026 WinAuto"; $cPad = [Math]::Floor((60 - $copyright.Length) / 2); Write-Host (" " * $cPad + "$FGCyan$copyright$Reset"); Write-Host ""
        return
    }

    $result = Invoke-SFCScan
    if ($result -eq "FAILED") {
        Write-Host ""; Write-LeftAligned "$FGYellow Triggering DISM Repair...$Reset"
        if (Invoke-DISMRepair) { Write-Host ""; Write-LeftAligned "$FGYellow Re-running SFC...$Reset"; Invoke-SFCScan | Out-Null }
    }

    Write-Host ""; Write-Boundary; Write-Centered "$FGGreen REPAIR FLOW COMPLETE $Reset"; Write-Boundary
    Write-Host ""
    $copyright = "Copyright (c) 2026 WinAuto"
    $cPad = [Math]::Floor((60 - $copyright.Length) / 2)
    Write-Host (" " * $cPad + "$FGCyan$copyright$Reset")
    Write-Host ""
    Start-Sleep -Seconds 2

} @args
