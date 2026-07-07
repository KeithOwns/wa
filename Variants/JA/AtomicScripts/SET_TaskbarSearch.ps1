#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Sets Taskbar Search to "Search icon only".
.DESCRIPTION
    Value 1 = Search icon only.
    Standalone version. Includes Reverse Mode.
.PARAMETER Reverse
    (Alias: -r) Reverses setting to Hidden (Value 0).
#>

& {
    param(
        [Parameter(Mandatory = $false)]
        [Alias('r')]
        [switch]$Reverse
    )

    # --- STANDALONE UI & LOGGING RESOURCES ---
    $Esc = [char]0x1B; $Reset = "$Esc[0m"; $Bold = "$Esc[1m"; $FGGreen = "$Esc[92m"; $FGRed = "$Esc[91m"; $FGCyan = "$Esc[96m"; $FGDarkBlue = "$Esc[34m"
    
    function Write-Boundary { param([string]$Color = $FGDarkBlue) Write-Host "$Color$([string]'_' * 60)$Reset" }
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
    function Write-LeftAligned { param($Text) Write-Host "  $Text" }

    Write-Header "TASKBAR SEARCH ICON"

    $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search"
    $regName = "SearchboxTaskbarMode"
    $desiredValue = if ($Reverse) { 0 } else { 1 }
    $statusText = if ($Reverse) { "HIDDEN (0)" } else { "ICON ONLY (1)" }

    try {
        if (-not (Test-Path $regPath)) { New-Item -Path $regPath -Force | Out-Null }
        Set-ItemProperty -Path $regPath -Name $regName -Value $desiredValue -Type DWord -Force
        Write-LeftAligned "$FGGreen[v] Search mode set to $statusText.$Reset"
        Write-LeftAligned "Restarting Windows Explorer to apply changes..."
        Stop-Process -Name explorer -Force
    }
    catch { Write-LeftAligned "$FGRed[x] Error: $($_.Exception.Message)$Reset" }

    Write-Host ""
    $copyright = "Copyright (c) 2026 WinAuto"
    $cPad = [Math]::Floor((60 - $copyright.Length) / 2)
    Write-Host (" " * $cPad + "$FGCyan$copyright$Reset")
    Write-Host ""

} @args