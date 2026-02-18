#Requires -RunAsAdministrator
<#
.SYNOPSIS
    WinAuto PowerShell Script Writing Rules and Visual Examples

.DESCRIPTION
    This script displays visual examples of WinAuto scripting standards by default.
    Includes the latest Script Output DEFAULTS and standardized visual legend.
    This version is STANDALONE and does not require external resource files.

.PARAMETER ShowRules
    Display the complete text-based rules documentation instead of visual examples.

.EXAMPLE
    .\scriptRULES.ps1
    Shows visual examples of formatting standards (default behavior)

.NOTES
    Author: WinAuto Team
    Version: 2.0.0 (Standalone + Updated Defaults)
    Repository: https://github.com/KeithOwns/WinAuto
#>

param(
    [switch]$ShowRules
)

# Set console output encoding to UTF-8
Clear-Host
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# --- STANDALONE RESOURCES (Inlined) ---
$Esc = [char]0x1B
$Reset = "$Esc[0m"
$Bold = "$Esc[1m"

# Script Palette (Foreground)
$Global:FGCyan = "$Esc[96m"
$Global:FGBlue = "$Esc[94m"
$Global:FGDarkBlue = "$Esc[34m"
$Global:FGDarkCyan = "$Esc[36m"
$Global:FGGreen = "$Esc[92m"
$Global:FGRed = "$Esc[91m"
$Global:FGMagenta = "$Esc[95m"
$Global:FGYellow = "$Esc[93m"
$Global:FGWhite = "$Esc[97m"
$Global:FGGray = "$Esc[37m"
$Global:FGDarkGray = "$Esc[90m"
$Global:FGDarkGreen = "$Esc[32m"
$Global:FGDarkRed = "$Esc[31m"
$Global:FGDarkYellow = "$Esc[33m"
$Global:FGBlack = "$Esc[30m"

# Script Palette (Background)
$Global:BGDarkGreen = "$Esc[42m"
$Global:BGDarkGray = "$Esc[100m"
$Global:BGYellow = "$Esc[103m"
$Global:BGRed = "$Esc[101m"
$Global:BGDarkCyan = "$Esc[46m"
$Global:BGWhite = "$Esc[107m"


# Unicode Icons & Characters
$Global:Char_HeavyCheck = "[v]" 
$Global:Char_Warn = "!" 
$Global:Char_Copyright = "(c)" 
$Global:Char_Finger = "->" 
$Global:Char_Keyboard = "[:::]" 
$Global:Char_Skip = ">>" 
$Global:Char_CheckMark = "v" 
$Global:Char_FailureX = "x" 
$Global:Char_HeavyMinus = "-" 
$Global:Char_HeavyLine = "=" 
$Global:Char_LightLine = "_" 
$Global:Char_Overline = "-" 
$Global:Char_EmDash = "-" 
$Global:Char_EnDash = "-"
$Global:Char_BallotCheck = "[v]"
$Global:Char_RedCross = "x" 

# Helper for formatted column output
function Write-Row {
    param($ColorName, $ANSI, $About, $Where, [string]$DefaultString, $ColorCode, [switch]$CenterValue) 

    $CNamePadded = $ColorName.PadLeft(12)
    $ANSIPadded = $ANSI.PadRight(6)
    $AboutPadded = $About.PadRight(6)
    $WherePadded = $Where.PadRight(8)
    
    if ($CenterValue) {
        $RawString = $DefaultString.Trim()
        $PadLeft = [Math]::Floor((16 - $RawString.Length) / 2)
        $DefaultStringPadded = (" " * $PadLeft) + $RawString
    }
    else {
        $DefaultStringPadded = $DefaultString
    }

    $OutputLine = "${ColorCode}${CNamePadded}${Global:Reset} ${ANSIPadded}  ${ColorCode}${AboutPadded}  ${WherePadded}   ${DefaultStringPadded}${Global:Reset}"
    Write-Host $OutputLine
}

function Show-Legend {
    Write-Output "$Global:FGDarkCyan$([string]'_' * 60)$Global:Reset"

    $LegendTitle = "${Global:FGCyan}$Global:Char_HeavyLine Script Output LEGEND $Global:Char_HeavyLine$Global:Reset"    
    $LegendTitlePadding = 18
    Write-Output (" " * $LegendTitlePadding + $LegendTitle)

    Write-Output ""
    Write-Output "       Color ANSI    About   Where       Default_String"
    Write-Output "$FGDarkGray$([string]'_' * 60)$Reset"

    # --- ROW DATA ---
    Write-Row "White" "\e[97m" "BOLD" "Body" "..." $Global:FGWhite -CenterValue
    Write-Row "Gray" "\e[37m" "normal" "Body" "-" $Global:FGGray -CenterValue

    $CyanDefaultString = " WinAuto"
    Write-Row "Cyan" "\e[96m" "Script" "Hdr/Ftr" $CyanDefaultString $Global:FGCyan -CenterValue
    
    $GreenDefaultString = " $Global:Char_CheckMark Success!"
    Write-Row "Green" "\e[92m" "Script" "Output" $GreenDefaultString $Global:FGGreen

    $RedDefaultString = " $Global:Char_FailureX Failure!"
    Write-Row "Red" "\e[91m" "Script" "Output" $RedDefaultString $Global:FGRed
    
    $YellowContent = "  $Global:Char_Finger [Key]"
    Write-Row "Yellow" "\e[93m" "Script" "Input" $YellowContent $Global:FGYellow

    Write-Row "DarkCyan" "\e[36m" "Script" "Lines" "$([string]'_' * 18)" $Global:FGDarkCyan
    Write-Row "DarkGray" "\e[90m" "System" "Lines" "$([string]'_' * 18)" $Global:FGDarkGray
    
    Write-Row "DarkGreen" "\e[32m" "System" "Output" " $Global:Char_HeavyCheck ENABLED" $Global:FGDarkGreen
    Write-Row "DarkRed" "\e[31m" "System" "Output" " [x] DISABLED" $Global:FGDarkRed
}

