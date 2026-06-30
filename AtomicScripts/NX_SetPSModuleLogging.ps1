param([switch]$Reverse)

# UI Location: none (registry/GPO-only)

$Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging"
$SubPath = "$Path\ModuleNames"

if ($Reverse) {
    Set-ItemProperty -Path $Path -Name "EnableModuleLogging" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
} else {
    if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
    Set-ItemProperty -Path $Path -Name "EnableModuleLogging" -Value 1 -Type DWord -Force
    if (-not (Test-Path $SubPath)) { New-Item -Path $SubPath -Force | Out-Null }
    Set-ItemProperty -Path $SubPath -Name "*" -Value "*" -Type String -Force
}
