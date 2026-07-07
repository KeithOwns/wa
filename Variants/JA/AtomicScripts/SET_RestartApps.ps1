#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Toggles 'Automatically save restartable apps and restart them when I sign back in'.
.DESCRIPTION
    Toggles the "RestartApps" registry key in HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon.
    1 = Enabled (Default Target)
    0 = Disabled
    Standalone version. Includes Reverse Mode.
.PARAMETER Reverse
    (Alias: -r) Forces the setting to be Disabled.
#>

& {
    param(
        [Parameter(Mandatory = $false)]
        [Alias('r')]
        [switch]$Reverse
    )

    # --- STANDALONE UI & LOGGING RESOURCES ---
    $Esc = [char]0x1B; $Reset = "$Esc[0m"; $Bold = "$Esc[1m"; $FGGreen = "$Esc[92m"; $FGRed = "$Esc[91m"; $FGCyan = "$Esc[96m"; $FGDarkBlue = "$Esc[34m"; $FGYellow = "$Esc[93m"
    
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

    Write-Header "APP RESTART"

    try {
        $regPath = "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
        $regName = "RestartApps"

        if (-not (Test-Path $regPath)) { New-Item -Path $regPath -Force | Out-Null }
        $currentVal = (Get-ItemProperty -Path $regPath -Name $regName -ErrorAction SilentlyContinue).$regName
        if ($null -eq $currentVal) { $currentVal = 0 }

        if ($Reverse) { $newValue = 0; $statusText = "DISABLED" }
        elseif ($currentVal -eq 1) { $newValue = 0; $statusText = "DISABLED" }
        else { $newValue = 1; $statusText = "ENABLED" }

        Set-ItemProperty -Path $regPath -Name $regName -Value $newValue -Type DWord -Force
        $color = if ($newValue -eq 1) { $FGGreen } else { $FGYellow }
        Write-LeftAligned "$color[v] 'Restart apps after signing in' is now $statusText.$Reset"
    }
    catch { Write-LeftAligned "$FGRed[x] Failed: $($_.Exception.Message)$Reset" }

    Write-Host ""
    $copyright = "Copyright (c) 2026 WinAuto"
    $cPad = [Math]::Floor((60 - $copyright.Length) / 2)
    Write-Host (" " * $cPad + "$FGCyan$copyright$Reset")
    Write-Host ""

} @args
