# Global Resources for WinAuto & PatchW11
# Centralized definition of ANSI colors and Unicode characters.

# --- ANSI Escape Sequences ---
$Esc = [char]0x1B
$Reset = "$Esc[0m"
$Bold = "$Esc[1m"

# Script Palette (Foreground)
$FGCyan       = "$Esc[96m"
$FGBlue       = "$Esc[94m"
$FGDarkBlue   = "$Esc[34m"
$FGGreen      = "$Esc[92m"
$FGRed        = "$Esc[91m"
$FGMagenta    = "$Esc[95m"
$FGYellow     = "$Esc[93m"
$FGDarkCyan   = "$Esc[36m"
$FGWhite      = "$Esc[97m"
$FGGray       = "$Esc[37m"
$FGDarkGray   = "$Esc[90m"
$FGDarkGreen  = "$Esc[32m"
$FGDarkRed    = "$Esc[31m"
$FGDarkMagenta= "$Esc[35m"
$FGDarkYellow = "$Esc[33m"
$FGBlack      = "$Esc[30m"

# Script Palette (Background)
$BGDarkGreen  = "$Esc[42m"
$BGDarkGray   = "$Esc[100m"
$BGYellow     = "$Esc[103m"
$BGRed        = "$Esc[101m"
$BGDarkBlue   = "$Esc[44m"
$BGDarkRed    = "$Esc[41m"
$BGDarkCyan   = "$Esc[46m"
$BGMagenta    = "$Esc[105m"
$BGGreen      = "$Esc[102m"
$BGWhite      = "$Esc[107m"
$BGCyan       = "$Esc[106m"
$BGDarkMagenta= "$Esc[45m"

# --- Unicode Icons & Characters ---
# Standard Symbols
$Char_HeavyCheck  = [char]0x2705 # âœ…
$Char_Warn        = [char]0x26A0 # âš ï¸
$Char_BallotCheck = [char]0x2611 # â˜‘
$Char_XSquare     = [char]0x26DD # â›
$Char_NoEntry     = [char]0x26D2 # â›” (Actually Circle X)
$Char_Keyboard    = [char]0x2328 # âŒ¨
$Char_Loop        = [char]::ConvertFromUtf32(0x1F504) # ðŸ”„
$Char_Copyright   = [char]0x00A9 # Â©
$Char_Finger      = [char]0x261B # â˜›
$Char_GreaterThan = [char]0x003E # >
$Char_Skip        = [char]0x23ED # â­
$Char_CheckMark   = [char]0x2714 # ✔
$Char_CheckLight  = [char]0x2713 # ✓
$Char_FailureX    = [char]0x2716 # ✖
$Char_CrossMark   = [char]0x274C # ❌
$Char_CrossSquare = [char]0x274E # ❎
$Char_RedCross    = [char]0x274C
$Char_RedX        = [char]0x2716
$Char_Eject       = [char]0x23CF # ⏏
$Char_Gear        = [char]0x2699 # âš™
$Char_BlackCircle = [char]0x25CF # â—
$Char_Radioactive = [char]0x2622 # â˜¢
$Char_Biohazard   = [char]0x2623 # â˜£
$Char_Skull       = [char]0x2620 # â˜ 
$Char_FastForward = [char]0x23E9 # â©
$Char_Timer       = [char]0x23F2 # â²
$Char_Alarm       = [char]0x23F0 # â°
$Char_OkButton    = [char]::ConvertFromUtf32(0x1F197) # ðŸ†—
$Char_Exclamation = [char]0x2757 # â—
$Char_Info        = [char]0x2139 # â„¹
$Char_Sun         = [char]0x2600 # â˜€
$Char_Cloud       = [char]0x2601 # â˜
$Char_ThumbsUp    = [char]::ConvertFromUtf32(0x1F44D) # ðŸ‘
$Char_Party       = [char]::ConvertFromUtf32(0x1F389) # ðŸŽ‰
$Char_Flag        = [char]::ConvertFromUtf32(0x1F3C1) # ðŸ
$Char_Stop        = [char]::ConvertFromUtf32(0x1F6D1) # ðŸ›‘
$Char_NoEntrySign = [char]0x26D4 # â›”
$Char_Prohibited  = [char]::ConvertFromUtf32(0x1F6AB) # ðŸš«
$Char_BallotBox   = [char]0x2610 # â˜
$Char_BallotBoxX  = [char]0x2612 # â˜’
$Char_Saltire     = [char]0x2613 # â˜“
$Char_Plus        = [char]0x2795 # âž•
$Char_ArrowRight  = [char]0x27A1 # âž¡
$Char_ArrowHeavy  = [char]0x2799 # âž™
$Char_ArrowDash   = [char]0x2794 # âž”
$Char_Recycle     = [char]0x267B # â™»
$Char_Lightning   = [char]0x26A1 # âš¡
$Char_Atom        = [char]0x269B # âš›
$Char_Soccer      = [char]0x26BD # âš½
$Char_Baseball    = [char]0x26BE # âš¾
$Char_WhiteCircle = [char]0x26AA # âšª
$Char_Trigram     = [char]0x2630 # â˜°
$Char_HeartBreak  = [char]::ConvertFromUtf32(0x1F494) # ðŸ’”
$Char_HeartSpark  = [char]::ConvertFromUtf32(0x1F496) # ðŸ’–
$Char_HeartDeco   = [char]::ConvertFromUtf32(0x1F49F) # ðŸ’Ÿ
$Char_Thought     = [char]::ConvertFromUtf32(0x1F4AD) # ðŸ’­
$Char_Hundred     = [char]::ConvertFromUtf32(0x1F4AF) # ðŸ’¯
$Char_Laptop      = [char]::ConvertFromUtf32(0x1F4BB) # ðŸ’»
$Char_Floppy      = [char]::ConvertFromUtf32(0x1F4BE) # ðŸ’¾
$Char_Folder      = [char]::ConvertFromUtf32(0x1F4C1) # ðŸ“
$Char_FolderOpen  = [char]::ConvertFromUtf32(0x1F4C2) # ðŸ“‚
$Char_Page        = [char]::ConvertFromUtf32(0x1F4C3) # ðŸ“ƒ
$Char_Memo        = [char]::ConvertFromUtf32(0x1F4DD) # ðŸ“
$Char_MegaPhone   = [char]::ConvertFromUtf32(0x1F4E3) # ðŸ“£
$Char_Outbox      = [char]::ConvertFromUtf32(0x1F4E4) # ðŸ“¤
$Char_Inbox       = [char]::ConvertFromUtf32(0x1F4E5) # ðŸ“¥
$Char_Mail        = [char]::ConvertFromUtf32(0x1F4E8) # ðŸ“¨
$Char_Vibrate     = [char]::ConvertFromUtf32(0x1F4F3) # ðŸ“³
$Char_NoPhone     = [char]::ConvertFromUtf32(0x1F4F5) # ðŸ“µ
$Char_Signal      = [char]::ConvertFromUtf32(0x1F4F6) # ðŸ“¶
$Char_Repeat      = [char]::ConvertFromUtf32(0x1F501) # ðŸ”
$Char_RepeatOne   = [char]::ConvertFromUtf32(0x1F502) # ðŸ”‚
$Char_Reload      = [char]::ConvertFromUtf32(0x1F503) # ðŸ”ƒ
$Char_Battery     = [char]::ConvertFromUtf32(0x1F50B) # ðŸ”‹
$Char_Plug        = [char]::ConvertFromUtf32(0x1F50C) # ðŸ”Œ
$Char_MagLeft     = [char]::ConvertFromUtf32(0x1F50D) # ðŸ”
$Char_MagRight    = [char]::ConvertFromUtf32(0x1F50E) # ðŸ”Ž
$Char_LockPen     = [char]::ConvertFromUtf32(0x1F50F) # ðŸ”
$Char_LockKey     = [char]::ConvertFromUtf32(0x1F510) # ðŸ”
$Char_Key         = [char]::ConvertFromUtf32(0x1F511) # ðŸ”‘
$Char_Lock        = [char]::ConvertFromUtf32(0x1F512) # ðŸ”’
$Char_Unlock      = [char]::ConvertFromUtf32(0x1F513) # ðŸ”“

