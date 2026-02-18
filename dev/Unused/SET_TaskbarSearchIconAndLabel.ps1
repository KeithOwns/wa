#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Sets Taskbar Search to "Search icon and label".
.DESCRIPTION
    Value 3 = Search icon and label.
    Standalone version. Includes Reverse Mode (-r).
.PARAMETER Reverse
    (Alias: -r) Reverses setting to Hidden (Value 0).
#>

& {
    param(
        [Parameter(Mandatory = $false)]
        [Alias('r')]
        [switch]$Reverse,
        [switch]$Undo
    )

    if ($Undo) { $Reverse = $true }

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
        function Write-LeftAligned { param($Text) Write-Host "  $Text" }
    }

    Write-Header "TASKBAR SEARCH LABEL"

    $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search"
    $regName = "SearchboxTaskbarMode"
    
    $desiredValue = if ($Reverse) { 0 } else { 3 }
    $statusText = if ($Reverse) { "HIDDEN (0)" } else { "ICON & LABEL (3)" }

    try {
        # Verify path exists
        if (-not (Test-Path $regPath)) {
            New-Item -Path $regPath -Force | Out-Null
        }

        # Set the registry value
        Set-ItemProperty -Path $regPath -Name $regName -Value $desiredValue -Type DWord -Force

        Write-LeftAligned "$FGGreen$Char_HeavyCheck Search mode set to $statusText.$Reset"
        Write-LeftAligned "Restarting Windows Explorer to apply changes..."
        
        # Restart Explorer to refresh the taskbar
        Stop-Process -Name explorer -Force
        
    }
    catch {
        Write-LeftAligned "$FGRed$Char_RedCross Error: $($_.Exception.Message)$Reset"
    }

    # --- FOOTER ---
    Write-Host ""
    $copyright = "Copyright (c) 2026 WinAuto"
    $cPad = [Math]::Floor((60 - $copyright.Length) / 2)
    Write-Host (" " * $cPad + "$FGCyan$copyright$Reset")
    Write-Host ""
} @args