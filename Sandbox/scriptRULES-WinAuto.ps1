#Requires -RunAsAdministrator
<#
.SYNOPSIS
    WinAuto PowerShell Script Writing Rules and Visual Examples

.DESCRIPTION
    This script displays visual examples of WinAuto scripting standards by default.
    Use the -ShowRules parameter to view the complete text-based rule documentation.

.PARAMETER ShowRules
    Display the complete text-based rules documentation instead of visual examples.

.EXAMPLE
    .\scriptRULES-WinAuto.ps1
    Shows visual examples of formatting standards (default behavior)

.NOTES
    Author: WinAuto Team
    Version: 1.0.0
    Repository: https://github.com/KeithOwns/WinAuto
#>

param(
    [switch]$ShowRules
)

# Set console output encoding to UTF-8
Clear-Host
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# --- LOAD SHARED RESOURCES ---
$ResourcePath = "$PSScriptRoot\scripts\Shared\Global_Resources.ps1"
if (Test-Path $ResourcePath) {
    . $ResourcePath
} else {
    Write-Warning "Global_Resources.ps1 not found at $ResourcePath. Some icons/colors may be missing."
}

# Helper for formatted column output
function Write-Row {
    param($ColorName, $ANSI, $About, $Where, [string]$DefaultString, $ColorCode) 

    $Width_TextColor   = 14
    $CNamePadded = $ColorName.PadLeft($Width_TextColor)
    
    $About = $About.Trim()
    $Where = $Where.Trim()

    $TabAfterWhere = "`t"
    if ($Where -eq "Body") { $TabAfterWhere = "`t`t" }

    $OutputLine = "${ColorCode}${CNamePadded}${Reset} ${ANSI}  ${ColorCode}$About`t$Where$TabAfterWhere${DefaultString}${Reset}"
    Write-Host $OutputLine
}

function Show-Legend {
    Write-Output "$FGDarkBlue$([string]'_' * 60)$Reset"

    $LegendTitle = "${FGCyan}$Char_HeavyLine Script Output LEGEND $Char_HeavyLine$Reset"    
    $LegendTitlePadding = 18
    Write-Output (" " * $LegendTitlePadding + $LegendTitle)

    Write-Output ""
    Write-Output "`t Color ANSI`tAbout`tWhere`tDefault_String"
    Write-Output "$FGDarkGray$([string]$Char_Overline * 60)$Reset"

    # --- ROW DATA ---
    Write-Row "White" "\e[97m" "BOLD" "Body" $Char_HeavyLine $FGWhite
    Write-Row "Gray" "\e[37m" "normal" "Body" "-" $FGGray

    $CyanDefaultString = " $Char_Window WinAuto $Char_Loop"
    Write-Row "Cyan" "\e[96m" "Script" "Hdr/Ftr" $CyanDefaultString $FGCyan
    
    $GreenDefaultString = " $Char_CheckMark Success!"
    Write-Row "Green" "\e[92m" "Script" "Output" $GreenDefaultString $FGGreen

    $RedDefaultString = " $Char_FailureX Failure!"
    Write-Row "Red" "\e[91m" "Script" "Output" $RedDefaultString $FGRed
    
    $YellowContent = "  $Char_Finger [Key]"
    Write-Row "Yellow" "\e[93m" "Script" "Input" $YellowContent $FGYellow

    Write-Row "DarkBlue" "\e[34m" "Script" "Lines" "$([string]$Char_LightLine * 15)" $FGDarkBlue
    Write-Row "DarkGray" "\e[90m" "System" "Lines" "$([string]$Char_LightLine * 15)" $FGDarkGray
    
    Write-Row "DarkGreen" "\e[32m" "System" "Output" " $Char_HeavyCheck ENABLED" $FGDarkGreen
    Write-Row "DarkRed" "\e[31m" "System" "Output" " $([char]0x274E) DISABLED" $FGDarkRed
    Write-Row "DarkYellow" "\e[33m" "System" "Output" " $Char_Warn  WARNING" $FGDarkYellow
}

