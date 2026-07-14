#Requires -RunAsAdministrator
<#
.SYNOPSIS
    WinAuto Self-Updater
.DESCRIPTION
    Updates the WinAuto suite by pulling the latest changes from the Git repository.
    Requires 'git' to be installed and the folder to be a valid repo.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# --- SHARED FUNCTIONS ---
. "$PSScriptRoot\..\Shared\Shared_UI_Functions.ps1"

# --- MAIN ---

Write-Header "SUITE UPDATE"

# Check for Git
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-LeftAligned "$FGRed$Char_Warn Git is not installed or not in PATH.$Reset"
    Write-LeftAligned "Please install Git to use this feature."
    Invoke-AnimatedPause -Timeout 10
    exit
}

# Check Repo
if (-not (Test-Path "$PSScriptRoot\..\..\.git")) {
    # PSScriptRoot is scripts\Main -> ..\ is scripts -> ..\..\ is Root
    Write-LeftAligned "$FGRed$Char_Warn This folder does not appear to be a Git repository.$Reset"
    Invoke-AnimatedPause -Timeout 10
    exit
}

try {
    Write-LeftAligned "$FGYellow Checking for updates...$Reset"
    $repoRoot = (Get-Item "$PSScriptRoot\..\..").FullName
    Set-Location $repoRoot
    
    # Stash local changes (preserve config)
    Write-LeftAligned "$FGGray Preserving local configuration...$Reset"
    $stashOut = git stash 2>&1
    $stashed = $false
    if ($stashOut -notmatch "No local changes") { $stashed = $true }

    # Run pull
    $output = git pull 2>&1
    
    # Restore changes
    if ($stashed) {
        Write-LeftAligned "$FGGray Restoring local configuration...$Reset"
        git stash pop | Out-Null
    }
    
    if ($output -match "Already up to date") {
        Write-LeftAligned "$FGGreen$Char_BallotCheck You are already running the latest version.$Reset"
    } else {
        Write-LeftAligned "$FGGreen$Char_BallotCheck Update successful!$Reset"
        Write-LeftAligned "Log:"
        $output | ForEach-Object { Write-LeftAligned "  $_" }
    }
} catch {
    Write-LeftAligned "$FGRed$Char_Warn Update failed: $($_.Exception.Message)$Reset"
}

Write-Host ""
Write-Boundary
Invoke-AnimatedPause -Timeout 10
Write-Host ""






