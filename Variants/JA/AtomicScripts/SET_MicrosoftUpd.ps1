#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Sets the 'Receive updates for other Microsoft products' setting.
.DESCRIPTION
    Modifies 'AllowMUUpdateService' in HKLM\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings.
    Standalone version. Includes Reverse Mode.
.PARAMETER State
    'On', 'Off', or 'Toggle' (Default).
.PARAMETER Reverse
    (Alias: -r) Forces the setting to 'Off'.
.PARAMETER NoWait
    Skips the "Press any key" pause.
#>

& {
    param(
        [string]$State = "Toggle",
        [Parameter(Mandatory = $false)]
        [Alias('r')]
        [switch]$Reverse,
        [switch]$NoWait
    )

    if ($Reverse) { $State = "Off" }

    # --- STANDALONE UI & LOGGING RESOURCES ---
    $Esc = [char]0x1B
    $Reset = "$Esc[0m"
    $Bold = "$Esc[1m"
    $FGGreen = "$Esc[92m"; $FGRed = "$Esc[91m"; $FGCyan = "$Esc[96m"; $FGDarkBlue = "$Esc[34m"; $FGGray = "$Esc[37m"

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

    Write-Header "MICROSOFT UPDATES"

    $regPath = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings"
    $regName = "AllowMUUpdateService"

    try {
        if (-not (Test-Path $regPath)) { New-Item -Path $regPath -Force | Out-Null }
        $current = (Get-ItemProperty -Path $regPath -Name $regName -ErrorAction SilentlyContinue).$regName
        if ($null -eq $current) { $current = 0 }

        $target = -1
        if ($State -eq "On") { $target = 1 }
        elseif ($State -eq "Off") { $target = 0 }
        else { $target = if ($current -eq 1) { 0 } else { 1 } }

        if ($current -ne $target) {
            Set-ItemProperty -Path $regPath -Name $regName -Value $target -Type DWord -Force
            Get-Process "SystemSettings" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
            $msg = if ($target -eq 1) { "ON (Receive Microsoft Updates)" } else { "OFF" }
            Write-LeftAligned "$FGGreen[v] 'Microsoft Updates' set to $msg.$Reset"
        }
        else { Write-LeftAligned "$FGGray[-] 'Microsoft Updates' is already set to target.$Reset" }
    }
    catch { Write-LeftAligned "$FGRed[x] Failed: $($_.Exception.Message)$Reset" }

    Write-Host ""
    $copyright = "Copyright (c) 2026 WinAuto"
    $cPad = [Math]::Floor((60 - $copyright.Length) / 2)
    Write-Host (" " * $cPad + "$FGCyan$copyright$Reset")
    Write-Host ""

    if (-not $NoWait) {
        Write-Host "Press any key to exit..."
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }

} @args
