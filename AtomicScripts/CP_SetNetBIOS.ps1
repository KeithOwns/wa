<#
.SYNOPSIS
    Configures Control Panel / Disk Optimization setting (CP_SetNetBIOS).
.DESCRIPTION
    Applies security hardening or system configuration for CP_SetNetBIOS in the Windows environment.
.PARAMETER Reverse
    If specified, reverses or restores default system behavior.
.EXAMPLE
    .\CP_SetNetBIOS.ps1
#>
param([switch]$Reverse)

# UI Location: Network adapter Properties > IPv4 > Advanced > WINS tab

$v = if ($Reverse) { 0 } else { 2 }
$adapters = Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration | Where-Object { $_.IPEnabled }
foreach ($a in $adapters) {
    Invoke-CimMethod -InputObject $a -MethodName SetTcpipNetbios -Arguments @{ TcpipNetbiosOptions = [uint32]$v } | Out-Null
    $regPath = "HKLM:\System\CurrentControlSet\Services\NetBT\Parameters\Interfaces\Tcpip_$($a.SettingID)"
    if (Test-Path $regPath) { Set-ItemProperty -Path $regPath -Name "NetbiosOptions" -Value $v -Type DWord -Force -ErrorAction SilentlyContinue }
}

