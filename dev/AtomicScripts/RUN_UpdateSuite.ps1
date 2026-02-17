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
# --- EMBEDDED SHARED RESOURCES & FUNCTIONS ---

# ANSI Escape Sequences
$Esc = [char]0x1B
$Reset = "$Esc[0m"
$Bold = "$Esc[1m"

# Colors
$FGCyan = "$Esc[96m"
$FGRed = "$Esc[91m"
$FGYellow = "$Esc[93m"
$FGGreen = "$Esc[92m"
$FGGray = "$Esc[37m"
$FGWhite = "$Esc[97m"
$FGBlack = "$Esc[30m"
$FGDarkBlue = "$Esc[34m"
$BGYellow = "$Esc[103m"


# Icons
$Char_Warn = [char]0x26A0
$Char_BallotCheck = [char]0x2611
$Char_Loop = [char]::ConvertFromUtf32(0x1F504)
$Char_Keyboard = [char]0x2328


# UI Functions
function Write-Centered {
    param([string]$Text, [int]$Width = 60)
    $cleanText = $Text -replace "$Esc\[[0-9;]*m", ""
    $padLeft = [Math]::Floor(($Width - $cleanText.Length) / 2)
    if ($padLeft -lt 0) { $padLeft = 0 }
    Write-Host (" " * $padLeft + $Text)
}

function Write-LeftAligned {
    param([string]$Text, [int]$Indent = 2)
    Write-Host (" " * $Indent + $Text)
}

function Write-Boundary {
    param([string]$Color = $FGDarkBlue)
    Write-Host "$Color$([string]'_' * 60)$Reset"
}

function Write-Header {
    param([string]$Title)
    Clear-Host
    Write-Host ""
    
    # Top Title
    $WinAutoTitle = "$([char]::ConvertFromUtf32(0x1FA9F)) WinAuto $Char_Loop"
    $WinAutoPadding = [Math]::Floor((60 - 11) / 2)
    Write-Host (" " * $WinAutoPadding + "$Bold$FGCyan$WinAutoTitle$Reset")
    
    # Sub-Header
    $SubText = $Title.ToUpper()
    $SubPadding = [Math]::Floor((60 - $SubText.Length) / 2)
    Write-Host (" " * $SubPadding + "$Bold$FGCyan$SubText$Reset")
    
    # Separator
    Write-Boundary
}

# Timeout / Pause Logic
$TickAction = {
    param($ElapsedTimespan, $ActionText = "RUN", $Timeout = 10, $PromptCursorTop, $SelectionChar = $null, $PreActionWord = "to")
    if ($null -eq $PromptCursorTop) { $PromptCursorTop = [Console]::CursorTop }

    $PromptStr = "$FGWhite$Char_Keyboard Press ${FGBlack}${BGYellow}[Enter]${Reset}$FGWhite $PreActionWord ${FGYellow}$ActionText${Reset}   $FGWhite| Press ${FGRed}[Esc]${Reset}$FGWhite to ${FGRed}EXIT$Reset"
    
    try { 
        [Console]::SetCursorPosition(0, $PromptCursorTop)
        Write-Host (" " * 80) -NoNewline
        [Console]::SetCursorPosition(0, $PromptCursorTop)
        Write-Centered $PromptStr 
    }
    catch {}
}

