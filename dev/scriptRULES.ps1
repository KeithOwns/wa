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
$FGCyan = "$Esc[96m"
$FGBlue = "$Esc[94m"
$FGDarkBlue = "$Esc[34m"
$FGGreen = "$Esc[92m"
$FGRed = "$Esc[91m"
$FGMagenta = "$Esc[95m"
$FGYellow = "$Esc[93m"
$FGWhite = "$Esc[97m"
$FGGray = "$Esc[37m"
$FGDarkGray = "$Esc[90m"
$FGDarkGreen = "$Esc[32m"
$FGDarkRed = "$Esc[31m"
$FGDarkYellow = "$Esc[33m"
$FGBlack = "$Esc[30m"

# Script Palette (Background)
$BGDarkGreen = "$Esc[42m"
$BGDarkGray = "$Esc[100m"
$BGYellow = "$Esc[103m"
$BGRed = "$Esc[101m"

# Unicode Icons & Characters
$Char_HeavyCheck = "[v]" 
$Char_Warn = [char]0x26A0 
$Char_Copyright = "(c)" 
$Char_Finger = "->" 
$Char_Keyboard = "[:::]" 
$Char_Skip = ">>" 
$Char_CheckMark = "v" 
$Char_FailureX = "x" 
$Char_HeavyMinus = [char]0x2796 
$Char_HeavyLine = "=" 
$Char_LightLine = "_" 
$Char_Overline = "-" 
$Char_EmDash = [char]0x2014 

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

    $OutputLine = "${ColorCode}${CNamePadded}${Reset} ${ANSIPadded}  ${ColorCode}${AboutPadded}  ${WherePadded}   ${DefaultStringPadded}${Reset}"
    Write-Host $OutputLine
}

function Show-Legend {
    Write-Output "$FGDarkBlue$([string]'_' * 56)$Reset"

    $LegendTitle = "${FGCyan}$Char_HeavyLine Script Output LEGEND $Char_HeavyLine$Reset"    
    $LegendTitlePadding = 16
    Write-Output (" " * $LegendTitlePadding + $LegendTitle)

    Write-Output ""
    Write-Output "       Color ANSI    About   Where       Default_String"
    Write-Output "$FGDarkGray$([string]'_' * 56)$Reset"

    # --- ROW DATA ---
    Write-Row "White" "\e[97m" "BOLD" "Body" "..." $FGWhite -CenterValue
    Write-Row "Gray" "\e[37m" "normal" "Body" "-" $FGGray -CenterValue

    $CyanDefaultString = " WinAuto"
    Write-Row "Cyan" "\e[96m" "Script" "Hdr/Ftr" $CyanDefaultString $FGCyan -CenterValue
    
    $GreenDefaultString = " $Char_CheckMark Success!"
    Write-Row "Green" "\e[92m" "Script" "Output" $GreenDefaultString $FGGreen

    $RedDefaultString = " $Char_FailureX Failure!"
    Write-Row "Red" "\e[91m" "Script" "Output" $RedDefaultString $FGRed
    
    $YellowContent = "  $Char_Finger [Key]"
    Write-Row "Yellow" "\e[93m" "Script" "Input" $YellowContent $FGYellow

    Write-Row "DarkBlue" "\e[34m" "Script" "Lines" "$([string]'_' * 15)" $FGDarkBlue
    Write-Row "DarkGray" "\e[90m" "System" "Lines" "$([string]'_' * 15)" $FGDarkGray
    
    Write-Row "DarkGreen" "\e[32m" "System" "Output" " $Char_HeavyCheck ENABLED" $FGDarkGreen
    Write-Row "DarkRed" "\e[31m" "System" "Output" " [x] DISABLED" $FGDarkRed
}

function Show-FormattingRules {
    Write-Output ""
    Write-Output "$FGDarkBlue$([string]'_' * 56)$Reset"
    
    $DefaultsTitle = "${FGCyan}$Char_HeavyLine Script Output DEFAULTS $Char_HeavyLine$Reset"
    $FormattingTitlePadding = 15
    Write-Output (" " * $FormattingTitlePadding + $DefaultsTitle)
    
    Write-Output ""
    Write-Output "  ${FGWhite}A. Development Standards:$Reset"
    Write-Output "     ${FGGray}1. File Encoding: Must be UTF-8 with BOM.$Reset"
    Write-Output "     ${FGGray}2. Admin: Include #Requires -RunAsAdministrator.$Reset"
    Write-Output "     ${FGGray}3. Display Width: Optimized for 56 characters.$Reset"
    Write-Output "     ${FGGray}4. Lines: Use (U+005F * 56).$Reset"
    
    Write-Output ""
    Write-Output "  ${FGWhite}B. Text & UI Formatting:$Reset"
    Write-Output "     ${FGGray}1. Headers: Cyan text only.$Reset"
    Write-Output "     ${FGGray}2. Info Text: Use `$FGGray for non-status text.$Reset"
    Write-Output "     ${FGGray}3. Body: Left-aligned with 2-space indentation.$Reset"
    Write-Output "     ${FGGray}4. Status: Use Write-FlexLine for alignment.$Reset"
    Write-Output "     ${FGGray}5. Active: Use `$BGDarkGreen for highlighting.$Reset"
    Write-Output "     ${FGGray}6. Footer: Cyan, (c) YYYY www.AIIT.support.$Reset"
    
    Write-Output ""
    Write-Output "  ${FGWhite}C. Interactive Logic:$Reset"
    Write-Output "     ${FGGray}1. Prompts: Include 10s timeout & safe default.$Reset"
    Write-Output "     ${FGGray}2. Flow: [Enter] to Expand, other keys to SKIP.$Reset"
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
    $WinAutoPadding = [Math]::Floor((56 - $WinAutoTitle.Length) / 2)
    Write-Output (" " * $WinAutoPadding + "$Bold$FGCyan$WinAutoTitle$Reset")
    
    $SubText = "SCRIPT OUTPUT RULES" 
    $SubPadding = [Math]::Floor((56 - $SubText.Length) / 2)
    Write-Output (" " * $SubPadding + "$Bold$FGCyan$SubText$Reset")

    # --- PART 1: SCRIPT OUTPUT LEGEND ---
    Show-Legend

    # --- PART 2: SCRIPT OUTPUT DEFAULTS ---
    if ($ShowFormattingRules) {
        Show-FormattingRules
    }
}

# Standard Footer Block
$PrintFooter = {
    Write-Output "$FGDarkBlue$([string]'_' * 56)$Reset"
    $FooterText = "$Char_Copyright 2026 www.AIIT.support"
    $FooterPadding = [Math]::Floor((56 - $FooterText.Length) / 2)
    Write-Host (" " * $FooterPadding + $FooterText) -ForegroundColor Cyan
}

Show-VisualExamples -ShowFormattingRules $true
& $PrintFooter