# --- SYSTEM PATHS ---
if (-not (Get-Variable -Name "WinAutoLogDir" -Scope Global -ErrorAction SilentlyContinue)) { $Global:WinAutoLogDir = "C:\Users\admin\GitHub\WinAuto\logs" }
$env:WinAutoLogDir = $Global:WinAutoLogDir
if (-not (Get-Variable -Name "WinAutoLogPath" -Scope Global -ErrorAction SilentlyContinue)) { $Global:WinAutoLogPath = "$Global:WinAutoLogDir\WinAuto_$(Get-Date -Format 'yyyyMMdd_HHmmss').log" }

# Registry Paths (Shared)
$Global:RegPath_WU_UX  = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings"
$Global:RegPath_WU_POL = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
$Global:RegPath_Winlogon_User = "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" 
$Global:RegPath_Winlogon_Machine = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"

# Lines & Blocks
$Char_EmDash      = [char]0x2014 # â€”
$Char_EnDash      = [char]0x2013 # â€“
$Char_Hyphen      = [char]0x002D # -
$Char_HeavyMinus  = [char]0x2796 # âž–
$Char_BlackRect   = [char]0x25AC # â–¬
$Char_HeavyLine   = [char]0x2501 # â”
$Char_LightLine   = [char]0x2500 # â”€
$Char_Overline    = [char]0x203E # â€¾

# Complex Emojis (Surrogates)
$Char_Shield      = [char]::ConvertFromUtf32(0x1F6E1) # ðŸ›¡ï¸
$Char_Person      = [char]::ConvertFromUtf32(0x1F464) # ðŸ‘¤
$Char_Satellite   = [char]::ConvertFromUtf32(0x1F4E1) # ðŸ“¡
$Char_CardIndex   = [char]::ConvertFromUtf32(0x1F4C7) # ðŸ“‡
$Char_Desktop     = [char]::ConvertFromUtf32(0x1F5A5) # ðŸ–¥ï¸
$Char_Speaker     = [char]::ConvertFromUtf32(0x1F50A) # ðŸ”Š
$Char_Bell        = [char]::ConvertFromUtf32(0x1F514) # ðŸ””
$Char_User        = [char]::ConvertFromUtf32(0x1F464) # ðŸ‘¤
$Char_Window      = [char]::ConvertFromUtf32(0x1FA9F) # ðŸªŸ
