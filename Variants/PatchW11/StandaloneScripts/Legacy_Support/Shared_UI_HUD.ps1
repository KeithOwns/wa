<#
.SYNOPSIS
    Displays a persistent header with system statistics.
    
.DESCRIPTION
    Standardizes the "Technician's Console" look. This function should be called
    at the start of every menu loop to clear the screen and show context.
    It relies on fast CIM instances to avoid menu lag.
#>

function Show-WinAutoHeader {
    param(
        [string]$Title = "Main Menu"
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



<#
.SYNOPSIS
    Displays a persistent header with system statistics.
    
.DESCRIPTION
    Standardizes the "Technician's Console" look. This function should be called
    at the start of every menu loop to clear the screen and show context.
    It relies on fast CIM instances to avoid menu lag.
#>

function Show-WinAutoHeader {
    param(
        [string]$Title = "Main Menu"
    )

    # 1. Standard Clear (User Preference)
    Clear-Host

    # 2. Gather Fast Stats
    try {
        $osInfo = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
        $freeMem = [math]::Round(($osInfo.FreePhysicalMemory / 1024), 1) # MB
        $totalMem = [math]::Round(($osInfo.TotalVisibleMemorySize / 1024), 1) # MB
        $osName = $osInfo.Caption -replace "Microsoft ", ""
        
        $ipAddr = (Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias "Wi-Fi","Ethernet" -ErrorAction SilentlyContinue | Select-Object -First 1).IPAddress
        if (-not $ipAddr) { $ipAddr = "Disconnected" }
    }
    catch {
        $osName = "Unknown"
        $freeMem = 0
    }

    # 3. Draw UI
    $line = "=" * 85
    $subLine = "-" * 85
    
    Write-Host $line -ForegroundColor Cyan
    Write-Host "  WinAuto | Technician Console" -NoNewline -ForegroundColor White
    Write-Host "                                         [User: $env:USERNAME]" -ForegroundColor DarkGray
    Write-Host $line -ForegroundColor Cyan
    
    # Row 1 Stats
    Write-Host "  HOST: " -NoNewline -ForegroundColor DarkCyan
    Write-Host "$($env:COMPUTERNAME.PadRight(15))" -NoNewline -ForegroundColor White
    
    Write-Host "  IP: " -NoNewline -ForegroundColor DarkCyan
    Write-Host "$($ipAddr.PadRight(15))" -NoNewline -ForegroundColor White
    
    Write-Host "  OS: " -NoNewline -ForegroundColor DarkCyan
    Write-Host "$osName" -ForegroundColor White

    # Row 2 Stats
    Write-Host "  MEM:  " -NoNewline -ForegroundColor DarkCyan
    Write-Host "$freeMem MB Free / $totalMem MB Total" -ForegroundColor White
    
    Write-Host $subLine -ForegroundColor DarkGray
    Write-Host "  CONTEXT: " -NoNewline -ForegroundColor Yellow
    Write-Host $Title.ToUpper() -ForegroundColor White
    Write-Host $subLine -ForegroundColor DarkGray
    Write-Host ""
}

Export-ModuleMember -Function Show-WinAutoHeader