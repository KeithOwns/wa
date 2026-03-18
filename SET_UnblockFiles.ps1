#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Unblocks PowerShell scripts in the current directory and subdirectories.
.DESCRIPTION
    Removes the 'Mark of the Web' (Zone.Identifier) from .ps1, .psm1, and .psd1 files.
    This prevents "not digitally signed" errors for files downloaded from the internet.
    Standalone AtomicScript for the 'Unblock' Infrastructure Setup phase.
.PARAMETER Reverse
    Note: Unblocking cannot be reversed via this script.
#>

& {
    param(
        [Parameter(Mandatory = $false)]
        [Alias('r')]
        [switch]$Reverse
    )

    # --- STANDALONE UI & LOGGING RESOURCES ---
    $Esc = [char]0x1B; $Reset = "$Esc[0m"; $Bold = "$Esc[1m"; $FGGreen = "$Esc[92m"; $FGRed = "$Esc[91m"; $FGCyan = "$Esc[96m"; $FGDarkBlue = "$Esc[34m"; $FGGray = "$Esc[90m"
    $Char_HeavyCheck = "[v]"; $Char_RedCross = "[x]"
    
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

    Write-Header "FILE UNBLOCKING"

    if ($Reverse) {
        Write-LeftAligned "$FGRed$Char_RedCross Reverse mode is not supported for Unblocking.$Reset"
        return
    }

    $TargetDir = $PSScriptRoot
    if (-not $TargetDir) { $TargetDir = $PWD.Path }

    Write-LeftAligned "$FGGray Scanning for blocked scripts in: $TargetDir...$Reset"

    try {
        $Files = Get-ChildItem -Path $TargetDir -Filter "*.ps*" -Recurse -ErrorAction SilentlyContinue
        
        if ($Files) {
            foreach ($File in $Files) {
                Unblock-File -Path $File.FullName -ErrorAction SilentlyContinue
            }
            Write-LeftAligned "$FGGreen$Char_HeavyCheck Successfully unblocked $($Files.Count) files.$Reset"
        }
        else {
            Write-LeftAligned "$FGGray No script files found to unblock.$Reset"
        }
    }
    catch {
        Write-LeftAligned "$FGRed$Char_RedCross Failed: $($_.Exception.Message)$Reset"
    }

} @args
