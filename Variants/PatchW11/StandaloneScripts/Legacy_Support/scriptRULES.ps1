#Requires -RunAsAdministrator
<#
.SYNOPSIS
    WinAuto PowerShell Script Writing Rules and Visual Examples

.DESCRIPTION
    This script displays visual examples of WinAuto scripting standards by default.
    Includes the latest Script Output DEFAULTS and standardized visual legend.
    This version is STANDALONE and inlines the standard WinAuto UI helper functions.

.PARAMETER ShowRules
    Display the complete text-based rules documentation instead of visual examples.

.EXAMPLE
    .\scriptRULES.ps1
    Shows visual examples of formatting standards (default behavior)

.NOTES
    Author: WinAuto Team
    Version: 2.1.0 (Standardized Output)
    Repository: https://github.com/KeithOwns/WinAuto
#>

param(
    [switch]$ShowRules
)

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



# --- LOGIC ---

function Show-Legend {
    Write-Centered "$FGCyan$Char_Hyphen Script Output LEGEND $Char_Hyphen$Reset"
    Write-Host ""

    # Header/Footer
    Write-LeftAligned "Header/Footer : $FGCyan WinAuto (Cyan)$Reset" 6
    Write-LeftAligned "Boundary      : $FGDarkBlue $([string]'_'*15)$Reset" 6

    # Status Types
    Write-LeftAligned "Success       : $FGGreen$Char_CheckMark Action Completed$Reset" 6
    Write-LeftAligned "Failure       : $FGRed$Char_RedCross Action Failed$Reset" 6
    Write-LeftAligned "Warning       : $FGDarkYellow$Char_Warn Warning Message$Reset" 6
    Write-LeftAligned "Input Request : $FGYellow$Char_Finger Press [Key]$Reset" 6
    
    Write-LeftAligned "Active Item   : $FGGray$Char_HeavyCheck Enabled Feature$Reset" 6
    Write-LeftAligned "Inactive Item : $FGDarkGray[ ] Disabled Feature$Reset" 6
}

function Show-FormattingRules {
    Write-Host ""
    Write-Boundary
    Write-Centered "$FGCyan$Char_Hyphen Script Output DEFAULTS $Char_Hyphen$Reset"
    Write-Host ""
    
    Write-BodyTitle "A. Development Standards"
    Write-LeftAligned "${FGGray}1. Encoding: UTF-8 with BOM.$Reset" 5
    Write-LeftAligned "${FGGray}2. Admin: Include #Requires -RunAsAdministrator.$Reset" 5
    Write-LeftAligned "${FGGray}3. Width: 60 (Center) / 56 (Boundary)$Reset" 5
    Write-LeftAligned "${FGGray}4. Safe Chars: Use only standard encoding chars.$Reset" 5
    
    Write-Host ""
    Write-BodyTitle "B. Text & UI Formatting"
    Write-LeftAligned "${FGGray}1. General: No split words. Left-align (2-space).$Reset" 5
    Write-LeftAligned "${FGGray}2. Headers: Cyan text only.$Reset" 5
    Write-LeftAligned "3. Indent Body text: 2 spaces. Legend: 6 spaces."
    Write-LeftAligned "4. Section Titles: Left-Aligned."
    Write-LeftAligned "5. Status: Active (Green BG), Inactive (D.Gray)."
    
    Write-Host ""
    Write-Centered "${FGCyan}- C. Dashboard & Menu Layout -${Reset}"
    Write-Host ""
    
    Write-LeftAligned "1. Indentation: Menu items indent 2 spaces."
    Write-LeftAligned "2. Numbering: `'1.Name`' (No space after dot)."
    Write-LeftAligned "3. Grid: Use DarkBlue `|` pipes for boundaries."
    Write-LeftAligned "4. Spacing: Pad bottoms; tight headers."

    Write-Host ""
    Write-Centered "${FGCyan}- D. Window Behavior -${Reset}"
    Write-Host ""
    
    Write-LeftAligned "1. Snap: Start @ 60 cols, Snap Top-Right."
    
    Write-Host ""
    Write-BodyTitle "E. Interactive Logic"
    Write-LeftAligned "${FGGray}1. Prompts: Include 10s timeout & safe default.$Reset" 5
}

function Show-VisualExamples {
    param(
        [bool]$ShowFormattingRules = $false
    )

    Write-Header "Script Output RULES"

    # --- PART 1: SCRIPT OUTPUT LEGEND ---
    Show-Legend

    # --- PART 2: SCRIPT OUTPUT DEFAULTS ---
    if ($ShowFormattingRules) {
        Show-FormattingRules
    }
}

Show-VisualExamples -ShowFormattingRules $true
Write-Footer
