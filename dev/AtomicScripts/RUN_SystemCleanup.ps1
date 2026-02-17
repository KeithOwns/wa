#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Performs System & User Temp Cleanup.
.DESCRIPTION
    Standardized for WinAuto. Removes files from Temp folders.
#>

# --- SHARED FUNCTIONS ---
. "$PSScriptRoot\..\Shared\Shared_UI_Functions.ps1"

# --- MAIN ---

Write-Header "SYSTEM CLEANUP"

try {
    $paths = @("$env:TEMP", "$env:WINDIR\Temp")
    $total = 0

    foreach ($p in $paths) {
        if (Test-Path $p) {
            Write-LeftAligned "$FGWhite$Char_HeavyMinus Cleaning: $p$Reset"
            try {
                $items = Get-ChildItem -Path $p -Recurse -Force -ErrorAction SilentlyContinue
                if ($items) {
                    $c = @($items).Count
                    $items | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
                    Write-LeftAligned "  $FGGreen$Char_BallotCheck Removed $c items.$Reset"
                    $total += $c
                } else {
                    Write-LeftAligned "  $FGGray Already empty.$Reset"
                }
            } catch {
                Write-LeftAligned "  $FGRed$Char_Warn Partial cleanup failure.$Reset"
                Write-Log "Partial cleanup failure for $p - $($_.Exception.Message)" -Level WARNING
            }
        }
    }
    
    Write-Host ""
    Write-LeftAligned "$FGGreen$Char_HeavyCheck Cleanup Complete. Total items removed: $total$Reset"

} catch {
    $errMsg = "$($_.Exception.Message)"
    Write-LeftAligned "$FGRed$Char_RedCross Error: $errMsg$Reset"
    Write-Log "System Cleanup Critical Error: $errMsg" -Level ERROR
}

Write-Host ""
Write-Boundary $FGDarkBlue
Start-Sleep -Seconds 1
Write-Host ""






