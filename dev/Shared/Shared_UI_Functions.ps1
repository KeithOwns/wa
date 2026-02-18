# WinAuto Shared UI & Logic Functions
# Standardizes visuals, colors, and interactive timeouts across the suite.

# --- ENCODING ---
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# --- REQUIREMENTS CHECK ---
if ($PSVersionTable.PSVersion.Major -lt 5) {
    Write-Warning "WinAuto requires PowerShell 5.1 or newer. You are running version $($PSVersionTable.PSVersion)."
    exit
}

# --- GLOBAL RESOURCES ---
. "$PSScriptRoot\Global_Resources.ps1"

# --- OS VALIDATION ---
function Test-IsWindows11 {
    $os = Get-CimInstance -ClassName Win32_OperatingSystem
    # Windows 11 is technically Windows 10 kernel, but Build number is 22000+
    $build = [int]$os.BuildNumber
    if ($build -lt 22000) {
        Write-Warning "WinAuto is designed for Windows 11 (Build 22000+). Detected Build: $build."
        Write-Warning "Some features (Smart App Control, Winget, Settings Layouts) may fail or cause errors."
        Write-Host "Press any key to continue at your own risk..."
        $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
}

# Run the check immediately upon loading shared functions
Test-IsWindows11

# --- CONSOLE SETTINGS ---

function Set-ConsoleSnapRight {
    param([int]$Columns = 64)
    try {
        $code = @"
        using System;
        using System.Runtime.InteropServices;
        namespace WinAutoNative {
            [StructLayout(LayoutKind.Sequential)] 
            public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }

            public class ConsoleUtils {
                [DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
                [DllImport("user32.dll")] public static extern bool MoveWindow(IntPtr hWnd, int X, int Y, int nWidth, int nHeight, bool bRepaint);
                [DllImport("user32.dll")] public static extern int GetSystemMetrics(int nIndex);
                [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
            }
        }
"@
        if (-not ([System.Management.Automation.PSTypeName]"WinAutoNative.ConsoleUtils").Type) {
            Add-Type -TypeDefinition $code -ErrorAction SilentlyContinue
        }

        # Safe Resizing Logic
        $buffer = $Host.UI.RawUI.BufferSize
        $window = $Host.UI.RawUI.WindowSize
        $targetHeight = [Math]::Max($window.Height, 50) # Ensure decent height

        # 1. Width Adjustment
        if ($Columns -lt $window.Width) {
            # Shrinking: Window FIRST, then Buffer
            $window.Width = $Columns
            $Host.UI.RawUI.WindowSize = $window
            $buffer.Width = $Columns
            $Host.UI.RawUI.BufferSize = $buffer
        }
        elseif ($Columns -gt $window.Width) {
            # Growing: Buffer FIRST, then Window
            $buffer.Width = $Columns
            $Host.UI.RawUI.BufferSize = $buffer
            $window.Width = $Columns
            $Host.UI.RawUI.WindowSize = $window
        }

        # 2. Height Adjustment
        if ($buffer.Height -lt $targetHeight) {
            $buffer.Height = $targetHeight
            $Host.UI.RawUI.BufferSize = $buffer
        }
        $window.Height = $targetHeight
        $Host.UI.RawUI.WindowSize = $window

        # 3. Position Adjustment
        $hWnd = [WinAutoNative.ConsoleUtils]::GetConsoleWindow()
        $screenW = [WinAutoNative.ConsoleUtils]::GetSystemMetrics(0) # SM_CXSCREEN
        $screenH = [WinAutoNative.ConsoleUtils]::GetSystemMetrics(1) # SM_CYSCREEN
        
        $targetW = [Math]::Floor($screenW / 3)
        $targetX = $screenW - $targetW
        
        # Snap to Right Third
        [WinAutoNative.ConsoleUtils]::MoveWindow($hWnd, $targetX, 0, $targetW, $screenH, $true) | Out-Null

    }
    catch {
        Write-Log "Failed to snap window: $($_.Exception.Message)" -Level WARNING
    }
}

function Disable-QuickEdit {
    try {
        $kernel32 = Add-Type -MemberDefinition @"
        [DllImport("kernel32.dll")]
        public static extern IntPtr GetStdHandle(int nStdHandle);
        [DllImport("kernel32.dll")]
        public static extern bool GetConsoleMode(IntPtr hConsoleHandle, out uint lpMode);
        [DllImport("kernel32.dll")]
        public static extern bool SetConsoleMode(IntPtr hConsoleHandle, uint dwMode);
"@ -Name "Kernel32" -Namespace Win32 -PassThru

        $STD_INPUT_HANDLE = -10
        $ENABLE_QUICK_EDIT_MODE = 0x0040
        
        $handle = $kernel32::GetStdHandle($STD_INPUT_HANDLE)
        $mode = 0
        if ($kernel32::GetConsoleMode($handle, [ref]$mode)) {
            $mode = $mode -band (-bnot $ENABLE_QUICK_EDIT_MODE)
            $null = $kernel32::SetConsoleMode($handle, $mode)
        }
    }
    catch {
        Write-Log "Failed to disable QuickEdit mode: $($_.Exception.Message)" -Level WARNING
    }
}

# --- FORMATTING HELPERS ---

function Get-VisualWidth {
    param([string]$String)
    $Width = 0
    $Chars = $String.ToCharArray()
    for ($i = 0; $i -lt $Chars.Count; $i++) {
        $c = $Chars[$i]
        # Check for High Surrogate (D800-DBFF) -> Emoji/Wide pair
        if ([char]::IsHighSurrogate($c)) {
            $Width += 2
            $i++ # Skip low surrogate
        }
        # Check for wide BMP characters (like some symbols) if needed
        # For now, assume BMP = 1 unless specifically handled
        else {
            $Width += 1
        }
    }
    return $Width
}

function Format-PaddedColumns {
    param(
        [Parameter(Mandatory)] [System.Collections.ArrayList] $Items,
        [int] $Columns = 4,
        [int] $Padding = 2 # Min spaces between cols
    )
    
    # Calculate max width per column to optimize spacing
    # Or simplified: Fixed width per column
    # Let's try dynamic:
    
    $ColWidths = New-Object int[] $Columns
    for ($i = 0; $i -lt $Items.Count; $i++) {
        $ColIndex = $i % $Columns
        $VisWidth = Get-VisualWidth $Items[$i]
        if ($VisWidth -gt $ColWidths[$ColIndex]) {
            $ColWidths[$ColIndex] = $VisWidth
        }
    }

    $Rows = [Math]::Ceiling($Items.Count / $Columns)
    for ($r = 0; $r -lt $Rows; $r++) {
        $RowString = ""
        for ($c = 0; $c -lt $Columns; $c++) {
            $Index = ($r * $Columns) + $c
            if ($Index -lt $Items.Count) {
                $Item = $Items[$Index]
                $VisWidth = Get-VisualWidth $Item
                
                # Calculate needed spaces
                if ($c -lt $Columns - 1) {
                    $Spaces = ($ColWidths[$c] - $VisWidth) + $Padding
                    $RowString += $Item + (" " * $Spaces)
                }
                else {
                    $RowString += $Item # Last column needs no extra padding
                }
            }
        }
        Write-LeftAligned $RowString
    }
}

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

function Write-Footer {
    Write-Boundary
    $FooterText = "$Char_Copyright 2026, www.AIIT.support. All Rights Reserved."
    $FooterPadding = [Math]::Floor((60 - $FooterText.Length) / 2)
    Write-Host (" " * $FooterPadding + $FooterText) -ForegroundColor Cyan
    
    # Standard Exit Spacing (User Preference)
    Write-Host "`n`n`n`n`n"
}
function Write-FlexLine {
    param(
        [string]$LeftIcon,
        [string]$LeftText,
        [string]$RightText,
        [bool]$IsActive,
        [int]$Width = 60,
        [string]$ActiveColor = "$BGDarkGreen"
    )
    # Define Char_BlackCircle locally if not global, or rely on it being present.
    # It wasn't in my previous update list. I should add it to ICONS section or here.
    # scriptRULES uses Char_BlackRect = 0x25AC (â–¬). C1 used Char_BlackCircle.
    # I will assume Char_BlackCircle should be Char_BlackRect (â–¬) to match rules?
    # Or I should add Char_BlackCircle. Let's add it to icons below this block if missing.
    $Circle = [char]0x25CF # â— Black Circle
    
    if ($IsActive) {
        $LeftDisplay = "$FGGray$LeftIcon $FGGray$LeftText$Reset"
    }
    else {
        $LeftDisplay = "$FGDarkGray$LeftIcon $FGDarkGray$LeftText$Reset"
    }

    $LeftRaw = "$LeftIcon $LeftText"
    
    if ($IsActive) {
        $RightDisplay = "$ActiveColor  $Circle$Reset$FGGray$RightText$Reset  "
        $RightRaw = "  $Circle$RightText  " 
    }
    else {
        $RightDisplay = "$BGDarkGray$FGBlack$Circle  $Reset${FGDarkGray}Off$Reset "
        $RightRaw = "$Circle  Off "
    }

    $SpaceCount = $Width - ($LeftRaw.Length + $RightRaw.Length + 3) - 1
    if ($SpaceCount -lt 1) { $SpaceCount = 1 }
    
    Write-Host ("   " + $LeftDisplay + (" " * $SpaceCount) + $RightDisplay)
}

function Write-BodyTitle {
    param([string]$Title)
    Write-LeftAligned "$FGWhite$Char_HeavyMinus $Bold$Title$Reset"
}

function Get-StatusLine {
    param([bool]$IsEnabled, [string]$Text)
    if ($IsEnabled) { return "$FGDarkGreen$Char_BallotCheck  $FGGray$Text$Reset" } 
    else { return "$FGDarkRed$Char_RedCross $FGGray$Text$Reset" }
}

# --- REGISTRY & LOGGING HELPERS ---

function Write-Log {
    param(
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet('INFO', 'WARNING', 'ERROR', 'SUCCESS')][string]$Level = 'INFO',
        [string]$Path = $Global:WinAutoLogPath
    )
    if (-not $Path) { $Path = "C:\Windows\Temp\WinAuto.log" }
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    
    # Ensure directory exists
    $logDir = Split-Path -Path $Path -Parent
    if (-not (Test-Path $logDir)) { New-Item -Path $logDir -ItemType Directory -Force | Out-Null }

    $logEntry = "[$timestamp] [$Level] $Message"
    Add-Content -Path $Path -Value $logEntry -ErrorAction SilentlyContinue

    # Secondary Error Log (if configured and level is relevant)
    if ($Global:WinAutoErrorLogPath -and ($Level -eq 'ERROR' -or $Level -eq 'WARNING')) {
        Add-Content -Path $Global:WinAutoErrorLogPath -Value $logEntry -ErrorAction SilentlyContinue
    }
}

function Get-WinAutoLastRun {
    param([string]$Module = "Maintenance")
    $StateFile = "$Global:WinAutoLogDir\WinAuto_State.json"
    if (Test-Path $StateFile) {
        try {
            $State = Get-Content $StateFile -Raw | ConvertFrom-Json
            if ($State.$Module) { return $State.$Module }
        }
        catch {}
    }
    return "Never"
}

function Set-WinAutoLastRun {
    param([string]$Module = "Maintenance")
    $StateFile = "$Global:WinAutoLogDir\WinAuto_State.json"
    $State = if (Test-Path $StateFile) { Get-Content $StateFile -Raw | ConvertFrom-Json } else { New-Object PSCustomObject }
    if (-not $State) { $State = New-Object PSCustomObject }
    
    Add-Member -InputObject $State -MemberType NoteProperty -Name $Module -Value (Get-Date -Format "yyyy-MM-dd HH:mm:ss") -Force
    
    $State | ConvertTo-Json | Set-Content $StateFile -Force
}

function Get-RegistryValue {
    param([Parameter(Mandatory)] [string]$Path, [Parameter(Mandatory)] [string]$Name)
    try {
        if (Test-Path $Path) {
            $prop = Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue
            return $prop.$Name
        }
        return $null
    }
    catch { return $null }
}

function Set-RegistryDword {
    param([Parameter(Mandatory)] [string]$Path, [Parameter(Mandatory)] [string]$Name, [Parameter(Mandatory)] [int]$Value, [string]$LogPath)
    try {
        if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
        if (Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue) {
            Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type DWord -Force | Out-Null
        }
        else {
            New-ItemProperty -Path $Path -Name $Name -PropertyType DWord -Value $Value -Force | Out-Null
        }
        if ($LogPath) { Write-Log -Message "Set registry: $Path\$Name = $Value" -Level SUCCESS -Path $LogPath }
    }
    catch {
        if ($LogPath) { Write-Log -Message "Failed to set registry: $Path\$Name - $($_.Exception.Message)" -Level ERROR -Path $LogPath }
        throw $_ 
    }
}

function Set-RegistryString {
    param([Parameter(Mandatory)] [string]$Path, [Parameter(Mandatory)] [string]$Name, [Parameter(Mandatory)] [string]$Value, [string]$LogPath)
    try {
        if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
        if (Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue) {
            Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type String -Force | Out-Null
        }
        else {
            New-ItemProperty -Path $Path -Name $Name -PropertyType String -Value $Value -Force | Out-Null
        }
        if ($LogPath) { Write-Log -Message "Set registry string: $Path\$Name = $Value" -Level SUCCESS -Path $LogPath }
    }
    catch {
        if ($LogPath) { Write-Log -Message "Failed to set registry: $Path\$Name - $($_.Exception.Message)" -Level ERROR -Path $LogPath }
        throw $_
    }
}

# --- TIMEOUT LOGIC ---

# --- TIMEOUT LOGIC ---

$Global:TickAction = {
    param($ElapsedTimespan, $ActionText = "RUN", $Timeout = 10, $PromptCursorTop, $SelectionChar = $null, $PreActionWord = "to")
    if ($null -eq $PromptCursorTop) { $PromptCursorTop = [Console]::CursorTop }

    # Dynamic prompt based on selection char (Dashboard vs Standard)
    if ($SelectionChar) {
        if ($SelectionChar -eq "->") {
            # Initial Mockup Special Case: "Press -> [Enter] for SmartRun"
            # Note: The mockup uses "->". We'll color it Yellow.
            $PromptStr = "$FGWhite$Char_Keyboard Press ${FGYellow}->${Reset}${FGWhite} ${FGBlack}${BGYellow}[Enter]${Reset}$FGWhite $PreActionWord ${FGGreen}$ActionText${Reset} ${FGDarkGray}|${Reset} ${FGRed}[Esc]${Reset}$FGWhite to ${FGRed}EXIT$Reset"
        }
        else {
            # Standard Dynamic with Hotkey option
            $PromptStr = "$FGWhite$Char_Keyboard Move ${FGYellow}->${Reset}$FGWhite and Press ${FGBlack}${BGYellow}[Enter]${Reset}$FGWhite or ${FGBlack}${BGYellow}[$SelectionChar]${Reset}$FGWhite $PreActionWord ${FGGreen}$ActionText${Reset} ${FGDarkGray}|${Reset} ${FGRed}[Esc]${Reset}$FGWhite to ${FGRed}EXIT$Reset"
        }
    }
    else {
        # Standard fallback text: "Press [Enter] to RUN"
        $PromptStr = "$FGWhite$Char_Keyboard Press ${FGBlack}${BGYellow}[Enter]${Reset}$FGWhite $PreActionWord ${FGGreen}$ActionText${Reset}   ${FGDarkGray}|${Reset} Press ${FGRed}[Esc]${Reset}$FGWhite to ${FGRed}EXIT$Reset"
    }
    
    try { 
        [Console]::SetCursorPosition(0, $PromptCursorTop)
        # Clear line to prevent artifacts
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
    param([string]$ActionText = "CONTINUE", [int]$Timeout = 10, [string]$SelectionChar = $null, [string]$PreActionWord = "to", [int]$OverrideCursorTop = $null)
    
    if ($null -ne $OverrideCursorTop) {
        $PromptCursorTop = $OverrideCursorTop
    }
    else {
        Write-Host ""
        $PromptCursorTop = [Console]::CursorTop
    }
    
    if ($Timeout -le 0) {
        # Instant/Static pause logic uses same TickAction renderer for consistency (0 elapsed)
        & $Global:TickAction -ElapsedTimespan ([timespan]::Zero) -ActionText $ActionText -Timeout 0 -PromptCursorTop $PromptCursorTop -SelectionChar $SelectionChar -PreActionWord $PreActionWord
        return $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }

    # Wrapper for dynamic tick
    $LocalTick = {
        param($Elapsed)
        & $Global:TickAction -ElapsedTimespan $Elapsed -ActionText $ActionText -Timeout $Timeout -PromptCursorTop $PromptCursorTop -SelectionChar $SelectionChar -PreActionWord $PreActionWord
    }

    $res = Wait-KeyPressWithTimeout -Seconds $Timeout -OnTick $LocalTick
    Write-Host ""
    return $res
}
