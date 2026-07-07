#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Local User Manager
.DESCRIPTION
    Quickly manage local user accounts: List, Create, Reset Password, Enable Admin.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Wait-KeyPressWithTimeout {
    param(
        [int]$Seconds,
        [scriptblock]$OnTick
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



#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Local User Manager
.DESCRIPTION
    Quickly manage local user accounts: List, Create, Reset Password, Enable Admin.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Wait-KeyPressWithTimeout {
    param(
        [int]$Seconds,
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
    return [PSCustomObject]@{ VirtualKeyCode = 13 }
}

function Invoke-AnimatedPause {
    Write-Host ""
    $PromptCursorTop = [Console]::CursorTop
    $TickAction = {
        param($ElapsedTimespan)
        $WiggleFrame = [Math]::Floor($ElapsedTimespan.TotalMilliseconds / 500)
        $IsRight = ($WiggleFrame % 2) -eq 1
        if ($IsRight) { $CurrentChars = @(" ", $Char_Finger, "[", "E", "n", "t", "e", "r", "]", " ") } 
        else { $CurrentChars = @($Char_Finger, " ", "[", "E", "n", "t", "e", "r", "]", " ") }
        $FilledCount = [Math]::Floor($ElapsedTimespan.TotalSeconds)
        if ($FilledCount -gt 10) { $FilledCount = 10 }
        $DynamicPart = ""
        for ($i = 0; $i -lt 10; $i++) {
            $Char = $CurrentChars[$i]
            if ($i -lt $FilledCount) { $DynamicPart += "${BGYellow}${FGBlack}$Char${Reset}" } 
            else { if ($Char -eq " ") { $DynamicPart += " " } else { $DynamicPart += "${FGYellow}$Char${Reset}" } }
        }
        $PromptStr = "${FGWhite}$Char_Keyboard  Press ${FGDarkGray}$DynamicPart${FGDarkGray}${FGWhite}to${FGDarkGray} ${FGYellow}CONTINUE${FGDarkGray} ${FGWhite}|${FGDarkGray} or any other key ${FGWhite}to SKIP$Char_Skip${Reset}"
        try { [Console]::SetCursorPosition(0, $PromptCursorTop); Write-Centered $PromptStr } catch {}
    }

    $null = Wait-KeyPressWithTimeout -Seconds 10 -OnTick $TickAction
    Write-Host ""
}

# --- STYLE ---
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$Char_HeavyLine = [char]0x2501; $Char_BallotCheck = [char]0x2611; $Char_RedCross = [char]0x274E; $Char_Warn = [char]0x26A0
$Char_Finger = [char]0x261B; $Char_Keyboard = [char]0x2328; $Char_Eject = [char]0x23CF; $Char_User = [char]::ConvertFromUtf32(0x1F464)
$Char_Skip = [char]0x23ED
$Esc = [char]0x1B; $Reset = "$Esc[0m"; $Bold = "$Esc[1m"
$FGCyan = "$Esc[96m"; $FGGreen = "$Esc[92m"; $FGYellow = "$Esc[93m"; $FGRed = "$Esc[91m"; $FGWhite = "$Esc[97m"; $FGGray = "$Esc[37m"
$FGDarkBlue = "$Esc[34m"; $FGDarkGray = "$Esc[90m"; $FGBlack = "$Esc[30m"; $BGYellow = "$Esc[103m"

function Write-Centered { param($Text, $Width = 60) $clean = $Text -replace "$Esc\[[0-9;]*m", ""; $pad = [Math]::Floor(($Width - $clean.Length) / 2); if ($pad -lt 0) { $pad = 0 }; Write-Host (" " * $pad + $Text) }
function Write-LeftAligned { param($Text, $Indent = 2) Write-Host (" " * $Indent + $Text) }
function Write-Header { param($Title) Write-Host ""; Write-Centered "$Bold$FGCyan $Char_HeavyLine WinAuto $Char_HeavyLine $Reset"; Write-Centered "$Bold$FGCyan$Title$Reset"; Write-Host "$FGDarkBlue$([string]$Char_HeavyLine * 60)$Reset" }
function Write-Boundary { param($Color = $FGDarkBlue) Write-Host "$Color$([string]$Char_HeavyLine * 60)$Reset" }

# --- FUNCTIONS ---

function Get-UserList {
    Write-Host ""
    Write-LeftAligned "$FGYellow Local Users:$Reset"
    $users = Get-LocalUser
    foreach ($u in $users) {
        $status = if ($u.Enabled) { "$FGGreen(Active)$Reset" } else { "$FGRed(Disabled)$Reset" }
        $admin = if ((Get-LocalGroupMember -Group "Administrators" -Member $u.Name -ErrorAction SilentlyContinue)) { "$FGYellow[Admin]$Reset" } else { "$FGGray[Std]$Reset" }
        Write-LeftAligned " $Char_User $($u.Name) $admin $status"
    }
}

function Enable-BuiltInAdmin {
    Write-Host ""
    try {
        Enable-LocalUser -Name "Administrator"
        Write-LeftAligned "$FGGreen$Char_BallotCheck Built-in 'Administrator' account enabled.$Reset"
    } catch {
        Write-LeftAligned "$FGRed$Char_RedCross Failed: $($_.Exception.Message)$Reset"
    }
}

function Reset-Password {
    Write-Host ""
    $name = Read-Host "  Enter Username to reset"
    if (-not (Get-LocalUser -Name $name -ErrorAction SilentlyContinue)) {
        Write-LeftAligned "$FGRed User not found.$Reset"
        return
    }
    
    $pass = Read-Host "  Enter New Password" -AsSecureString
    try {
        Set-LocalUser -Name $name -Password $pass
        Write-LeftAligned "$FGGreen$Char_BallotCheck Password reset successfully.$Reset"
    } catch {
        Write-LeftAligned "$FGRed$Char_RedCross Failed: $($_.Exception.Message)$Reset"
    }
}

function Create-User {
    Write-Host ""
    $name = Read-Host "  New Username"
    $pass = Read-Host "  Password" -AsSecureString
    $desc = Read-Host "  Description (Optional)"
    
    try {
        New-LocalUser -Name $name -Password $pass -Description $desc -FullName $name -AccountNeverExpires | Out-Null
        Write-LeftAligned "$FGGreen$Char_BallotCheck User '$name' created.$Reset"
        
        Write-Host ""
        Write-LeftAligned "Add to Administrators group?"
        $choice = Read-Host "  (Y/N)"
        if ($choice -match '^[Yy]') {
            Add-LocalGroupMember -Group "Administrators" -Member $name
            Write-LeftAligned "$FGGreen$Char_BallotCheck Added to Administrators.$Reset"
        }
    } catch {
        Write-LeftAligned "$FGRed$Char_RedCross Failed: $($_.Exception.Message)$Reset"
    }
}

# --- MENU ---
$menu = $true
while ($menu) {

    Write-Header "USER MANAGER"
    Get-UserList
    
    Write-Host ""
    Write-LeftAligned " ${FGBlack}${BGYellow}[1]${Reset} ${FGGray}Enable Built-in Administrator${Reset}"
    Write-LeftAligned " ${FGBlack}${BGYellow}[2]${Reset} ${FGGray}Reset User Password${Reset}"
    Write-LeftAligned " ${FGBlack}${BGYellow}[3]${Reset} ${FGGray}Create New User${Reset}"
    
    Write-Boundary
    $prompt = "${FGWhite}$Char_Keyboard  Type${FGYellow} ID ${FGWhite}to Execute${FGWhite}|${FGDarkGray}any other to ${FGWhite}EXIT$Char_Eject${Reset}"
    Write-Centered $prompt
    
    $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    $c = $key.Character.ToString().ToUpper()
    
    switch ($c) {
        '1' { Enable-BuiltInAdmin; Start-Sleep -Seconds 1 }
        '2' { Reset-Password; Start-Sleep -Seconds 1 }
        '3' { Create-User; Start-Sleep -Seconds 1 }
        Default { $menu = $false }
    }
}




