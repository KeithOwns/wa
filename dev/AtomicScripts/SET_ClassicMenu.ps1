#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Enables 'Classic' Context Menu (Windows 10 Style) on Windows 11.
.DESCRIPTION
    Restores the classic right-click context menu by modifying the CLSID registry key.
    Standalone version.
    Includes Reverse Mode (-r) to revert to Windows 11 default.
.PARAMETER Reverse
    (Alias: -r) Reverses the setting (Restores Windows 11 Default Menu).
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
    $FGGray = "$Esc[90m"
    
    $Char_HeavyCheck = "[v]"
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

    # --- MAIN ---
    Write-Header "CLASSIC CONTEXT MENU"
    
    $Path = "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32"
    
    try {
        if ($Reverse) {
            # Revert to Windows 11 Default (Delete Key)
            if (Test-Path "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}") {
                Remove-Item -Path "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}" -Recurse -Force -ErrorAction SilentlyContinue
                Write-LeftAligned "$FGGreen$Char_HeavyCheck Reverted to Windows 11 Default Menu.$Reset"
            }
            else {
                Write-LeftAligned "$FGGray Already using default menu.$Reset"
            }
        }
        else {
            # Enable Classic Menu (Create Key with Default Empty Value)
            if (-not (Test-Path $Path)) {
                New-Item -Path $Path -Force | Out-Null
            }
            # Set Default property to empty string (Required for this hack)
            Set-ItemProperty -Path $Path -Name "(default)" -Value "" -Force
            
            Write-LeftAligned "$FGGreen$Char_HeavyCheck Classic Context Menu Enabled.$Reset"
        }
        
        Write-LeftAligned "$FGCyan Restarting Explorer to apply...$Reset"
        Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 1
        Start-Process explorer
    }
    catch {
        Write-LeftAligned "$FGRed$Char_RedCross Failed: $($_.Exception.Message)$Reset"
    }

    # --- FOOTER ---
    Write-Host ""
    $copyright = "Copyright (c) 2026 WinAuto"
    $cPad = [Math]::Floor((60 - $copyright.Length) / 2)
    Write-Host (" " * $cPad + "$FGCyan$copyright$Reset")
    Write-Host ""
} @args
