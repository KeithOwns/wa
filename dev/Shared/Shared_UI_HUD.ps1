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