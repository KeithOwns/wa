#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Box for Office Installer - Standalone AtomicScript
.DESCRIPTION
    Downloads and installs Box for Office (EXE) silently.
    Standalone version. Includes Reverse Mode (-r) for uninstall.
.PARAMETER Reverse
    (Alias: -r) Uninstalls Box for Office.
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

    # --- STANDALONE UI & LOGGING RESOURCES ---
$Esc = [char]0x1B
$Reset = "$Esc[0m"
$Bold = "$Esc[1m"
$FGCyan = "$Esc[96m"; $FGGreen = "$Esc[92m"; $FGRed = "$Esc[91m"; $FGYellow = "$Esc[93m"; $FGWhite = "$Esc[97m"; $FGGray = "$Esc[37m"; $FGDarkGray = "$Esc[90m"; $FGDarkBlue = "$Esc[34m"; $BGYellow = "$Esc[103m"; $FGBlack = "$Esc[30m"
$Char_Warn = [char]0x26A0; $Char_BallotCheck = [char]0x2611; $Char_Keyboard = [char]0x2328; $Char_Loop = [char]::ConvertFromUtf32(0x1F504); $Char_Copyright = [char]0x00A9; $Char_Finger = [char]0x261B; $Char_HeavyCheck = [char]0x2705; $Char_RedCross = [char]0x2716; $Char_HeavyMinus = [char]0x2796; $Char_Skip = [char]0x23ED

