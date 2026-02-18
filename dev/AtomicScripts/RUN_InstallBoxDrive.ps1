#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Box Drive Installer - Standalone AtomicScript
.DESCRIPTION
    Downloads and installs Box Drive (x64 MSI) silently.
    Standalone version. Includes Reverse Mode (-r) for uninstall.
.PARAMETER Reverse
    (Alias: -r) Uninstalls Box Drive.
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
    $AppName = "Box"
    $MatchName = "Box"
    $MsiUrl = "https://e3.boxcdn.net/box-installers/desktop/releases/win/Box-x64.msi"

    # --- DETECTION ---
    function Test-BoxInstalled {
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

    Write-Header "BOX DRIVE INSTALLER"

    # --- REVERSE MODE (Uninstall) ---
    if ($Reverse) {
        Write-LeftAligned "$FGYellow$Char_Warn Reverse Mode: Attempting to uninstall Box Drive...$Reset"
        
        $scopes = @(
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
            "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
        )
        $uninstallString = $null
        foreach ($s in $scopes) {
            if (Test-Path $s) {
                foreach ($k in (Get-ChildItem $s -ErrorAction SilentlyContinue)) {
                    $dn = $k.GetValue('DisplayName', $null)
                    if ($dn -and $dn -like $MatchName) {
                        $uninstallString = $k.GetValue('UninstallString', $null)
                        break
                    }
                }
            }
            if ($uninstallString) { break }
        }

        if ($uninstallString) {
            try {
                Write-LeftAligned "$FGGray Running uninstaller...$Reset"
                if ($uninstallString -match 'msiexec') {
                    $guid = [regex]::Match($uninstallString, '\{[A-F0-9\-]+\}').Value
                    if ($guid) {
                        $p = Start-Process "msiexec.exe" -ArgumentList "/x $guid /quiet /norestart" -Wait -PassThru
                    }
                    else {
                        $p = Start-Process "cmd.exe" -ArgumentList "/c $uninstallString /quiet /norestart" -Wait -PassThru
                    }
                }
                else {
                    $p = Start-Process "cmd.exe" -ArgumentList "/c $uninstallString /quiet /norestart" -Wait -PassThru
                }

                if ($p.ExitCode -eq 0 -or $p.ExitCode -eq 3010) {
                    Write-LeftAligned "$FGGreen$Char_HeavyCheck Box Drive uninstalled.$Reset"
                }
                else {
                    Write-LeftAligned "$FGRed$Char_RedCross Uninstall finished with code $($p.ExitCode).$Reset"
                }
            }
            catch {
                Write-LeftAligned "$FGRed$Char_RedCross Uninstall failed: $($_.Exception.Message)$Reset"
            }
        }
        else {
            Write-LeftAligned "$FGGray Box Drive is not installed.$Reset"
        }

        Write-Host ""
        $copyright = "Copyright (c) 2026 WinAuto"; $cPad = [Math]::Floor((60 - $copyright.Length) / 2); Write-Host (" " * $cPad + "$FGCyan$copyright$Reset"); Write-Host ""
        return
    }

    # --- INSTALL MODE ---
    if (Test-BoxInstalled) {
        Write-LeftAligned "$FGGreen$Char_HeavyCheck $AppName is already installed.$Reset"
        Write-Host ""
        $copyright = "Copyright (c) 2026 WinAuto"; $cPad = [Math]::Floor((60 - $copyright.Length) / 2); Write-Host (" " * $cPad + "$FGCyan$copyright$Reset"); Write-Host ""
        Start-Sleep -Seconds 3
        return
    }

    Write-LeftAligned "$FGWhite$Char_Finger Installing $AppName...$Reset"

    try {
        # Download
        $tempFile = "$env:TEMP\WinAuto_Install.msi"
        Write-LeftAligned "$FGGray Downloading installer...$Reset"
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
        Invoke-WebRequest -Uri $MsiUrl -OutFile $tempFile -UseBasicParsing -ErrorAction Stop

        # Install via msiexec
        Write-LeftAligned "$FGGray Running installer...$Reset"
        $msiArgs = "/i `"$tempFile`" /quiet /norestart"
        $p = Start-Process "msiexec.exe" -ArgumentList $msiArgs -Wait -PassThru

        if ($p.ExitCode -eq 0 -or $p.ExitCode -eq 3010) {
            Write-LeftAligned "$FGGreen$Char_CheckMark Installation Successful.$Reset"
        }
        else {
            throw "msiexec exited with code $($p.ExitCode)"
        }

        Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
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
