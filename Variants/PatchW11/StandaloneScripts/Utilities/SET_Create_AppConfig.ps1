#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Interactive Application Configuration Generator for WinAuto
.DESCRIPTION
    Helps users create or edit the 'Install_Apps-Config.json' file used by the
    Install_Apps-Configurable.ps1 script.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# --- [USER PREFERENCE] CLEAR SCREEN START ---

# --------------------------------------------

# --- STYLE & FORMATTING CONFIGURATION ---
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Icons
$Char_HeavyLine   = [char]0x2501 # â”
$Char_BallotCheck = [char]0x2611 # â˜‘
$Char_RedCross    = [char]0x274E # âŽ
$Char_Warn        = [char]0x26A0 # âš 
$Char_Finger      = [char]0x261B # â˜›
$Char_Keyboard    = [char]0x2328 # âŒ¨
$Char_Skip        = [char]0x23ED # â­
$Char_HeavyMinus  = [char]0x2796 # âž–
$Char_Eject       = [char]0x23CF # â
$Char_Plus        = [char]0x2795 # âž•
$Char_Minus       = [char]0x2796 # âž–
$Char_Floppy      = [char]::ConvertFromUtf32(0x1F4BE) # ðŸ’¾
$Char_Search      = [char]::ConvertFromUtf32(0x1F50D) # ðŸ”

# Colors
$Esc = [char]0x1B
$Reset = "$Esc[0m"
$Bold = "$Esc[1m"
$FGCyan       = "$Esc[96m"
$FGBlue       = "$Esc[94m"
$FGDarkBlue   = "$Esc[34m"
$FGGreen      = "$Esc[92m"
$FGRed        = "$Esc[91m"
$FGYellow     = "$Esc[93m"
$FGDarkCyan   = "$Esc[36m"
$FGWhite      = "$Esc[97m"
$FGGray       = "$Esc[37m"
$FGDarkGray   = "$Esc[90m"
$FGBlack      = "$Esc[30m"
$BGYellow     = "$Esc[103m"

# Paths
$ConfigPath = "$PSScriptRoot\Install_Apps-Config.json"

# --- Helper Functions ---