function Show-FormattingRules {
    Write-Output ""
    Write-Output "$FGDarkBlue$([string]'_' * 60)$Reset"
    
    $DefaultsTitle = "${FGCyan}$Char_HeavyLine Script Output FORMATTING $Char_HeavyLine$Reset"
    $FormattingTitlePadding = 16
    Write-Output (" " * $FormattingTitlePadding + $DefaultsTitle)
    
    Write-Output ""
    Write-Output "  ${FGWhite}A. Text Formatting:$Reset"
    Write-Output "     ${FGGray}1. Never split whole words over multiple lines.$Reset"
    Write-Output "     ${FGGray}2. Default alignment: Center-align$Reset"
    Write-Output "     ${FGGray}3. Body Alignment: Left-align; 2 space indentation$Reset"
    Write-Output "     ${FGGray}4. Boundaries composed of (`"$Char_EmDash`" * 60)$Reset"
    Write-Output "     ${FGGray}5. Optimize output for window 60 characters in width$Reset"
    Write-Output "     ${FGGray}6. Structured Status Display (Write-FlexLine):$Reset"
    Write-Output "         Highlight positive status states (Active/On) using$Reset"
    Write-Output "         a background color (e.g., `$BGDarkGreen).$Reset"
    Write-Output "     ${FGGray}7. Always use `$FGGray for informational text that is $Reset"
    Write-Output "         not a status or title.$Reset"
    Write-Output "     ${FGGray}8. Interactive Prompts:$Reset"
    Write-Output "         Must include a timeout (default 10s) and a safe$Reset"
    Write-Output "         default action to enable unattended execution.$Reset"
    Write-Output ""
}

function Show-LinesInUse {
    Write-Output "$FGDarkBlue$([string]'_' * 60)$Reset"
    $LinesTitle = "${FGCyan}$Char_HeavyLine Script Output Lines IN-USE $Char_HeavyLine$Reset"
    $LinesTitlePadding = [Math]::Floor((60 - 28) / 2)
    Write-Output (" " * $LinesTitlePadding + $LinesTitle)
    Write-Output ""

    $w1 = 7
    $RepCount = 8 
    $HorizontalChars = @(0x005F, 0x203E, 0x2500, 0x2550, 0x2580, 0x2584, 0x2588)

    Write-Output "  $FGCyan[ LINE & BLOCK CHARACTERS - 50x Grayscale ]$Reset"
    foreach ($hex in $HorizontalChars) {
        $char = [char]$hex
        $code = "U+{0:X4}" -f $hex
        if ($hex -eq 0x2588) {
            $FullLine = "${FGDarkYellow}   33   ${FGWhite}   97   ${FGGray}   37   ${FGDarkGray}   90   ${Reset}${FGBlack}   30   ${Reset}${FGBlack}${BGWhite} 30;47  ${Reset}"
        } else {
            $FullLine = "$FGDarkYellow$([string]$char * $RepCount)$FGWhite$([string]$char * $RepCount)$FGGray$([string]$char * $RepCount)$FGDarkGray$([string]$char * $RepCount)$Reset$FGBlack$([string]$char * $RepCount)$Reset$FGBlack$BGWhite$([string]$char * $RepCount)$Reset"
        }
        Write-Output "  $($code.PadRight($w1)) $FullLine"
    }
}

