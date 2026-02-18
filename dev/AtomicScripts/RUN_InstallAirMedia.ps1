#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Crestron AirMedia Installer - Standalone AtomicScript
.DESCRIPTION
    Installs Crestron AirMedia via WinGet (Machine scope).
    Standalone version. Includes Reverse Mode (-r) for uninstall.
.PARAMETER Reverse
    (Alias: -r) Uninstalls Crestron AirMedia via WinGet.
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

    # --- STANDALONE HELPERS ---
    $Esc = [char]0x1B
    $Reset = "$Esc[0m"
    $Bold = "$Esc[1m"
    $FGGreen = "$Esc[92m"
    $FGRed = "$Esc[91m"
    $FGCyan = "$Esc[96m"
    $FGDarkBlue = "$Esc[34m"
    $FGGray = "$Esc[37m"
    $FGYellow = "$Esc[93m"
    $FGWhite = "$Esc[97m"
    
    $Char_HeavyCheck = "[v]"
    $Char_RedCross = "x"
    $Char_Warn = "!"
    $Char_Finger = "->"
    $Char_CheckMark = "v"
    
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

    # --- CONFIG ---
    $AppName = "Crestron AirMedia"
    $MatchName = "*AirMedia*"
    $WingetId = "Crestron.AirMedia"
    $WingetScope = "Machine"

    # --- DETECTION ---
    function Test-AppInstalled {
        $scopes = @(
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
            "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
        )
        foreach ($s in $scopes) {
            if (Test-Path $s) {
                foreach ($k in (Get-ChildItem $s -ErrorAction SilentlyContinue)) {
                    $dn = $k.GetValue('DisplayName', $null)
                    if ($dn -and $dn -like $MatchName) { return $true }
                }
            }
        }
        return $false
    }

    Write-Header "CRESTRON AIRMEDIA INSTALLER"

    # --- REVERSE MODE (Uninstall) ---
    if ($Reverse) {
        Write-LeftAligned "$FGYellow$Char_Warn Reverse Mode: Uninstalling via WinGet...$Reset"
        
        if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
            Write-LeftAligned "$FGRed$Char_RedCross WinGet is not available.$Reset"
            Write-Host ""
            $copyright = "Copyright (c) 2026 WinAuto"; $cPad = [Math]::Floor((60 - $copyright.Length) / 2); Write-Host (" " * $cPad + "$FGCyan$copyright$Reset"); Write-Host ""
            return
        }

        try {
            $p = Start-Process "winget.exe" -ArgumentList "uninstall --id $WingetId --silent --accept-source-agreements" -Wait -PassThru -NoNewWindow
            if ($p.ExitCode -eq 0) {
                Write-LeftAligned "$FGGreen$Char_HeavyCheck $AppName uninstalled.$Reset"
            }
            else {
                Write-LeftAligned "$FGRed$Char_RedCross Uninstall finished with code $($p.ExitCode).$Reset"
            }
        }
        catch {
            Write-LeftAligned "$FGRed$Char_RedCross Uninstall failed: $($_.Exception.Message)$Reset"
        }

        Write-Host ""
        $copyright = "Copyright (c) 2026 WinAuto"; $cPad = [Math]::Floor((60 - $copyright.Length) / 2); Write-Host (" " * $cPad + "$FGCyan$copyright$Reset"); Write-Host ""
        return
    }

    # --- INSTALL MODE ---
    if (Test-AppInstalled) {
        Write-LeftAligned "$FGGreen$Char_HeavyCheck $AppName is already installed.$Reset"
        Write-Host ""
        $copyright = "Copyright (c) 2026 WinAuto"; $cPad = [Math]::Floor((60 - $copyright.Length) / 2); Write-Host (" " * $cPad + "$FGCyan$copyright$Reset"); Write-Host ""
        Start-Sleep -Seconds 3
        return
    }

    if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
        Write-LeftAligned "$FGRed$Char_Warn WinGet is not installed or not in PATH.$Reset"
        Write-LeftAligned "Please install App Installer from the Microsoft Store."
        Write-Host ""
        Write-Boundary
        Start-Sleep -Seconds 3
        return
    }

    Write-LeftAligned "$FGWhite$Char_Finger Installing $AppName via WinGet...$Reset"

    try {
        # Initialize WinGet sources (required on fresh machines)
        Write-LeftAligned "$FGGray Initializing WinGet sources...$Reset"
        Start-Process "winget.exe" -ArgumentList "source reset --force --disable-interactivity --accept-source-agreements" -NoNewWindow -Wait -ErrorAction SilentlyContinue
        Start-Process "winget.exe" -ArgumentList "source update --disable-interactivity --accept-source-agreements" -NoNewWindow -Wait -ErrorAction SilentlyContinue

        $installArgs = "install --id $WingetId --exact --accept-package-agreements --accept-source-agreements --silent --scope $WingetScope"
        $p = Start-Process "winget.exe" -ArgumentList $installArgs -NoNewWindow -PassThru -Wait
        
        if ($p.ExitCode -eq 0) {
            Write-LeftAligned "$FGGreen$Char_CheckMark Installation Successful.$Reset"
        }
        else {
            throw "WinGet exited with code $($p.ExitCode)"
        }
    }
    catch {
        Write-LeftAligned "$FGRed$Char_Warn Error: $($_.Exception.Message)$Reset"
    }

    # --- FOOTER ---
    Write-Host ""
    $copyright = "Copyright (c) 2026 WinAuto"
    $cPad = [Math]::Floor((60 - $copyright.Length) / 2)
    Write-Host (" " * $cPad + "$FGCyan$copyright$Reset")
    Write-Host ""
    Start-Sleep -Seconds 3
} @args
