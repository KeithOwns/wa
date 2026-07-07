#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Sets the PowerShell Execution Policy to RemoteSigned.
.DESCRIPTION
    Ensures local scripts can run by setting the policy to 'RemoteSigned' for LocalMachine.
    Standalone version. Includes Reverse Mode.
.PARAMETER Reverse
    (Alias: -r) Reverses the setting (Sets to Restricted).
#>

& {
    param(
        [Parameter(Mandatory = $false)]
        [Alias('r')]
        [switch]$Reverse
    )

    # --- STANDALONE UI & LOGGING RESOURCES ---
    $Esc = [char]0x1B; $Reset = "$Esc[0m"; $Bold = "$Esc[1m"; $FGGreen = "$Esc[92m"; $FGRed = "$Esc[91m"; $FGCyan = "$Esc[96m"; $FGDarkBlue = "$Esc[34m"
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

    Write-Header "EXECUTION POLICY"

    $Policy = if ($Reverse) { "Restricted" } else { "RemoteSigned" }

    try {
        Set-ExecutionPolicy -ExecutionPolicy $Policy -Scope "LocalMachine" -Force -ErrorAction Stop
        Write-LeftAligned "$FGGreen$Char_HeavyCheck Execution Policy set to '$Policy' for LocalMachine.$Reset"
    }
    catch { Write-LeftAligned "$FGRed$Char_RedCross Failed: $($_.Exception.Message)$Reset" }

} @args
