<#
.SYNOPSIS
    Configures the PowerShell ExecutionPolicy to RemoteSigned.
.DESCRIPTION
    Ensures that local scripts can be executed while maintaining security for downloaded scripts.
    Standalone AtomicScript for the 'Execution' Infrastructure Setup phase.
.PARAMETER Reverse
    Sets the ExecutionPolicy back to Restricted.
#>
param(
    [Parameter(Mandatory = $false)]
    [Alias('r')]
    [switch]$Reverse,
    
    [switch]$Force
)

# --- BOILERPLATE ---
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# --- COLORS & ICONS ---
$Esc = [char]27
$Reset = "$Esc[0m"; $Bold = "$Esc[1m"; $FGYellow = "$Esc[93m"; $FGGreen = "$Esc[92m"; $FGRed = "$Esc[91m"; $FGGray = "$Esc[90m"
$Char_Check = "[v]"; $Char_X = "[x]"

# --- ADMIN CHECK ---
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "$FGRed CRITICAL: Administrator privileges required for this system-level change.$Reset"
    return
}

# --- STATUS DISCOVERY ---
$currentPolicy = Get-ExecutionPolicy -Scope LocalMachine
$targetPolicy = if ($Reverse) { "Restricted" } else { "RemoteSigned" }
$isMatched = $currentPolicy -eq $targetPolicy

# --- HEADER ---
Write-Host "`n$Bold$FGYellow --- EXECUTION POLICY CONFIGURATION --- $Reset"
Write-Host "$FGGray Current System Policy (LocalMachine): $currentPolicy$Reset"

# --- EXECUTION ---
if ($isMatched -and -not $Force) {
    Write-Host "$FGGreen $Char_Check State is already set to $targetPolicy. Skipping.$Reset`n"
    return
}

try {
    Write-Host "$FGGray Transitioning ExecutionPolicy to '$targetPolicy'... $Reset"
    Set-ExecutionPolicy -ExecutionPolicy $targetPolicy -Scope LocalMachine -Force
    Write-Host "$FGGreen $Char_Check Success: System ExecutionPolicy set to $targetPolicy.$Reset`n"
}
catch {
    Write-Host "$FGRed $Char_X Failed: $($_.Exception.Message)$Reset`n"
}
