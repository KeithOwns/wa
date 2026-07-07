#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Disables or Enables the Task View button on the Taskbar.
.DESCRIPTION
    Standardized for WinAuto.
    0 = Hidden (Default)
    1 = Show
    Standalone version. Includes Reverse Mode.
.PARAMETER Reverse
    (Alias: -r) Reverses the setting (Shows Task View button).
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

    Write-Header "TASK VIEW BUTTON"

    try {
        $registryPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
        $name = "ShowTaskViewButton"
        $targetValue = if ($Reverse) { 1 } else { 0 }
        $statusText = if ($Reverse) { "VISIBLE" } else { "HIDDEN" }

        if (-not (Test-Path $registryPath)) { New-Item -Path $registryPath -Force | Out-Null }
        Set-ItemProperty -Path $registryPath -Name $name -Value $targetValue -Type DWord -Force
        Write-LeftAligned "$FGGreen[v] Task View Button is now $statusText.$Reset"
        Write-LeftAligned "Restarting Explorer to apply..."
        Stop-Process -Name explorer -Force
    }
    catch { Write-LeftAligned "$FGRed[x] Failed: $($_.Exception.Message)$Reset" }

    Write-Host ""
    $copyright = "Copyright (c) 2026 WinAuto"
    $cPad = [Math]::Floor((60 - $copyright.Length) / 2)
    Write-Host (" " * $cPad + "$FGCyan$copyright$Reset")
    Write-Host ""

} @args