function Show-CharactersUsed {

    Write-Output "$FGDarkBlue$([string]'_' * 60)$Reset"

    $ExtraTitle = "${FGCyan}$Char_HeavyLine Script Output Characters USED $Char_HeavyLine$Reset"

    $ExtraTitlePadding = [Math]::Floor((60 - 34) / 2)

    Write-Output (" " * $ExtraTitlePadding + $ExtraTitle)

    Write-Output ""

    

    Write-Output "  ${FGWhite}Characters IN-USE$Reset"
    Write-Output ("  0x1FA9F: $([char]::ConvertFromUtf32(0x1FA9F))  0x1F504: $([char]::ConvertFromUtf32(0x1F504))  0x2501 : $([char]0x2501)    0x2500 : $Char_LightLine")
    Write-Output ("  0x2796 : $Char_HeavyMinus  0x2713 : $([char]0x2713)   0x2705 : $([char]0x2705)   0x274E : $([char]0x274E)")
    Write-Output ("  0x274C : $([char]0x274C)  0x26A0 : $([char]0x26A0)   0x261B : $([char]0x261B)    0x2328 : $Char_Keyboard")
    Write-Output ("  0x23ED : $Char_Skip   0x23CF : $([char]0x23CF)")

    Write-Output ""

        Write-Output "  ${FGWhite}Available Characters :$Reset"

        Write-Output ("  0x2699 : $Char_Gear   0x2B50 : $([char]0x2B50)  0x1F514: $Char_Bell  0x1F6E1: $Char_Shield")

        Write-Output ("  0x1F464: $Char_User  0x1F4E1: $Char_Satellite  0x1F5C2: $Char_CardIndex  0x1F5A5: $Char_Desktop")

        Write-Output ("  0x1F4E2: $Char_Speaker  0x23F1 : $([char]0x23F1)   0x26AB : $Char_BlackCircle   0x1F518: $([char]::ConvertFromUtf32(0x1F518))")

        Write-Output ("  0x00A9 : $Char_Copyright   0x003E : $Char_GreaterThan   0x2620 : $([char]0x2620)   0x2622 : $Char_Radioactive")

        Write-Output ("  0x2623 : $([char]0x2623)   0x1F197: $([char]::ConvertFromUtf32(0x1F197))  0x2757 : $([char]0x2757)  0x2139 : $([char]0x2139)")

        Write-Output ("  0x2600 : $([char]0x2600)   0x2601 : $([char]0x2601)   0x2609 : $([char]0x2609)   0x2610 : $([char]0x2610)")

        Write-Output ("  0x2611 : $Char_BallotCheck   0x2714 : $Char_CheckMark   0x1F44D: $([char]::ConvertFromUtf32(0x1F44D))  0x1F389: $([char]::ConvertFromUtf32(0x1F389))")

        Write-Output ("  0x1F3C1: $([char]::ConvertFromUtf32(0x1F3C1))  0x1F480: $([char]::ConvertFromUtf32(0x1F480))  0x1F6D1: $([char]::ConvertFromUtf32(0x1F6D1))  0x26D4 : $([char]0x26D4)")

        Write-Output ("  0x1F6AB: $([char]::ConvertFromUtf32(0x1F6AB))  0x26D2 : $Char_NoEntry   0x26DD : $Char_XSquare   0x2612 : $([char]0x2612)")

        Write-Output ("  0x2613 : $([char]0x2613)   0x2716 : $Char_FailureX   0x261A : $([char]0x261A)   0x261D : $([char]0x261D)")

        Write-Output ("  0x261F : $([char]0x261F)   0x2630 : $([char]0x2630)   0x2631 : $([char]0x2631)   0x2632 : $([char]0x2632)")

        Write-Output ("  0x2633 : $([char]0x2633)   0x2634 : $([char]0x2634)   0x2635 : $([char]0x2635)   0x2636 : $([char]0x2636)")

        Write-Output ("  0x2637 : $([char]0x2637)   0x2638 : $([char]0x2638)   0x2639 : $([char]0x2639)   0x263A : $([char]0x263A)")

        Write-Output ("  0x263B : $([char]0x263B)   0x263C : $([char]0x263C)   0x267B : $([char]0x267B)   0x268A : $([char]0x268A)")

        Write-Output ("  0x268B : $([char]0x268B)   0x268C : $([char]0x268C)   0x268D : $([char]0x268D)   0x268E : $([char]0x268E)")

        Write-Output ("  0x268F : $([char]0x268F)   0x269B : $([char]0x269B)   0x26A1 : $([char]0x26A1)  0x26CB : $([char]0x26CB)")

        Write-Output ("  0x26CC : $([char]0x26CC)   0x26DA : $([char]0x26DA)   0x26AA : $([char]0x26AA)  0x26BD : $([char]0x26BD)")

        Write-Output ("  0x26BE : $([char]0x26BE)  0x26DE : $([char]0x26DE)   0x26EC : $([char]0x26EC)   0x26ED : $([char]0x26ED)")

        Write-Output ("  0x26EE : $([char]0x26EE)   0x26EF : $([char]0x26EF)   0x26F6 : $([char]0x26F6)   0x2718 : $([char]0x2718)")

        Write-Output ("  0x2719 : $([char]0x2719)   0x271A : $([char]0x271A)   0x271B : $([char]0x271B)   0x271C : $([char]0x271C)")

        Write-Output ("  0x274D : $([char]0x274D)   0x274F : $([char]0x274F)   0x2750 : $([char]0x2750)   0x2794 : $([char]0x2794)")

        Write-Output ("  0x2795 : $([char]0x2795)  0x2799 : $([char]0x2799)   0x27A1 : $([char]0x27A1)   0x27A8 : $([char]0x27A8)")

        Write-Output ("  0x27B1 : $([char]0x27B1)   0x27B2 : $([char]0x27B2)   0x1F494: $([char]::ConvertFromUtf32(0x1F494))  0x1F496: $([char]::ConvertFromUtf32(0x1F496))")

        Write-Output ("  0x1F49F: $([char]::ConvertFromUtf32(0x1F49F))  0x1F4AD: $([char]::ConvertFromUtf32(0x1F4AD))  0x1F4AF: $([char]::ConvertFromUtf32(0x1F4AF))  0x1F4BB: $([char]::ConvertFromUtf32(0x1F4BB))")

        Write-Output ("  0x1F4BD: $([char]::ConvertFromUtf32(0x1F4BD))  0x1F4BE: $([char]::ConvertFromUtf32(0x1F4BE))  0x1F4C1: $([char]::ConvertFromUtf32(0x1F4C1))  0x1F4C2: $([char]::ConvertFromUtf32(0x1F4C2))")

        Write-Output ("  0x1F4C3: $([char]::ConvertFromUtf32(0x1F4C3))  0x1F4DD: $([char]::ConvertFromUtf32(0x1F4DD))  0x1F4E3: $([char]::ConvertFromUtf32(0x1F4E3))  0x1F4E4: $([char]::ConvertFromUtf32(0x1F4E4))")

        Write-Output ("  0x1F4E5: $([char]::ConvertFromUtf32(0x1F4E5))  0x1F4E8: $([char]::ConvertFromUtf32(0x1F4E8))  0x1F4F3: $([char]::ConvertFromUtf32(0x1F4F3))  0x1F4F5: $([char]::ConvertFromUtf32(0x1F4F5))")

        Write-Output ("  0x1F4F6: $([char]::ConvertFromUtf32(0x1F4F6))  0x1F501: $([char]::ConvertFromUtf32(0x1F501))  0x1F502: $([char]::ConvertFromUtf32(0x1F502))  0x1F503: $([char]::ConvertFromUtf32(0x1F503))")

        Write-Output ("  0x1F50B: $([char]::ConvertFromUtf32(0x1F50B))  0x1F50C: $([char]::ConvertFromUtf32(0x1F50C))  0x1F50D: $([char]::ConvertFromUtf32(0x1F50D))  0x1F50E: $([char]::ConvertFromUtf32(0x1F50E))")

        Write-Output ("  0x1F50F: $([char]::ConvertFromUtf32(0x1F50F))  0x1F510: $([char]::ConvertFromUtf32(0x1F510))  0x1F511: $([char]::ConvertFromUtf32(0x1F511))  0x1F512: $([char]::ConvertFromUtf32(0x1F512))")

        Write-Output ("  0x1F513: $([char]::ConvertFromUtf32(0x1F513))")

}

