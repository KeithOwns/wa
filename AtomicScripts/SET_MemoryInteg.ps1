param([switch]$Reverse)

$Path = "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity"

if ($Reverse) {
    Set-ItemProperty -Path $Path -Name "Enabled" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
} else {
    if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
    Set-ItemProperty -Path $Path -Name "Enabled" -Value 1 -Type DWord -Force
    Set-ItemProperty -Path $Path -Name "WasEnabledBy" -Value 2 -Type DWord -Force -ErrorAction SilentlyContinue
}
