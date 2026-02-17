#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Optimizes all fixed disks (TRIM for SSD, Defrag for HDD).
.DESCRIPTION
    Standardized for WinAuto.
#>

# --- SHARED FUNCTIONS ---
. "$PSScriptRoot\..\Shared\Shared_UI_Functions.ps1"

# --- MAIN ---

Write-Header "DISK OPTIMIZATION"

try {
    $volumes = Get-Volume | Where-Object { $_.DriveLetter -and $_.DriveType -eq 'Fixed' }
    foreach ($v in $volumes) {
        $drive = $v.DriveLetter
        Write-LeftAligned "$FGWhite$Char_HeavyMinus Drive $drive`: $Reset"
        
        $isSSD = $false
        $part = Get-Partition -DriveLetter $drive -ErrorAction SilentlyContinue
        if ($part) {
            $disk = Get-Disk -Number $part.DiskNumber -ErrorAction SilentlyContinue
            if ($disk -and $disk.MediaType -eq 'SSD') { $isSSD = $true }
        }

        if ($isSSD) {
            Write-LeftAligned "  $FGYellow Type: SSD - Running TRIM...$Reset"
            Optimize-Volume -DriveLetter $drive -ReTrim | Out-Null
        } else {
            Write-LeftAligned "  $FGYellow Type: HDD - Running Defrag...$Reset"
            Optimize-Volume -DriveLetter $drive -Defrag | Out-Null
        }
        Write-LeftAligned "  $FGGreen$Char_HeavyCheck Optimization Complete.$Reset"
    }
} catch {
    $errMsg = "$($_.Exception.Message)"
    Write-LeftAligned "$FGRed$Char_RedCross Error: $errMsg$Reset"
    Write-Log "Disk Optimization Error: $errMsg" -Level ERROR
}

Write-Host ""
Write-Boundary $FGDarkBlue
Start-Sleep -Seconds 1
Write-Host ""