function Show-VisualExamples {
    param(
        [bool]$ShowFormattingRules = $false,
        [bool]$ShowExtraChars = $false
    )

    Clear-Host
    Write-Output ""

    # --- TOP TITLE ---
    $WinAutoTitle = "$Char_Window WinAuto $Char_Loop"
    $WinAutoPadding = [Math]::Floor((60 - 11) / 2)
    Write-Output (" " * $WinAutoPadding + "$Bold$FGCyan$WinAutoTitle$Reset")
    
    $SubText = "SCRIPT OUTPUT RULES" 
    $SubPadding = [Math]::Floor((60 - $SubText.Length) / 2)
    Write-Output (" " * $SubPadding + "$Bold$FGCyan$SubText$Reset")

    # --- PART 1: SCRIPT OUTPUT LEGEND ---
    Show-Legend

    # --- PART 2: SCRIPT OUTPUT FORMATTING ---
    if ($ShowFormattingRules) {
        Show-FormattingRules
        Show-LinesInUse
    }

    # --- PART 4: SCRIPT OUTPUT CHARACTERS USED ---
    if ($ShowExtraChars) {
        Show-CharactersUsed
    }
}

# Helper to wait for keypress or default to Enter after timeout
function Wait-KeyPressWithTimeout {
    param([int]$Seconds, [scriptblock]$OnTick)
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
    return [PSCustomObject]@{ VirtualKeyCode = 13 }
}

# Standard Footer Block
$PrintFooter = {
    Write-Output "$FGDarkBlue$([string]'_' * 60)$Reset"
    $FooterText = "$([char]0x00A9) 2026, www.AIIT.support. All Rights Reserved."
    $FooterPadding = [Math]::Floor((60 - $FooterText.Length) / 2)
    Write-Host (" " * $FooterPadding + $FooterText) -ForegroundColor Cyan
}