function Wait-KeyPressWithTimeout {
    param(
        [int]$Seconds = 10,
        [scriptblock]$OnTick
    )
    $StopWatch = [System.Diagnostics.Stopwatch]::StartNew()
    while ($StopWatch.Elapsed.TotalSeconds -lt $Seconds) {
        if ($OnTick) { & $OnTick $StopWatch.Elapsed }
        if ([Console]::KeyAvailable) {
            $StopWatch.Stop()
            return $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
        Start-Sleep -Milliseconds 100
    }
    $StopWatch.Stop()
    return [PSCustomObject]@{ VirtualKeyCode = 13 } # Default to Enter
}

function Invoke-AnimatedPause {
    param([string]$ActionText = "CONTINUE", [int]$Timeout = 10)
    Write-Host ""
    $PromptCursorTop = [Console]::CursorTop
    
    $LocalTick = {
        param($Elapsed)
        & $TickAction -ElapsedTimespan $Elapsed -ActionText $ActionText -Timeout $Timeout -PromptCursorTop $PromptCursorTop
    }

    $res = Wait-KeyPressWithTimeout -Seconds $Timeout -OnTick $LocalTick
    Write-Host ""
    return $res
}

# --- MAIN ---

Write-Header "SUITE UPDATE"

# --- UPDATE STRATEGY SELECTOR ---

$HasGit = $false
$IsGitRepo = $false

# 1. Check for Git Availability
if (Get-Command git -ErrorAction SilentlyContinue) {
    $HasGit = $true
    # 2. Check if current folder is a repo
    Invoke-Expression "git rev-parse --is-inside-work-tree" -ErrorAction SilentlyContinue | Out-Null
    if ($LASTEXITCODE -eq 0) { $IsGitRepo = $true }
}

if ($HasGit -and $IsGitRepo) {
    # --- STRATEGY A: GIT PULL ---
    try {
        Write-LeftAligned "$FGYellow Git detected. Checking for updates via Git...$Reset"
        $repoRoot = git rev-parse --show-toplevel 2>$null
        Set-Location $repoRoot
        
        # Stash logic
        Write-LeftAligned "$FGGray Preserving local configuration...$Reset"
        $stashOut = git stash 2>&1
        $stashed = ($stashOut -notmatch "No local changes")

        $output = git pull 2>&1
        
        if ($stashed) {
            Write-LeftAligned "$FGGray Restoring local configuration...$Reset"
            git stash pop | Out-Null
        }
        
        if ($output -match "Already up to date") {
            Write-LeftAligned "$FGGreen$Char_BallotCheck System is up to date.$Reset"
        }
        else {
            Write-LeftAligned "$FGGreen$Char_BallotCheck Update successful!$Reset"
            Write-LeftAligned "Log:"
            $output | ForEach-Object { Write-LeftAligned "  $_" }
        }
    }
    catch {
        Write-LeftAligned "$FGRed$Char_Warn Git Update failed: $($_.Exception.Message)$Reset"
        Write-LeftAligned "$FGYellow Falling back to direct download...$Reset"
        $IsGitRepo = $false # Trigger fallback
    }
}

if (-not $IsGitRepo) {
    # --- STRATEGY B: DIRECT ZIP DOWNLOAD ---
    Write-LeftAligned "$FGYellow Git not found/valid. Using Direct Download method...$Reset"
    
    try {
        $ZipUrl = "https://github.com/KeithOwns/wa/archive/refs/heads/main.zip"
        $TempZip = "$env:TEMP\winauto_update.zip"
        $TempExtract = "$env:TEMP\winauto_update_extracted"
        
        # Cleanup Pre-existing
        if (Test-Path $TempZip) { Remove-Item $TempZip -Force }
        if (Test-Path $TempExtract) { Remove-Item $TempExtract -Recurse -Force }
        
        # Download
        Write-LeftAligned "Downloading latest version..."
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $ZipUrl -OutFile $TempZip -UseBasicParsing
        
        # Extract
        Write-LeftAligned "Extracting package..."
        Expand-Archive -Path $TempZip -DestinationPath $TempExtract -Force
        
        # Locate 'dev' folder (Configured for standard repo structure: wa-main/dev)
        $SourceDev = Join-Path $TempExtract "wa-main\dev"
        
        if (-not (Test-Path $SourceDev)) {
            throw "Update package structure mismatch. 'dev' folder not found."
        }
        
        # Define Destination (Suite Root)
        $SuiteRoot = $null
        
        # 1. Try standard script path
        if ($PSScriptRoot) {
            $Check = Join-Path $PSScriptRoot "..\.."
            if (Test-Path (Join-Path $Check "wa.ps1")) {
                $SuiteRoot = Resolve-Path $Check
            }
        }
        
        # 2. Key-based Fallback (Search up from Current Location)
        if (-not $SuiteRoot) {
            $SearchPath = (Get-Location).Path
            for ($i = 0; $i -lt 5; $i++) {
                if (Test-Path (Join-Path $SearchPath "wa.ps1")) {
                    $SuiteRoot = $SearchPath
                    break
                }
                $parent = Split-Path $SearchPath -Parent
                if (-not $parent) { break }
                $SearchPath = $parent
            }
        }
        
        if (-not $SuiteRoot) {
            throw "Could not locate WinAuto installation root (wa.ps1). Please ensure you are running this from the WinAuto folder."
        }
        
        $SuiteRoot = $SuiteRoot.Path 
        Write-LeftAligned "Installing updates to: $SuiteRoot"
        
        # Copy / Overwrite
        Copy-Item -Path "$SourceDev\*" -Destination $SuiteRoot -Recurse -Force
        
        # Cleanup
        Remove-Item $TempZip -Force
        Remove-Item $TempExtract -Recurse -Force
        
        Write-LeftAligned "$FGGreen$Char_BallotCheck Update installed successfully!$Reset"
        Write-LeftAligned "Please restart the suite to apply changes."
    }
    catch {
        Write-LeftAligned "$FGRed$Char_Warn Direct Update failed: $($_.Exception.Message)$Reset"
        Write-LeftAligned "Please manually download the latest version from GitHub."
    }
}

Write-Host ""
Write-Boundary
Invoke-AnimatedPause -Timeout 10
Write-Host ""