function Write-Boundary { param([string]$Color = $FGDarkBlue) Write-Host "$Color$([string]'_' * 60)$Reset" }
function Write-LeftAligned { param([string]$Text, [int]$Indent = 2) Write-Host (" " * $Indent + $Text) }
function Write-Centered { param([string]$Text, [int]$Width = 60) $clean = $Text -replace "\x1B\[[0-9;]*m", ""; $pad = [Math]::Floor(($Width - $clean.Length) / 2); if ($pad -lt 0) { $pad = 0 }; Write-Host (" " * $pad + $Text) }
function Write-Header { param([string]$Title) Clear-Host; Write-Host ""; $t1 = "$([char]::ConvertFromUtf32(0x1FA9F)) WinAuto $Char_Loop"; Write-Centered "$Bold$FGCyan$t1$Reset"; Write-Boundary; Write-Centered "$Bold$FGCyan$($Title.ToUpper())$Reset"; Write-Boundary }
function Invoke-AnimatedPause { param([string]$ActionText = "CONTINUE", [int]$Timeout = 10) Write-Host ""; $top = [Console]::CursorTop; $StopWatch = [System.Diagnostics.Stopwatch]::StartNew(); while ($StopWatch.Elapsed.TotalSeconds -lt $Timeout) { if ([Console]::KeyAvailable) { $StopWatch.Stop(); return $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") }; $Elapsed = $StopWatch.Elapsed; $Filled = [Math]::Floor($Elapsed.TotalSeconds); $Dynamic = ""; for ($i=0;$i-lt 10;$i++) { $c = if ($i -lt 5) { "Enter"[$i] } else { " " }; if ($i -lt $Filled) { $Dynamic += "${BGYellow}${FGBlack}$c${Reset}" } else { $Dynamic += "${FGYellow}$c${Reset}" } }; Write-Centered "${FGWhite}$Char_Keyboard Press ${FGDarkGray}$Dynamic${FGDarkGray}${FGWhite} to ${FGYellow}$ActionText${FGDarkGray} | or SKIP$Char_Skip${Reset}"; try { [Console]::SetCursorPosition(0, $top) } catch {}; Start-Sleep -Milliseconds 100 }; $StopWatch.Stop(); return [PSCustomObject]@{VirtualKeyCode=13} }
function Write-Log { param([string]$Message, [string]$Level = 'INFO') $c = switch($Level){'ERROR'{$FGRed};'WARNING'{$FGYellow};'SUCCESS'{$FGGreen};Default{$FGGray}}; Write-LeftAligned "$c$Message$Reset" }

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

    Write-Header "BOX FOR OFFICE INSTALLER"

    # --- REVERSE MODE (Uninstall) ---
    if ($Reverse) {
        Write-LeftAligned "$FGYellow$Char_Warn Reverse Mode: Attempting to uninstall $AppName...$Reset"
        
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
                    # For logic trying to execute uninstall string directly if not msiexec
                    # Often uninstall string has quotes and args
                    # Simple attempt:
                    $p = Start-Process "cmd.exe" -ArgumentList "/c $uninstallString /quiet /norestart" -Wait -PassThru
                }

                if ($p.ExitCode -eq 0 -or $p.ExitCode -eq 3010) {
                    Write-LeftAligned "$FGGreen$Char_HeavyCheck $AppName uninstalled.$Reset"
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
            Write-LeftAligned "$FGGray $AppName is not installed.$Reset"
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

    Write-LeftAligned "$FGWhite$Char_Finger Installing $AppName...$Reset"

    try {
        # Download
        $tempFile = "$env:TEMP\WinAuto_InstallBoxOffice.exe"
        Write-LeftAligned "$FGGray Downloading installer...$Reset"
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
        Invoke-WebRequest -Uri $ExeUrl -OutFile $tempFile -UseBasicParsing -ErrorAction Stop

        # Delay if needed (Box for Office has PreInstallDelay in wa.ps1 config)
        if ($PreInstallDelay -gt 0) {
            Write-LeftAligned "$FGGray Waiting ${PreInstallDelay}s for prereqs...$Reset"
            Start-Sleep -Seconds $PreInstallDelay
        }

        # Install via EXE
        Write-LeftAligned "$FGGray Running installer...$Reset"
        $p = Start-Process $tempFile -ArgumentList $SilentArgs -Wait -PassThru

        if ($p.ExitCode -eq 0 -or $p.ExitCode -eq 3010) {
            Write-LeftAligned "$FGGreen$Char_CheckMark Installation Successful.$Reset"
        }
        else {
            throw "Installer exited with code $($p.ExitCode)"
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


# --- CONFIG ---
    $AppName = "Box for Office"
    $MatchName = "*Box for Office*"
    $ExeUrl = "https://e3.boxcdn.net/box-installers/boxforoffice/currentrelease/BoxForOffice.exe"
    $SilentArgs = "/quiet /norestart"
    $PreInstallDelay = 10

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

    Write-Header "BOX FOR OFFICE INSTALLER"

    # --- REVERSE MODE (Uninstall) ---
    if ($Reverse) {
        Write-LeftAligned "$FGYellow$Char_Warn Reverse Mode: Attempting to uninstall $AppName...$Reset"
        
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
                    # For logic trying to execute uninstall string directly if not msiexec
                    # Often uninstall string has quotes and args
                    # Simple attempt:
                    $p = Start-Process "cmd.exe" -ArgumentList "/c $uninstallString /quiet /norestart" -Wait -PassThru
                }

                if ($p.ExitCode -eq 0 -or $p.ExitCode -eq 3010) {
                    Write-LeftAligned "$FGGreen$Char_HeavyCheck $AppName uninstalled.$Reset"
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
            Write-LeftAligned "$FGGray $AppName is not installed.$Reset"
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

    Write-LeftAligned "$FGWhite$Char_Finger Installing $AppName...$Reset"

    try {
        # Download
        $tempFile = "$env:TEMP\WinAuto_InstallBoxOffice.exe"
        Write-LeftAligned "$FGGray Downloading installer...$Reset"
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
        Invoke-WebRequest -Uri $ExeUrl -OutFile $tempFile -UseBasicParsing -ErrorAction Stop

        # Delay if needed (Box for Office has PreInstallDelay in wa.ps1 config)
        if ($PreInstallDelay -gt 0) {
            Write-LeftAligned "$FGGray Waiting ${PreInstallDelay}s for prereqs...$Reset"
            Start-Sleep -Seconds $PreInstallDelay
        }

        # Install via EXE
        Write-LeftAligned "$FGGray Running installer...$Reset"
        $p = Start-Process $tempFile -ArgumentList $SilentArgs -Wait -PassThru

        if ($p.ExitCode -eq 0 -or $p.ExitCode -eq 3010) {
            Write-LeftAligned "$FGGreen$Char_CheckMark Installation Successful.$Reset"
        }
        else {
            throw "Installer exited with code $($p.ExitCode)"
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