if ($ShowRules) {
    Show-VisualExamples -ShowFormattingRules $true -ShowExtraChars $true
    & $PrintFooter
} else {
    Show-VisualExamples -ShowFormattingRules $false
    $PromptCursorTop = [Console]::CursorTop
    Write-Output ""
    & $PrintFooter
    
    $TickAction = {
        param($ElapsedTimespan)
        $WiggleFrame = [Math]::Floor($ElapsedTimespan.TotalMilliseconds / 500)
        $IsRight = ($WiggleFrame % 2) -eq 1
        $CurrentChars = if ($IsRight) { @(" ", $Char_Finger, "[", "E", "n", "t", "e", "r", "]", " ") } else { @($Char_Finger, " ", "[", "E", "n", "t", "e", "r", "]", " ") }
        $FilledCount = [Math]::Floor($ElapsedTimespan.TotalSeconds)
        if ($FilledCount -gt 10) { $FilledCount = 10 }
        
        $DynamicPart = ""
        for ($i = 0; $i -lt 10; $i++) {
            $Char = $CurrentChars[$i]
            if ($i -lt $FilledCount) { $DynamicPart += "${BGYellow}${FGBlack}$Char${Reset}" } 
            else { $DynamicPart += if ($Char -eq " ") { " " } else { "${FGYellow}$Char${Reset}" } }
        }

        $PromptStr = "${FGWhite}$Char_Keyboard Press ${FGDarkGray}$DynamicPart${FGDarkGray}${FGWhite}to${FGDarkGray} ${FGYellow}EXPAND${FGDarkGray} ${FGWhite}|${FGDarkGray} or any other key ${FGWhite}to SKIP$Char_Skip${Reset}"
        $VisibleText = "$Char_Keyboard Press  â˜›[Enter] to EXPAND | or any other key to SKIP$Char_Skip"
        $Pad = [Math]::Max(0, [Math]::Floor((60 - $VisibleText.Length) / 2))

        [Console]::SetCursorPosition(0, $PromptCursorTop)
        [Console]::Write(" " * 80)
        [Console]::SetCursorPosition(0, $PromptCursorTop)
        Write-Host (" " * $Pad + $PromptStr) -NoNewline
    }

    $key = Wait-KeyPressWithTimeout -Seconds 10 -OnTick $TickAction
    if ($key.VirtualKeyCode -eq 13) { 
        Show-VisualExamples -ShowFormattingRules $true
        
        $PromptCursorTop2 = [Console]::CursorTop
        Write-Output ""
        & $PrintFooter
        
        $TickAction2 = {
            param($ElapsedTimespan)
            $WiggleFrame = [Math]::Floor($ElapsedTimespan.TotalMilliseconds / 500)
            $IsRight = ($WiggleFrame % 2) -eq 1
            $CurrentChars = if ($IsRight) { @(" ", $Char_Finger, "[", "E", "n", "t", "e", "r", "]", " ") } else { @($Char_Finger, " ", "[", "E", "n", "t", "e", "r", "]", " ") }
            $FilledCount = [Math]::Floor($ElapsedTimespan.TotalSeconds)
            if ($FilledCount -gt 10) { $FilledCount = 10 }
            
            $DynamicPart = ""
            for ($i = 0; $i -lt 10; $i++) {
                $Char = $CurrentChars[$i]
                if ($i -lt $FilledCount) { $DynamicPart += "${BGYellow}${FGBlack}$Char${Reset}" } 
                else { $DynamicPart += if ($Char -eq " ") { " " } else { "${FGYellow}$Char${Reset}" } }
            }

            $PromptStr = "${FGWhite}$Char_Keyboard Press ${FGDarkGray}$DynamicPart${FGDarkGray}${FGWhite}to${FGDarkGray} ${FGYellow}EXPAND CHARS${FGDarkGray} ${FGWhite}|${FGDarkGray} or any other key ${FGWhite}to SKIP$Char_Skip${Reset}"
            $VisibleText = "$Char_Keyboard Press  â˜›[Enter] to EXPAND CHARS | or any other key to SKIP$Char_Skip"
            $Pad = [Math]::Max(0, [Math]::Floor((60 - $VisibleText.Length) / 2))

            [Console]::SetCursorPosition(0, $PromptCursorTop2)
            [Console]::Write(" " * 80)
            [Console]::SetCursorPosition(0, $PromptCursorTop2)
            Write-Host (" " * $Pad + $PromptStr) -NoNewline
        }

        $key2 = Wait-KeyPressWithTimeout -Seconds 10 -OnTick $TickAction2
        if ($key2.VirtualKeyCode -eq 13) {
            Show-VisualExamples -ShowFormattingRules $true -ShowExtraChars $true
            & $PrintFooter
        } else {
            try {
                [Console]::SetCursorPosition(0, $PromptCursorTop2)
                [Console]::Write(" " * 80)
                [Console]::SetCursorPosition(0, $PromptCursorTop2)
                Write-Output ""
                & $PrintFooter
            } catch {}
        }
    } else {
        try {
            [Console]::SetCursorPosition(0, $PromptCursorTop)
            Write-Output (" " * 80)
            [Console]::SetCursorPosition(0, $PromptCursorTop + 1)
            Write-Output (" " * 80)
            [Console]::SetCursorPosition(0, $PromptCursorTop)
            Write-Output ""
            & $PrintFooter
        } catch {}
    }
}
