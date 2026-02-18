#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Sets the 'Notify me when a restart is required to finish updating' setting.
.DESCRIPTION
    Modifies 'RestartNotificationsAllowed2' in HKLM\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings.
    Standalone version. Includes Reverse Mode (-r).
.PARAMETER State
    'On', 'Off', or 'Toggle' (Default).
.PARAMETER Reverse
    (Alias: -r) Forces the setting to 'Off' (Disable Notification).
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

    # --- STANDALONE HELPERS ---
    $Esc = [char]0x1B
    $Reset = "$Esc[0m"
    $Bold = "$Esc[1m"
    $FGCyan = "$Esc[96m"
    $FGDarkBlue = "$Esc[34m"
    $FGGreen = "$Esc[92m"
    $FGGray = "$Esc[37m"

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

    Write-Header "RESTART NOTIFICATION"

    # Ensure script is running as Administrator
    if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        Write-Warning "Run as Administrator required."
        if (-not $NoWait) { Start-Sleep -Seconds 5 }
        Exit
    }

    $regPath = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings"
    $regName = "RestartNotificationsAllowed2"

    if (-not (Test-Path $regPath)) { New-Item -Path $regPath -Force | Out-Null }

    $current = (Get-ItemProperty -Path $regPath -Name $regName -ErrorAction SilentlyContinue).$regName
    if ($null -eq $current) { $current = 0 }

    $target = -1
    if ($State -eq "On") { $target = 1 }
    elseif ($State -eq "Off") { $target = 0 }
    else { $target = if ($current -eq 1) { 0 } else { 1 } }

    if ($current -ne $target) {
        if (-not (Get-ItemProperty -Path $regPath -Name $regName -ErrorAction SilentlyContinue)) {
            New-ItemProperty -Path $regPath -Name $regName -Value $target -PropertyType DWord -Force | Out-Null
        }
        else {
            Set-ItemProperty -Path $regPath -Name $regName -Value $target -Type DWord -Force
        }

        # Also restart Settings app to refresh UI if open
        Get-Process "SystemSettings" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        
        $msg = if ($target -eq 1) { "ON (Notify Restart)" } else { "OFF" }
        Write-Host "  Success: 'Notify Restart' set to $msg." -ForegroundColor Green
    }
    else {
        Write-Host "  No Change: 'Notify Restart' is already set to target." -ForegroundColor Gray
    }

    # --- FOOTER ---
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
