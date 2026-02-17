#Requires -RunAsAdministrator
<#
.SYNOPSIS
    System Hardening Check (Pre-Flight) - Extracted from wa.ps1
.DESCRIPTION
    Checks system uptime, disk space, and reboot pending status.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# --- SHARED FUNCTIONS ---
. "$PSScriptRoot\..\Shared\Shared_UI_Functions.ps1"

Write-Header "SYSTEM PRE-FLIGHT CHECK"

# 1. OS & Uptime
$os = Get-CimInstance Win32_OperatingSystem
Write-LeftAligned "$FGWhite OS: $($os.Caption) ($($os.Version))$Reset"
$uptime = (Get-Date) - $os.LastBootUpTime
$color = & { if ($uptime.Days -gt 7) { $FGRed } else { $FGGreen } }
Write-LeftAligned "$FGWhite Uptime: $color$($uptime.Days) days$Reset"

# 2. Disk Space (C:)
$drive = Get-Volume -DriveLetter C
$freeGB = [math]::Round($drive.SizeRemaining / 1GB, 2)
$dColor = & { if ($freeGB -lt 10) { $FGRed } else { $FGGreen } }
Write-LeftAligned "$FGWhite Free Space (C:): $dColor$freeGB GB$Reset"

# 3. Reboot Pending
$pending = $false
if (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending") { $pending = $true }
if ($pending) { Write-LeftAligned "$FGRed$Char_Warn REBOOT PENDING$Reset" } 
else { Write-LeftAligned "$FGGreen$Char_BallotCheck System Ready$Reset" }

Write-Host ""
Write-Boundary
Start-Sleep -Seconds 3
