#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Disables or Enables the Task View button on the Taskbar.
.DESCRIPTION
    Standardized for WinAuto.
    0 = Hidden (Default)
    1 = Show
    Standalone version: Can be copy-pasted directly into PowerShell.
    Includes Reverse Mode (-r) to undo changes.
.PARAMETER Reverse
    (Alias: -r) Reverses the setting (Shows Task View button).
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
    
    $Char_HeavyCheck = "[v]"
    $Char_RedCross = "[x]"

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
        function Write-LeftAligned {
            param([string]$Text, [int]$Indent = 2)
            Write-Host (" " * $Indent + $Text)
        }
    }

    # --- MAIN LOGIC ---
    Write-Header "TASK VIEW BUTTON"

    try {
        $registryPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
        $name = "ShowTaskViewButton"
        
        $targetValue = if ($Reverse) { 1 } else { 0 }
        $statusText = if ($Reverse) { "VISIBLE" } else { "HIDDEN" }

        # Check / Create Path
        if (-not (Test-Path $registryPath)) {
            New-Item -Path $registryPath -Force | Out-Null
        }

        # Set Value
        Set-ItemProperty -Path $registryPath -Name $name -Value $targetValue -Type DWord -Force

        Write-LeftAligned "$FGGreen$Char_HeavyCheck  Task View Button is now $statusText.$Reset"
        Write-LeftAligned "Restarting Explorer to apply..."

        # Restart Explorer
        Stop-Process -Name explorer -Force

    }
    catch {
        Write-LeftAligned "$FGRed$Char_RedCross  Failed: $($_.Exception.Message)$Reset"
    }

    # --- FOOTER ---
    Write-Host ""
    $copyright = "Copyright (c) 2026 WinAuto"
    $cPad = [Math]::Floor((60 - $copyright.Length) / 2)
    Write-Host (" " * $cPad + "$FGCyan$copyright$Reset")
    Write-Host ""
} @args