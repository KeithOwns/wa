#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Toggles 'Automatically save restartable apps and restart them when I sign back in'.
.DESCRIPTION
    Toggles the "RestartApps" registry key in HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon.
    1 = Enabled (Default Target)
    0 = Disabled
    Standalone version. Includes Reverse Mode (-r).
.PARAMETER TurnOn
    Forces the setting to be Enabled.
.PARAMETER Reverse
    (Alias: -r) Forces the setting to be Disabled.
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
    $FGYellow = "$Esc[93m"
    
    $Char_HeavyCheck = "[v]"
    $Char_Warn = "!"
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

    Write-Header "APP RESTART"

    try {
        $regPath = "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
        $regName = "RestartApps"

        # Ensure path exists (Though HKCU Winlogon usually does)
        if (-not (Test-Path $regPath)) {
            New-Item -Path $regPath -Force | Out-Null
        }

        # Get current value (Default to 0 if not present)
        $currentVal = (Get-ItemProperty -Path $regPath -Name $regName -ErrorAction SilentlyContinue).$regName
        if ($null -eq $currentVal) { $currentVal = 0 }

        # Logic: 
        # -Reverse forces 0
        # -TurnOn forces 1 (Takes precedence over Reverse if both set, though unlikely)
        # Else Toggle
        
        if ($Reverse) {
            $newValue = 0
            $statusText = "DISABLED"
            $icon = $Char_Warn
            $color = $FGYellow
        }
        elseif ($currentVal -eq 1) {
            $newValue = 0
            $statusText = "DISABLED"
            $icon = $Char_Warn
            $color = $FGYellow
        }
        else {
            $newValue = 1
            $statusText = "ENABLED"
            $icon = $Char_HeavyCheck
            $color = $FGGreen
        }

        # Apply new value
        Set-ItemProperty -Path $regPath -Name $regName -Value $newValue -Type DWord -Force

        Write-LeftAligned "$color$icon  'Restart apps after signing in' is now $statusText.$Reset"

    }
    catch {
        Write-LeftAligned "$FGRed$Char_RedCross  Failed to modify setting: $($_.Exception.Message)$Reset"
    }

    # --- FOOTER ---
    Write-Host ""
    $copyright = "Copyright (c) 2026 WinAuto"
    $cPad = [Math]::Floor((60 - $copyright.Length) / 2)
    Write-Host (" " * $cPad + "$FGCyan$copyright$Reset")
    Write-Host ""
} @args
