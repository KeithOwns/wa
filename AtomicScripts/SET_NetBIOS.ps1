param([switch]$Reverse)

$v = if ($Reverse) { 0 } else { 2 }
$adapters = Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration | Where-Object { $_.IPEnabled }
foreach ($a in $adapters) {
    Invoke-CimMethod -InputObject $a -MethodName SetTcpipNetbios -Arguments @{ TcpipNetbiosOptions = [uint32]$v } | Out-Null
    $regPath = "HKLM:\System\CurrentControlSet\Services\NetBT\Parameters\Interfaces\Tcpip_$($a.SettingID)"
    if (Test-Path $regPath) { Set-ItemProperty -Path $regPath -Name "NetbiosOptions" -Value $v -Type DWord -Force -ErrorAction SilentlyContinue }
}
