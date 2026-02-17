#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Windows System File Integrity & Repair Tool (SFC/DISM)
.DESCRIPTION
    Automated flow to check and repair Windows system files using SFC and DISM.
    Follows WinAuto visual standards.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# --- SHARED FUNCTIONS ---
. "$PSScriptRoot\..\Shared\Shared_UI_Functions.ps1"

# --- LOGIC ---

function Invoke-SFCScan {
    Write-Host ""
    Write-LeftAligned "$Bold$FGWhite$Char_HeavyMinus System File Checker (SFC)$Reset"
    Write-LeftAligned "$FGGray Initializing sfc /scannow...$Reset"
    
    try {
        $rawOutput = & sfc /scannow 2>&1
        $sfcOutput = ($rawOutput -join " ") -replace '[^\x20-\x7E]', '' # Keep only printable ASCII
        Write-Host ""
        
        if ($sfcOutput -match "did not find any integrity violations") {
            Write-LeftAligned "$FGGreen$Char_BallotCheck System files are healthy.$Reset"
            return "SUCCESS"
        }
        elseif ($sfcOutput -match "found corrupt files and successfully repaired them") {
            Write-LeftAligned "$FGGreen$Char_BallotCheck Corrupt files were found and repaired.$Reset"
            return "REPAIRED"
        }
        elseif ($sfcOutput -match "found corrupt files but was unable to fix some of them") {
            Write-LeftAligned "$FGRed$Char_RedCross SFC found unfixable corruption.$Reset"
            return "FAILED"
        }
        else {
            Write-LeftAligned "$FGDarkMagenta$Char_Warn SFC completed with unknown status.$Reset"
            Write-Log "SFC completed with unknown status." -Level WARNING
            return "UNKNOWN"
        }
    } catch {
        $errMsg = "$($_.Exception.Message)"
        Write-LeftAligned "$FGRed$Char_RedCross SFC execution error: $errMsg$Reset"
        Write-Log "SFC execution error: $errMsg" -Level ERROR
        return "ERROR"
    }
}

function Invoke-DISMRepair {
    Write-Host ""
    Write-LeftAligned "$Bold$FGWhite$Char_HeavyMinus Deployment Image Servicing (DISM)$Reset"
    Write-LeftAligned "$FGYellow Starting online image repair...$Reset"
    Write-LeftAligned "$FGGray This may take several minutes.$Reset"
    
    try {
        $dismOutput = & DISM /Online /Cleanup-Image /RestoreHealth 2>&1 | Out-String
        
        if ($dismOutput -match "The restore operation completed successfully") {
            Write-LeftAligned "$FGGreen$Char_BallotCheck DISM repair completed successfully.$Reset"
            return $true
        } else {
            Write-LeftAligned "$FGRed$Char_RedCross DISM repair failed.$Reset"
            Write-Log "DISM repair failed. Output: $dismOutput" -Level ERROR
            return $false
        }
    } catch {
        $errMsg = "$($_.Exception.Message)"
        Write-LeftAligned "$FGRed$Char_RedCross DISM execution error: $errMsg$Reset"
        Write-Log "DISM execution error: $errMsg" -Level ERROR
        return $false
    }
}

# --- MAIN FLOW ---
Write-Header "SYSTEM REPAIR FLOW"

$result = Invoke-SFCScan

if ($result -eq "FAILED") {
    Write-Host ""
    Write-LeftAligned "$FGYellow Triggering DISM Repair to fix underlying component store...$Reset"
    $dismSuccess = Invoke-DISMRepair
    
    if ($dismSuccess) {
        Write-Host ""
        Write-LeftAligned "$FGYellow Re-running SFC to verify repairs...$Reset"
        Invoke-SFCScan | Out-Null
    }
}

Write-Host ""
Write-Boundary
Write-Centered "$FGGreen REPAIR FLOW COMPLETE $Reset"
Write-Boundary

Invoke-AnimatedPause -Timeout 10
Write-Host ""





