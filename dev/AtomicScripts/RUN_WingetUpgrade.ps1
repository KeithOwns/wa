#Requires -RunAsAdministrator
<#
.SYNOPSIS
    WinGet Application Updater - Extracted from wa.ps1
.DESCRIPTION
    Updates all installed applications using Windows Package Manager (winget).
    Runs silently with automatic acceptance of package agreements.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# --- SHARED FUNCTIONS ---
. "$PSScriptRoot\..\Shared\Shared_UI_Functions.ps1"

Write-Header "WINGET APP UPDATE"

# Check for WinGet
if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
    Write-LeftAligned "$FGRed$Char_Warn WinGet is not installed or not in PATH.$Reset"
    Write-LeftAligned "Please install App Installer from the Microsoft Store."
    Write-Host ""
    Write-Boundary
    Start-Sleep -Seconds 3
    exit
}

Write-LeftAligned "$FGGray Running winget upgrade --all...$Reset"
Write-Host ""

try {
    $wingetArgs = @(
        "upgrade",
        "--all",
        "--include-unknown",
        "--accept-package-agreements",
        "--accept-source-agreements",
        "--silent"
    )
    
    Start-Process "winget.exe" -ArgumentList $wingetArgs -Wait -NoNewWindow
    
    Write-Host ""
    Write-LeftAligned "$FGGreen$Char_HeavyCheck WinGet update completed.$Reset"
}
catch {
    Write-LeftAligned "$FGRed$Char_Warn Update failed: $($_.Exception.Message)$Reset"
}

Write-Host ""
Write-Boundary
Start-Sleep -Seconds 3
