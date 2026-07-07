#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Restarts the Windows Explorer process.
.DESCRIPTION
    Standardized for WinAuto. Force closes and restarts explorer.exe to apply UI changes.
    Standalone version.
#>

& {
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

    Write-Header "RESTART EXPLORER"

    try {
        Write-LeftAligned "Restarting Explorer..."
        Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 1
        if (-not (Get-Process explorer -ErrorAction SilentlyContinue)) { Start-Process explorer }
        Write-LeftAligned "$FGGreen$Char_HeavyCheck Explorer restarted.$Reset"
    }
    catch { Write-LeftAligned "$FGRed$Char_RedCross Failed: $($_.Exception.Message)$Reset" }

} @args