function Write-Centered {
    param([string]$Text, [int]$Width = 60)

# --- STANDALONE UI & LOGGING RESOURCES ---
$Esc = [char]0x1B
$Reset = "$Esc[0m"
$Bold = "$Esc[1m"
$FGCyan = "$Esc[96m"; $FGGreen = "$Esc[92m"; $FGRed = "$Esc[91m"; $FGYellow = "$Esc[93m"; $FGWhite = "$Esc[97m"; $FGGray = "$Esc[37m"; $FGDarkGray = "$Esc[90m"; $FGDarkBlue = "$Esc[34m"; $BGYellow = "$Esc[103m"; $FGBlack = "$Esc[30m"
$Char_Warn = [char]0x26A0; $Char_BallotCheck = [char]0x2611; $Char_Keyboard = [char]0x2328; $Char_Loop = [char]::ConvertFromUtf32(0x1F504); $Char_Copyright = [char]0x00A9; $Char_Finger = [char]0x261B; $Char_HeavyCheck = [char]0x2705; $Char_RedCross = [char]0x2716; $Char_HeavyMinus = [char]0x2796; $Char_Skip = [char]0x23ED

function Write-Boundary { param([string]$Color = $FGDarkBlue) Write-Host "$Color$([string]'_' * 60)$Reset" }
function Write-LeftAligned { param([string]$Text, [int]$Indent = 2) Write-Host (" " * $Indent + $Text) }
function Write-Centered { param([string]$Text, [int]$Width = 60) $clean = $Text -replace "\x1B\[[0-9;]*m", ""; $pad = [Math]::Floor(($Width - $clean.Length) / 2); if ($pad -lt 0) { $pad = 0 }; Write-Host (" " * $pad + $Text) }
function Write-Header { param([string]$Title) Clear-Host; Write-Host ""; $t1 = "$([char]::ConvertFromUtf32(0x1FA9F)) WinAuto $Char_Loop"; Write-Centered "$Bold$FGCyan$t1$Reset"; Write-Boundary; Write-Centered "$Bold$FGCyan$($Title.ToUpper())$Reset"; Write-Boundary }
function Invoke-AnimatedPause { param([string]$ActionText = "CONTINUE", [int]$Timeout = 10) Write-Host ""; $top = [Console]::CursorTop; $StopWatch = [System.Diagnostics.Stopwatch]::StartNew(); while ($StopWatch.Elapsed.TotalSeconds -lt $Timeout) { if ([Console]::KeyAvailable) { $StopWatch.Stop(); return $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") }; $Elapsed = $StopWatch.Elapsed; $Filled = [Math]::Floor($Elapsed.TotalSeconds); $Dynamic = ""; for ($i=0;$i-lt 10;$i++) { $c = if ($i -lt 5) { "Enter"[$i] } else { " " }; if ($i -lt $Filled) { $Dynamic += "${BGYellow}${FGBlack}$c${Reset}" } else { $Dynamic += "${FGYellow}$c${Reset}" } }; Write-Centered "${FGWhite}$Char_Keyboard Press ${FGDarkGray}$Dynamic${FGDarkGray}${FGWhite} to ${FGYellow}$ActionText${FGDarkGray} | or SKIP$Char_Skip${Reset}"; try { [Console]::SetCursorPosition(0, $top) } catch {}; Start-Sleep -Milliseconds 100 }; $StopWatch.Stop(); return [PSCustomObject]@{VirtualKeyCode=13} }
function Write-Log { param([string]$Message, [string]$Level = 'INFO') $c = switch($Level){'ERROR'{$FGRed};'WARNING'{$FGYellow};'SUCCESS'{$FGGreen};Default{$FGGray}}; Write-LeftAligned "$c$Message$Reset" }



#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Interactive Application Configuration Generator for WinAuto
.DESCRIPTION
    Helps users create or edit the 'Install_Apps-Config.json' file used by the
    Install_Apps-Configurable.ps1 script.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# --- [USER PREFERENCE] CLEAR SCREEN START ---

# --------------------------------------------

# --- STYLE & FORMATTING CONFIGURATION ---
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Icons
$Char_HeavyLine   = [char]0x2501 # â”
$Char_BallotCheck = [char]0x2611 # â˜‘
$Char_RedCross    = [char]0x274E # âŽ
$Char_Warn        = [char]0x26A0 # âš 
$Char_Finger      = [char]0x261B # â˜›
$Char_Keyboard    = [char]0x2328 # âŒ¨
$Char_Skip        = [char]0x23ED # â­
$Char_HeavyMinus  = [char]0x2796 # âž–
$Char_Eject       = [char]0x23CF # â
$Char_Plus        = [char]0x2795 # âž•
$Char_Minus       = [char]0x2796 # âž–
$Char_Floppy      = [char]::ConvertFromUtf32(0x1F4BE) # ðŸ’¾
$Char_Search      = [char]::ConvertFromUtf32(0x1F50D) # ðŸ”

# Colors
$Esc = [char]0x1B
$Reset = "$Esc[0m"
$Bold = "$Esc[1m"
$FGCyan       = "$Esc[96m"
$FGBlue       = "$Esc[94m"
$FGDarkBlue   = "$Esc[34m"
$FGGreen      = "$Esc[92m"
$FGRed        = "$Esc[91m"
$FGYellow     = "$Esc[93m"
$FGDarkCyan   = "$Esc[36m"
$FGWhite      = "$Esc[97m"
$FGGray       = "$Esc[37m"
$FGDarkGray   = "$Esc[90m"
$FGBlack      = "$Esc[30m"
$BGYellow     = "$Esc[103m"

# Paths
$ConfigPath = "$PSScriptRoot\Install_Apps-Config.json"

# --- Helper Functions ---

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

function Write-Header {
    param([string]$Title)
    Write-Host ""
    $TopTitle = " $Char_HeavyLine WinAuto $Char_HeavyLine "
    Write-Centered "$Bold$FGCyan$TopTitle$Reset"
    Write-Centered "$Bold$FGCyan$Title$Reset"
    Write-Boundary $FGDarkBlue
}

function Write-Boundary {
    param([string]$Color = $FGDarkBlue)
    Write-Host "$Color$([string]$Char_HeavyLine * 60)$Reset"
}

function Read-Input {
    param([string]$Prompt, [bool]$Mandatory = $false)
    while ($true) {
        $input = Read-Host "  $FGGray$Prompt$Reset"
        if (-not [string]::IsNullOrWhiteSpace($input)) {
            return $input
        }
        if (-not $Mandatory) { return $null }
        Write-LeftAligned "$FGRed$Char_RedCross Value required.$Reset"
    }
}

# --- State Management ---
$AppsList = @()

# Load existing logic
if (Test-Path $ConfigPath) {
    try {
        $json = Get-Content $ConfigPath -Raw | ConvertFrom-Json
        if ($json.BaseApps) {
            $AppsList += $json.BaseApps
        }
    } catch {
        Write-LeftAligned "$FGRed$Char_Warn Could not parse existing config.$Reset"
    }
}

# --- App Builder Function ---
function New-AppEntry {
    Write-Host ""
    Write-Boundary $FGDarkGray
    Write-LeftAligned "$FGWhite$Char_Plus ADD NEW APPLICATION$Reset"
    Write-Host ""

    Write-LeftAligned "Step 1: Application Name"
    $name = Read-Input -Prompt "Enter a friendly name (e.g. 'Google Chrome')" -Mandatory $true
    
    Write-Host ""
    Write-LeftAligned "Step 2: Installation Type"
    Write-LeftAligned " ${FGBlack}${BGYellow}[1]${Reset} ${FGGray}Winget (Recommended - Microsoft Store/Package Manager)${Reset}"
    Write-LeftAligned " ${FGBlack}${BGYellow}[2]${Reset} ${FGGray}MSI (Direct Download URL)${Reset}"
    Write-LeftAligned " ${FGBlack}${BGYellow}[3]${Reset} ${FGGray}EXE (Direct Download URL)${Reset}"
    
    $type = "WINGET"
    $typeInput = Read-Input -Prompt "Select Type [1-3]" -Mandatory $true
    switch ($typeInput) {
        '2' { $type = "MSI" }
        '3' { $type = "EXE" }
        Default { $type = "WINGET" }
    }

    $newApp = [ordered]@{
        AppName      = $name
        MatchName    = "*$name*"
        Type         = $type
        CheckMethod  = "Registry"
        InstallOrder = ($AppsList.Count + 1) * 10
    }

    Write-Host ""
    Write-LeftAligned "Step 3: Source Details"

    if ($type -eq 'WINGET') {
        Write-LeftAligned "Do you know the exact Winget ID?"
        Write-LeftAligned " ${FGBlack}${BGYellow}[1]${Reset} ${FGGray}Yes, I'll type it${Reset}"
        Write-LeftAligned " ${FGBlack}${BGYellow}[2]${Reset} ${FGGray}No, help me search for it${Reset}"
        
        $searchMode = Read-Input -Prompt "Select [1-2]"
        $id = $null
        
        if ($searchMode -eq '2') {
            Write-Host ""
            $term = Read-Input -Prompt "Enter search keyword (e.g. 'chrome')" -Mandatory $true
            Write-LeftAligned "$FGYellow$Char_Search Searching Winget...$Reset"
            
            try {
                # Run winget search and output directly to host
                Write-Host "$FGDarkCyan"
                winget search "$term" --accept-source-agreements
                Write-Host "$Reset"
                Write-LeftAligned "$FGGreen$Char_BallotCheck Search complete.$Reset"
                Write-LeftAligned "Copy the 'Id' from the list above."
            } catch {
                Write-LeftAligned "$FGRed$Char_Warn Search failed or Winget not available.$Reset"
            }
            Write-Host ""
        }
        
        $id = Read-Input -Prompt "Enter Winget ID (e.g. 'Google.Chrome')" -Mandatory $true
        $newApp['WingetId'] = $id
        
    } else {
        $url = Read-Input -Prompt "Direct Download URL (http/https)" -Mandatory $true
        $newApp['Url'] = $url
        
        Write-Host ""
        Write-LeftAligned "Silent Arguments (Optional)"
        Write-LeftAligned "Leave empty to use defaults: /quiet /norestart"
        $args = Read-Input -Prompt "Arguments"
        
        if ($args) { $newApp['SilentArgs'] = $args }
        elseif ($type -eq 'MSI') { $newApp['SilentArgs'] = "/qn /norestart" }
        else { $newApp['SilentArgs'] = "/quiet /norestart" }
    }

    return $newApp
}

# --- Main Loop ---
$running = $true
while ($running) {

    Write-Header "CONFIG GENERATOR"
    
    Write-LeftAligned "$FGGray Current List:$Reset"
    if ($AppsList.Count -eq 0) {
        Write-LeftAligned "  (Empty)"
    } else {
        $i = 1
        foreach ($app in $AppsList) {
            $info = if ($app.Type -eq 'WINGET') { $app.WingetId } else { "URL" }
            Write-LeftAligned " ${FGYellow}[$i]${Reset} ${FGWhite}$($app.AppName)$Reset $FGDarkGray($($app.Type): $info)$Reset"
            $i++
        }
    }

    Write-Host ""
    Write-Boundary $FGDarkBlue
    
    $prompt = "${FGWhite}$Char_Keyboard  Press${FGDarkGray} ${FGYellow}$Char_Finger [Key]${FGDarkGray} ${FGWhite}to${FGDarkGray} ${FGYellow}Action${FGWhite}|${FGDarkGray}any other to ${FGWhite}EXIT$Char_Eject${Reset}"
    Write-Centered $prompt
    Write-Centered "${FGYellow}A${FGDarkGray}dd New  |  ${FGYellow}R${FGDarkGray}emove Last  |  ${FGYellow}S${FGDarkGray}ave & Exit"

    $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    $char = $key.Character.ToString().ToUpper()

    if ($char -eq 'A') {
        $entry = New-AppEntry
        $AppsList += $entry
    }
    elseif ($char -eq 'R') {
        if ($AppsList.Count -gt 0) {
            $removed = $AppsList[$AppsList.Count - 1]
            $AppsList = $AppsList[0..($AppsList.Count - 2)]
            Write-Host ""
            Write-LeftAligned "$FGRed$Char_Minus Removed '$($removed.AppName)'$Reset"
            Start-Sleep -Milliseconds 800
        }
    }
    elseif ($char -eq 'S') {
        # Save
        $export = [ordered]@{
            BaseApps = $AppsList
            LaptopApps = @()
        }
        $json = $export | ConvertTo-Json -Depth 3
        Set-Content -Path $ConfigPath -Value $json -Encoding UTF8
        
        Write-Host ""
        Write-LeftAligned "$FGGreen$Char_Floppy Configuration saved to:$Reset"
        Write-LeftAligned "$FGGray $ConfigPath$Reset"
        Write-LeftAligned "$FGGreen Exiting...$Reset"
        Start-Sleep -Seconds 2
        $running = $false
    }
    else {
        $running = $false
        Write-Host ""
        Write-LeftAligned "$FGGray Exiting without saving...$Reset"
        Start-Sleep -Milliseconds 500
    }
}

