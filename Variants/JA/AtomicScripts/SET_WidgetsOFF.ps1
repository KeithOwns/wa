#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Disables the Widgets button on the Taskbar.
.DESCRIPTION
    Sets 'TaskbarDa' to 0 in HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced.
    Standalone version. Includes Reverse Mode.
.PARAMETER Reverse
    (Alias: -r) Reverses the setting (Shows Widgets button).
#>

& {
    param(
        [Parameter(Mandatory = $false)]
        [Alias('r')]
        [switch]$Reverse
    )

    # --- STANDALONE UI & LOGGING RESOURCES ---
    $Esc = [char]0x1B; $Reset = "$Esc[0m"; $Bold = "$Esc[1m"; $FGGreen = "$Esc[92m"; $FGRed = "$Esc[91m"; $FGCyan = "$Esc[96m"; $FGDarkBlue = "$Esc[34m"
    $Char_HeavyCheck = "[v]"; $Char_RedCross = "[x]"
    
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

    Write-Header "WIDGETS TOGGLE"

    $Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    $Name = "TaskbarDa"
    $Value = if ($Reverse) { 1 } else { 0 }
    $ActionStr = if ($Reverse) { "SHOWN" } else { "HIDDEN" }

    try {
        if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type DWord -Force
        Write-LeftAligned "$FGGreen$Char_HeavyCheck Taskbar Widgets button is $ActionStr.$Reset"
        Write-LeftAligned "$FGCyan Restarting Explorer to apply...$Reset"
        Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 1
        Start-Process explorer
    }
    catch { Write-LeftAligned "$FGRed$Char_RedCross Failed: $($_.Exception.Message)$Reset" }

    Write-Host ""
    $copyright = "Copyright (c) 2026 WinAuto"
    $cPad = [Math]::Floor((60 - $copyright.Length) / 2)
    Write-Host (" " * $cPad + "$FGCyan$copyright$Reset")
    Write-Host ""

} @args
