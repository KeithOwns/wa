<#
.SYNOPSIS
    Sets the 'Notify me when a restart is required to finish updating' setting.
.DESCRIPTION
    Modifies 'RestartNotificationsAllowed2' in HKLM\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings.
.PARAMETER State
    'On', 'Off', or 'Toggle' (Default).
.PARAMETER NoWait
    Skips the "Press any key" pause.
#>
param([string]$State = "Toggle", [switch]$NoWait)

# Ensure script is running as Administrator
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "Run as Administrator required."
    if (-not $NoWait) { Start-Sleep -Seconds 5 }
    Exit
}

$regPath = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings"
$regName = "RestartNotificationsAllowed2"

if (-not (Test-Path $regPath)) { New-Item -Path $regPath -Force | Out-Null }

$current = (Get-ItemProperty -Path $regPath -Name $regName -ErrorAction SilentlyContinue).$regName
if ($null -eq $current) { $current = 0 }

$target = -1
if ($State -eq "On") { $target = 1 }
elseif ($State -eq "Off") { $target = 0 }
else { $target = if ($current -eq 1) { 0 } else { 1 } }

if ($current -ne $target) {
    if (-not (Get-ItemProperty -Path $regPath -Name $regName -ErrorAction SilentlyContinue)) {
        New-ItemProperty -Path $regPath -Name $regName -Value $target -PropertyType DWord -Force | Out-Null
    }
    else {
        Set-ItemProperty -Path $regPath -Name $regName -Value $target -Type DWord -Force
    }

    # Also restart Settings app to refresh UI if open
    Get-Process "SystemSettings" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    
    $msg = if ($target -eq 1) { "ON (Notify Restart)" } else { "OFF" }
    Write-Host "Success: 'Notify Restart' set to $msg." -ForegroundColor Green
}
else {
    Write-Host "No Change: 'Notify Restart' is already set to target." -ForegroundColor Gray
}

if (-not $NoWait) {
    Write-Host "`nPress any key to exit..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}