function Show-FormattingRules {
    Write-Output ""
    Write-Output "$FGDarkCyan$([string]'_' * 60)$Reset"
    
    $DefaultsTitle = "${Global:FGCyan}$Global:Char_HeavyLine Script Output DEFAULTS $Global:Char_HeavyLine$Global:Reset"
    $FormattingTitlePadding = 17
    Write-Output (" " * $FormattingTitlePadding + $DefaultsTitle)
    
    Write-Output ""
    Write-Output "  ${FGWhite}A. Development Standards:$Reset"
    Write-Output "     ${Global:FGGray}1. File Encoding: Must be UTF-8 with BOM.$Reset"
    Write-Output "     ${Global:FGGray}2. Admin: Manual check (iex compat). No #Requires.$Reset"
    Write-Output "     ${Global:FGGray}3. Display Width: Optimized for 60 characters.$Reset"
    Write-Output "     ${Global:FGGray}4. Lines: Use (U+005F * 60).$Reset"
    
    Write-Output ""
    Write-Output "  ${FGWhite}B. Text & UI Formatting:$Reset"
    Write-Output "     ${Global:FGGray}1. Headers: Cyan text only.$Reset"
    Write-Output "     ${Global:FGGray}2. Info Text: Use `$Global:FGGray for non-status text.$Reset"
    Write-Output "     ${Global:FGGray}3. Body: Left-aligned with 2-space indentation.$Reset"
    Write-Output "     ${Global:FGGray}4. Status: Use Write-FlexLine for alignment.$Reset"
    Write-Output "     ${Global:FGGray}5. Active: Use `$Global:BGDarkGreen for highlighting.$Reset"
    Write-Output "     ${Global:FGGray}6. Footer: Cyan, Copyright (c) YYYY WinAuto.$Reset"
    
    Write-Output ""
    Write-Output "  ${Global:FGWhite}C. Interactive Logic:$Reset"
    Write-Output "     ${Global:FGGray}1. Prompts: Include 10s timeout & safe default.$Reset"
    Write-Output "     ${Global:FGGray}2. Flow: [Enter] to Expand, other keys to SKIP.$Reset"
    Write-Output ""
    Write-Output ""
    Write-Output "  ${Global:FGWhite}D. Execution Standards:$Reset"
    Write-Output "     ${Global:FGGray}1. Portable: Scripts must be copy-pasteable into console.$Reset"
    Write-Output "     ${Global:FGGray}2. Atomic Modularity: Standalone scripts.$Reset"
    Write-Output "     ${Global:FGGray}3. Embedded: Atomic scripts use global helpers (no standalone wrapper).$Reset"
    Write-Output "     ${Global:FGGray}4. Undo Info: Use `[Alias('r')][switch]$Reverse` for reversion.$Reset"
    Write-Output ""
}

function Show-VisualExamples {
    param(
        [bool]$ShowFormattingRules = $false
    )

    Clear-Host
    Write-Output ""

    # --- TOP TITLE ---
    $WinAutoTitle = "WinAuto"
    $WinAutoPadding = [Math]::Floor((60 - $WinAutoTitle.Length) / 2)
    Write-Output (" " * $WinAutoPadding + "$Global:Bold$Global:FGCyan$WinAutoTitle$Global:Reset")
    
    $SubText = "SCRIPT OUTPUT RULES" 
    $SubPadding = [Math]::Floor((60 - $SubText.Length) / 2)
    Write-Output (" " * $SubPadding + "$Global:Bold$Global:FGCyan$SubText$Global:Reset")

    # --- PART 1: SCRIPT OUTPUT LEGEND ---
    Show-Legend

    # --- PART 2: SCRIPT OUTPUT DEFAULTS ---
    if ($ShowFormattingRules) {
        Show-FormattingRules
    }
}

# Standard Footer Block
$PrintFooter = {
    Write-Output "$Global:FGDarkCyan$([string]'_' * 60)$Global:Reset"
    $FooterText = "Copyright (c) 2026 WinAuto"
    $FooterPadding = [Math]::Floor((60 - $FooterText.Length) / 2)
    Write-Host (" " * $FooterPadding + $FooterText) -ForegroundColor Cyan
}

Show-VisualExamples -ShowFormattingRules $true
& $PrintFooter
